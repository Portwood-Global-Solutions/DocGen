/**
 * Tests for DocGenButtonAdminController — the Command Hub button builder's
 * server side. The Metadata API deploy itself is a no-op in test context
 * (custom metadata can't be deployed during a test), so saveButtonConfig is
 * exercised for validation + build-up only; the read/describe helpers and the
 * dev-name sanitizer are covered directly.
 */
@IsTest
private class DocGenButtonAdminControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createStandardTestData(); // assigns DocGen_Admin to the running user
    }

    @IsTest
    static void getters_returnDataWithoutError() {
        Test.startTest();
        List<DocGenButtonAdminController.ButtonConfigDTO> cfgs = DocGenButtonAdminController.getButtonConfigs();
        List<DocGenButtonAdminController.Option> tpls = DocGenButtonAdminController.getTemplateOptions();
        List<DocGenButtonAdminController.Option> rts = DocGenButtonAdminController.getObjectRecordTypes('Account');
        List<DocGenButtonAdminController.Option> none = DocGenButtonAdminController.getObjectRecordTypes(null);
        List<DocGenButtonAdminController.Option> bogus = DocGenButtonAdminController.getObjectRecordTypes(
            'No_Such_Obj__x'
        );
        Test.stopTest();

        System.assertNotEquals(null, cfgs, 'Button configs list should be returned');
        System.assertNotEquals(null, tpls, 'Template options should be returned');
        System.assertNotEquals(null, rts, 'Record-type options should be returned (possibly empty)');
        System.assertEquals(0, none.size(), 'A blank object yields no record types');
        System.assertEquals(0, bogus.size(), 'An unknown object yields no record types');
    }

    @IsTest
    static void saveButtonConfig_validDto_deployIsNoOpInTest() {
        // Map param (as the LWC sends it) — sortOrder deliberately a STRING to prove
        // it no longer breaks the whole bind (the "An object is required" bug).
        Map<String, Object> cfg = new Map<String, Object>{
            'label' => 'Test Invoice Button',
            'objectApiName' => 'Account',
            'templateApiName' => 'Some_Template_Key',
            'documentTitle' => 'Invoice for {Name}',
            'saveToRecord' => true,
            'active' => true,
            'sortOrder' => '3',
            'recordTypeDeveloperNames' => 'Standard'
        };

        Test.startTest();
        Id jobId = DocGenButtonAdminController.saveButtonConfig(cfg);
        Test.stopTest();

        System.assertEquals(null, jobId, 'Metadata deploy is skipped in test context (returns null)');
    }

    @IsTest
    static void saveButtonConfig_missingObject_throws() {
        assertThrows(new Map<String, Object>{ 'label' => 'X', 'templateApiName' => 'K' }, 'object');
    }

    @IsTest
    static void saveButtonConfig_missingTemplate_throws() {
        assertThrows(new Map<String, Object>{ 'label' => 'X', 'objectApiName' => 'Account' }, 'template');
    }

    @IsTest
    static void saveButtonConfig_missingLabel_throws() {
        assertThrows(new Map<String, Object>{ 'objectApiName' => 'Account', 'templateApiName' => 'K' }, 'label');
    }

    @IsTest
    static void sanitizeDevName_variants() {
        System.assertEquals('My_Button', DocGenButtonAdminController.sanitizeDevName('My Button'));
        System.assertEquals('B_123abc', DocGenButtonAdminController.sanitizeDevName('123abc'));
        System.assertEquals('A_b_c', DocGenButtonAdminController.sanitizeDevName('A!!b@@c'));
        System.assertEquals(null, DocGenButtonAdminController.sanitizeDevName('   '));
        System.assertEquals(null, DocGenButtonAdminController.sanitizeDevName(null));
    }

    private static void assertThrows(Map<String, Object> cfg, String context) {
        // NOTE: AuraHandledException.getMessage() returns "Script-thrown exception"
        // in test context, so we assert that a validation error is raised rather
        // than on its wording (the user-facing messages are asserted by hand-review).
        Boolean threw = false;
        try {
            DocGenButtonAdminController.saveButtonConfig(cfg);
        } catch (Exception e) {
            threw = true;
        }
        System.assert(threw, 'Expected a validation error for missing ' + context);
    }
}
