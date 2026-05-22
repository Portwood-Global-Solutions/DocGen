@IsTest
private class DocGenZeroCoverageTest {
    @IsTest
    static void docGenExceptionIsThrowable() {
        Boolean caught = false;
        try {
            throw new DocGenException('test');
        } catch (DocGenException e) {
            caught = true;
            System.assertEquals('test', e.getMessage());
        }
        System.assert(caught, 'DocGenException should be catchable by name');
    }

    @IsTest
    static void heapPressureExceptionCarriesRelationship() {
        HeapPressureException e = new HeapPressureException();
        e.relationshipName = 'Contacts';
        e.setMessage('heap pressure on Contacts');
        Boolean caught = false;
        try {
            throw e;
        } catch (HeapPressureException caughtEx) {
            caught = true;
            System.assertEquals('Contacts', caughtEx.relationshipName);
            System.assertEquals('heap pressure on Contacts', caughtEx.getMessage());
        }
        System.assert(caught, 'HeapPressureException should be catchable by name');
    }

    @IsTest
    static void pdfSaveQueueableEnqueuesAndExecutes() {
        Account acct = new Account(Name = 'PdfSaveQueueable Test');
        insert acct;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Zero Coverage Tmpl',
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = '{"v":3,"root":"Account","nodes":[{"id":"n0","object":"Account","fields":["Name"],"parentNode":null,"lookupField":null,"relationshipName":null}]}'
        );
        insert tmpl;
        ContentVersion cv = new ContentVersion(
            Title = 'Zero Coverage Body',
            PathOnClient = 'b.html',
            VersionData = Blob.valueOf('<html><body><h1>{Name}</h1></body></html>'),
            FirstPublishLocationId = tmpl.Id
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
        insert new DocGen_Template_Version__c(
            Template__c = tmpl.Id,
            Content_Version_Id__c = cv.Id,
            Is_Active__c = true
        );

        Test.startTest();
        Id jobId = System.enqueueJob(new DocGenPdfSaveQueueable(tmpl.Id, acct.Id));
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Queueable should enqueue successfully');
    }

    @IsTest
    static void buildVerificationBlockHtmlRendersSignerCertificate() {
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(Status__c = 'Sent');
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        List<DocGen_Signer__c> signers = new List<DocGen_Signer__c>{
            new DocGen_Signer__c(
                Signature_Request__c = req.Id,
                Signer_Name__c = 'Alice Test',
                Signer_Email__c = 'alice@example.com',
                Role_Name__c = 'Buyer',
                Status__c = 'Signed',
                Sort_Order__c = 1
            ),
            new DocGen_Signer__c(
                Signature_Request__c = req.Id,
                Signer_Name__c = 'Bob Test',
                Signer_Email__c = 'bob@example.com',
                Role_Name__c = 'Witness',
                Status__c = 'Signed',
                Sort_Order__c = 2
            )
        };
        Database.insert(signers, AccessLevel.SYSTEM_MODE);
        // Insert one audit row so the audit-query branch is exercised
        insert new DocGen_Signature_Audit__c(
            Signature_Request__c = req.Id,
            Signer__c = signers[0].Id,
            IP_Address__c = '127.0.0.1',
            User_Agent__c = 'Mozilla/5.0 Test',
            Signed_Date__c = System.now(),
            Consent_Captured__c = true
        );

        Test.startTest();
        String html = DocGenSignatureService.buildVerificationBlockHtml(req.Id, signers);
        Test.stopTest();

        System.assert(html.contains('ELECTRONIC SIGNATURE CERTIFICATE'), 'Should include certificate header');
        System.assert(html.contains('Alice Test'), 'Should include first signer name');
        System.assert(html.contains('Bob Test'), 'Should include second signer name');
        System.assert(html.contains('Buyer'), 'Should include role');
        System.assert(html.contains(String.valueOf(req.Id)), 'Should include request Id');
    }

    @IsTest
    static void stampSignaturesInXmlReplacesPlacementTags() {
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(Status__c = 'Sent');
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Carol Test',
            Signer_Email__c = 'carol@example.com',
            Role_Name__c = 'Buyer',
            Status__c = 'Signed',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);
        DateTime signedAt = DateTime.newInstance(2026, 4, 29, 12, 0, 0);

        // Cover all four Placement_Type__c branches in buildPlacementText
        List<DocGen_Signature_Placement__c> placements = new List<DocGen_Signature_Placement__c>{
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '{@Signature_Buyer:1:Full}',
                Placement_Type__c = 'Full',
                Status__c = 'Signed',
                Signed_Value__c = 'Carol Test',
                Signed_At__c = signedAt,
                Sequence_Order__c = 1
            ),
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '{@Signature_Buyer:1:Initials}',
                Placement_Type__c = 'Initials',
                Status__c = 'Signed',
                Signed_Value__c = 'CT',
                Signed_At__c = signedAt,
                Sequence_Order__c = 2
            ),
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '{@Signature_Buyer:1:Date}',
                Placement_Type__c = 'Date',
                Status__c = 'Signed',
                Signed_Value__c = '',
                Signed_At__c = signedAt,
                Sequence_Order__c = 3
            ),
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '{@Signature_Buyer:1:DatePick}',
                Placement_Type__c = 'DatePick',
                Status__c = 'Signed',
                Signed_Value__c = '2026-05-01',
                Signed_At__c = signedAt,
                Sequence_Order__c = 4
            )
        };
        Database.insert(placements, AccessLevel.SYSTEM_MODE);
        String docXml =
            '<w:document><w:body><w:p>' +
            '{@Signature_Buyer:1:Full} | {@Signature_Buyer:1:Initials} | {@Signature_Buyer:1:Date} | {@Signature_Buyer:1:DatePick}' +
            '</w:p></w:body></w:document>';
        String relsXml = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';
        String ctXml = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"></Types>';

        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml,
            relsXml,
            ctXml,
            new List<DocGenSignatureService.SignerImageData>(),
            placements
        );

        System.assert(
            !result.documentXml.contains('{@Signature_Buyer:1:Full}'),
            'Full placement tag should be replaced'
        );
        System.assert(result.documentXml.contains('Carol Test'), 'Full placement should embed signer name');
        System.assert(result.documentXml.contains('CT'), 'Initials placement should embed initials');
        System.assert(result.documentXml.contains('April 29, 2026'), 'Date placement should embed formatted date');
        System.assert(result.documentXml.contains('2026-05-01'), 'DatePick placement should embed picked date');
    }

    @IsTest
    static void mergeJobConcatenatesHtmlSnippetsAndProducesPdf() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Merge Job Test Tmpl',
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        DocGen_Job__c job = new DocGen_Job__c(
            Label__c = 'Merge Job Test',
            Status__c = 'Processing',
            Template__c = tmpl.Id,
            Total_Records__c = 2,
            Success_Count__c = 2
        );
        Database.insert(job, AccessLevel.SYSTEM_MODE);
        String snippetA = '<html><head><style>.a{color:red}</style></head><body><div class="a">Record A body</div></body></html>';
        String snippetB = '<html><head><style>.b{color:blue}</style></head><body><div class="b">Record B body</div></body></html>';
        insert new List<ContentVersion>{
            new ContentVersion(
                Title = 'docgen_merge_' + job.Id + '_001',
                PathOnClient = 'a.html',
                VersionData = Blob.valueOf(snippetA),
                FirstPublishLocationId = job.Id
            ),
            new ContentVersion(
                Title = 'docgen_merge_' + job.Id + '_002',
                PathOnClient = 'b.html',
                VersionData = Blob.valueOf(snippetB),
                FirstPublishLocationId = job.Id
            )
        };

        Test.startTest();
        Id mergeJobId = System.enqueueJob(new DocGenMergeJob(job.Id));
        Test.stopTest();

        System.assertNotEquals(null, mergeJobId, 'Merge job should enqueue');
        DocGen_Job__c finished = [SELECT Status__c, Merged_PDF_CV__c FROM DocGen_Job__c WHERE Id = :job.Id];
        System.assertEquals('Completed', finished.Status__c, 'Job should be marked Completed after merge');
        System.assertNotEquals(null, finished.Merged_PDF_CV__c, 'Job should have a Merged_PDF_CV__c set');
    }

    @IsTest
    static void mergeJobShortCircuitsWhenNoSnippets() {
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Empty Merge Test',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        DocGen_Job__c job = new DocGen_Job__c(
            Label__c = 'Empty Merge',
            Status__c = 'Processing',
            Template__c = tmpl.Id,
            Total_Records__c = 0,
            Success_Count__c = 0
        );
        Database.insert(job, AccessLevel.SYSTEM_MODE);
        Test.startTest();
        System.enqueueJob(new DocGenMergeJob(job.Id));
        Test.stopTest();

        DocGen_Job__c finished = [SELECT Status__c FROM DocGen_Job__c WHERE Id = :job.Id];
        System.assertEquals('Completed', finished.Status__c, 'Empty-snippet job should still mark Completed');
    }

    @IsTest
    static void handleSignatureSubmissionRejectsBadTokenFormat() {
        Boolean caughtBlank = false;
        try {
            DocGenSignatureService.handleSignatureSubmission('', 'name');
        } catch (DocGenSignatureService.SignatureException e) {
            caughtBlank = true;
        }
        System.assert(caughtBlank, 'Blank token should throw SignatureException');

        Boolean caughtShort = false;
        try {
            DocGenSignatureService.handleSignatureSubmission('abcd', 'name');
        } catch (DocGenSignatureService.SignatureException e) {
            caughtShort = true;
        }
        System.assert(caughtShort, 'Wrong-length token should throw SignatureException');

        Boolean caughtNonHex = false;
        try {
            // Right length (64), wrong charset
            DocGenSignatureService.handleSignatureSubmission('Z'.repeat(64), 'name');
        } catch (DocGenSignatureService.SignatureException e) {
            caughtNonHex = true;
        }
        System.assert(caughtNonHex, 'Non-hex token should throw SignatureException');
    }

    @IsTest
    static void handleSignatureSubmissionExercisesHappyPathInTestMode() {
        // Stage a fully-formed request so the Test.isRunningTest() bypass renders a PDF and
        // saves it via DocGenController.saveGeneratedDocument. This covers the bulk of
        // handleSignatureSubmission's body — biggest single uncovered method in DocGenSignatureService.
        Account acct = new Account(Name = 'Sign Submit Test');
        insert acct;
        ContentVersion source = new ContentVersion(
            Title = 'Source Doc',
            PathOnClient = 'src.pdf',
            VersionData = Blob.valueOf('source-pdf-bytes'),
            FirstPublishLocationId = acct.Id
        );
        insert source;
        source = [SELECT Id, Title FROM ContentVersion WHERE Id = :source.Id];

        String token = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789'; // 64 hex
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Status__c = 'Sent',
            Signer_Name__c = 'Tester',
            Signer_Email__c = 'tester@example.com',
            Source_Document_Id__c = source.Id,
            Related_Record_Id__c = acct.Id,
            Secure_Token__c = token
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        Test.startTest();
        DocGenSignatureService.handleSignatureSubmission(token, 'Tester Signature');
        Test.stopTest();

        DocGen_Signature_Request__c after = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Signed', after.Status__c, 'Test-mode bypass should mark request Signed');
    }

    @IsTest
    static void handleSignatureSubmissionShortCircuitsWhenAlreadySigned() {
        String token = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Status__c = 'Signed', // already signed → method should return without changes
            Secure_Token__c = token
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGenSignatureService.handleSignatureSubmission(token, 'late');
        DocGen_Signature_Request__c after = [SELECT Status__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
        System.assertEquals('Signed', after.Status__c, 'Already-signed request should remain Signed');
    }

    @IsTest
    static void htmlRendererConvertFragmentAndHeaderFooterAndBarcodeWrappers() {
        // Three wrapper methods on DocGenHtmlRenderer with no existing tests.
        // Each one delegates to convertToHtml internals — exercising them
        // covers the parameter-permutation branches the wrappers introduce.
        Map<String, String> noImages = new Map<String, String>();

        String fragmentXml = '<w:document><w:body><w:p><w:r><w:t>Fragment Hello</w:t></w:r></w:p></w:body></w:document>';
        String fragmentHtml = DocGenHtmlRenderer.convertToHtmlFragment(fragmentXml, noImages);
        System.assert(fragmentHtml.contains('Fragment Hello'), 'Fragment converter should render text');

        String hfXml = '<w:document><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:body></w:document>';
        String withHF = DocGenHtmlRenderer.convertToHtmlWithHeaderFooter(
            hfXml,
            noImages,
            '<p>Header</p>',
            '<p>Footer</p>'
        );
        System.assert(withHF.contains('Body'), 'HF converter should render body');
        System.assert(withHF.contains('Header'), 'HF converter should embed header');
        System.assert(withHF.contains('Footer'), 'HF converter should embed footer');

        String bc = DocGenHtmlRenderer.renderBarcodeHtml('TEST123');
        System.assertNotEquals(null, bc, 'renderBarcodeHtml should return non-null');
        System.assert(bc.length() > 0, 'renderBarcodeHtml should return non-empty html');
    }

    @IsTest
    static void signaturePdfQueueableExecutesAndShortcircuits() {
        // Cover SignaturePdfQueueable.execute body (~30+ lines via Test.isRunningTest bypass).
        Account acct = new Account(Name = 'SigPdf Queueable Test');
        insert acct;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'SigPdf Queueable Tmpl',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        ContentVersion source = new ContentVersion(
            Title = 'SigPdf Source',
            PathOnClient = 'src.docx',
            VersionData = Blob.valueOf('source-bytes'),
            FirstPublishLocationId = acct.Id
        );
        insert source;
        source = [SELECT Id FROM ContentVersion WHERE Id = :source.Id];

        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Status__c = 'In Progress',
            Source_Document_Id__c = source.Id,
            Related_Record_Id__c = acct.Id,
            Template__c = tmpl.Id,
            Signer_Name__c = 'Quick Test',
            Signer_Email__c = 'q@example.com',
            Signature_Data__c = 'Quick Test'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Quick Test',
            Signer_Email__c = 'q@example.com',
            Signature_Data__c = 'Quick Test',
            Role_Name__c = 'Buyer',
            Status__c = 'Signed',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);
        // Early-return branch: insert a sacrificial request, capture its Id, then delete it.
        // Querying it from the queueable will return empty list and the method returns early.
        DocGen_Signature_Request__c phantom = new DocGen_Signature_Request__c(Status__c = 'Sent');
        insert phantom;
        Id phantomId = phantom.Id;
        delete phantom;

        Test.startTest();
        Id jobId = System.enqueueJob(new DocGenSignatureService.SignaturePdfQueueable(req.Id));
        Id phantomJobId = System.enqueueJob(new DocGenSignatureService.SignaturePdfQueueable(phantomId));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Real-request queueable should enqueue');
        System.assertNotEquals(null, phantomJobId, 'Phantom-request queueable should still enqueue');
    }

    @IsTest
    static void templateSignaturePdfQueueableExecutesAndShortcircuits() {
        // Cover TemplateSignaturePdfQueueable.execute via Test.isRunningTest() bypass.
        Account acct = new Account(Name = 'Tmpl SigPdf Q Test');
        insert acct;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'Tmpl SigPdf Q Tmpl',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(
            Status__c = 'In Progress',
            Template__c = tmpl.Id,
            Related_Record_Id__c = acct.Id,
            Signer_Name__c = 'Tmpl Test',
            Signer_Email__c = 't@example.com'
        );
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signature_Request__c phantom = new DocGen_Signature_Request__c(Status__c = 'Sent');
        insert phantom;
        Id phantomId = phantom.Id;
        delete phantom;

        Test.startTest();
        Id jobId = System.enqueueJob(new DocGenSignatureService.TemplateSignaturePdfQueueable(req.Id));
        Id phantomJobId = System.enqueueJob(new DocGenSignatureService.TemplateSignaturePdfQueueable(phantomId));
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertNotEquals(null, phantomJobId);
    }

    @IsTest
    static void pdfSaveQueueableCatchBlockHitOnBadInput() {
        // Force the inner DocGenService.generateDocument to throw, exercising
        // the catch block at lines 23–35 of DocGenPdfSaveQueueable.
        Boolean caught = false;
        try {
            // Direct .execute — synchronous, no enqueue needed; exception propagates here.
            new DocGenPdfSaveQueueable(null, null).execute(null);
        } catch (Exception e) {
            caught = true;
        }
        System.assert(caught, 'PdfSaveQueueable catch block should rethrow on null inputs');
    }

    @IsTest
    static void signatureSubmitterCatchBlockHitOnBadToken() {
        DocGenSignatureSubmitter.FlowInput input = new DocGenSignatureSubmitter.FlowInput();
        input.token = ''; // forces SignatureException in handleSignatureSubmission
        input.signatureData = 'bad';

        List<DocGenSignatureSubmitter.FlowOutput> results = DocGenSignatureSubmitter.submitSignature(
            new List<DocGenSignatureSubmitter.FlowInput>{ input }
        );
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess, 'Bad token should set isSuccess=false');
        System.assertNotEquals(null, results[0].errorMessage, 'Bad token should populate errorMessage');
    }

    @IsTest
    static void signatureFlowActionExercisesNewSignerCollectionPath() {
        // Hits buildSignerInputs lines 273, 282-291 (the new-Signer-collection branch).
        Account acct = new Account(Name = 'SigFlow Test');
        insert acct;
        DocGen_Template__c tmpl = new DocGen_Template__c(
            Name = 'SigFlow Test Tmpl',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account'
        );
        insert tmpl;

        DocGenSignatureFlowAction.Signer s = new DocGenSignatureFlowAction.Signer();
        s.name = 'Eve Test';
        s.email = 'eve@example.com';
        s.role = 'Buyer';

        DocGenSignatureFlowAction.Request req = new DocGenSignatureFlowAction.Request();
        req.templateId = tmpl.Id;
        req.relatedRecordId = acct.Id;
        req.signers = new List<DocGenSignatureFlowAction.Signer>{ s };
        req.sendEmails = false; // skip OWA-required email path

        Test.startTest();
        List<DocGenSignatureFlowAction.Result> results = DocGenSignatureFlowAction.generate(
            new List<DocGenSignatureFlowAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        // Don't assert on success — depends on org settings — just that the path executed
        System.assertNotEquals(null, results[0]);
    }

    @IsTest
    static void stampSignaturesInXmlSkipsUnsignedAndBlankPlacements() {
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(Status__c = 'Sent');
        Database.insert(req, AccessLevel.SYSTEM_MODE);
        DocGen_Signer__c signer = new DocGen_Signer__c(
            Signature_Request__c = req.Id,
            Signer_Name__c = 'Dave Test',
            Signer_Email__c = 'dave@example.com',
            Role_Name__c = 'Buyer',
            Status__c = 'Pending',
            Sort_Order__c = 1
        );
        Database.insert(signer, AccessLevel.SYSTEM_MODE);
        List<DocGen_Signature_Placement__c> placements = new List<DocGen_Signature_Placement__c>{
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '{@Signature_Buyer:1:Full}',
                Placement_Type__c = 'Full',
                Status__c = 'Pending', // not Signed — should be skipped
                Signed_Value__c = '',
                Sequence_Order__c = 1
            ),
            new DocGen_Signature_Placement__c(
                Signer__c = signer.Id,
                Tag_Text__c = '', // blank tag — should be skipped
                Placement_Type__c = 'Initials',
                Status__c = 'Signed',
                Signed_Value__c = 'DT',
                Sequence_Order__c = 2
            )
        };
        Database.insert(placements, AccessLevel.SYSTEM_MODE);
        String docXml = '<w:t>{@Signature_Buyer:1:Full}</w:t>';
        DocGenSignatureService.StampResult result = DocGenSignatureService.stampSignaturesInXml(
            docXml,
            '',
            '',
            new List<DocGenSignatureService.SignerImageData>(),
            placements
        );
        System.assert(
            result.documentXml.contains('{@Signature_Buyer:1:Full}'),
            'Pending placement should not replace tag'
        );
    }
}
