// DocGen Diagnostic — Multipath Signature Duplicate Documents
// Run: sf apex run --target-org <org> -f scripts/diag-multipath.apex
//
// Purpose: User reported that selecting 4 templates in docGenSignatureSender
// produces a packet whose document headers are correct (1, 2, 3, 4) but whose
// document BODIES duplicate (e.g., 1, 2, 1, 2). Pattern can vary.
//
// This script mimics the per-template loop in
// DocGenSignatureSenderController.createPacketSignerRequestWithTitle()
// (force-app/main/default/classes/DocGenSignatureSenderController.cls:613-670)
// and asserts that each iteration produces unique output for distinct templates.
//
// Picks the 4 most-recently-modified active templates and a record (Account by
// default; override RECORD_ID below). Calls mergeTemplateForSignature() and
// DocGenHtmlRenderer.convertToHtml() in the same order the sender does, then
// hashes documentXml and HTML per iteration and reports any collisions.
//
// If collisions appear: root cause is in the merge / convert pipeline (likely
// stale static state in DocGenService or DocGenHtmlRenderer).
// If no collisions: root cause is upstream — LWC sending duplicated templateIds,
// or downstream — signer-page render path consuming a stale cache.

Integer pass = 0;
Integer fail = 0;

// ───────── Setup ─────────
String recordIdOverride = null; // set to a record Id to override Account default

List<DocGen_Template__c> templates;
try {
    // Prefer the seeded "Diag Multipath" templates (have unique sentinel markers
    // for cross-leak detection). Fall back to any 4 active Word templates if not seeded.
    Set<Id> activeWordTemplateIds = new Set<Id>();
    for (DocGen_Template_Version__c v : [
        SELECT Template__c
        FROM DocGen_Template_Version__c
        WHERE Is_Active__c = TRUE AND Type__c = 'Word'
    ]) {
        activeWordTemplateIds.add(v.Template__c);
    }
    templates = [
        SELECT Id, Name
        FROM DocGen_Template__c
        WHERE Name LIKE 'Diag Multipath %' AND Id IN :activeWordTemplateIds
        ORDER BY Name ASC
    ];
    if (templates.size() < 4) {
        System.debug(
            'SETUP: only found ' +
                templates.size() +
                ' Diag Multipath templates. Run scripts/diag-multipath-seed.apex first, ' +
                'or falling back to any 4 active Word templates (no sentinel cross-leak check).'
        );
        templates = [
            SELECT Id, Name
            FROM DocGen_Template__c
            WHERE Id IN :activeWordTemplateIds
            ORDER BY LastModifiedDate DESC
            LIMIT 4
        ];
    }
} catch (Exception e) {
    System.debug('SETUP: FAIL — could not query templates: ' + e.getMessage());
    return;
}

if (templates.size() < 4) {
    System.debug(
        'SETUP: FAIL — need ≥4 active Word templates, found ' +
            templates.size() +
            '. Create more or seed via e2e-02-template-crud.apex.'
    );
    return;
}

System.debug('SETUP: using ' + templates.size() + ' templates:');
for (Integer i = 0; i < templates.size(); i++) {
    System.debug('  [' + i + '] ' + templates[i].Id + ' — ' + templates[i].Name);
}

String recordId;
if (String.isNotBlank(recordIdOverride)) {
    recordId = recordIdOverride;
} else {
    List<Account> accs = [
        SELECT Id
        FROM Account
        WHERE Name = 'Diag Multipath Acct'
        LIMIT 1
    ];
    if (accs.isEmpty()) {
        // Fall back to any account
        accs = [SELECT Id FROM Account LIMIT 1];
    }
    if (accs.isEmpty()) {
        System.debug('SETUP: FAIL — no Account record found. Run diag-multipath-seed.apex or set recordIdOverride.');
        return;
    }
    recordId = accs[0].Id;
}
System.debug('SETUP: recordId = ' + recordId);

// ───────── Mimic sender loop, capture per-iteration output ─────────
List<String> docXmls = new List<String>();
List<String> htmls = new List<String>();
List<Integer> docXmlLens = new List<Integer>();
List<Integer> htmlLens = new List<Integer>();
List<String> tplNames = new List<String>();

for (Integer docIdx = 0; docIdx < templates.size(); docIdx++) {
    Id tid = templates[docIdx].Id;
    String tname = templates[docIdx].Name;
    tplNames.add(tname);

    try {
        Map<String, Object> mergeData = DocGenService.mergeTemplateForSignature(tid, recordId);
        String docXml = (String) mergeData.get('documentXml');
        Map<String, String> pdfImageMap = (Map<String, String>) mergeData.get('pdfImageMap');
        if (pdfImageMap == null) {
            pdfImageMap = new Map<String, String>();
        }

        // Apply watermark override — same as sender does
        DocGenService.applyWatermarkOverride(tid);

        // Mimic the preview image map build (skip ContentDistribution side effects;
        // they don't affect docXml/html identity which is what we're testing).
        Map<String, String> previewImageMap = new Map<String, String>();
        for (String relId : pdfImageMap.keySet()) {
            previewImageMap.put(relId, pdfImageMap.get(relId));
        }

        String html = DocGenHtmlRenderer.convertToHtml(docXml, previewImageMap);

        docXmls.add(docXml == null ? '' : docXml);
        htmls.add(html == null ? '' : html);
        docXmlLens.add(docXml == null ? 0 : docXml.length());
        htmlLens.add(html == null ? 0 : html.length());

        System.debug(
            'ITER ' +
                docIdx +
                ' — tid=' +
                tid +
                ' name="' +
                tname +
                '" docXmlLen=' +
                docXmlLens[docIdx] +
                ' htmlLen=' +
                htmlLens[docIdx]
        );
    } catch (Exception e) {
        fail++;
        System.debug('ITER ' + docIdx + ': FAIL — exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
        docXmls.add('');
        htmls.add('');
        docXmlLens.add(0);
        htmlLens.add(0);
    }
}

// ───────── Assertion 1: every documentXml unique ─────────
System.debug('=== ASSERT 1: documentXml uniqueness ===');
Boolean docXmlAllUnique = true;
for (Integer i = 0; i < docXmls.size(); i++) {
    for (Integer j = i + 1; j < docXmls.size(); j++) {
        if (docXmls[i].length() > 0 && docXmls[i] == docXmls[j]) {
            fail++;
            docXmlAllUnique = false;
            System.debug(
                'COLLISION docXml[' +
                    i +
                    '] (' +
                    tplNames[i] +
                    ') == docXml[' +
                    j +
                    '] (' +
                    tplNames[j] +
                    ') — SMOKING GUN: mergeTemplateForSignature returned identical XML for distinct templates.'
            );
        }
    }
}
if (docXmlAllUnique) {
    pass++;
    System.debug('ASSERT 1: PASS — all documentXml outputs distinct.');
}

// ───────── Assertion 2: every HTML unique ─────────
System.debug('=== ASSERT 2: convertToHtml uniqueness ===');
Boolean htmlAllUnique = true;
for (Integer i = 0; i < htmls.size(); i++) {
    for (Integer j = i + 1; j < htmls.size(); j++) {
        if (htmls[i].length() > 0 && htmls[i] == htmls[j]) {
            fail++;
            htmlAllUnique = false;
            System.debug(
                'COLLISION html[' +
                    i +
                    '] (' +
                    tplNames[i] +
                    ') == html[' +
                    j +
                    '] (' +
                    tplNames[j] +
                    ') — convertToHtml emitted identical output for distinct docXml inputs (or identical inputs).'
            );
        }
    }
}
if (htmlAllUnique) {
    pass++;
    System.debug('ASSERT 2: PASS — all convertToHtml outputs distinct.');
}

// ───────── Assertion 2.5: Diag sentinel markers (only when seeded) ─────────
// If templates are the seeded "Diag Multipath ALPHA/BRAVO/CHARLIE/DELTA" set,
// each iteration's HTML must contain its OWN DIAG_<MARKER> and none of the others.
System.debug('=== ASSERT 2.5: DIAG sentinel attribution (only if seeded) ===');
Boolean seededRun = true;
List<String> diagMarkers = new List<String>();
for (Integer i = 0; i < tplNames.size(); i++) {
    if (tplNames[i].startsWith('Diag Multipath ')) {
        diagMarkers.add('DIAG_' + tplNames[i].substringAfter('Diag Multipath ').trim());
    } else {
        seededRun = false;
        break;
    }
}
if (seededRun) {
    Boolean sentinelOK = true;
    for (Integer i = 0; i < htmls.size(); i++) {
        String mine = diagMarkers[i];
        if (!htmls[i].contains(mine)) {
            fail++;
            sentinelOK = false;
            System.debug(
                'SENTINEL MISS: iter ' + i + ' (' + tplNames[i] + ') html does NOT contain its marker ' + mine
            );
        }
        for (Integer j = 0; j < diagMarkers.size(); j++) {
            if (i == j) {
                continue;
            }
            String other = diagMarkers[j];
            if (htmls[i].contains(other)) {
                fail++;
                sentinelOK = false;
                System.debug(
                    'SENTINEL CROSS-LEAK: iter ' +
                        i +
                        ' (' +
                        tplNames[i] +
                        ') html contains ' +
                        other +
                        ' which belongs to iter ' +
                        j +
                        ' (' +
                        tplNames[j] +
                        ').'
                );
            }
        }
    }
    if (sentinelOK) {
        pass++;
        System.debug('ASSERT 2.5: PASS — each iteration HTML contains exactly its own DIAG marker.');
    }
} else {
    System.debug('ASSERT 2.5: SKIP — templates are not the seeded Diag Multipath set.');
}

// ───────── Assertion 3: each HTML contains its template name ─────────
// Templates often render their Name somewhere in body or header. This is a
// soft assertion — only counts as fail if the template Name appears in a
// DIFFERENT iteration's HTML but not its own (clear evidence of cross-leak).
System.debug('=== ASSERT 3: template Name attribution (soft) ===');
Boolean attributionOK = true;
for (Integer i = 0; i < htmls.size(); i++) {
    String name = tplNames[i];
    if (String.isBlank(name) || name.length() < 4) {
        continue; // too short to be a reliable marker
    }
    for (Integer j = 0; j < htmls.size(); j++) {
        if (i == j) {
            continue;
        }
        if (htmls[j].contains(name) && !htmls[i].contains(name)) {
            fail++;
            attributionOK = false;
            System.debug(
                'CROSS-LEAK: template[' +
                    i +
                    '] name "' +
                    name +
                    '" appears in html[' +
                    j +
                    '] but NOT in its own html[' +
                    i +
                    '] — likely indicates iteration ' +
                    j +
                    ' rendered template ' +
                    i +
                    '\'s content.'
            );
        }
    }
}
if (attributionOK) {
    pass++;
    System.debug('ASSERT 3: PASS (soft) — no cross-attribution detected by name marker.');
}

// ───────── Assertion 4: re-call iteration 0 after the loop, compare to first ─────────
// If mergeTemplate has stale static state, calling it again for the SAME template
// after a sequence of other templates should still produce identical output.
System.debug('=== ASSERT 4: replay first template after sequence ===');
try {
    Map<String, Object> replay = DocGenService.mergeTemplateForSignature(templates[0].Id, recordId);
    String replayXml = (String) replay.get('documentXml');
    if (replayXml != null && replayXml == docXmls[0]) {
        pass++;
        System.debug('ASSERT 4: PASS — replay of templates[0] reproduces original docXml.');
    } else {
        fail++;
        System.debug(
            'ASSERT 4: FAIL — replay of templates[0] differs from original. ' +
                'origLen=' +
                docXmlLens[0] +
                ' replayLen=' +
                (replayXml == null ? 0 : replayXml.length()) +
                ' — indicates stale state across calls.'
        );
    }
} catch (Exception e) {
    fail++;
    System.debug('ASSERT 4: FAIL — replay threw: ' + e.getMessage());
}

// ───────── Summary ─────────
System.debug('────────────────────────────────────');
System.debug('PASS: ' + pass + '  FAIL: ' + fail);
if (fail == 0) {
    System.debug('ALL TESTS PASSED — merge/convert pipeline is clean.');
    System.debug(
        'NEXT: bug is upstream (LWC sending duplicate templateIds) or downstream ' +
            '(signer-side fetchDocumentData consuming stale cache). Capture a real ' +
            'DocGen_Signature_Request__c.Id from a reproducer and dump its ' +
            'Signature_Data__c + Template_Ids__c to compare.'
    );
} else {
    System.debug('FAILURES DETECTED — root cause is in the merge/convert pipeline.');
    System.debug(
        'NEXT: audit static state in DocGenService.mergeTemplate / ' +
        'tryMergeFromPreDecomposed / DocGenHtmlRenderer for cross-iteration leaks.'
    );
}
