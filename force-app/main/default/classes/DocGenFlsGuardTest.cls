/**
 * Coverage for DocGenFlsGuard — per-field FLS describe-check helper
 * used by every admin DML site to enforce the v2.0 hybrid CRUD/FLS
 * pattern (object Schema gate + per-field describe + SYSTEM_MODE DML).
 */
@IsTest
private class DocGenFlsGuardTest {
    @IsTest
    static void assertCreateable_happyPath_passesWithAllowlistedFields() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'FLS Probe Template');
        Set<String> fields = new Set<String>{ 'Name', 'Base_Object_API__c', 'Type__c' };
        // Should not throw — running test user has DocGen_Admin permset assigned
        // via TestDataFactory.assignAdminPermissionSet (called by all admin tests).
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertCreateable(t, fields);
        Test.stopTest();
        System.assert(true, 'assertCreateable did not throw for allowlisted createable fields');
    }

    @IsTest
    static void assertUpdateable_happyPath_passesWithAllowlistedFields() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'FLS Probe Template');
        Set<String> fields = new Set<String>{ 'Name', 'Is_Active__c' };
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertUpdateable(t, fields);
        Test.stopTest();
        System.assert(true, 'assertUpdateable did not throw for allowlisted updateable fields');
    }

    @IsTest
    static void assertCreateable_emptyAllowlist_onlyEnforcesObjectCRUD() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'Object-only Probe');
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertCreateable(t, new Set<String>());
        DocGenFlsGuard.assertCreateable(t, null);
        Test.stopTest();
        System.assert(true, 'assertCreateable with empty allowlist passes (object-level CRUD only)');
    }

    @IsTest
    static void assertUpdateable_emptyAllowlist_onlyEnforcesObjectCRUD() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'Object-only Probe');
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertUpdateable(t, new Set<String>());
        DocGenFlsGuard.assertUpdateable(t, null);
        Test.stopTest();
        System.assert(true, 'assertUpdateable with empty allowlist passes (object-level CRUD only)');
    }

    @IsTest
    static void assertCreateable_nullRecord_throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenFlsGuard.assertCreateable((SObject) null, new Set<String>{ 'Name' });
        } catch (DocGenException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('null record'),
                'Error message identifies null-record cause: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'assertCreateable should throw on null record');
    }

    @IsTest
    static void assertCreateable_unknownField_throws() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'Unknown Field Probe');
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenFlsGuard.assertCreateable(t, new Set<String>{ 'Name', 'No_Such_Field__c' });
        } catch (DocGenException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('No_Such_Field__c'),
                'Error message identifies missing field: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'assertCreateable should throw on unknown field name');
    }

    @IsTest
    static void assertUpdateable_unknownField_throws() {
        DocGen_Template__c t = new DocGen_Template__c(Name = 'Unknown Field Probe');
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenFlsGuard.assertUpdateable(t, new Set<String>{ 'No_Such_Field__c' });
        } catch (DocGenException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('No_Such_Field__c'),
                'Error message identifies missing field: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'assertUpdateable should throw on unknown field name');
    }

    @IsTest
    static void listOverloads_emptyListIsNoOp() {
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertCreateable((List<SObject>) null, new Set<String>{ 'Name' });
        DocGenFlsGuard.assertCreateable(new List<DocGen_Template__c>(), new Set<String>{ 'Name' });
        DocGenFlsGuard.assertUpdateable((List<SObject>) null, new Set<String>{ 'Name' });
        DocGenFlsGuard.assertUpdateable(new List<DocGen_Template__c>(), new Set<String>{ 'Name' });
        Test.stopTest();
        System.assert(true, 'List overloads with null/empty input are no-ops');
    }

    @IsTest
    static void listOverloads_nonEmptyListDelegatesToFirstRecord() {
        TestDataFactory.assignAdminPermissionSet();
        List<DocGen_Template__c> tpls = new List<DocGen_Template__c>{
            new DocGen_Template__c(Name = 'A'),
            new DocGen_Template__c(Name = 'B')
        };
        Test.startTest();
        DocGenFlsGuard.assertCreateable(tpls, new Set<String>{ 'Name' });
        DocGenFlsGuard.assertUpdateable(tpls, new Set<String>{ 'Name' });
        Test.stopTest();
        System.assert(true, 'List overloads enforce against the first record\'s SObjectType');
    }

    @IsTest
    static void assertAccessible_happyPath_passesWithAllowlistedFields() {
        TestDataFactory.assignAdminPermissionSet();
        Set<String> fields = new Set<String>{ 'Name', 'Base_Object_API__c', 'Query_Config__c', 'Header_Html__c' };
        Test.startTest();
        DocGenFlsGuard.assertAccessible(DocGen_Template__c.sObjectType, fields);
        Test.stopTest();
        System.assert(true, 'assertAccessible did not throw for allowlisted readable fields');
    }

    @IsTest
    static void assertAccessible_emptyAllowlist_onlyEnforcesObjectCRUD() {
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        DocGenFlsGuard.assertAccessible(DocGen_Template__c.sObjectType, new Set<String>());
        DocGenFlsGuard.assertAccessible(DocGen_Template__c.sObjectType, null);
        Test.stopTest();
        System.assert(true, 'assertAccessible with empty allowlist passes (object-level only)');
    }

    @IsTest
    static void assertAccessible_nullSObjectType_throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenFlsGuard.assertAccessible((Schema.SObjectType) null, new Set<String>{ 'Name' });
        } catch (DocGenException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('null SObjectType'),
                'Error message identifies null cause: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'assertAccessible should throw on null SObjectType');
    }

    @IsTest
    static void assertAccessible_unknownField_throws() {
        TestDataFactory.assignAdminPermissionSet();
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenFlsGuard.assertAccessible(
                DocGen_Template__c.sObjectType,
                new Set<String>{ 'Name', 'No_Such_Field__c' }
            );
        } catch (DocGenException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('No_Such_Field__c'),
                'Error message identifies missing field: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'assertAccessible should throw on unknown field name');
    }
}
