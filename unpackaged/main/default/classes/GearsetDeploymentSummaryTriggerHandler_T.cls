@isTest
public class GearsetDeploymentSummaryTriggerHandler_T {
    @isTest
    private static void test_before_insert() {
        List<Gearset_Deployment_Summary__c> records = new List<Gearset_Deployment_Summary__c>();
        Gearset_Deployment_Summary__c thisRecord = new Gearset_Deployment_Summary__c();
        thisRecord.Date__c = Date.newInstance(13, 7, 2022);
        thisRecord.Cumulative_Successful_Deployments__c = 3;
        thisRecord.Cumulative_Failed_Deployments__c = 2;
        records.add(thisRecord);

        Test.startTest();
        GearsetDeploymentSummaryTriggerHandler.beforeInsert(records);
        Test.stopTest();

        System.assertEquals(3, thisRecord.Cumulative_Successful_Deployments__c, 'successful total incorrect');
        System.assertEquals(2, thisRecord.Cumulative_Failed_Deployments__c, 'failed total incorrect');
    }
}