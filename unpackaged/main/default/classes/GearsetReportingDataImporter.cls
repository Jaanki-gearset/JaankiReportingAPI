public with sharing class GearsetReportingDataImporter {
    public void executeImport() {
        DateTime lastDateTime = getNewStartTime();
        List<Gearset_Deployment__c> latestDetails = getLatestDetails(lastDateTime);
        saveData(latestDetails);
    }

    public DateTime getNewStartTime() {
        DateTime response = null;

        List<Gearset_Deployment__c> deployments = [SELECT Time_of_Deployment__c FROM Gearset_Deployment__c ORDER BY Time_of_Deployment__c DESC LIMIT 1];

        if (deployments.size() == 1) {
            response = deployments[0].Time_of_Deployment__c;
        }

        return response;
    }

    public List<Gearset_Deployment__c> getLatestDetails(Datetime lastDateTime) {
        List<Gearset_Deployment__c> results = new List<Gearset_Deployment__c>();
        Deployment data;

        if (lastDateTime == null) {
            lastDateTime = Datetime.now().addMonths(-6);
        }

        HttpRequest request = createReportingRequest(lastDateTime);
        Http http = new Http();
        HttpResponse response = http.send(request);

        data = (Deployment)JSON.deserialize(response.getBody().replace('"Date"', '"DeploymentDate"'), Deployment.class);

        if (data != null && data.Deployments != null) {
            System.debug('Found ' + data.Deployments.size() + ' records');
            for (DeploymentDetails thisDeployment : data.Deployments) {
                results.add(thisDeployment.convertToSObject());
            }
        }

        return results;
    }

    public void saveData(List<Gearset_Deployment__c> data) {
        insert data;
    }

    private HttpRequest createReportingRequest(DateTime lastDateTime) {
        HttpRequest req = new HttpRequest();
        String encodedStartDate = EncodingUtil.urlEncode(String.valueOf(lastDateTime).replace(' ', 'T'), 'UTF-8');
        String encodedEndDate = EncodingUtil.urlEncode(String.valueOf(Datetime.now()).replace(' ', 'T'), 'UTF-8');
        String url = 'deployment-frequency?StartDate=' + encodedStartDate + 'Z&EndDate=' + encodedEndDate + 'Z';
        req.setEndpoint('callout:Gearset_Reporting_API/' + url);
        req.setMethod('GET');
        req.setTimeout(120000);

        return req;
    }

    public class Deployment {
        List<DeploymentDetails> Deployments { get; set; }

        public Deployment() {
            Deployments = new List<DeploymentDetails>();
        }
    }

    public class DeploymentDetails {
        public String DeploymentId { get; set; }
        public String Status { get; set; }
        public String Name { get; set; }
        public String Owner { get; set; }
        public String TriggeredBy { get; set; }
        public DateTime DeploymentDate { get; set; }
        public String FriendlyName { get; set; }
        public String SourceUsername { get; set; }
        public String SourceMetadataLocationType { get; set; }
        public String TargetUsername { get; set; }
        public String TargetMetadataLocationType { get; set; }
        public String DeploymentType { get; set; }
        public Id SalesforceFinalDeploymentId { get; set; }

        public Gearset_Deployment__c convertToSObject() {
            Gearset_Deployment__c dbRecord = new Gearset_Deployment__c();            
            dbRecord.Name = this.Name.length() <= 80 ? this.Name : this.Name.substring(0, 80);
            dbRecord.Deployment_Id__c = this.DeploymentId;
            dbRecord.Friendly_Name__c = this.FriendlyName;
            dbRecord.Owner_Name__c = this.Owner;
            dbRecord.Salesforce_Final_Deployment_Id__c = this.SalesforceFinalDeploymentId;
            dbRecord.Source_Metadata_Location__c = this.SourceMetadataLocationType;
            dbRecord.Status__c = this.Status;
            dbRecord.Target_Metadata_Location__c = this.TargetMetadataLocationType;
            dbRecord.Target_Username__c = this.TargetUsername;
            dbRecord.Time_of_Deployment__c = this.DeploymentDate;
            dbRecord.Triggered_By__c = this.TriggeredBy;
            dbRecord.Type__c = this.DeploymentType;

            return dbRecord;
        }
    }
}