public with sharing class GearsetChangeFailureStatsImporter implements Queueable, Database.AllowsCallouts {    
    private final String INTERVAL = 'Daily';
    /* should move this out into sommething like custom metadata & allow multiple environments to be provided*/
    private final List<String> ENVIRONMENT_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetChangeFailureStatsImporter(List<String> envIds, Integer counter, Integer pastMonths) {
        this.ENVIRONMENT_IDS = envIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Change_Failure_Summary__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.ENVIRONMENT_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetChangeFailureStatsImporter(this.ENVIRONMENT_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Change_Failure_Summary__c> getLatestDetails(Datetime lastDateTime) {
        Map<DateTime, GSR_Change_Failure_Summary__c> detailsMap = new Map<DateTime, GSR_Change_Failure_Summary__c>();
        List<GSR_Change_Failure_Summary__c> results = new List<GSR_Change_Failure_Summary__c>();
        SummaryResults responseData;

        HttpRequest request = createDeploymentStatsRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);

        responseData = (SummaryResults)JSON.deserialize(response.getBody().replace('"Date"', '"DeploymentDate"'), SummaryResults.class);

        if (responseData != null) {
            for (DeploymentDateSummary thisDate : responseData.NumberOfSuccessfulDeployments) {
                GSR_Change_Failure_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Change_Failure_Summary__c();
                }

                thisDaysDetails.Successful_Deployments__c = thisDate.Value;
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DeploymentDateSummary thisDate : responseData.NumberOfFailedDeployments) {
                GSR_Change_Failure_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Change_Failure_Summary__c();
                }

                thisDaysDetails.Unsuccessful_Deployments__c = thisDate.Value;
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DeploymentDateSummary thisDate : responseData.FailureRate) {
                GSR_Change_Failure_Summary__c thisDaysDetails;
                if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                    thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                }
                else {
                    thisDaysDetails = new GSR_Change_Failure_Summary__c();
                }

                thisDaysDetails.Daily_Failure_Rate__c = thisDate.Value * 100;
                
                detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
            }

            for (DateTime summaryDate : detailsMap.keySet()) {
                GSR_Change_Failure_Summary__c summary = detailsMap.get(summaryDate);
                summary.Date__c = summaryDate.dateGmt();
                summary.GS_Environment_Id__c = this.ENVIRONMENT_IDS[this.INDEX_COUNTER];
                if (summary.Daily_Failure_Rate__c == null) {
                    summary.Daily_Failure_Rate__c = 0.00;
                }
            }
        }

        return detailsMap.values();
    }

    private HttpRequest createDeploymentStatsRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');        
        String url = 'change-failure-rate/' + this.ENVIRONMENT_IDS[this.INDEX_COUNTER] + '/aggregate?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z&Interval=' + INTERVAL;
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public void saveData(List<GSR_Change_Failure_Summary__c> data) {
        insert data;
    }

    public class SummaryResults {
        public List<DeploymentDateSummary> NumberOfSuccessfulDeployments { get; set; }
        public List<DeploymentDateSummary> NumberOfFailedDeployments { get; set; }
        public List<DeploymentDateSummary> FailureRate { get; set; }
    }

    public class DeploymentDateSummary {
        public DateTime DeploymentDate { get; set; }
        public Decimal Value { get; set; } 
    }
}