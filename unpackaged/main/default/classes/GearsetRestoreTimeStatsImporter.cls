public with sharing class GearsetRestoreTimeStatsImporter implements Queueable, Database.AllowsCallouts {
    private final String INTERVAL = 'Daily';
    /* should move this out into sommething like custom metadata & allow multiple environments to be provided*/
    private final List<String> ENVIRONMENT_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetRestoreTimeStatsImporter(List<String> envIds, Integer counter, Integer pastMonths) {
        this.ENVIRONMENT_IDS = envIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Time_To_Restore_Summary__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.ENVIRONMENT_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetRestoreTimeStatsImporter(this.ENVIRONMENT_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Time_To_Restore_Summary__c> getLatestDetails(Datetime lastDateTime) {
        Map<DateTime, GSR_Time_To_Restore_Summary__c> detailsMap = new Map<DateTime, GSR_Time_To_Restore_Summary__c>();
        List<GSR_Time_To_Restore_Summary__c> results = new List<GSR_Time_To_Restore_Summary__c>();
        SummaryResults responseData;

        HttpRequest request = createDeploymentStatsRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);
        responseData = (SummaryResults)JSON.deserialize(response.getBody().replace('"Date"', '"DeploymentDate"'), SummaryResults.class);

        if (responseData != null) {
            for (DeploymentDateSummary thisDate : responseData.MeanTimeToRestore) {
                GSR_Time_To_Restore_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Time_To_Restore_Summary__c();
                }

                thisDaysDetails.Mean_Time_To_Restore__c = convertTimeSpanStringToDecimal(thisDate.Value);
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DeploymentDateSummary thisDate : responseData.MaxTimeToRestore) {
                GSR_Time_To_Restore_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Time_To_Restore_Summary__c();
                }

                thisDaysDetails.Max_Time_To_Restore__c = convertTimeSpanStringToDecimal(thisDate.Value);
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DeploymentDateSummary thisDate : responseData.MinTimeToRestore) {
                GSR_Time_To_Restore_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Time_To_Restore_Summary__c();
                }

                thisDaysDetails.Min_Time_To_Restore__c = convertTimeSpanStringToDecimal(thisDate.Value);
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DateTime summaryDate : detailsMap.keySet()) {
                GSR_Time_To_Restore_Summary__c summary = detailsMap.get(summaryDate);
                summary.GS_Environment_Id__c = this.ENVIRONMENT_IDS[this.INDEX_COUNTER];           
                summary.Date__c = summaryDate;     
            }
        }

        return detailsMap.values();
    }

    private HttpRequest createDeploymentStatsRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');        
        String url = 'time-to-restore/' + this.ENVIRONMENT_IDS[this.INDEX_COUNTER] + '/aggregate?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z&Interval=' + INTERVAL;
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    private Decimal convertTimeSpanStringToDecimal(String timeSpan) {
        Decimal result = 0;
        List<String> parts = timeSpan.split(':');
        Boolean positive = true;

        // there should be three
        if (parts.size() == 3) {            
            // check if there are days involved            
            if (parts[0].indexOf('.') > -1) {
                List<String> days = parts[0].split('\\.');                
                Decimal daysValue = Decimal.valueOf(days[0]);
                if (daysValue < 0) {
                    positive = false;
                }
                result += daysValue;

                if (positive) {
                    result += Decimal.valueOf(days[1]) / 24;
                }
                else {
                    result -= Decimal.valueOf(days[1]) / 24;
                }
            }
            else {
                result += Decimal.valueOf(parts[0]) / 24;
            }

            if (positive) {
                result += Decimal.valueOf(parts[1]) / 24 / 60;
                result += Decimal.valueOf(parts[2]) / 24 / 60 / 60;
            }
            else {
                result -= Decimal.valueOf(parts[1]) / 24 / 60;
                result -= Decimal.valueOf(parts[2]) / 24 / 60 / 60;
            }
        }
        
        return result;
    }

    public void saveData(List<GSR_Time_To_Restore_Summary__c> data) {
        insert data;
    }

    public class SummaryResults {
        public List<DeploymentDateSummary> MeanTimeToRestore { get; set; }
        public List<DeploymentDateSummary> MaxTimeToRestore { get; set; }
        public List<DeploymentDateSummary> MinTimeToRestore { get; set; }
    }

    public class DeploymentDateSummary {
        public DateTime DeploymentDate { get; set; }
        public String Value { get; set; }
    }
}