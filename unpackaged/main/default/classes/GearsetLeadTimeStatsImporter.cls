public with sharing class GearsetLeadTimeStatsImporter implements Queueable, Database.AllowsCallouts {
    private final String INTERVAL = 'Daily';
    /* should move this out into sommething like custom metadata & allow multiple environments to be provided*/
    private final List<String> PIPELINE_IDS;
    private Integer INDEX_COUNTER;
    private final Integer PAST_MONTHS;

    public GearsetLeadTimeStatsImporter(List<String> pipelineIds, Integer counter, Integer pastMonths) {
        this.PIPELINE_IDS = pipelineIds;
        this.INDEX_COUNTER = counter;
        this.PAST_MONTHS = pastMonths;
    }

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<GSR_Lead_Time_Summary__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);

        if (this.INDEX_COUNTER < (this.PIPELINE_IDS.size() - 1)) {
            this.INDEX_COUNTER++;
            System.enqueueJob(new GearsetLeadTimeStatsImporter(this.PIPELINE_IDS, this.INDEX_COUNTER, this.PAST_MONTHS));
        }
    }

    public DateTime getNewStartTime() {
        // API requires Zulu time, so let's use GMT
        return DateTime.now().addMonths(this.PAST_MONTHS);
    }

    public List<GSR_Lead_Time_Summary__c> getLatestDetails(Datetime lastDateTime) {
        Map<DateTime, GSR_Lead_Time_Summary__c> detailsMap = new Map<DateTime, GSR_Lead_Time_Summary__c>();
        List<GSR_Lead_Time_Summary__c> results = new List<GSR_Lead_Time_Summary__c>();
        SummaryResults responseData;

        HttpRequest request = createDeploymentStatsRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);
        responseData = (SummaryResults)JSON.deserialize(response.getBody().replace('"Date"', '"DeploymentDate"'), SummaryResults.class);

        if (responseData != null) {
            for (Environment thisEnv : responseData.Environments) {
                for (DeploymentDateSummary thisDate : thisEnv.MeanTimeLeadTimeForChanges) {
                    GSR_Lead_Time_Summary__c thisDaysDetails;
                    if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                        thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                    }
                    else {
                        thisDaysDetails = new GSR_Lead_Time_Summary__c();
                    }

                    thisDaysDetails.Mean_Lead_Time__c = convertTimeSpanStringToDecimal(thisDate.Value);
                    
                    detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
                }

                for (DeploymentDateSummary thisDate : thisEnv.MaxTimeLeadTimeForChanges) {
                    GSR_Lead_Time_Summary__c thisDaysDetails;
                    if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                        thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                    }
                    else {
                        thisDaysDetails = new GSR_Lead_Time_Summary__c();
                    }

                    thisDaysDetails.Max_Lead_Time__c = convertTimeSpanStringToDecimal(thisDate.Value);
                    
                    detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
                }

                for (DeploymentDateSummary thisDate : thisEnv.MinTimeLeadTimeForChanges) {
                    GSR_Lead_Time_Summary__c thisDaysDetails;
                    if (detailsMap.containsKey(thisDate.DeploymentDate)) {
                        thisDaysDetails = detailsMap.get(thisDate.DeploymentDate);
                    }
                    else {
                        thisDaysDetails = new GSR_Lead_Time_Summary__c();
                    }

                    thisDaysDetails.Min_Lead_Time__c = convertTimeSpanStringToDecimal(thisDate.Value);
                    
                    detailsMap.put(thisDate.DeploymentDate, thisDaysDetails);
                }

                for (DateTime summaryDate : detailsMap.keySet()) {
                    GSR_Lead_Time_Summary__c summary = detailsMap.get(summaryDate);
                    summary.Date__c = summaryDate.dateGmt();
                    summary.GS_Environment_Id__c = thisEnv.EnvironmentId;
                    summary.Environment_Name__c = thisEnv.EnvironmentName;
                    summary.Source_Branch__c = thisEnv.SourceBranch;
                }
            }
        }

        return detailsMap.values();
    }

    private HttpRequest createDeploymentStatsRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');        
        String url = 'lead-time/' + this.PIPELINE_IDS[this.INDEX_COUNTER] + '/aggregate?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z&Interval=' + INTERVAL;
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

    public void saveData(List<GSR_Lead_Time_Summary__c> data) {
        insert data;
    }

    public class SummaryResults {
        public List<Environment> Environments { get; set; }
    }

    public class Environment {
        public List<DeploymentDateSummary> MeanTimeLeadTimeForChanges { get; set; }
        public List<DeploymentDateSummary> MaxTimeLeadTimeForChanges { get; set; }
        public List<DeploymentDateSummary> MinTimeLeadTimeForChanges { get; set; }
        public String EnvironmentName { get; set; }
        public String SourceBranch { get; set; }
        public String EnvironmentId { get; set; }
    }

    public class DeploymentDateSummary {
        public DateTime DeploymentDate { get; set; }
        public String Value { get; set; }
    }
}