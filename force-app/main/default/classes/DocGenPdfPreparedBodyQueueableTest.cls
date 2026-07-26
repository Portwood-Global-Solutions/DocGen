/**
 * Tests for DocGenPdfPreparedBodyQueueable.
 *
 * This class was at 0% — nothing in the org exercised a single line of it, so
 * nothing would have noticed if it broke. It is the tail of the PDF-template
 * upload path: the browser uploads a large body in base64 chunks, and this
 * queueable reassembles them into one ContentVersion and points the template
 * version at the result.
 *
 * A silent failure here does not throw. It leaves the DocGen_Template_Version__c
 * pointing at nothing, and the template simply has no body — which surfaces much
 * later as "No template file found (active or attached)" at generate time, a
 * long way from the cause.
 */
@IsTest
private class DocGenPdfPreparedBodyQueueableTest {
    /** Template + version pair, which is what the queueable updates. */
    private static DocGen_Template_Version__c newVersion(String fileName) {
        DocGen_Template__c t = new DocGen_Template__c(
            Name = 'PreparedBody ' + Datetime.now().getTime(),
            Type__c = 'PDF',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert t;
        DocGen_Template_Version__c v = new DocGen_Template_Version__c(Template__c = t.Id, Is_Active__c = true);
        insert v;
        return [SELECT Id, Template__c, Content_Version_Id__c FROM DocGen_Template_Version__c WHERE Id = :v.Id];
    }

    /**
     * Chunks of BASE64 TEXT, not of the bytes. The queueable concatenates the
     * chunks and decodes once at the end, so the split point does not have to
     * fall on a 3-byte boundary — but each chunk's VersionData must be the
     * base64 STRING, which is what the browser uploader sends.
     */
    private static List<Id> uploadChunks(String payload, Integer parts) {
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(payload));
        List<ContentVersion> cvs = new List<ContentVersion>();
        Integer size = (b64.length() / parts) + 1;
        for (Integer i = 0; i < b64.length(); i += size) {
            String slice = b64.substring(i, Math.min(i + size, b64.length()));
            cvs.add(
                new ContentVersion(
                    Title = 'chunk_' + i,
                    PathOnClient = 'chunk_' + i + '.txt',
                    VersionData = Blob.valueOf(slice)
                )
            );
        }
        insert cvs;
        List<Id> ids = new List<Id>();
        for (ContentVersion cv : [SELECT Id FROM ContentVersion WHERE Id IN :cvs ORDER BY Title]) {
            ids.add(cv.Id);
        }
        return ids;
    }

    @IsTest
    static void reassemblesChunksAndPointsTheVersionAtTheResult() {
        DocGen_Template_Version__c v = newVersion('quarterly-report.pdf');
        String payload = '%PDF-1.4 a body long enough to be worth chunking ' + '0123456789'.repeat(20);
        List<Id> chunks = uploadChunks(payload, 3);
        System.assert(chunks.size() > 1, 'the fixture must actually produce multiple chunks');

        Test.startTest();
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, 'quarterly-report.pdf', chunks));
        Test.stopTest();

        DocGen_Template_Version__c after = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :v.Id
        ];
        System.assertNotEquals(null, after.Content_Version_Id__c, 'the version must point at the assembled body');

        ContentVersion prepared = [
            SELECT Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE Id = :after.Content_Version_Id__c
        ];
        // The BYTES matter, not just that a file exists: reassembling in the
        // wrong order, or decoding each chunk separately, still produces a
        // ContentVersion of a plausible size that is not the original document.
        System.assertEquals(
            payload,
            prepared.VersionData.toString(),
            'the reassembled body must be byte-identical to what was uploaded'
        );
        System.assertEquals('quarterly-report.pdf', prepared.PathOnClient, 'extension is replaced with .pdf');
        System.assert(
            prepared.Title.startsWith('docgen_pdf_body_' + v.Template__c),
            'the title carries the template id so the file is traceable: ' + prepared.Title
        );
    }

    @IsTest
    static void fileNameWithoutAnExtensionKeepsItsName() {
        // Apex's substringBeforeLast returns the WHOLE string when the separator
        // is absent — it does not return ''. So an extensionless upload keeps its
        // name and simply gains .pdf, which is the better outcome. This test
        // originally asserted a fallback to 'template.pdf' and failed; the
        // expectation was wrong, not the code.
        DocGen_Template_Version__c v = newVersion(null);
        List<Id> chunks = uploadChunks('%PDF-1.4 no extension', 1);

        Test.startTest();
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, 'noextension', chunks));
        Test.stopTest();

        DocGen_Template_Version__c after = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :v.Id
        ];
        ContentVersion prepared = [SELECT PathOnClient FROM ContentVersion WHERE Id = :after.Content_Version_Id__c];
        System.assertEquals('noextension.pdf', prepared.PathOnClient, 'the uploaded name is preserved');
    }

    @IsTest
    static void aNameThatIsNothingButAnExtensionFallsBack() {
        // '.pdf'.substringBeforeLast('.') IS the empty string — the one input
        // that reaches the String.isBlank(pathBase) guard. Without it the file
        // would be saved as exactly ".pdf": nameless, and hidden on some systems.
        DocGen_Template_Version__c v = newVersion(null);
        List<Id> chunks = uploadChunks('%PDF-1.4 dot only', 1);

        Test.startTest();
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, '.pdf', chunks));
        Test.stopTest();

        DocGen_Template_Version__c after = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :v.Id
        ];
        ContentVersion prepared = [SELECT PathOnClient FROM ContentVersion WHERE Id = :after.Content_Version_Id__c];
        System.assertEquals('template.pdf', prepared.PathOnClient, 'never a bare .pdf');
    }

    @IsTest
    static void blankFileNameFallsBack() {
        DocGen_Template_Version__c v = newVersion(null);
        List<Id> chunks = uploadChunks('%PDF-1.4 blank name', 1);

        Test.startTest();
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, '', chunks));
        Test.stopTest();

        DocGen_Template_Version__c after = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :v.Id
        ];
        ContentVersion prepared = [SELECT PathOnClient FROM ContentVersion WHERE Id = :after.Content_Version_Id__c];
        System.assertEquals('template.pdf', prepared.PathOnClient);
    }

    /**
     * The three guard branches. Each must be a clean no-op — the queueable is
     * enqueued from a path where any of these can legitimately be missing, and
     * throwing there would surface as an unexplained async failure rather than
     * as the "nothing to assemble" it actually is.
     */
    @IsTest
    static void missingInputsAreANoOpRatherThanAFailure() {
        DocGen_Template_Version__c v = newVersion('x.pdf');
        List<Id> chunks = uploadChunks('%PDF-1.4 x', 1);
        Integer before = [SELECT COUNT() FROM ContentVersion];

        Test.startTest();
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(null, v.Id, 'x.pdf', chunks));
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, null, 'x.pdf', chunks));
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, 'x.pdf', new List<Id>()));
        // A null chunk list must be as safe as an empty one — the constructor
        // normalises it, and that normalisation is the only thing standing
        // between this and a null-pointer inside execute().
        System.enqueueJob(new DocGenPdfPreparedBodyQueueable(v.Template__c, v.Id, 'x.pdf', null));
        Test.stopTest();

        System.assertEquals(before, [SELECT COUNT() FROM ContentVersion], 'no file should have been produced');
        DocGen_Template_Version__c after = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Id = :v.Id
        ];
        System.assertEquals(null, after.Content_Version_Id__c, 'the version must be left untouched');
    }
}
