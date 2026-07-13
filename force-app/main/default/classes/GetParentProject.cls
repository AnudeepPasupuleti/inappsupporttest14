@SuppressWarnings('PMD.AvoidGlobalModifier')
global class GetParentProject implements copado.ParameterExpressionCallable {
    global String execute(Id contextId) {
        return getProjectJson(contextId);
    }

    private String getProjectJson(Id jobStepId) {
        String projectKey = '';
        String projectName = '';
        if (jobStepId != null) {
            List<copado__JobStep__c> jobExecutionData = [
                Select Id,
                    copado__JobExecution__r.copado__Deployment__c,
                    copado__JobExecution__r.copado__Deployment__r.copado__Promotion__r.copado__Project__c,
                    copado__JobExecution__r.copado__Deployment__r.copado__Promotion__r.copado__Project__r.Name,
                    copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__c,
                    copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__r.copado__Project__c,
                    copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__r.copado__Project__r.Name,
                    copado__JobExecution__r.copado__ParentId__c
                FROM copado__JobStep__c WHERE Id = :jobStepId LIMIT 1
            ];
            if (!jobExecutionData.isEmpty() && jobExecutionData[0].copado__JobExecution__r.copado__Deployment__c != null) {
                projectKey  = jobExecutionData[0].copado__JobExecution__r.copado__Deployment__r.copado__Promotion__r.copado__Project__c;
                projectName = jobExecutionData[0].copado__JobExecution__r.copado__Deployment__r.copado__Promotion__r.copado__Project__r.Name;
            } else if (!jobExecutionData.isEmpty() && jobExecutionData[0].copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__c != null) {
                projectKey  = jobExecutionData[0].copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__r.copado__Project__c;
                projectName = jobExecutionData[0].copado__JobExecution__r.copado__UserStoryCommit__r.copado__User_Story__r.copado__Project__r.Name;
            } else {
                Map<String, String> result = getProjectFromTests(jobExecutionData);
                projectKey  = result.get('key');
                projectName = result.get('name');
            }
        }
        return JSON.serialize(new Map<String, String>{ 'projectKey' => projectKey, 'projectName' => projectName });
    }

    private Map<String, String> getProjectFromTests(List<copado__JobStep__c> jobExecutionData) {
        String testId = jobExecutionData[0].copado__JobExecution__r.copado__ParentId__c;

        if (String.isBlank(testId)) {
            return new Map<String, String>{ 'key' => '', 'name' => '' };
        }

        List<copado__Test__c> tests = [
            Select copado__User_Story__r.copado__Project__c,
                   copado__User_Story__r.copado__Project__r.Name
            from copado__Test__c where Id = :testId LIMIT 1
        ];

        if (!tests.isEmpty()) {
            return new Map<String, String>{
                'key'  => tests[0].copado__User_Story__r.copado__Project__c,
                'name' => tests[0].copado__User_Story__r.copado__Project__r.Name
            };
        }

        return new Map<String, String>{ 'key' => '', 'name' => '' };
    }
}