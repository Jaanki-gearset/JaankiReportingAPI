public with sharing class GearsetDeploymentStatsImporter implements Queueable, Database.AllowsCallouts {
    private final String INTERVAL = 'Daily';
    private final String GROUP_BY = 'Status';

    public void execute(QueueableContext context) {
        this.executeImport();
    }

    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<Gearset_Deployment_Summary__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);
    }

    public DateTime getNewStartTime() {
        DateTime response = null;

        List<Gearset_Deployment_Summary__c> deployments = [SELECT Date__c FROM Gearset_Deployment_Summary__c ORDER BY Date__c DESC LIMIT 1];

        if (deployments.size() == 1) {
            response = deployments[0].Date__c;
        }

        return response;
    }

    public List<Gearset_Deployment_Summary__c> getLatestDetails(Datetime lastDateTime) {
        Map<Date, Gearset_Deployment_Summary__c> detailsMap = new Map<Date, Gearset_Deployment_Summary__c>();
        List<Gearset_Deployment_Summary__c> results = new List<Gearset_Deployment_Summary__c>();
        ItemResults responseData;

        if (lastDateTime == null) {
            lastDateTime = Datetime.newInstance(2022, 1, 1);
        }

        HttpRequest request = createDeploymentStatsRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);

        responseData = (ItemResults)JSON.deserialize(response.getBody().replace('"Date"', '"DeploymentDate"'), ItemResults.class);

        if (responseData != null && responseData.Items != null) {
            for (Item thisItem : responseData.Items) {
                switch on thisItem.Field {
                    when 'Successful' {
                        for (Count thisCount : thisItem.Values) {
                            Gearset_Deployment_Summary__c deploymentStats;
                            Date thisDate = Date.newInstance(thisCount.DeploymentDate.year(), thisCount.DeploymentDate.month(), thisCount.DeploymentDate.day());
                            if (detailsMap.containsKey(thisDate) && detailsMap.get(thisDate) != null) {
                                deploymentStats = detailsMap.get(thisDate);
                            }
                            else {
                                deploymentStats = new Gearset_Deployment_Summary__c(Date__c = thisDate, Cumulative_Successful_Deployments__c = 0, Cumulative_Failed_Deployments__c = 0);
                            }

                            if (thisCount.Value != null) {
                                deploymentStats.Cumulative_Successful_Deployments__c += thisCount.Value;
                                detailsMap.put(thisDate, deploymentStats);
                            }
                        }
                    }

                    when 'Failed' {
                        for (Count thisCount : thisItem.Values) {
                            Gearset_Deployment_Summary__c deploymentStats;
                            Date thisDate = Date.newInstance(thisCount.DeploymentDate.year(), thisCount.DeploymentDate.month(), thisCount.DeploymentDate.day());
                            if (detailsMap.containsKey(thisDate) && detailsMap.get(thisDate) != null) {
                                deploymentStats = detailsMap.get(thisDate);
                            }
                            else {
                                deploymentStats = new Gearset_Deployment_Summary__c(Date__c = thisDate, Cumulative_Failed_Deployments__c = 0, Cumulative_Successful_Deployments__c = 0);
                            }

                            if (thisCount.Value != null) {
                                deploymentStats.Cumulative_Failed_Deployments__c += thisCount.Value;
                                detailsMap.put(thisDate, deploymentStats);
                            }
                        }
                    }
                }
            }
        }

        return detailsMap.values();
    }

    private HttpRequest createDeploymentStatsRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');        
        String url = 'deployment-frequency/aggregate?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z&Interval=' + INTERVAL + '&GroupBy=' + GROUP_BY;
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public void saveData(List<Gearset_Deployment_Summary__c> data) {
        insert data;
    }

    public class ItemResults {
        public List<Item> Items { get; set; }
    }

    public class Item {
        public String Field { get; set; }
        public List<Count> Values { get; set; } 
    }

    public class Count {
        public DateTime DeploymentDate { get; set; }
        public Integer Value { get; set; }
    }
}