/**
 * Tests for the guided PDF-signing path (#163):
 *   - DocGenSignatureSenderController.createGuidedPdfSignatureRequest
 *   - DocGenSignatureController.saveCompositedSignedPdf
 *   - DocGenSignatureController.getSignatureCertificate
 */
@IsTest
private class DocGenGuidedSigningTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Guided Sig Co', Industry = 'Technology');
    }

    // HTML template with three placement tags (initials / full / date).
    private static Id createTaggedTemplate() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Guided ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name, Industry'
        );
        insert tmpl;

        String body =
            '<html><body>' +
            '<h1>{Name}</h1>' +
            '<p>Initials: {@Signature_Member:1:Initials}</p>' +
            '<p>Signature: {@Signature_Member:2:Full}</p>' +
            '<p>Date: {@Signature_Member:3:Date}</p>' +
            '</body></html>';
        ContentVersion cv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'body.html',
            VersionData = Blob.valueOf(body),
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

    private static String signersJson() {
        return '[{"signerName":"Member One","signerEmail":"m1@example.com","roleName":"Member"}]';
    }

    @IsTest
    static void createsGuidedRequestWithSentinelPlacements() {
        Id tplId = createTaggedTemplate();
        Account a = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tplId, a.Id, signersJson(), 'Parallel', null);
        Test.stopTest();

        DocGen_Signature_Request__c req = [
            SELECT Id, Template__c, Source_Document_Id__c, Frozen_Document__c, Status__c
            FROM DocGen_Signature_Request__c
            WHERE Template__c = :tplId
            LIMIT 1
        ];
        System.assertNotEquals(null, req.Source_Document_Id__c, 'Viewing PDF should be stored as Source_Document');
        System.assertNotEquals(null, req.Frozen_Document__c, 'Frozen sentinel body should be captured');

        List<DocGen_Signature_Placement__c> plcs = [
            SELECT Tag_Text__c, Placement_Type__c, Status__c
            FROM DocGen_Signature_Placement__c
            WHERE Signature_Request__c = :req.Id
            ORDER BY Sequence_Order__c
        ];
        System.assertEquals(3, plcs.size(), 'Three placements created from the three tags');
        for (DocGen_Signature_Placement__c p : plcs) {
            System.assert(
                p.Tag_Text__c != null && p.Tag_Text__c.startsWith('@@SIG-'),
                'Placement should key on a unique sentinel, got: ' + p.Tag_Text__c
            );
            System.assertEquals('Pending', p.Status__c, 'Placement starts Pending');
        }
    }

    @IsTest
    static void synthesizesPlacementsForTaglessTemplate() {
        // #170 option (b): a tag-less legacy template is no longer rejected — the guided
        // path auto-appends a "Signatures" block (Full + Date per signer) so it signs
        // through the one consolidated path with zero author change.
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'NoTags ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert tmpl;
        ContentVersion cv = new ContentVersion(
            Title = tmpl.Name + ' Body',
            PathOnClient = 'body.html',
            VersionData = Blob.valueOf('<html><body><p>{Name}</p></body></html>'),
            FirstPublishLocationId = tmpl.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Content_Version_Id__c = cv.Id,
            Is_Active__c = true
        );
        Account a = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tmpl.Id, a.Id, signersJson(), 'Parallel', null);
        Test.stopTest();

        DocGen_Signature_Request__c req = [
            SELECT Id, Source_Document_Id__c, Frozen_Document__c
            FROM DocGen_Signature_Request__c
            WHERE Template__c = :tmpl.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, req.Source_Document_Id__c, 'Tag-less template should still produce a viewing PDF');
        System.assertNotEquals(null, req.Frozen_Document__c, 'Frozen body should be captured');

        List<DocGen_Signature_Placement__c> plcs = [
            SELECT Tag_Text__c, Placement_Type__c
            FROM DocGen_Signature_Placement__c
            WHERE Signature_Request__c = :req.Id
        ];
        // One signer → synthesized Full + Date.
        System.assertEquals(2, plcs.size(), 'Synthesized Full + Date placements for the one signer');
        Set<String> types = new Set<String>();
        for (DocGen_Signature_Placement__c p : plcs) {
            types.add(p.Placement_Type__c);
            System.assert(
                p.Tag_Text__c != null && p.Tag_Text__c.startsWith('@@SIG-'),
                'Synthesized placement keys on a sentinel: ' + p.Tag_Text__c
            );
        }
        System.assert(types.contains('Full') && types.contains('Date'), 'Both Full and Date synthesized: ' + types);
    }

    @IsTest
    static void compositeFinalizeAndCertificate() {
        Id tplId = createTaggedTemplate();
        Account a = [SELECT Id FROM Account LIMIT 1];
        DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tplId, a.Id, signersJson(), 'Parallel', null);

        DocGen_Signer__c signer = [
            SELECT Id, Secure_Token__c, Signature_Request__c
            FROM DocGen_Signer__c
            WHERE Signature_Request__r.Template__c = :tplId
            LIMIT 1
        ];
        signer.PIN_Verified_At__c = System.now();
        update signer;
        String token = signer.Secure_Token__c;

        Test.startTest();
        // Certificate roster: single signer => this signer completes the request.
        Map<String, Object> cert = DocGenSignatureController.getSignatureCertificate(token);
        System.assertEquals(true, cert.get('othersAllSigned'), 'Single signer completes the request');
        List<Object> roster = (List<Object>) cert.get('signers');
        System.assertEquals(1, roster.size(), 'One signer on the roster');

        // Finalize with a client-composited PDF.
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 composited test'));
        DocGenSignatureController.SavePdfSignatureResult r = DocGenSignatureController.saveCompositedSignedPdf(
            token,
            b64,
            true,
            '1.2.3.4',
            'JUnit/1.0'
        );
        Test.stopTest();

        System.assertEquals(true, r.success, 'Composite save succeeds');
        System.assertEquals(true, r.isComplete, 'Single signer => complete');
        System.assertEquals(0, r.remaining, 'No remaining signers');

        DocGen_Signer__c after = [SELECT Status__c FROM DocGen_Signer__c WHERE Id = :signer.Id];
        System.assertEquals('Signed', after.Status__c, 'Signer marked Signed');

        DocGen_Signature_Request__c req = [
            SELECT Status__c
            FROM DocGen_Signature_Request__c
            WHERE Id = :signer.Signature_Request__c
        ];
        System.assertEquals('Signed', req.Status__c, 'Request completed');

        // Final signed document attached to the related record.
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :a.Id AND ContentDocument.Title LIKE '%Signed%'
        ];
        System.assert(!links.isEmpty(), 'Signed document attached to the related record');

        // Audit row with IP captured.
        List<DocGen_Signature_Audit__c> audits = [
            SELECT IP_Address__c, Consent_Captured__c
            FROM DocGen_Signature_Audit__c
            WHERE Signer__c = :signer.Id
        ];
        System.assert(!audits.isEmpty(), 'Audit row created');
        System.assertEquals('1.2.3.4', audits[0].IP_Address__c, 'IP captured on audit');
        System.assertEquals(true, audits[0].Consent_Captured__c, 'Consent captured on audit');
    }

    @IsTest
    static void rejectsInvalidTokens() {
        Test.startTest();
        Boolean a = false, b = false;
        try {
            DocGenSignatureController.getSignatureCertificate('short');
        } catch (Exception e) {
            a = true;
        }
        try {
            DocGenSignatureController.saveCompositedSignedPdf('short', 'x', true, '1.1.1.1', 'ua');
        } catch (Exception e) {
            b = true;
        }
        Test.stopTest();
        System.assert(a, 'getSignatureCertificate rejects bad token');
        System.assert(b, 'saveCompositedSignedPdf rejects bad token');
    }
}
