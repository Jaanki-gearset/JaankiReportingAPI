public with sharing class GearsetChangeFailureDataImporter implements Queueable, Database.AllowsCallouts {
    private final List<String> ENVIRONMENT_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetChangeFailureDataImporter(List<String> envIds, Integer counter, Integer pastMonths) {
        this.ENVIRONMENT_IDS = envIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Change_Failed_PR__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.ENVIRONMENT_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetChangeFailureDataImporter(this.ENVIRONMENT_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Change_Failed_PR__c> getLatestDetails(Datetime lastDateTime) {
        List<GSR_Change_Failed_PR__c> results = new List<GSR_Change_Failed_PR__c>();
        Events data;

        HttpRequest request = createReportingRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);

        data = (Events)JSON.deserialize(response.getBody(), Events.class);

        if (data != null && data.Events != null) {
            for (DeploymentDetails thisDeployment : data.Events) {
                for (PullRequest pr : thisDeployment.PullRequests) {
                    results.add(pr.convertToSObject(thisDeployment.DeploymentId, this.ENVIRONMENT_IDS[this.INDEX_COUNTER]));
                }
            }
        }

        return results;
    }

    public void saveData(List<GSR_Change_Failed_PR__c> data) {
        insert data;
    }

    private HttpRequest createReportingRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');
        String url = 'change-failure-rate/' + this.ENVIRONMENT_IDS[this.INDEX_COUNTER] + '?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z';
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public class Events {
        List<DeploymentDetails> Events { get; set; }

        public Events() {
            Events = new List<DeploymentDetails>();
        }
    }

    public class DeploymentDetails {
        public String DeploymentId { get; set; }
        public DateTime Timestamp { get; set; }
        public List<PullRequest> PullRequests;

        public DeploymentDetails() {
            PullRequests = new List<PullRequest>();
        }
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

        public GSR_Change_Failed_PR__c convertToSObject(String deploymentId, String queriedEnvId) {
            GSR_Change_Failed_PR__c pr = new GSR_Change_Failed_PR__c();
            pr.Author_Name__c = this.AuthorName;
            pr.Author_User_Name__c = this.AuthorUsername;
            pr.Description__c = this.Description;
            pr.Gearset_Deployment__r = new Gearset_Deployment__c(Deployment_Id__c = deploymentId);
            pr.GS_Environment_Id__c = queriedEnvId;
            pr.Merged_At__c = this.MergedAt;
            pr.Number__c = this.PullRequestNumber;
            pr.Title__c = this.Title;
            pr.URL__c = this.Url;

            return pr;
        }
    }
}