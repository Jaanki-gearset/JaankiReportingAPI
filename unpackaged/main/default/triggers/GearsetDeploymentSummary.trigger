trigger GearsetDeploymentSummary on Gearset_Deployment_Summary__c (before insert) {
    switch on Trigger.operationType {
        when BEFORE_INSERT {
            GearsetDeploymentSummaryTriggerHandler.beforeInsert(Trigger.new);
        }
    }
}