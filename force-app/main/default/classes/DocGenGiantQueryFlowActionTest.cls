@IsTest
private class DocGenGiantQueryFlowActionTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'GQFA Test Co', Industry = 'Technology');
    }

    private static Id createSyncHtmlTemplate() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'GQFA Tpl ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name, Industry'
        );
        insert tmpl;

        ContentVersion cv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'body.html',
            VersionData = Blob.valueOf('<html><body><h1>{Name}</h1><p>{Industry}</p></body></html>'),
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
    static void syncPathReturnsContentDocumentId() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Id tmplId = createSyncHtmlTemplate();

        DocGenGiantQueryFlowAction.Request req = new DocGenGiantQueryFlowAction.Request();
        req.templateId = tmplId;
        req.recordId = acct.Id;
        req.saveToRecord = false;

        Test.startTest();
        List<DocGenGiantQueryFlowAction.Response> responses = DocGenGiantQueryFlowAction.generateDocument(
            new List<DocGenGiantQueryFlowAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request');
        DocGenGiantQueryFlowAction.Response r = responses[0];
        System.assertEquals(true, r.success, 'Sync path should succeed: ' + r.errorMessage);
        System.assertEquals(false, r.isGiantQuery, 'V1 config + small dataset = sync');
        System.assertNotEquals(null, r.contentDocumentId, 'CD id returned');
        System.assertNotEquals(null, r.contentVersionId, 'CV id returned');
    }

    @IsTest
    static void syncPathWithSaveToRecordLinksFile() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Id tmplId = createSyncHtmlTemplate();

        DocGenGiantQueryFlowAction.Request req = new DocGenGiantQueryFlowAction.Request();
        req.templateId = tmplId;
        req.recordId = acct.Id;
        req.saveToRecord = true;

        Test.startTest();
        List<DocGenGiantQueryFlowAction.Response> responses = DocGenGiantQueryFlowAction.generateDocument(
            new List<DocGenGiantQueryFlowAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, responses[0].success, 'Should succeed');
        // The link helper inserts a ContentDocumentLink — confirm one points to the record.
        List<ContentDocumentLink> cdls = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :acct.Id AND ContentDocumentId = :responses[0].contentDocumentId
        ];
        System.assert(!cdls.isEmpty(), 'CDL to the source record should exist');
    }

    @IsTest
    static void v3ConfigSmallDatasetTakesSyncPath() {
        // V3 JSON config triggers the scout-counts path (lines 88-108). With a
        // child count under 2000, giantRelationship stays null and falls through
        // to sync — exercising the configVersion>=3 branch without async setup.
        Account acct = [SELECT Id FROM Account LIMIT 1];
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'GQFA V3 ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = '{"version":3,"nodes":[{"relationshipName":"Contacts","fields":["LastName"]}]}'
        );
        insert tmpl;
        ContentVersion cv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'body.html',
            VersionData = Blob.valueOf('<html><body><h1>{Name}</h1></body></html>'),
            FirstPublishLocationId = tmpl.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Content_Version_Id__c = cv.Id,
            Is_Active__c = true
        );

        DocGenGiantQueryFlowAction.Request req = new DocGenGiantQueryFlowAction.Request();
        req.templateId = tmpl.Id;
        req.recordId = acct.Id;
        req.saveToRecord = false;

        Test.startTest();
        List<DocGenGiantQueryFlowAction.Response> responses = DocGenGiantQueryFlowAction.generateDocument(
            new List<DocGenGiantQueryFlowAction.Request>{ req }
        );
        Test.stopTest();

        DocGenGiantQueryFlowAction.Response r = responses[0];
        System.assertEquals(false, r.isGiantQuery, 'Under threshold = sync');
        System.assertEquals(true, r.success, 'Sync V3 path should succeed: ' + r.errorMessage);
    }

    @IsTest
    static void invalidTemplateIdSurfacesAsError() {
        // Valid Id shape, no template → load query returns empty → throws inside the action's try block.
        DocGenGiantQueryFlowAction.Request req = new DocGenGiantQueryFlowAction.Request();
        req.templateId = '001000000000000AAA'; // wrong sObject prefix but valid Id format
        req.recordId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        List<DocGenGiantQueryFlowAction.Response> responses = DocGenGiantQueryFlowAction.generateDocument(
            new List<DocGenGiantQueryFlowAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Bad template id should fail gracefully');
        System.assertNotEquals(null, responses[0].errorMessage, 'errorMessage populated');
    }
}
