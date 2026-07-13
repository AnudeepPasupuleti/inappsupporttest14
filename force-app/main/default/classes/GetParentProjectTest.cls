@IsTest
public with sharing class GetParentProjectTest {
    
    @TestSetup
    private static void makeData() {
        // Create test user with proper permissions
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser@example.com' + System.currentTimeMillis()
        );
        insert testUser;

        System.runAs(testUser) {
            // Assign Copado License
            copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
            copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
            userLicense.isCCMEnabled = true;
            userLicense.isCopadoEnabled = true;
            userLicense.userId = testUser.Id;
            copadoGlobalAPI.upsertCopadoLicense(userLicense);
            
            PermissionSetAssignment copadoPS = new PermissionSetAssignment();
            copadoPS.PermissionSetId = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Copado_User' LIMIT 1].Id;
            copadoPS.AssigneeId = testUser.Id;
            insert copadoPS;

            // Base Pipeline Setup
            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
                Name = 'Test Pipeline',
                copado__Active__c = true,
                copado__Platform__c = 'SFDX'
            );
            insert pipeline;

            copado__Project__c project = new copado__Project__c(
                Name = 'Test-Project', 
                copado__Deployment_Flow__c = pipeline.Id
            );
            insert project;

            // Create User Story (Needed for all scenarios ideally)
            copado__User_Story__c userStory = new copado__User_Story__c(
                copado__Status__c = 'Draft',
                copado__Project__c = project.Id
            );
            insert userStory;
            
            // Environment & Org Setup (Needed for Deployment scenario)
            copado__Environment__c env = new copado__Environment__c(Name = 'Test Env', copado__Type__c = 'Production/Developer', copado__Platform__c = 'SFDX');
            insert env;
            
            copado__Org__c credential = new copado__Org__c(
                Name = 'Test Credential',
                copado__Username__c = 'test@example.com',
                copado__Environment__c = env.Id
            );
            insert credential;
            copado__Git_Repository__c gitRepo = new copado__Git_Repository__c(Name = 'gitRepo');
            insert gitRepo;
            
            copado__Git_Backup__c gitSnapshotDev1 = new copado__Git_Backup__c(copado__Git_Repository__c = gitRepo.Id, copado__Org__c = credential.Id, copado__Branch__c = 'dev1');
            insert new List<copado__Git_Backup__c>{gitSnapshotDev1};

            copado__Git_Org_Commit__c snapshotCommit1 = new copado__Git_Org_Commit__c(
            copado__Git_Backup__c = gitSnapshotDev1.Id,
            copado__Org__c = credential.Id,
            copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8974',
            copado__Commit_Date__c = Date.today().addDays(-5),
            copado__Commit_Message__c = 'test 1',
            copado__Status__c = 'Complete'
        );
        insert snapshotCommit1;
        }
    }

   

    // TEST CASE 2: Context is a User Story Commit (Covers the first else-if)
    @IsTest
    public static void executeWithUserStoryCommitContext() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        copado__Project__c project = [SELECT Id, Name FROM copado__Project__c LIMIT 1];
        copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];
        copado__Git_Org_Commit__c gitSnapshot = [SELECT Id FROM copado__Git_Org_Commit__c LIMIT 1];

        System.runAs(testUser) {
            copado__User_Story_Commit__c usCommit = new copado__User_Story_Commit__c(
                copado__User_Story__c = userStory.Id,
                copado__External_Id__c = '123456789',
                copado__Snapshot_Commit__c = gitSnapshot.id
            );
            insert usCommit;

            copado__JobExecution__c jobExecution = new copado__JobExecution__c(
                copado__Status__c = 'In Progress',
                copado__UserStoryCommit__c = usCommit.Id
            );
            insert jobExecution;

            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__JobExecution__c = jobExecution.Id,
                copado__Type__c = 'Function'
            );
            insert jobStep;

            Test.startTest();
            String result = new GetParentProject().execute(jobStep.Id);
            Test.stopTest();

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
            System.assertEquals(project.Id,   (String) parsed.get('projectKey'),  'Should return Project Id as projectKey');
            System.assertEquals(project.Name, (String) parsed.get('projectName'), 'Should return Project Name as projectName');
        }
    }

    @IsTest
    public static void executeWithTestRecordContext() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        copado__Project__c project = [SELECT Id, Name FROM copado__Project__c LIMIT 1];
        copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];

        System.runAs(testUser) {
            copado__Test__c copadoTest = new copado__Test__c(
                Name = 'Unit Test 1',
                copado__User_Story__c = userStory.Id
            );
            insert copadoTest;

            copado__JobExecution__c jobExecution = new copado__JobExecution__c(
                copado__Status__c = 'In Progress',
                copado__ParentRecord_Id__c = copadoTest.Id
            );
            insert jobExecution;

            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__JobExecution__c = jobExecution.Id,
                copado__Type__c = 'Function'
            );
            insert jobStep;

            Test.startTest();
            String result = new GetParentProject().execute(jobStep.Id);
            Test.stopTest();

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
            System.assertEquals(project.Id,   (String) parsed.get('projectKey'),  'Should return Project Id as projectKey');
            System.assertEquals(project.Name, (String) parsed.get('projectName'), 'Should return Project Name as projectName');
        }
    }

    // TEST CASE 4: Context is Null (Safety check)
    @IsTest
    public static void executeWithNullContext() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];

        System.runAs(testUser) {
            Test.startTest();
            String result = new GetParentProject().execute(null);
            Test.stopTest();

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
            System.assertEquals('', (String) parsed.get('projectKey'),  'Should return empty projectKey for null input');
            System.assertEquals('', (String) parsed.get('projectName'), 'Should return empty projectName for null input');
        }
    }
}