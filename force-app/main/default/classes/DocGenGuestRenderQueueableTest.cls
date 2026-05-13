@IsTest
private class DocGenGuestRenderQueueableTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'GuestRender Test Co', Industry = 'Technology');
    }

    private static Id createHtmlTemplate(String bodyHtml) {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'GuestRenderTpl ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name, Industry'
        );
        insert tmpl;

        ContentVersion cv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'body.html',
            VersionData = Blob.valueOf(bodyHtml),
            FirstPublishLocationId = tmpl.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Content_Version_Id__c = cv.Id,
            Is_Active__c = true
        );
        return tmpl.Id;
    }

    @IsTest
    static void happyPathCompletesJobAndStampsCv() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Id tmplId = createHtmlTemplate('<html><body><p>{Name}</p></body></html>');

        DocGen_Job__c job = new DocGen_Job__c(Status__c = 'Queued', Template__c = tmplId);
        insert job;

        Test.startTest();
        System.enqueueJob(new DocGenGuestRenderQueueable(job.Id, tmplId, acct.Id));
        Test.stopTest();

        job = [SELECT Status__c, Merged_PDF_CV__c FROM DocGen_Job__c WHERE Id = :job.Id];
        System.assertEquals('Completed', job.Status__c, 'Job should complete');
        System.assertNotEquals(null, job.Merged_PDF_CV__c, 'CV id should be stamped');
    }

    @IsTest
    static void failurePathRecordsError() {
        // Template with no active version → generateDocument throws → queueable's
        // catch block stamps Status__c='Failed' + Label__c.
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'BrokenTpl ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert tmpl;

        Account acct = [SELECT Id FROM Account LIMIT 1];
        DocGen_Job__c job = new DocGen_Job__c(Status__c = 'Queued', Template__c = tmpl.Id);
        insert job;

        Test.startTest();
        System.enqueueJob(new DocGenGuestRenderQueueable(job.Id, tmpl.Id, acct.Id));
        Test.stopTest();

        job = [SELECT Status__c, Label__c FROM DocGen_Job__c WHERE Id = :job.Id];
        System.assertEquals('Failed', job.Status__c, 'Job should land Failed');
        System.assertNotEquals(null, job.Label__c, 'Label__c should hold the error message');
    }
}
