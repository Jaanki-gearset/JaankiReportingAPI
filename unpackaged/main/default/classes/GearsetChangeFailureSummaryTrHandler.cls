public with sharing class GearsetChangeFailureSummaryTrHandler {
    // static variable to prevent recursion
    private static Boolean executed = false;

    public static void beforeInsert(List<GSR_Change_Failure_Summary__c> newRecords) {
        if (!executed) {
            executed = true;

            Decimal totalSuccess = 0, totalFailed = 0;
            Date earliestDate, previousDate;
            Map<Date, GSR_Change_Failure_Summary__c> allExistingRecords = new Map<Date, GSR_Change_Failure_Summary__c>();
            Map<Date, GSR_Change_Failure_Summary__c> allNewRecords = new Map<Date, GSR_Change_Failure_Summary__c>();
            List<GSR_Change_Failure_Summary__c> updatedRecordsNotInTrigger = new List<GSR_Change_Failure_Summary__c>();

            // get the earliest date from the new records
            for (GSR_Change_Failure_Summary__c thisSummary : newRecords) {
                if (earliestDate == null || thisSummary.Date__c < earliestDate) {
                    earliestDate = thisSummary.Date__c;
                }
            }

            if (earliestDate != null) {
                previousDate = earliestDate.addDays(-1);

                // need to get all records since this date, will only be one months' worth for now so that's fine
                List<GSR_Change_Failure_Summary__c> existingRecords = [SELECT Id, Successful_Deployments__c, Unsuccessful_Deployments__c, Daily_Failure_Rate__c, Cumulative_Successful_CF_Deployments__c, Cumulative_Unsuccessful_CF_Deployments__c, Date__c FROM GSR_Change_Failure_Summary__c WHERE Date__c >= :previousDate ORDER BY Date__c ASC];

                if (existingRecords.size() > 0) {
                    totalSuccess = existingRecords[0].Cumulative_Successful_CF_Deployments__c;
                    totalFailed = existingRecords[0].Cumulative_Unsuccessful_CF_Deployments__c;

                    for (GSR_Change_Failure_Summary__c thisRecord : existingRecords) {
                        allExistingRecords.put(thisRecord.Date__c, thisRecord);
                    }
                }
            }

            // the incoming records might not be ordered by date
            for (GSR_Change_Failure_Summary__c newRecord : newRecords) {
                allNewRecords.put(newRecord.Date__c, newRecord);
            }

            // now, we need to go over the new records again, and adjust all values any records
            Date iterationDate = earliestDate;
            while (iterationDate <= Date.today()) {
                if (allNewRecords.containsKey(iterationDate)) {
                    GSR_Change_Failure_Summary__c thisNewSummary = allNewRecords.get(iterationDate);
                    totalSuccess += thisNewSummary.Successful_Deployments__c;
                    totalFailed += thisNewSummary.Unsuccessful_Deployments__c;
                    thisNewSummary.Cumulative_Successful_CF_Deployments__c = totalSuccess;
                    thisNewSummary.Cumulative_Unsuccessful_CF_Deployments__c = totalFailed;
                    if (totalSuccess > 0 || totalFailed > 0) {
                        thisNewSummary.Running_Change_Failure_Percentage__c = (totalFailed / (totalSuccess + totalFailed)) * 100;
                    }
                    else {
                        thisNewSummary.Running_Change_Failure_Percentage__c = 0.00;
                    }
                }
                else if (allExistingRecords.containsKey(iterationDate)) {
                    GSR_Change_Failure_Summary__c thisExistingSummary = allExistingRecords.get(iterationDate);
                    totalSuccess += thisExistingSummary.Successful_Deployments__c;
                    totalFailed += thisExistingSummary.Unsuccessful_Deployments__c;
                    thisExistingSummary.Cumulative_Successful_CF_Deployments__c = totalSuccess;
                    thisExistingSummary.Cumulative_Unsuccessful_CF_Deployments__c = totalFailed;
                    if (totalSuccess > 0 || totalFailed > 0) {
                        thisExistingSummary.Running_Change_Failure_Percentage__c = (totalFailed / (totalSuccess + totalFailed)) * 100;
                    }
                    else {
                        thisExistingSummary.Running_Change_Failure_Percentage__c = 0.00;
                    }
                    updatedRecordsNotInTrigger.add(thisExistingSummary);
                }

                iterationDate = iterationDate.addDays(1);
            }

            insert updatedRecordsNotInTrigger;
        }
    }
}