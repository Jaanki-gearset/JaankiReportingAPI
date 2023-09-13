public with sharing class GearsetLeadTimeDataImporter implements Queueable, Database.AllowsCallouts {
    /* should move this out into sommething like custom metadata & allow multiple environments to be provided*/
    private final List<String> PIPELINE_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetLeadTimeDataImporter(List<String> pipelineIds, Integer counter, Integer pastMonths) {
        this.PIPELINE_IDS = pipelineIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Lead_Time_PR__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.PIPELINE_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetLeadTimeDataImporter(this.PIPELINE_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Lead_Time_PR__c> getLatestDetails(Datetime lastDateTime) {
        List<GSR_Lead_Time_PR__c> results = new List<GSR_Lead_Time_PR__c>();
        Data data;

        HttpRequest request = createReportingRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);
        System.debug(response.getBody());
        data = (Data)JSON.deserialize(response.getBody().replace('"Number"', '"PullRequestNumber"'), Data.class);

        if (data != null && data.PullRequests != null) {
            for (PullRequest thisPr : Data.PullRequests) {
                results.add(thisPr.convertToSObject(this.PIPELINE_IDS[this.INDEX_COUNTER]));
            }
        }

        return results;
    }

    public void saveData(List<GSR_Lead_Time_PR__c> data) {
        insert data;
    }

    private HttpRequest createReportingRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');
        String url = 'lead-time/' + this.PIPELINE_IDS[this.INDEX_COUNTER] + '?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z';
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public class Data {
        public List<PullRequest> PullRequests { get; set; }

        public Data() {
            PullRequests = new List<PullRequest>();
        }
    }

    public class PullRequest {
        public String EnvironmentId { get; set; }
        public String EnvironmentName { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime MergedAt { get; set; }
        public DateTime DeploymentCompletedAt { get; set; }
        public String DeploymentId { get; set; }
        public String Title { get; set; }
        public Integer PullRequestNumber { get; set; }
        public String Description { get; set; }
        public String FeatureName { get; set; }
        public String AuthorName { get; set; }
        public String AuthorUsername { get; set; }
        public List<String> JiraTicketReference { get; set; }
        public List<Integer> AzureWorkItemIds { get; set; }
        
        public PullRequest() {
            JiraTicketReference = new List<String>();
            AzureWorkItemIds = new List<Integer>();
        }

        public GSR_Lead_Time_PR__c convertToSObject(String queriedPipelineId) {
            GSR_Lead_Time_PR__c pr = new GSR_Lead_Time_PR__c();
            List<String> adoIds = new List<String>();
            if (!this.AzureWorkItemIds.isEmpty()) {
                for (Integer awoId : this.AzureWorkItemIds) {
                    adoIds.add(String.valueOf(awoId));
                }                
            }
            pr.ADO_Ids__c = String.join(adoIds, ', ');
            pr.Author_Name__c = this.AuthorName;
            pr.Author_Username__c = this.AuthorUsername;
            pr.Created_At__c = this.CreatedAt;
            pr.Deployment_Completed_At__c = this.DeploymentCompletedAt;
            pr.Deployment_Id__c = this.DeploymentId;
            pr.Description__c = this.Description;
            pr.Environment_Name__c = this.EnvironmentName;
            pr.Feature_Name__c = this.FeatureName;
            pr.GS_Environment_Id__c = this.EnvironmentId;
            pr.Jira_IDs__c = String.join(this.JiraTicketReference, ', ');
            pr.Merged_At__c = this.MergedAt;
            pr.Number__c = this.PullRequestNumber;
            pr.Pipeline_Id__c = queriedPipelineId;
            pr.Title__c = this.Title;

            return pr;
        }
    }
}