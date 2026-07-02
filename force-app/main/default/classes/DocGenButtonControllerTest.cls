/**
 * Tests for DocGenButtonController.
 *
 * The managed-package call is replaced with a mock Generator, and custom metadata
 * is injected via the configOverride seam (CMDT records cannot be DML-inserted in
 * tests). This exercises the full controller flow — config resolution, file
 * read-back, inline base64 vs. download-URL branches, and error handling — without
 * actually invoking Portwood DocGen.
 */
@IsTest
private class DocGenButtonControllerTest {
    private static final String OBJ = 'User';

    /** Mock that creates a real ContentVersion and returns its ids. */
    private class MockGenerator implements DocGenButtonController.Generator {
        public DocGenButtonController.GenResult generate(DocGenButtonController.GenRequest req) {
            ContentVersion cv = new ContentVersion(
                Title = String.isNotBlank(req.documentTitle) ? req.documentTitle : 'Mock Document',
                PathOnClient = 'Mock Document.pdf',
                VersionData = Blob.valueOf('%PDF-1.4 mock content')
            );
            insert cv;
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            DocGenButtonController.GenResult r = new DocGenButtonController.GenResult();
            r.success = true;
            r.contentVersionId = cv.Id;
            r.contentDocumentId = cv.ContentDocumentId;
            return r;
        }
    }

    /** Mock that reports a failure (e.g., template locked, merge error). */
    private class FailingGenerator implements DocGenButtonController.Generator {
        public DocGenButtonController.GenResult generate(DocGenButtonController.GenRequest req) {
            DocGenButtonController.GenResult r = new DocGenButtonController.GenResult();
            r.success = false;
            r.errorMessage = 'Simulated package failure.';
            return r;
        }
    }

    private static DocGen_Button__mdt cfg(String devName, String objectApi, String templateId, Boolean active) {
        return new DocGen_Button__mdt(
            DeveloperName = devName,
            MasterLabel = devName.replace('_', ' '),
            Object_API_Name__c = objectApi,
            Template_Id__c = templateId,
            Save_To_Record__c = false,
            Active__c = active,
            Sort_Order__c = 1
        );
    }

    @IsTest
    static void getButtons_returnsActiveConfigsForObject() {
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true),
            cfg('WO_Summary', OBJ, UserInfo.getUserId(), true),
            cfg('Other_Obj', 'Contact', UserInfo.getUserId(), true),
            cfg('Inactive_One', OBJ, UserInfo.getUserId(), false)
        };

        Test.startTest();
        List<DocGenButtonController.ButtonOption> opts = DocGenButtonController.getButtons(UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(2, opts.size(), 'Only active configs for the record object should be returned');
    }

    @IsTest
    static void getButtons_nullRecordId_returnsEmpty() {
        Test.startTest();
        List<DocGenButtonController.ButtonOption> opts = DocGenButtonController.getButtons((Id) null);
        Test.stopTest();
        System.assertEquals(0, opts.size(), 'Null recordId should yield no options');
    }

    @IsTest
    static void generate_smallFile_returnsBase64() {
        DocGenButtonController.generator = new MockGenerator();
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true)
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(UserInfo.getUserId(), 'WO_PDF');
        Test.stopTest();

        System.assertEquals(true, dto.success, 'Expected success');
        System.assertNotEquals(null, dto.base64Data, 'Small file should return base64');
        System.assertNotEquals(null, dto.downloadUrl, 'A servlet download URL is always provided');
        System.assertEquals('application/pdf', dto.mimeType, 'PDF mime expected');
        System.assert(dto.fileName.endsWithIgnoreCase('.pdf'), 'Filename should carry extension');
    }

    @IsTest
    static void generate_largeFile_returnsDownloadUrl() {
        DocGenButtonController.generator = new MockGenerator();
        DocGenButtonController.inlineDownloadMaxBytes = 1; // force the URL branch
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true)
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(UserInfo.getUserId(), 'WO_PDF');
        Test.stopTest();

        System.assertEquals(true, dto.success, 'Expected success');
        System.assertEquals(null, dto.base64Data, 'Large file should not return base64');
        System.assert(
            dto.downloadUrl != null && dto.downloadUrl.contains('/sfc/servlet.shepherd/version/download/'),
            'Large file should return a download servlet URL'
        );
    }

    @IsTest
    static void generate_unknownConfig_returnsError() {
        DocGenButtonController.generator = new MockGenerator();
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true)
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(UserInfo.getUserId(), 'DOES_NOT_EXIST');
        Test.stopTest();

        System.assertEquals(false, dto.success, 'Unknown config should fail');
        System.assert(dto.errorMessage.contains('No active DocGen Button'), 'Expected config-not-found message');
    }

    @IsTest
    static void generate_blankTemplateId_returnsError() {
        DocGenButtonController.generator = new MockGenerator();
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, null, true)
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(UserInfo.getUserId(), 'WO_PDF');
        Test.stopTest();

        System.assertEquals(false, dto.success, 'Blank template id should fail');
        System.assert(dto.errorMessage.contains('no Template Id'), 'Expected missing-template message');
    }

    @IsTest
    static void generate_packageFailure_returnsError() {
        DocGenButtonController.generator = new FailingGenerator();
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true)
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(UserInfo.getUserId(), 'WO_PDF');
        Test.stopTest();

        System.assertEquals(false, dto.success, 'Package failure should surface as error');
        System.assertEquals('Simulated package failure.', dto.errorMessage, 'Package error message should pass through');
    }

    /**
     * Exercises the default ServiceGenerator -> DocGenService path
     * (no mock injected) so the real package call and its error handling are covered.
     * A valid-format but non-existent Template Id makes the package call fail; the
     * generator catches it and the controller surfaces a graceful error. We assert on
     * the outcome, not a specific message, since the package controls the wording.
     */
    @IsTest
    static void generate_packagePath_handlesInvalidTemplateGracefully() {
        // Intentionally do NOT set DocGenButtonController.generator here.
        DocGenButtonController.configOverride = new List<DocGen_Button__mdt>{
            cfg('WO_PDF', OBJ, UserInfo.getUserId(), true) // valid Id format, not a real template
        };

        Test.startTest();
        DocGenButtonController.GenerateResultDTO dto = DocGenButtonController.generate(
            UserInfo.getUserId(),
            'WO_PDF'
        );
        Test.stopTest();

        System.assertEquals(false, dto.success, 'A non-existent template via the real package path should fail gracefully');
        System.assertNotEquals(null, dto.errorMessage, 'A user-facing error message should be returned');
    }
}
