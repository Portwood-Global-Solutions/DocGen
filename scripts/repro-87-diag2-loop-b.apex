// DocGen Repro #87 — Diagnostic 2: Loop B isolation
// Run: sf apex run --target-org <org> -f scripts/repro-87-diag2-loop-b.apex
//
// Diagnostic 1 proved the LWC preview-cache loop (Loop A) is clean. This
// diagnostic isolates what's different in Loop B (renderPacketSignaturePdf
// inside TemplateSignaturePdfQueueable). The loop body at
// DocGenSignatureService.cls:1009-1043 does:
//
//   for (Integer docIdx = 0; docIdx < templateIds.size(); docIdx++) {
//       Id tid = templateIds[docIdx];
//       Map<String, Object> mergeData = DocGenService.mergeTemplateForSignature(tid, recordId);
//       String documentXml = (String) mergeData.get('documentXml');
//       ... stampSignaturesInXml ... applyWatermarkOverride ... convertToHtml ...
//   }
//
// This script replays the same first two steps (mergeTemplateForSignature +
// documentXml extraction) for 3 templates in sequence and inspects each
// returned body for its expected marker. If markers appear in the wrong
// iteration's result, mergeTemplateForSignature has cross-call state leakage.
// If markers appear correctly here but the final signed PDF is still wrong,
// the bug lives in stampSignaturesInXml/applyWatermarkOverride/convertToHtml
// or in the async context the queueable runs in.
//
// Requires the 3 REPRO87_DOC_A/B/C templates from Diagnostic 1.

List<DocGen_Template__c> tmpls = [
    SELECT Id, Name
    FROM DocGen_Template__c
    WHERE Name IN ('REPRO87_DOC_A', 'REPRO87_DOC_B', 'REPRO87_DOC_C')
    ORDER BY Name ASC
];

if (tmpls.size() != 3) {
    System.debug('========================================');
    System.debug('Repro #87 Diag 2 ABORTED: need REPRO87_DOC_A/B/C templates. Run Diagnostic 1 first.');
    System.debug('========================================');
    return;
}

Id tA = tmpls[0].Id;
Id tB = tmpls[1].Id;
Id tC = tmpls[2].Id;
System.debug('Templates: A=' + tA + ' B=' + tB + ' C=' + tC);

List<Account> accts = [SELECT Id FROM Account LIMIT 1];
Id recordId = accts.isEmpty() ? null : accts[0].Id;
if (recordId == null) {
    System.debug('Need at least one Account record. Aborted.');
    return;
}

List<Id> templateIds = new List<Id>{ tA, tB, tC };
List<String> expectedMarkers = new List<String>{ 'REPRO87_BODY_A', 'REPRO87_BODY_B', 'REPRO87_BODY_C' };

Integer pass = 0;
Integer fail = 0;

System.debug('===== Sequential mergeTemplateForSignature calls (replays Loop B body steps 1-2) =====');
for (Integer i = 0; i < templateIds.size(); i++) {
    Id tid = templateIds[i];
    String expected = expectedMarkers[i];

    Map<String, Object> mergeData = DocGenService.mergeTemplateForSignature(tid, recordId);
    String documentXml = (String) mergeData.get('documentXml');

    if (documentXml == null) {
        fail++;
        System.debug('FAIL: slot ' + i + ' (' + tid + ') returned null documentXml');
        continue;
    }

    Integer markerPos = documentXml.indexOf(expected);
    Boolean hasOwnMarker = markerPos >= 0;

    // Check for cross-contamination: this slot's documentXml must NOT contain other templates' markers.
    Boolean leakedFromA = (i != 0) && documentXml.contains('REPRO87_BODY_A');
    Boolean leakedFromB = (i != 1) && documentXml.contains('REPRO87_BODY_B');
    Boolean leakedFromC = (i != 2) && documentXml.contains('REPRO87_BODY_C');
    Boolean anyLeak = leakedFromA || leakedFromB || leakedFromC;

    String snippet = documentXml.substring(0, Math.min(250, documentXml.length()));
    System.debug('slot ' + i + ' tid=' + tid + ' markerPos=' + markerPos + ' snippet=' + snippet);

    if (hasOwnMarker && !anyLeak) {
        pass++;
        System.debug('PASS: slot ' + i + ' contains only its own marker (' + expected + ')');
    } else {
        fail++;
        System.debug(
            'FAIL: slot ' +
                i +
                ' — hasOwnMarker=' +
                hasOwnMarker +
                ' leakedFromA=' +
                leakedFromA +
                ' leakedFromB=' +
                leakedFromB +
                ' leakedFromC=' +
                leakedFromC
        );
    }
}

// Also: do the call sequence in REVERSE to surface order-dependent statics.
System.debug('===== Reverse-order calls (C, B, A) — surfaces order-dependent statics =====');
List<Id> reverseIds = new List<Id>{ tC, tB, tA };
List<String> reverseExpected = new List<String>{ 'REPRO87_BODY_C', 'REPRO87_BODY_B', 'REPRO87_BODY_A' };
for (Integer i = 0; i < reverseIds.size(); i++) {
    Id tid = reverseIds[i];
    String expected = reverseExpected[i];
    Map<String, Object> mergeData = DocGenService.mergeTemplateForSignature(tid, recordId);
    String documentXml = (String) mergeData.get('documentXml');
    if (documentXml == null) {
        fail++;
        System.debug('FAIL (reverse): slot ' + i + ' null documentXml');
        continue;
    }
    Boolean ok = documentXml.contains(expected);
    Boolean leakC = (expected != 'REPRO87_BODY_C') && documentXml.contains('REPRO87_BODY_C');
    Boolean leakB = (expected != 'REPRO87_BODY_B') && documentXml.contains('REPRO87_BODY_B');
    Boolean leakA = (expected != 'REPRO87_BODY_A') && documentXml.contains('REPRO87_BODY_A');
    if (ok && !leakA && !leakB && !leakC) {
        pass++;
        System.debug('PASS (reverse): slot ' + i + ' contains only ' + expected);
    } else {
        fail++;
        System.debug(
            'FAIL (reverse): slot ' + i + ' ok=' + ok + ' leakA=' + leakA + ' leakB=' + leakB + ' leakC=' + leakC
        );
    }
}

// Bonus: call mergeTemplateForSignature for the SAME template twice in a row — if
// some static caches the first call's result and returns it for the second template,
// re-calling with the same template should produce identical results; this is a
// sanity check that the cache reset path works.
System.debug('===== Same-template repeat (A, A) — sanity check on cache reset =====');
Map<String, Object> first = DocGenSignatureService.class.getName() == 'DocGenSignatureService'
    ? DocGenService.mergeTemplateForSignature(tA, recordId)
    : null;
Map<String, Object> second = DocGenService.mergeTemplateForSignature(tA, recordId);
String firstXml = first == null ? null : (String) first.get('documentXml');
String secondXml = (String) second.get('documentXml');
Boolean repeatOk =
    firstXml != null &&
    secondXml != null &&
    firstXml.contains('REPRO87_BODY_A') &&
    secondXml.contains('REPRO87_BODY_A');
if (repeatOk) {
    pass++;
    System.debug('PASS: same-template repeat returns A body both times');
} else {
    fail++;
    System.debug(
        'FAIL: same-template repeat — firstHasA=' +
            (firstXml != null && firstXml.contains('REPRO87_BODY_A')) +
            ' secondHasA=' +
            secondXml.contains('REPRO87_BODY_A')
    );
}

System.debug('========================================');
System.debug('REPRO #87 DIAG 2 — PASS: ' + pass + '  FAIL: ' + fail);
if (fail == 0) {
    System.debug('mergeTemplateForSignature is content-correct in sync sequential calls.');
    System.debug('Bug is NOT in mergeTemplateForSignature itself.');
    System.debug('Next: instrument renderPacketSignaturePdf line 1037 to debug-log per-iteration docHtml');
    System.debug('and run the queueable end-to-end (Diagnostic 3) — bug is downstream of merge.');
} else {
    System.debug('CONFIRMED: mergeTemplateForSignature has state leakage across consecutive calls.');
    System.debug('Inspect DocGenService.cls statics: cachedXmlParts, cachedPreDecompTemplateId,');
    System.debug('imageCounter, currentTemplateType, currentOutputFormat, runningUserContext.');
}
System.debug('========================================');
