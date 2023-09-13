public with sharing class GearsetDeploymentSummaryTriggerHandler {
    public static void beforeInsert(List<Gearset_Deployment_Summary__c> newRecords) {
        Map<Date, Gearset_Deployment_Summary__c> recordMap = new Map<Date, Gearset_Deployment_Summary__c>();
        List<Date> sortedDateList = new List<Date>();

        for (Gearset_Deployment_Summary__c thisRecord : newRecords) {
            recordMap.put(thisRecord.Date__c, thisRecord);
            sortedDateList.add(thisRecord.Date__c);
        }

        sortedDateList.sort();
        Decimal currentSuccessTotal = 0, currentFailedTotal = 0;

        List<Gearset_Deployment_Summary__c> prevRecords = [SELECT Date__c, Cumulative_Successful_Deployments__c, Cumulative_Failed_Deployments__c FROM Gearset_Deployment_Summary__c ORDER BY Date__c DESC LIMIT 1];

        if (prevRecords.size() == 1) {
            currentSuccessTotal = prevRecords[0].Cumulative_Successful_Deployments__c;
            currentFailedTotal = prevRecords[0].Cumulative_Failed_Deployments__c;
        }

        for (Date thisDeploymentDate : sortedDateList) {
            Gearset_Deployment_Summary__c thisDeployment = recordMap.get(thisDeploymentDate);

            thisDeployment.Cumulative_Successful_Deployments__c += currentSuccessTotal;
            thisDeployment.Cumulative_Failed_Deployments__c += currentFailedTotal;

            currentSuccessTotal = thisDeployment.Cumulative_Successful_Deployments__c;
            currentFailedTotal = thisDeployment.Cumulative_Failed_Deployments__c;
        }
    }
}