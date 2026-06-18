/**
 * Tests for the point-in-time signature snapshot (Frozen_Document__c).
 *
 * The integrity guarantee: a template-based signature request renders the signed PDF
 * from the document body frozen at CREATION, never a live re-merge — so if the record
 * changes between send and sign, the signer still signs exactly what was reviewed.
 *
 * These exercise the freeze/load/hash mechanics directly (deterministic, no rendering)
 * plus the round-trip that proves frozen content is immune to later "re-merge" data.
 */
@isTest
private class DocGenSignatureSnapshotTest {
    // A merge output shaped like DocGenService.mergeTemplateForSignature's return.
    private static Map<String, Object> mergeOutput(String body, String type) {
        return new Map<String, Object>{
            'combinedDocumentXml' => body,
            'documentXml' => body,
            'relsXml' => '<rels/>',
            'contentTypesXml' => '<types/>',
            'templateType' => type,
            'docTitle' => 'Test Doc',
            'stylesXml' => '<styles/>',
            'numberingXml' => null,
            'pdfImageMap' => new Map<String, String>{ 'rId1' => '/sfc/x' }
        };
    }

    @isTest
    static void freezeAndLoadRoundTrip_singleTemplate() {
        Id tid = '0Ax000000000001AAA';
        String json = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{ mergeOutput('<body>Original Corp</body>', 'Word') },
            new List<Id>{ tid }
        );
        System.assertNotEquals(null, json, 'A normal-size body should be frozen');

        List<Map<String, Object>> docs = DocGenSignatureService.loadFrozenMergeData(json);
        System.assertNotEquals(null, docs, 'Frozen JSON should load back');
        System.assertEquals(1, docs.size(), 'One template → one frozen doc');
        Map<String, Object> d = docs[0];
        System.assertEquals('<body>Original Corp</body>', (String) d.get('combinedDocumentXml'), 'Body preserved');
        System.assertEquals('<body>Original Corp</body>', (String) d.get('documentXml'), 'documentXml mirrors body');
        System.assertEquals('Word', (String) d.get('templateType'), 'templateType preserved');
        System.assertEquals('<rels/>', (String) d.get('relsXml'), 'relsXml preserved');
        System.assertEquals('<types/>', (String) d.get('contentTypesXml'), 'contentTypesXml preserved');
        // pdfImageMap is intentionally empty — caller fills from the cached image map.
        System.assert(d.get('pdfImageMap') instanceof Map<String, String>, 'pdfImageMap is an (empty) map');
        System.assertEquals(0, ((Map<String, String>) d.get('pdfImageMap')).size(), 'pdfImageMap starts empty');
    }

    @isTest
    static void freezeAndLoadRoundTrip_packetPreservesOrder() {
        List<Id> tids = new List<Id>{ '0Ax000000000001AAA', '0Ax000000000002AAA' };
        String json = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{
                mergeOutput('<body>DOC ONE</body>', 'Word'),
                mergeOutput('<body>DOC TWO</body>', 'Word')
            },
            tids
        );
        List<Map<String, Object>> docs = DocGenSignatureService.loadFrozenMergeData(json);
        System.assertEquals(2, docs.size(), 'Two templates → two frozen docs');
        System.assertEquals('<body>DOC ONE</body>', (String) docs[0].get('combinedDocumentXml'), 'Order preserved [0]');
        System.assertEquals('<body>DOC TWO</body>', (String) docs[1].get('combinedDocumentXml'), 'Order preserved [1]');
    }

    @isTest
    static void pointInTime_frozenBodyIsImmuneToLaterData() {
        // Freeze the body as it was at "send" time.
        String json = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{ mergeOutput('Amount: $100 — Original Corp', 'HTML') },
            new List<Id>{ '0Ax000000000001AAA' }
        );

        // Simulate the record changing afterward by producing a DIFFERENT live merge.
        // The frozen JSON must still yield the ORIGINAL content — that is the whole fix.
        Map<String, Object> liveAfterChange = mergeOutput('Amount: $999 — Changed Corp', 'HTML');

        List<Map<String, Object>> frozen = DocGenSignatureService.loadFrozenMergeData(json);
        String frozenBody = (String) frozen[0].get('combinedDocumentXml');

        System.assert(frozenBody.contains('$100'), 'Frozen body retains the reviewed amount');
        System.assert(frozenBody.contains('Original Corp'), 'Frozen body retains the reviewed party');
        System.assert(!frozenBody.contains('$999'), 'Frozen body must NOT reflect the later record change');
        System.assert(
            frozenBody != (String) liveAfterChange.get('combinedDocumentXml'),
            'Signed-from-frozen differs from a live re-merge after the record changed'
        );
    }

    @isTest
    static void oversizedBodyIsFrozenToContentVersion() {
        // #156: a body over the old 131,072 LongText limit is no longer dropped — it
        // serializes in full and persists to a ContentVersion, so large templates get a
        // true point-in-time snapshot instead of degrading to a live re-merge at sign time.
        String huge = 'X'.repeat(140000);
        String json = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{ mergeOutput(huge, 'Word') },
            new List<Id>{ '0Ax000000000001AAA' }
        );
        System.assert(json != null && json.length() > 131072, 'Oversized snapshot serializes in full (no cap)');

        Test.startTest();
        Id cvId = DocGenSignatureService.saveFrozenSnapshotCv(json);
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'Oversized snapshot persists to a ContentVersion');
        String roundTrip = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1].VersionData.toString();
        System.assertEquals(json, roundTrip, 'CV round-trips the oversized snapshot intact');
        System.assertNotEquals(
            null,
            DocGenSignatureService.loadFrozenMergeData(roundTrip),
            'Oversized snapshot loads back into renderable merge data'
        );
    }

    @isTest
    static void loadHandlesAbsentAndCorruptGracefully() {
        System.assertEquals(null, DocGenSignatureService.loadFrozenMergeData(null), 'Null → null (legacy request)');
        System.assertEquals(null, DocGenSignatureService.loadFrozenMergeData(''), 'Blank → null');
        System.assertEquals(
            null,
            DocGenSignatureService.loadFrozenMergeData('{not valid json'),
            'Corrupt JSON → null (degrade to live merge, never throw)'
        );
        System.assertEquals(
            null,
            DocGenSignatureService.loadFrozenMergeData('{"v":1,"templateType":"Word","docs":"oops"}'),
            'docs not a list → null'
        );
        System.assertEquals(
            null,
            DocGenSignatureService.loadFrozenMergeData('{"v":1,"templateType":"Word","docs":[]}'),
            'Empty docs → null'
        );
    }

    @isTest
    static void hashIsStableAndContentBound() {
        String json = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{ mergeOutput('<body>A</body>', 'Word') },
            new List<Id>{ '0Ax000000000001AAA' }
        );
        String h1 = DocGenSignatureService.hashFrozenDocument(json);
        String h2 = DocGenSignatureService.hashFrozenDocument(json);
        System.assertEquals(64, h1.length(), 'SHA-256 hex is 64 chars');
        System.assertEquals(h1, h2, 'Hash is deterministic for identical content');

        String other = DocGenSignatureService.buildFrozenDocumentJson(
            new List<Map<String, Object>>{ mergeOutput('<body>B</body>', 'Word') },
            new List<Id>{ '0Ax000000000001AAA' }
        );
        System.assertNotEquals(
            h1,
            DocGenSignatureService.hashFrozenDocument(other),
            'Different content → different hash'
        );
        System.assertEquals(null, DocGenSignatureService.hashFrozenDocument(null), 'Null content → null hash');
    }

    @isTest
    static void emptyInputsReturnNull() {
        System.assertEquals(
            null,
            DocGenSignatureService.buildFrozenDocumentJson(null, null),
            'Null merge outputs → null'
        );
        System.assertEquals(
            null,
            DocGenSignatureService.buildFrozenDocumentJson(new List<Map<String, Object>>(), null),
            'Empty merge outputs → null'
        );
    }
}
