public with sharing class GearsetImporterOrchestrator implements Schedulable {
    public void execute(SchedulableContext context) {
        // get all pipelines and environments
        List<Gearset_Pipeline__mdt> pipelines = [SELECT Pipeline_ID__c FROM Gearset_Pipeline__mdt];
        List<Gearset_Environment__mdt> environments = [SELECT Environment_Id__c FROM Gearset_Environment__mdt];
        List<Gearset_Reporting_Options__mdt> options = [SELECT Months_To_Retrieve__c FROM Gearset_Reporting_Options__mdt WHERE DeveloperName = 'Standard_Options'];
        List<String> pipelineIds = new List<String>(), environmentIds = new List<String>();
        Integer pastMonths = 1;
        for (Gearset_Pipeline__mdt pipeline : pipelines) {
            pipelineIds.add(pipeline.Pipeline_ID__c);
        }
        for (Gearset_Environment__mdt environment : environments) {
            environmentIds.add(environment.Environment_Id__c);
        }
        if (options != null && options.size() == 1) {
            pastMonths = Integer.valueOf(options[0].Months_To_Retrieve__c);
        }
        pastMonths = pastMonths * -1;

        // others refer to this data, so do this one synchronously
        GearsetReportingDataImporter grImporter = new GearsetReportingDataImporter();
        grImporter.executeImport();
        GearsetDeploymentStatsImporter deploymentSummaryImporter = new GearsetDeploymentStatsImporter();
        System.enqueueJob(deploymentSummaryImporter);
        GearsetChangeFailureDataImporter cfrImporter = new GearsetChangeFailureDataImporter(environmentIds, 0, pastMonths);
        System.enqueueJob(cfrImporter);
        GearsetChangeFailureStatsImporter cfrSummaryImporter = new GearsetChangeFailureStatsImporter(environmentIds, 0, pastMonths);
        System.enqueueJob(cfrSummaryImporter);
        GearsetLeadTimeDataImporter ltImporter = new GearsetLeadTimeDataImporter(pipelineIds, 0, pastMonths);
        System.enqueueJob(ltImporter);
        GearsetLeadTimeStatsImporter ltsImporter = new GearsetLeadTimeStatsImporter(pipelineIds, 0, pastMonths);
        System.enqueueJob(ltsImporter);
        GearsetRestoreTimeDataImporter rtImporter = new GearsetRestoreTimeDataImporter(environmentIds, 0, pastMonths);
        System.enqueueJob(rtImporter);
        GearsetRestoreTimeStatsImporter rtsImporter = new GearsetRestoreTimeStatsImporter(environmentIds, 0, pastMonths);
        System.enqueueJob(rtsImporter);

        /*List<Gearset_Deployment__c> gd = [SELECT Id FROM Gearset_Deployment__c];
        delete gd;
        List<Gearset_Deployment_Summary__c> gds = [SELECT Id FROM Gearset_Deployment_Summary__c];
        delete gds;
        List<GSR_Change_Failed_PR__c> cfp = [SELECT Id FROM GSR_Change_Failed_PR__c];
        delete cfp;
        List<GSR_Change_Failure_Summary__c> cfs = [SELECT Id FROM GSR_Change_Failure_Summary__c];
        delete cfs;
        List<GSR_Lead_Time_PR__c> ltp = [SELECT Id FROM GSR_Lead_Time_PR__c];
        delete ltp;
        List<GSR_Lead_Time_Summary__c> lts = [SELECT Id FROM GSR_Lead_Time_Summary__c];
        delete lts;
        List<GSR_Time_To_Restore_PR__c> ttrp = [SELECT Id FROM GSR_Time_To_Restore_PR__c];
        delete ttrp;
        List<GSR_Time_To_Restore_Summary__c> ttrs = [SELECT Id FROM GSR_Time_To_Restore_Summary__c];
        delete ttrs;*/
    }
}