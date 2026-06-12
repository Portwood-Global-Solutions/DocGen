// CxSAST: Test class — SOQL/DML findings are test data operations, not production code paths
@isTest
private class DocGenSignaturePdfTests {
    // 64-char hex tokens (the only valid Secure_Token__c shape).
    private static final String SIGNER_TOKEN = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    private static final String FOREIGN_TOKEN = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'PDF Sign Test Co');
        insert acc;

        // The pre-generated document the signer will see (bound via Source_Document_Id__c).
        ContentVersion pdfCv = new ContentVersion(
            Title = 'Generated Agreement',
            PathOnClient = 'agreement.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 fake pdf bytes')
        );
        insert pdfCv;
        pdfCv = [SELECT Id FROM ContentVersion WHERE Id = :pdfCv.Id LIMIT 1];

        // A SECOND, unrelated CV — used to prove the token cannot reach a foreign file.
        ContentVersion foreignCv = new ContentVersion(
            Title = 'Someone Elses File',
            PathOnClient = 'secret.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 confidential')
        );
        insert foreignCv;
        foreignCv = [SELECT Id FROM ContentVersion WHERE Id = :foreignCv.Id LIMIT 1];

        // Template__c-null request bound to the generated PDF.
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Source_Document_Id__c = pdfCv.Id,
            Related_Record_Id__c = acc.Id,
            Status__c = 'Sent',
            Signing_Order__c = 'Parallel'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);

        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Pat Signer',
            Signer_Email__c = 'pat@test.com',
            Role_Name__c = 'Signer',
            Secure_Token__c = SIGNER_TOKEN,
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);

        // A foreign request/signer bound to the foreign CV — its token must NOT be
        // able to read this request's source PDF, and vice versa.
        DocGen_Signature_Request__c foreignReq = new DocGen_Signature_Request__c(
            Source_Document_Id__c = foreignCv.Id,
            Related_Record_Id__c = acc.Id,
            Status__c = 'Sent'
        );
        Database.insert(foreignReq, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c foreignSigner = new DocGen_Signer__c(
            Signature_Request__c = foreignReq.Id,
            Signer_Name__c = 'Foreign Signer',
            Signer_Email__c = 'foreign@test.com',
            Secure_Token__c = FOREIGN_TOKEN,
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        Database.insert(foreignSigner, AccessLevel.SYSTEM_MODE);
    }

    private static DocGen_Signer__c getSigner(String token) {
        return [
            SELECT Id, Secure_Token__c, Status__c, Signature_Request__c, PIN_Verified_At__c
            FROM DocGen_Signer__c
            WHERE Secure_Token__c = :token
            LIMIT 1
        ];
    }

    /**
     * An active Guest user to exercise true guest context, or null if the org
     * has no Site (some package-build orgs). Callers fall back to the current
     * user so the test never fails merely for lack of a guest user.
     */
    private static User getGuestUser() {
        List<User> guests = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = TRUE LIMIT 1];
        return guests.isEmpty() ? null : guests[0];
    }

    // =========================================================================
    // Guest-context regression
    // validateToken on the PDF (Source_Document_Id__c) path must NOT fail when
    // the optional public preview link can't be created. getOrCreatePublicLink
    // inserts a ContentDistribution, which a guest user cannot create — that's a
    // user permission, NOT bypassed by SYSTEM_MODE. Before the validateSignerToken
    // try/catch, this threw and surfaced as the page's "no longer active" error
    // for every guest. Strongest where a real guest user exists (scratch/Site
    // orgs); harmless where one doesn't.
    // =========================================================================
    @isTest
    static void testGuestContext_validateToken_pdfPath_survivesPublicLinkFailure() {
        DocGenSignatureController.SignatureInitResponse res;
        User guest = getGuestUser();

        Test.startTest();
        if (guest != null) {
            System.runAs(guest) {
                res = DocGenSignatureController.validateToken(SIGNER_TOKEN);
            }
        } else {
            res = DocGenSignatureController.validateToken(SIGNER_TOKEN);
        }
        Test.stopTest();

        System.assertEquals(
            true,
            res.isValid,
            'PDF-path token must validate even when the public preview link cannot be created (guest cannot insert ContentDistribution)'
        );
        System.assertEquals('Pat Signer', res.signerName);
    }

    // =========================================================================
    // A1 — getSourcePdfBase64
    // =========================================================================

    @isTest
    static void testGetSourcePdf_success() {
        Test.startTest();
        Map<String, String> result = DocGenSignatureController.getSourcePdfBase64(SIGNER_TOKEN);
        Test.stopTest();

        System.assertEquals(null, result.get('error'), 'Should not error for an authorized token');
        System.assert(String.isNotBlank(result.get('base64')), 'Base64 PDF bytes expected');
        System.assertEquals('application/pdf', result.get('mimeType'));
        System.assertEquals('Generated Agreement', result.get('fileName'));
        // Confirm it served the bound document, not the foreign one.
        System.assertEquals(
            EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.7 fake pdf bytes')),
            result.get('base64'),
            'Must serve the request-bound source PDF'
        );
    }

    @isTest
    static void testGetSourcePdf_invalidTokenShape() {
        Test.startTest();
        Map<String, String> result = DocGenSignatureController.getSourcePdfBase64('not-a-token');
        Test.stopTest();
        System.assertEquals('Invalid token', result.get('error'));
        System.assertEquals(null, result.get('base64'));
    }

    @isTest
    static void testGetSourcePdf_foreignTokenServesOnlyOwnDoc() {
        // IDOR: the foreign token must serve ITS OWN doc, never the first request's.
        Test.startTest();
        Map<String, String> result = DocGenSignatureController.getSourcePdfBase64(FOREIGN_TOKEN);
        Test.stopTest();
        System.assertEquals(
            EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.7 confidential')),
            result.get('base64'),
            'Foreign token must only resolve its own bound source document'
        );
        System.assertNotEquals(
            EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.7 fake pdf bytes')),
            result.get('base64'),
            'Foreign token must NOT reach the other request source PDF'
        );
    }

    @isTest
    static void testGetSourcePdf_expiredToken() {
        // Backdate CreatedDate past the 48h expiry window via test setObjectField.
        DocGen_Signer__c signer = getSigner(SIGNER_TOKEN);
        Test.setCreatedDate(signer.Id, System.now().addHours(-49));
        Test.startTest();
        Map<String, String> result = DocGenSignatureController.getSourcePdfBase64(SIGNER_TOKEN);
        Test.stopTest();
        System.assertEquals('Invalid or expired token', result.get('error'));
    }

    // =========================================================================
    // A2 — savePdfSignature
    // =========================================================================

    @isTest
    static void testSavePdfSignature_success() {
        DocGen_Signer__c signer = getSigner(SIGNER_TOKEN);
        signer.PIN_Verified_At__c = System.now();
        signer.Status__c = 'Viewed';
        Database.update(signer, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        DocGenSignatureController.SavePdfSignatureResult result = DocGenSignatureController.savePdfSignature(
            SIGNER_TOKEN,
            'Pat Signer',
            true,
            '203.0.113.7',
            'Mozilla/5.0'
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(true, result.isComplete, 'Single signer → complete');
        System.assertEquals(0, result.remaining);

        signer = [
            SELECT Status__c, Signature_Data__c, Consent_Captured__c, Signature_Request__c
            FROM DocGen_Signer__c
            WHERE Id = :signer.Id
        ];
        System.assertEquals('Signed', signer.Status__c);
        System.assertEquals('Pat Signer', signer.Signature_Data__c);
        System.assertEquals(true, signer.Consent_Captured__c);

        DocGen_Signature_Request__c req = [
            SELECT Status__c
            FROM DocGen_Signature_Request__c
            WHERE Id = :signer.Signature_Request__c
        ];
        System.assertEquals('Signed', req.Status__c, 'Request flips to Signed when all signers done');

        List<DocGen_Signature_Audit__c> audits = [
            SELECT Signer_Name__c, IP_Address__c, Consent_Captured__c, Document_Hash_SHA256__c
            FROM DocGen_Signature_Audit__c
            WHERE Signer__c = :signer.Id
        ];
        System.assertEquals(1, audits.size(), 'Audit row created');
        System.assertEquals('Pat Signer', audits[0].Signer_Name__c);
        System.assertEquals(true, audits[0].Consent_Captured__c);
        System.assertEquals(null, audits[0].Document_Hash_SHA256__c, 'No hash — nothing was stamped in M1');
    }

    @isTest
    static void testSavePdfSignature_noStampingEvent() {
        // Proves the PDF path does NOT route through the DOCX-XML stamping queueable.
        // saveSignature publishes DocGen_Signature_PDF__e which enqueues that queueable;
        // savePdfSignature must NOT — so no async jobs should be enqueued.
        DocGen_Signer__c signer = getSigner(SIGNER_TOKEN);
        signer.PIN_Verified_At__c = System.now();
        Database.update(signer, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', true, '203.0.113.7', 'UA');
        Integer enqueued = Limits.getAsyncCalls();
        Test.stopTest();

        System.assertEquals(0, enqueued, 'savePdfSignature must not enqueue any stamping job');
    }

    @isTest
    static void testSavePdfSignature_noConsent() {
        DocGen_Signer__c signer = getSigner(SIGNER_TOKEN);
        signer.PIN_Verified_At__c = System.now();
        Database.update(signer, AccessLevel.SYSTEM_MODE);
        Test.startTest();
        try {
            DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', false, '1.1.1.1', 'UA');
            System.assert(false, 'Should have thrown without consent');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    @isTest
    static void testSavePdfSignature_noPinVerification() {
        Test.startTest();
        try {
            DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', true, '1.1.1.1', 'UA');
            System.assert(false, 'Should have thrown — PIN not verified');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    @isTest
    static void testSavePdfSignature_invalidToken() {
        Test.startTest();
        try {
            DocGenSignatureController.savePdfSignature('bad', 'Name', true, '1.1.1.1', 'UA');
            System.assert(false, 'Should have thrown');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    // =========================================================================
    // A3 — createRequestFromContentVersion
    // =========================================================================

    @isTest
    static void testCreateRequestFromContentVersion() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Fresh Generated Doc',
            PathOnClient = 'fresh.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 fresh')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        String signersJson = '[{"signerName":"Sam Signer","signerEmail":"sam@test.com","roleName":"Signer","contactId":""}]';

        Test.startTest();
        List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createRequestFromContentVersion(
            cv.Id,
            acc.Id,
            signersJson,
            'Parallel',
            null
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Sam Signer', results[0].signerName);
        System.assert(String.isNotBlank(results[0].signerUrl), 'Signer URL expected');
        System.assert(results[0].signerUrl.contains('DocGenSignaturePdf'), 'URL must target the flat-PDF page');

        // Verify a Template__c-null request was created with the source CV + a signer token.
        DocGen_Signer__c created = [
            SELECT
                Secure_Token__c,
                Signature_Request__r.Source_Document_Id__c,
                Signature_Request__r.Template__c,
                Signature_Request__r.Status__c
            FROM DocGen_Signer__c
            WHERE Signer_Email__c = 'sam@test.com'
            LIMIT 1
        ];
        System.assertEquals(cv.Id, created.Signature_Request__r.Source_Document_Id__c);
        System.assertEquals(null, created.Signature_Request__r.Template__c, 'Template must be null for the PDF path');
        System.assertEquals('Sent', created.Signature_Request__r.Status__c);
        System.assertEquals(64, created.Secure_Token__c.length(), 'A 64-char token must be issued');
    }

    @isTest
    static void testCreateRequestFromContentVersion_nullCv() {
        Test.startTest();
        try {
            DocGenSignatureSenderController.createRequestFromContentVersion(
                null,
                null,
                '[{"signerName":"X","signerEmail":"x@test.com"}]',
                'Parallel',
                null
            );
            System.assert(false, 'Should have thrown for null CV');
        } catch (Exception e) {
            // AuraHandledException
        }
        Test.stopTest();
    }

    // =========================================================================
    // A4 — DocGenSignaturePdfFlowAction invocable
    // =========================================================================

    @isTest
    static void testPdfFlowAction_success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Flow Generated Doc',
            PathOnClient = 'flow.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 flow')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        DocGenSigner s = new DocGenSigner();
        s.name = 'Flow Signer';
        s.email = 'flow@test.com';
        s.role = 'Signer';

        DocGenSignaturePdfFlowAction.Request req = new DocGenSignaturePdfFlowAction.Request();
        req.contentVersionId = cv.Id;
        req.relatedRecordId = acc.Id;
        req.signerRecords = new List<DocGenSigner>{ s };
        req.signingOrder = 'Parallel';

        Test.startTest();
        List<DocGenSignaturePdfFlowAction.Result> results = DocGenSignaturePdfFlowAction.send(
            new List<DocGenSignaturePdfFlowAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        DocGenSignaturePdfFlowAction.Result r = results[0];
        System.assertEquals(true, r.success, 'Expected success; error=' + r.errorMessage);
        System.assertNotEquals(null, r.signatureRequestId);
        System.assertEquals(1, r.signerUrls.size());
        System.assertEquals('Flow Signer', r.signerNames[0]);
        System.assert(r.signerUrls[0].contains('DocGenSignaturePdf'), 'URL must target the flat-PDF page');
    }

    @isTest
    static void testPdfFlowAction_missingEmail() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Flow Doc 2',
            PathOnClient = 'flow2.pdf',
            VersionData = Blob.valueOf('%PDF-1.7')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        DocGenSigner s = new DocGenSigner();
        s.name = 'No Email Signer';

        DocGenSignaturePdfFlowAction.Request req = new DocGenSignaturePdfFlowAction.Request();
        req.contentVersionId = cv.Id;
        req.relatedRecordId = acc.Id;
        req.signerRecords = new List<DocGenSigner>{ s };

        Test.startTest();
        try {
            DocGenSignaturePdfFlowAction.send(new List<DocGenSignaturePdfFlowAction.Request>{ req });
            System.assert(false, 'Should have thrown on missing email');
        } catch (Exception e) {
            // DocGenException from validation
        }
        Test.stopTest();
    }

    @isTest
    static void testPdfFlowAction_nullRequests() {
        Test.startTest();
        List<DocGenSignaturePdfFlowAction.Result> results = DocGenSignaturePdfFlowAction.send(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}
