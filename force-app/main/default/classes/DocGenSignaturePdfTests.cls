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
            'Mozilla/5.0',
            '{}'
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
        DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', true, '203.0.113.7', 'UA', '{}');
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
            DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', false, '1.1.1.1', 'UA', '{}');
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
            DocGenSignatureController.savePdfSignature(SIGNER_TOKEN, 'Pat Signer', true, '1.1.1.1', 'UA', '{}');
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
            DocGenSignatureController.savePdfSignature('bad', 'Name', true, '1.1.1.1', 'UA', '{}');
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
    static void testCreateRequestFromContentVersion_removed() {
        // v3.18: sending a pre-generated PDF (ContentVersion) for signature is removed —
        // a flat PDF has no parseable signature tags, so it can't drive guided signing or
        // stamp-back. The entry now fails fast with guidance; no request is created.
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Fresh Generated Doc',
            PathOnClient = 'fresh.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 fresh')
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        String signersJson = '[{"signerName":"Sam Signer","signerEmail":"sam@test.com","roleName":"Signer","contactId":""}]';

        Boolean threw = false;
        Test.startTest();
        try {
            DocGenSignatureSenderController.createRequestFromContentVersion(
                cv.Id,
                acc.Id,
                signersJson,
                'Parallel',
                null
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Pre-generated PDF signing must be rejected (removed in v3.18)');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM DocGen_Signer__c WHERE Signer_Email__c = 'sam@test.com'],
            'No signature request is created on the removed path'
        );
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

    @isTest
    static void testSignatureTagStrippedInNormalGeneration() {
        // Leak fix: {@Signature_*} must be stripped from a normally-generated document
        // (preserveSignatureTags=false) and kept only during a signature merge.
        String body = 'A {@Signature_Signer:1:Full} B';
        Test.startTest();
        DocGenService.preserveSignatureTags = false;
        String gen = DocGenService.processXmlForTest(body, new Map<String, Object>());
        DocGenService.preserveSignatureTags = true;
        String sig = DocGenService.processXmlForTest(body, new Map<String, Object>());
        DocGenService.preserveSignatureTags = false;
        Test.stopTest();
        System.assert(!gen.contains('{@Signature'), 'Normal generation strips signing tags (no leak): ' + gen);
        System.assert(sig.contains('{@Signature_Signer:1:Full}'), 'Signing preserves the tag for stamping');
    }

    // =========================================================================
    // A4 — DocGenSignaturePdfFlowAction invocable
    // =========================================================================

    @isTest
    static void testPdfFlowAction_success() {
        // v3.18: the action is template-only. Provide a Template Id; DocGen snapshots +
        // re-renders on completion.
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id tmplId = createHtmlSignatureTemplate(
            '<html><body><p>{Name}</p><p>Sign: {@Signature_Signer:1:Full}</p></body></html>'
        );

        DocGenSigner s = new DocGenSigner();
        s.name = 'Flow Signer';
        s.email = 'flow@test.com';
        s.role = 'Signer';

        DocGenSignaturePdfFlowAction.Request req = new DocGenSignaturePdfFlowAction.Request();
        req.templateId = tmplId;
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
        System.assert(r.signerUrls[0].contains('DocGenSignaturePdf'), 'URL must target the signing page');
    }

    @isTest
    static void testPdfFlowAction_contentVersionRejected() {
        // The pre-generated-PDF path is removed: passing only a Content Version Id (no
        // Template Id) must be rejected.
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

        DocGenSignaturePdfFlowAction.Request req = new DocGenSignaturePdfFlowAction.Request();
        req.contentVersionId = cv.Id;
        req.relatedRecordId = acc.Id;
        req.signerRecords = new List<DocGenSigner>{ s };

        Boolean threw = false;
        Test.startTest();
        try {
            DocGenSignaturePdfFlowAction.send(new List<DocGenSignaturePdfFlowAction.Request>{ req });
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Content-Version-only signing must be rejected (Template Id required)');
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
        // Template-based now (v3.18); the missing-email validation still applies.
        req.templateId = createHtmlSignatureTemplate(
            '<html><body><p>{Name} {@Signature_Signer:1:Full}</p></body></html>'
        );
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

    // =========================================================================
    // M2 — snapshot signing (data snapshot at send-time → re-render + cert page
    // onto the record at completion).
    // =========================================================================

    private static Id createHtmlSignatureTemplate(String bodyHtml) {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'M2 HTML Template ' + Datetime.now().getTime(),
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name, Industry',
            Type__c = 'HTML',
            Output_Format__c = 'PDF'
        );
        insert tmpl;
        ContentVersion bodyCv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'template.html',
            VersionData = Blob.valueOf(bodyHtml),
            FirstPublishLocationId = tmpl.Id
        );
        insert bodyCv;
        bodyCv = [SELECT Id FROM ContentVersion WHERE Id = :bodyCv.Id LIMIT 1];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Is_Active__c = true,
            Content_Version_Id__c = bodyCv.Id
        );
        return tmpl.Id;
    }

    @isTest
    static void testCreateTemplateSnapshotRequest_capturesSnapshot() {
        Account acc = new Account(Name = 'Snapshot Co', Industry = 'Technology');
        insert acc;
        Id templateId = createHtmlSignatureTemplate(
            '<html><body><h1>{Name}</h1><p>Industry: {Industry}</p></body></html>'
        );
        String signersJson = JSON.serialize(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'signerName' => 'Dana Buyer',
                    'signerEmail' => 'dana@test.com',
                    'roleName' => 'Buyer'
                }
            }
        );

        Test.startTest();
        List<DocGenSignatureSenderController.SignerResult> res = DocGenSignatureSenderController.createTemplateSnapshotRequest(
            templateId,
            acc.Id,
            signersJson,
            'Parallel',
            null
        );
        Test.stopTest();

        System.assertEquals(1, res.size(), 'One signer result');
        System.assert(String.isNotBlank(res[0].signerUrl), 'Signer URL minted');

        DocGen_Signature_Request__c req = [
            SELECT Template__c, Render_Data_Snapshot__c, Source_Document_Id__c, Related_Record_Id__c, Status__c
            FROM DocGen_Signature_Request__c
            WHERE Template__c = :templateId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(templateId, req.Template__c);
        System.assertEquals(acc.Id, req.Related_Record_Id__c);
        System.assertEquals('Sent', req.Status__c);
        System.assert(String.isNotBlank(req.Render_Data_Snapshot__c), 'Snapshot JSON captured');
        System.assert(req.Render_Data_Snapshot__c.contains('Snapshot Co'), 'Snapshot froze the record Name');
        System.assert(req.Render_Data_Snapshot__c.contains('Technology'), 'Snapshot froze the record Industry');
        System.assertNotEquals(null, req.Source_Document_Id__c, 'Viewing CV bound to the request');

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Id = :req.Source_Document_Id__c];
        System.assertEquals(1, cvs.size(), 'Viewing PDF ContentVersion created');

        List<DocGen_Signer__c> signers = [
            SELECT Secure_Token__c, Status__c
            FROM DocGen_Signer__c
            WHERE Signature_Request__c = :req.Id
        ];
        System.assertEquals(1, signers.size());
        System.assertEquals('Pending', signers[0].Status__c);
        System.assert(String.isNotBlank(signers[0].Secure_Token__c), 'Signer token minted');
    }

    @isTest
    static void testGuidedEntry_loopOnlyTemplate_routesToSnapshot() {
        // Consolidation: the single canonical entry (createGuidedPdfSignatureRequest)
        // dispatches a {#Signatures}-loop template that has NO {@Signature_*} placement
        // tags to the snapshot render strategy, so the variable-signer loop still
        // repopulates with signed rows at completion (the guided frozen-body path can't).
        // Backwards-compat for loop templates after both Flow actions were unified.
        Account acc = new Account(Name = 'Loop Co', Industry = 'Technology');
        insert acc;
        Id templateId = createHtmlSignatureTemplate(
            '<html><body><h1>{Name}</h1>{#Signatures}<div>{Name} {Date}</div>{/Signatures}</body></html>'
        );
        String signersJson = JSON.serialize(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'signerName' => 'Loop Signer',
                    'signerEmail' => 'loop@test.com',
                    'roleName' => 'Signer'
                }
            }
        );

        Test.startTest();
        DocGenSignatureSenderController.createGuidedPdfSignatureRequest(
            templateId,
            acc.Id,
            signersJson,
            'Parallel',
            null
        );
        Test.stopTest();

        DocGen_Signature_Request__c req = [
            SELECT Render_Data_Snapshot__c, Frozen_Document__c
            FROM DocGen_Signature_Request__c
            WHERE Template__c = :templateId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(
            String.isNotBlank(req.Render_Data_Snapshot__c),
            'Loop-only template must route to the snapshot strategy so the loop repopulates at completion'
        );
        System.assert(String.isBlank(req.Frozen_Document__c), 'Snapshot strategy does not freeze a sentinel body');
    }

    @isTest
    static void testGuidedEntry_tagTemplate_staysGuidedAndKeepsInline() {
        // A {@Signature_*} template stays on the guided sentinel path and carries the
        // :inline flag onto the placement — Sarah's waiver fix (:inline was previously
        // dropped when the deprecated Flow action sent through the snapshot path).
        Account acc = new Account(Name = 'Tag Co');
        insert acc;
        Id templateId = createHtmlSignatureTemplate(
            '<html><body><p>Sign: {@Signature_Signer:1:Full:inline}</p></body></html>'
        );
        String signersJson = JSON.serialize(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'signerName' => 'Tag Signer',
                    'signerEmail' => 'tag@test.com',
                    'roleName' => 'Signer'
                }
            }
        );

        Test.startTest();
        DocGenSignatureSenderController.createGuidedPdfSignatureRequest(
            templateId,
            acc.Id,
            signersJson,
            'Parallel',
            null
        );
        Test.stopTest();

        DocGen_Signature_Request__c req = [
            SELECT Render_Data_Snapshot__c, Frozen_Document__c
            FROM DocGen_Signature_Request__c
            WHERE Template__c = :templateId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(String.isNotBlank(req.Frozen_Document__c), 'Tag template stays on the guided frozen-body path');
        System.assert(String.isBlank(req.Render_Data_Snapshot__c), 'Guided path does not snapshot record data');

        DocGen_Signature_Placement__c plc = [
            SELECT Render_Inline__c
            FROM DocGen_Signature_Placement__c
            WHERE Signature_Request__c = :req.Id AND Placement_Type__c = 'Full'
            LIMIT 1
        ];
        System.assertEquals(true, plc.Render_Inline__c, ':inline flag must reach the placement on the guided path');
    }

    @isTest
    static void testSavePdfSignature_snapshotBacked_leavesInProgressForFinalizer() {
        // A snapshot-backed request must stay 'In Progress' after savePdfSignature so the
        // platform-event trigger can enqueue the finalizer (which sets 'Signed'). This is the
        // tell that the snapshot/publish branch was taken (vs the M1 path which sets 'Signed').
        Account acc = new Account(Name = 'Finalize Co');
        insert acc;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'M2 Stub Tmpl',
            Base_Object_API__c = 'Account',
            Type__c = 'HTML'
        );
        insert tmpl;
        ContentVersion srcCv = new ContentVersion(
            Title = 'Src',
            PathOnClient = 'src.pdf',
            VersionData = Blob.valueOf('%PDF-1.7 source')
        );
        insert srcCv;
        srcCv = [SELECT Id FROM ContentVersion WHERE Id = :srcCv.Id LIMIT 1];

        String token = '1111111111111111111111111111111111111111111111111111111111111111';
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Template__c = tmpl.Id,
            Render_Data_Snapshot__c = '{"Name":"Finalize Co"}',
            Source_Document_Id__c = srcCv.Id,
            Related_Record_Id__c = acc.Id,
            Status__c = 'Sent',
            Signing_Order__c = 'Parallel'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Pat',
            Signer_Email__c = 'pat@test.com',
            Role_Name__c = 'Signer',
            Secure_Token__c = token,
            Status__c = 'Pending',
            Sort_Order__c = 1,
            PIN_Verified_At__c = System.now()
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);

        // No Test.stopTest wrapper — assert the synchronous state savePdfSignature leaves,
        // before the published event's trigger would finalize.
        DocGenSignatureController.SavePdfSignatureResult result = DocGenSignatureController.savePdfSignature(
            token,
            'Pat',
            true,
            '1.2.3.4',
            'UA',
            '{}'
        );

        System.assertEquals(true, result.success);
        System.assertEquals(true, result.isComplete);
        DocGen_Signer__c after = [SELECT Status__c FROM DocGen_Signer__c WHERE Id = :signer.Id];
        System.assertEquals('Signed', after.Status__c, 'Signer marked Signed');
        DocGen_Signature_Request__c reqAfter = [
            SELECT Status__c
            FROM DocGen_Signature_Request__c
            WHERE Id = :req.Id
        ];
        System.assertEquals(
            'In Progress',
            reqAfter.Status__c,
            'Snapshot-backed request stays In Progress so the finalizer can produce the doc + cert and set Signed'
        );
    }

    @isTest
    static void testSnapshotFinalizeQueueable_attachesSignedDocAndHash() {
        // The finalizer (stubbed PDF under test) must attach a signed document to the related
        // record, write the SHA-256 to the audit, and flip the request to Signed.
        Account acc = new Account(Name = 'Queueable Co');
        insert acc;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'M2 Q Tmpl',
            Base_Object_API__c = 'Account',
            Type__c = 'HTML'
        );
        insert tmpl;
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Template__c = tmpl.Id,
            Render_Data_Snapshot__c = '{"Name":"Queueable Co"}',
            Related_Record_Id__c = acc.Id,
            Status__c = 'In Progress',
            Signing_Order__c = 'Parallel'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Pat',
            Signer_Email__c = 'pat@test.com',
            Secure_Token__c = '2222222222222222222222222222222222222222222222222222222222222222',
            Status__c = 'Signed',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);
        DocGen_Signature_Audit__c audit = new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer__c = signer.Id,
            Signer_Name__c = 'Pat',
            Signer_Email__c = 'pat@test.com',
            Signed_Date__c = System.now(),
            Consent_Captured__c = true
        );
        Database.insert(audit, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        System.enqueueJob(new DocGenSignatureService.TemplateSignaturePdfQueueable(req.Id));
        Test.stopTest();

        DocGen_Signature_Request__c reqAfter = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Signed', reqAfter.Status__c, 'Finalizer flips the request to Signed');

        DocGen_Signature_Audit__c auditAfter = [
            SELECT Document_Hash_SHA256__c
            FROM DocGen_Signature_Audit__c
            WHERE Id = :audit.Id
        ];
        System.assert(String.isNotBlank(auditAfter.Document_Hash_SHA256__c), 'SHA-256 hash written to the audit');

        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :acc.Id];
        System.assert(!links.isEmpty(), 'Signed PDF linked to the related record');
    }

    @isTest
    static void testCertificate_showsTypedSignatureName() {
        // The certificate must show the name the signer TYPED (Signature_Data__c) —
        // their electronic signature — not just the invited name, and surface the
        // invited name as "Registered as" when the two differ.
        Account acc = new Account(Name = 'Cert Co');
        insert acc;
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Related_Record_Id__c = acc.Id,
            Status__c = 'Signed'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Pat Tester',
            Signer_Email__c = 'pat@test.com',
            Role_Name__c = 'Signer',
            Secure_Token__c = '3333333333333333333333333333333333333333333333333333333333333333',
            Status__c = 'Signed',
            Signature_Data__c = 'Pat Tester NATHAN',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);

        List<DocGen_Signer__c> signers = [
            SELECT Signer_Name__c, Signature_Data__c, Signer_Email__c, Role_Name__c, PIN_Verified_At__c
            FROM DocGen_Signer__c
            WHERE Id = :signer.Id
        ];

        Test.startTest();
        String certHtml = DocGenSignatureService.buildVerificationBlockHtml(req.Id, signers);
        Test.stopTest();

        System.assert(certHtml.contains('Pat Tester NATHAN'), 'Certificate shows the typed signature name');
        System.assert(
            certHtml.contains('Registered as: Pat Tester'),
            'Certificate shows the invited name as "Registered as" when the typed name differs'
        );
    }

    // =========================================================================
    // M3 — signature loop block ({#Signatures})
    // =========================================================================

    @isTest
    static void testBuildSignerLoopData_oneRowPerSignerWithTypedName() {
        Account acc = new Account(Name = 'Loop Co');
        insert acc;
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Related_Record_Id__c = acc.Id,
            Status__c = 'Signed'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c s1 = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Ada Buyer',
            Signer_Email__c = 'ada@test.com',
            Role_Name__c = 'Buyer',
            Secure_Token__c = '4444444444444444444444444444444444444444444444444444444444444444',
            Status__c = 'Signed',
            Signature_Data__c = 'Ada B. Buyer', // typed e-signature differs from the invited name
            Sort_Order__c = 1
        );
        DocGen_Signer__c s2 = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Ben Seller',
            Signer_Email__c = 'ben@test.com',
            Role_Name__c = 'Seller',
            Secure_Token__c = '5555555555555555555555555555555555555555555555555555555555555555',
            Status__c = 'Signed',
            Sort_Order__c = 2 // no typed name → falls back to the invited name
        );
        Database.insert(new List<DocGen_Signer__c>{ s1, s2 }, AccessLevel.SYSTEM_MODE);
        Database.insert(
            new DocGen_Signature_Audit__c(
                Signature_Request__c = req.Id,
                Signer__c = s1.Id,
                Signer_Name__c = 'Ada Buyer',
                Signer_Email__c = 'ada@test.com',
                Signed_Date__c = System.now()
            ),
            AccessLevel.SYSTEM_MODE
        );

        Test.startTest();
        List<Map<String, Object>> rows = DocGenSignatureService.buildSignerLoopData(req.Id);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'One row per signer');
        // Ordered by Sort_Order__c.
        System.assertEquals('Ada B. Buyer', rows[0].get('Name'), 'Row 0 shows the typed e-signature');
        System.assertEquals('Ada Buyer', rows[0].get('RegisteredName'), 'Row 0 keeps the invited name');
        System.assertEquals('Buyer', rows[0].get('Role'));
        System.assertEquals('ada@test.com', rows[0].get('Email'));
        System.assert(
            String.isNotBlank((String) rows[0].get('SignedDate')),
            'Row 0 has a signed date from the audit record'
        );
        System.assertEquals(
            'Ben Seller',
            rows[1].get('Name'),
            'Row 1 falls back to the invited name (no typed signature captured)'
        );
        System.assertEquals('Seller', rows[1].get('Role'));
        System.assertEquals('', rows[1].get('SignedDate'), 'Row 1 has no audit → blank signed date');
    }

    @isTest
    static void testSignaturesLoop_rendersOneBlockPerSigner() {
        // The reserved {#Signatures} loop block renders once per injected signer row —
        // one authored layout, any signer count, no per-count templates.
        // Pending rows leave {Name} (the signature line) BLANK until the signer signs;
        // the invited/printed name is exposed as {RegisteredName}.
        String template = '<w:t>{#Signatures}</w:t><w:t>Signed by {RegisteredName} ({Role})</w:t><w:t>{/Signatures}</w:t>';

        List<Map<String, Object>> twoSigners = DocGenSignatureService.buildPendingSignerLoopData(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'signerName' => 'Ada Buyer',
                    'signerEmail' => 'ada@test.com',
                    'roleName' => 'Buyer'
                },
                new Map<String, Object>{
                    'signerName' => 'Ben Seller',
                    'signerEmail' => 'ben@test.com',
                    'roleName' => 'Seller'
                }
            }
        );
        String two = DocGenService.processXmlForTest(template, new Map<String, Object>{ 'Signatures' => twoSigners });
        System.assert(two.contains('Ada Buyer') && two.contains('(Buyer)'), 'First signer block rendered');
        System.assert(two.contains('Ben Seller') && two.contains('(Seller)'), 'Second signer block rendered');

        // Same template, a single signer → exactly one block.
        List<Map<String, Object>> oneSigner = DocGenSignatureService.buildPendingSignerLoopData(
            new List<Map<String, Object>>{
                new Map<String, Object>{
                    'signerName' => 'Solo Signer',
                    'signerEmail' => 'solo@test.com',
                    'roleName' => 'Signer'
                }
            }
        );
        String one = DocGenService.processXmlForTest(template, new Map<String, Object>{ 'Signatures' => oneSigner });
        System.assert(one.contains('Solo Signer'), 'Single signer block rendered from the same template');
        System.assert(!one.contains('Ada Buyer'), 'Only the one injected signer renders');
    }

    @isTest
    static void testSignaturesLoop_backwardsCompatible() {
        // Backwards-compat guarantee #1: a template with NO {#Signatures} marker renders
        // exactly as before, even when a Signatures collection is present in the data map.
        String plain = '<w:t>Agreement for {Name}</w:t>';
        String out = DocGenService.processXmlForTest(
            plain,
            new Map<String, Object>{
                'Name' => 'World',
                'Signatures' => DocGenSignatureService.buildPendingSignerLoopData(
                    new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'signerName' => 'Ghost',
                            'signerEmail' => 'g@test.com',
                            'roleName' => 'Signer'
                        }
                    }
                )
            }
        );
        System.assert(out.contains('Agreement for World'), 'No {#Signatures} marker → existing merge is unchanged');
        System.assert(!out.contains('Ghost'), 'Signer rows are never emitted without a {#Signatures} block');

        // Backwards-compat guarantee #2: an empty signer collection collapses cleanly —
        // the block emits nothing and never leaks the raw {#Signatures}/{Name} tags.
        String withBlock = '<w:t>{#Signatures}</w:t><w:t>{Name}</w:t><w:t>{/Signatures}</w:t>';
        String empty = DocGenService.processXmlForTest(
            withBlock,
            new Map<String, Object>{ 'Signatures' => new List<Object>() }
        );
        System.assert(
            !empty.contains('{#Signatures}') && !empty.contains('{Name}'),
            'Empty Signatures collection collapses cleanly with no leaked tags'
        );
    }

    // The finalize queueable short-circuits under Test.isRunningTest(), so the snapshot
    // re-render (mergeTemplateForSignatureFromData) was only covered by manual demo
    // scripts. This exercises it directly and proves the point-in-time guarantee: the
    // document renders from the send-time data snapshot, immune to later record edits.
    @isTest
    static void testMergeTemplateForSignatureFromData_rendersFromSnapshotNotLiveRecord() {
        Account acc = new Account(Name = 'Frozen Co', Industry = 'FrozenIndustry');
        insert acc;
        Id templateId = createHtmlSignatureTemplate(
            '<html><body><h1>{Name}</h1><p>Industry: {Industry}</p></body></html>'
        );

        // Capture the snapshot exactly as the send-time flow does.
        Map<String, Object> snapshot = DocGenDataRetriever.getRecordData(acc.Id, 'Account', 'Name, Industry');

        // Mutate the record AFTER the snapshot — the re-render must ignore this.
        acc.Name = 'Mutated Co';
        update acc;

        Test.startTest();
        Map<String, Object> merged = DocGenService.mergeTemplateForSignatureFromData(templateId, snapshot);
        Test.stopTest();

        String body = (String) merged.get('combinedDocumentXml');
        if (String.isBlank(body)) {
            body = (String) merged.get('documentXml');
        }
        System.assert(body.contains('Frozen Co'), 'Renders the frozen snapshot name: ' + body);
        System.assert(!body.contains('Mutated Co'), 'Must NOT reflect the post-snapshot record edit');
        System.assertEquals('HTML', (String) merged.get('templateType'), 'HTML template type preserved');
    }

    @isTest
    static void testMergeTemplateForSignatureFromData_nullDataMapThrows() {
        Id templateId = createHtmlSignatureTemplate('<html><body>{Name}</body></html>');
        Boolean threw = false;
        try {
            DocGenService.mergeTemplateForSignatureFromData(templateId, null);
        } catch (DocGenException e) {
            threw = true;
        }
        System.assert(threw, 'A null snapshot data map must throw rather than fall back to the live record');
    }
}
