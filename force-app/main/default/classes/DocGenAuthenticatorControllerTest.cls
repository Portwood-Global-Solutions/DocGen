// CxSAST: Test class — SOQL/DML findings are test data operations, not production code paths
@isTest
private class DocGenAuthenticatorControllerTest {
    private static final String VALID_HASH = 'a3f1c2b4d5e6f7081a2b3c4d5e6f70819a0b1c2d3e4f50617283940a1b2c3d4e';

    @testSetup
    static void setup() {
        TestDataFactory.assignAdminPermissionSet();

        Account acc = new Account(Name = 'Auth Test Account');
        insert acc;

        // Signature Request — verify-by-id endpoint queries by this Id
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Signer_Name__c = 'Auth Test',
            Signer_Email__c = 'auth@test.com',
            Source_Document_Id__c = '068000000000001AAA',
            Related_Record_Id__c = acc.Id,
            Secure_Token__c = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            Status__c = 'Sent'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        // Signer record (audit FK)
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Auth Signer',
            Signer_Email__c = 'auth-signer@test.com',
            Role_Name__c = 'Buyer',
            Secure_Token__c = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
            Status__c = 'Signed',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);
        // The audit row that both endpoints will find
        DocGen_Signature_Audit__c audit = new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer__c = signer.Id,
            Signer_Name__c = 'Auth Signer',
            Signer_Email__c = 'auth-signer@test.com',
            Signed_Date__c = Datetime.now(),
            IP_Address__c = '203.0.113.42',
            Consent_Captured__c = true,
            PIN_Verified_At__c = Datetime.now(),
            Document_Hash_SHA256__c = VALID_HASH
        );
        Database.insert(audit, AccessLevel.SYSTEM_MODE);
    }

    private static DocGen_Signature_Request__c getRequest() {
        return [SELECT Id FROM DocGen_Signature_Request__c LIMIT 1];
    }

    // =========================================================================
    // verifyDocument
    // =========================================================================

    @isTest
    static void testVerifyDocument_validHash() {
        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results = DocGenAuthenticatorController.verifyDocument(
            VALID_HASH
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Valid hash should match the inserted audit');
        DocGenAuthenticatorController.VerificationResult res = results[0];
        System.assertEquals(true, res.isValid, 'Audit row should be marked valid');
        System.assertEquals('Auth Signer', res.signerName);
        System.assertEquals('auth-signer@test.com', res.signerEmail);
        System.assertEquals(VALID_HASH, res.documentHash);
        System.assertEquals(true, res.consentCaptured);
        System.assertEquals('Authentic Document Verified', res.message);
        System.assertNotEquals(null, res.pinVerifiedAt);
    }

    @isTest
    static void testVerifyDocument_invalidFormat() {
        // Malformed inputs MUST NOT reach SOQL — verifyDocument returns an empty
        // list. The Document Verifier UI treats an empty list as "not verified".
        String tooLong = VALID_HASH + '0';
        System.assertEquals(
            0,
            DocGenAuthenticatorController.verifyDocument(tooLong).size(),
            '65-char input must be rejected'
        );
        System.assertEquals(0, DocGenAuthenticatorController.verifyDocument('').size(), 'Empty input must be rejected');
        System.assertEquals(
            0,
            DocGenAuthenticatorController.verifyDocument(null).size(),
            'Null input must be rejected'
        );

        String nonHex = 'g3f1c2b4d5e6f7081a2b3c4d5e6f70819a0b1c2d3e4f50617283940a1b2c3d4!';
        System.assertEquals(
            0,
            DocGenAuthenticatorController.verifyDocument(nonHex).size(),
            'Non-hex chars must be rejected'
        );

        String tooShort = VALID_HASH.substring(0, 63);
        System.assertEquals(
            0,
            DocGenAuthenticatorController.verifyDocument(tooShort).size(),
            '63-char input must be rejected'
        );
    }

    @isTest
    static void testVerifyDocument_notFound() {
        // Well-formed 64-hex but no matching audit — returns empty list.
        String unmatched = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results = DocGenAuthenticatorController.verifyDocument(
            unmatched
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Valid format but no match should return empty');
    }

    @isTest
    static void testVerifyDocument_multipleSignersSameDoc() {
        // A multi-signer document has one audit per signer, all sharing the
        // same Document_Hash_SHA256__c (the hash of the final stamped PDF).
        // verifyDocument MUST return every signer for the complete audit
        // trail — regression guard against the v1.99 LIMIT 1 bug where only
        // the first signer was returned.
        DocGen_Signature_Request__c req = getRequest();

        DocGen_Signer__c signer2 = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Second Signer',
            Signer_Email__c = 'signer2@test.com',
            Role_Name__c = 'Seller',
            Secure_Token__c = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            Status__c = 'Signed',
            Sort_Order__c = 2
        );
        Database.insert(signer2, AccessLevel.SYSTEM_MODE);

        DocGen_Signature_Audit__c audit2 = new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer__c = signer2.Id,
            Signer_Name__c = 'Second Signer',
            Signer_Email__c = 'signer2@test.com',
            Signed_Date__c = Datetime.now().addMinutes(2),
            IP_Address__c = '198.51.100.99',
            Consent_Captured__c = true,
            Document_Hash_SHA256__c = VALID_HASH
        );
        Database.insert(audit2, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results = DocGenAuthenticatorController.verifyDocument(
            VALID_HASH
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both signers of the multi-signer doc must be returned');
        // ORDER BY Signed_Date__c ASC — original audit was at now(), second at now()+2 min
        System.assertEquals('Auth Signer', results[0].signerName, 'First signer (earliest signed) returned first');
        System.assertEquals('Second Signer', results[1].signerName);
        System.assertEquals('Seller', results[1].roleName, 'roleName populated from Signer__r.Role_Name__c');
    }

    // =========================================================================
    // verifyByRequestId
    // =========================================================================

    @isTest
    static void testVerifyByRequestId_valid18() {
        DocGen_Signature_Request__c req = getRequest();
        // Salesforce 18-char Id — req.Id is already 18 chars in Apex
        System.assertEquals(18, String.valueOf(req.Id).length(), 'Id should be 18 chars');

        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results = DocGenAuthenticatorController.verifyByRequestId(
            req.Id
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find the one inserted audit');
        DocGenAuthenticatorController.VerificationResult r = results[0];
        System.assertEquals(true, r.isValid);
        System.assertEquals('Auth Signer', r.signerName);
        System.assertEquals('Buyer', r.roleName, 'Role from Signer__r should be populated');
        System.assertEquals(VALID_HASH, r.documentHash);
        System.assertEquals('Signature verified', r.message);
    }

    @isTest
    static void testVerifyByRequestId_invalidFormat() {
        // 14 chars (too short)
        List<DocGenAuthenticatorController.VerificationResult> r1 = DocGenAuthenticatorController.verifyByRequestId(
            '00112233445566'
        );
        System.assertEquals(0, r1.size(), '14-char input must return empty');

        // 19 chars (too long)
        List<DocGenAuthenticatorController.VerificationResult> r2 = DocGenAuthenticatorController.verifyByRequestId(
            '0011223344556677889'
        );
        System.assertEquals(0, r2.size(), '19-char input must return empty');

        // 18 chars with special characters (not alphanumeric)
        List<DocGenAuthenticatorController.VerificationResult> r3 = DocGenAuthenticatorController.verifyByRequestId(
            '001122334455667!@#'
        );
        System.assertEquals(0, r3.size(), 'Special chars must return empty');

        // null
        List<DocGenAuthenticatorController.VerificationResult> r4 = DocGenAuthenticatorController.verifyByRequestId(
            null
        );
        System.assertEquals(0, r4.size(), 'Null must return empty');

        // empty string
        List<DocGenAuthenticatorController.VerificationResult> r5 = DocGenAuthenticatorController.verifyByRequestId('');
        System.assertEquals(0, r5.size(), 'Empty must return empty');

        // SOQL injection attempt — ' OR ' in the middle, length matched to 18
        List<DocGenAuthenticatorController.VerificationResult> r6 = DocGenAuthenticatorController.verifyByRequestId(
            '001\' OR Id != \'X'
        );
        System.assertEquals(0, r6.size(), 'Injection attempt must be rejected by validator');
    }

    @isTest
    static void testVerifyByRequestId_notFound() {
        // Well-formed but unused 15-char alphanumeric Id
        Test.startTest();
        List<DocGenAuthenticatorController.VerificationResult> results = DocGenAuthenticatorController.verifyByRequestId(
            'a0B000000000ABC'
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Valid format with no match should return empty list');
    }
}
