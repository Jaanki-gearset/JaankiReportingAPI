trigger GearsetChangeFailureSummary on GSR_Change_Failure_Summary__c (before insert, before update) {
    switch on Trigger.operationType {
        when BEFORE_INSERT, BEFORE_UPDATE {
            GearsetChangeFailureSummaryTrHandler.beforeInsert(Trigger.new);
        }
    }
}