@isTest
public class GearsetDeploymentSummaryTrigger_Test {
    @isTest
    private static void before_insert_triggered_correctly() {
        Gearset_Deployment_Summary__c record = new Gearset_Deployment_Summary__c();
        record.Date__c = Date.newInstance(2021, 7, 2);
        record.Cumulative_Successful_Deployments__c = 3;
        record.Cumulative_Failed_Deployments__c = 1;
        
        Test.startTest();
        insert record;
        Test.stopTest();

        System.assertEquals(3, record.Cumulative_Successful_Deployments__c, 'successful value incorrect');
        System.assertEquals(1, record.Cumulative_Failed_Deployments__c, 'failed value incorrect');
    }
}