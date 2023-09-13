public with sharing class GearsetRestoreTimeDataImporter implements Queueable, Database.AllowsCallouts {
    /* should move this out into sommething like custom metadata & allow multiple environments to be provided*/
    private final List<String> ENVIRONMENT_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetRestoreTimeDataImporter(List<String> envIds, Integer counter, Integer pastMonths) {
        this.ENVIRONMENT_IDS = envIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Time_To_Restore_PR__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.ENVIRONMENT_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetRestoreTimeDataImporter(this.ENVIRONMENT_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Time_To_Restore_PR__c> getLatestDetails(Datetime lastDateTime) {
        List<GSR_Time_To_Restore_PR__c> results = new List<GSR_Time_To_Restore_PR__c>();
        Data data;

        HttpRequest request = createReportingRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);        
        System.debug(response.getBody());
        System.debug(response.getBody().replace('"Number"', '"PullRequestNumber"').replace('"Type"', '"PRType"'));
        data = (Data)JSON.deserialize(response.getBody().replace('"Number"', '"PullRequestNumber"').replace('"Type"', '"PRType"'), Data.class);
        System.debug(data);
        if (data.Events != null) {
            for (Event thisEvent : data.Events) {
                if (thisEvent.Failure != null) {
                    Failure failureDetails = thisEvent.Failure;
                    for (PullRequest thisFailurePr : thisEvent.Failure.PullRequests) {
                        GSR_Time_To_Restore_PR__c failurePr = new GSR_Time_To_Restore_PR__c();
                        failurePr.Type__c = failureDetails.PRType;
                        failurePr.Deployment_Id__c = failureDetails.DeploymentId;
                        failurePr.Deployment_Time__c = failureDetails.Timestamp;
                        failurePr.Merged_At__c = thisFailurePr.MergedAt;
                        failurePr.PR_Created_At__c = thisFailurePr.CreatedAt;
                        failurePr.Author_Username__c = thisFailurePr.AuthorUsername;
                        failurePr.Author_Name__c = thisFailurePr.AuthorName;
                        failurePr.Description__c = thisFailurePr.Description;
                        failurePr.Title__c = thisFailurePr.Title;
                        failurePr.Number__c = thisFailurePr.PullRequestNumber;
                        failurePr.URL__c = thisFailurePr.Url;

                        results.add(failurePr);
                    }
                }

                if (thisEvent.Success != null) {
                    Success successDetails = thisEvent.Success;
                    for (PullRequest thisSuccessPr : thisEvent.Success.PullRequests) {
                        GSR_Time_To_Restore_PR__c successPr = new GSR_Time_To_Restore_PR__c();
                        successPr.Type__c = successDetails.PRType;
                        successPr.Deployment_Id__c = successDetails.DeploymentId;
                        successPr.Deployment_Time__c = successDetails.Timestamp;
                        successPr.Merged_At__c = thisSuccessPr.MergedAt;
                        successPr.PR_Created_At__c = thisSuccessPr.CreatedAt;
                        successPr.Author_Username__c = thisSuccessPr.AuthorUsername;
                        successPr.Author_Name__c = thisSuccessPr.AuthorName;
                        successPr.Description__c = thisSuccessPr.Description;
                        successPr.Title__c = thisSuccessPr.Title;
                        successPr.Number__c = thisSuccessPr.PullRequestNumber;
                        successPr.URL__c = thisSuccessPr.Url;

                        results.add(successPr);
                    }
                }
            }
        }

        return results;
    }

    public void saveData(List<GSR_Time_To_Restore_PR__c> data) {
        insert data;
    }

    private HttpRequest createReportingRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');
        String url = 'time-to-restore/' + this.ENVIRONMENT_IDS[this.INDEX_COUNTER] + '?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z';
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public class Data {
        public List<Event> Events { get; set; }
    }

    public class Event {
        public Failure Failure { get; set; }
        public Success Success { get; set; }
    }

    public class Failure {
        public String PRType { get; set; }
        public String DeploymentId { get; set; }
        public DateTime Timestamp { get; set; }
        public List<PullRequest> PullRequests { get; set; }
    }

    public class Success {
        public String PRType { get; set; }
        public String DeploymentId { get; set; }
        public DateTime Timestamp { get; set; }
        public List<PullRequest> PullRequests { get; set; }
    }

    public class PullRequest {
        public DateTime MergedAt { get; set; }
        public DateTime CreatedAt { get; set; }
        public String AuthorUsername { get; set; }
        public String AuthorName { get; set; }
        public String Description { get; set; }
        public String Title { get; set; }
        public Integer PullRequestNumber { get; set; }
        public String Url { get; set; }
    }
}