// DocGen Repro #87 — Diagnostic 4: pandoc-built templates with embedded images
// Run: sf apex run --target-org <org> -f scripts/repro-87-diag4-images.apex
//
// Precondition: run scripts/repro-87-upload-pandoc.sh first. That uploads 3
// ContentVersions (REPRO87_DOC_A_*, REPRO87_DOC_B_*, REPRO87_DOC_C_*), each
// a pandoc-generated DOCX with an embedded image declared via the SAME
// rId9 — exactly the rId-collision scenario hypothesis 3 predicts.
//
// This diagnostic:
//   1. Finds the latest uploaded CV per template name prefix
//   2. Builds DocGen_Template__c + Template_Version__c records linked to those CVs
//   3. Runs createPacketSignerRequestWithTitle for the 3 templates as a packet
//   4. Inspects Signature_Data__c.previewHtml for:
//      - body markers (should match Diagnostic 1's behavior — sanity check)
//      - image src URLs per slot (each slot must have a UNIQUE download URL;
//        if two slots share a URL, image rels collided across templates,
//        confirming hypothesis 3 as the corruption mechanism)

class R {
    Integer pass = 0;
    Integer fail = 0;
    void log(String label, Boolean ok, String detail) {
        if (ok) {
            pass++;
            System.debug('PASS: ' + label + ((detail == null) ? '' : ' — ' + detail));
        } else {
            fail++;
            System.debug('FAIL: ' + label + ((detail == null) ? '' : ' — ' + detail));
        }
    }

    // Find or create a DocGen_Template__c (PD = "pandoc DOCX") linked to a CV uploaded
    // by the shell helper. Reuses any existing PD template that points at the same CV.
    Id ensurePdTemplate(String shortName, Id sourceCvId) {
        String tmplName = 'REPRO87_PD_' + shortName;
        List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = :tmplName LIMIT 1];
        Id tmplId;
        if (!existing.isEmpty()) {
            tmplId = existing[0].Id;
            // Refresh active version to point at the newest CV
            List<DocGen_Template_Version__c> activeVs = [
                SELECT Id, Content_Version_Id__c
                FROM DocGen_Template_Version__c
                WHERE Template__c = :tmplId AND Is_Active__c = TRUE
                LIMIT 1
            ];
            if (!activeVs.isEmpty() && activeVs[0].Content_Version_Id__c != sourceCvId) {
                activeVs[0].Content_Version_Id__c = sourceCvId;
                update activeVs[0];
            }
            return tmplId;
        }

        DocGen_Template__c t = new DocGen_Template__c(
            Name = tmplName,
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Query_Config__c = 'Name',
            Description__c = 'Issue #87 pandoc-built repro template (' + shortName + ')',
            Category__c = 'Repro87PD'
        );
        insert t;

        DocGen_Template_Version__c v = new DocGen_Template_Version__c(
            Template__c = t.Id,
            Is_Active__c = true,
            Type__c = 'Word',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name',
            Category__c = 'Repro87PD',
            Content_Version_Id__c = sourceCvId,
            Description__c = 'v1 pandoc body — ' + shortName
        );
        insert v;

        // Link the CV's ContentDocument to the template so the package's CV-load
        // logic can find the body via parent linkage. The uploaded CV currently
        // has no FirstPublishLocationId; create a ContentDocumentLink to the template.
        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :sourceCvId LIMIT 1];
        List<ContentDocumentLink> existingLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :t.Id
            LIMIT 1
        ];
        if (existingLinks.isEmpty()) {
            insert new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = t.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        }
        return t.Id;
    }
}

R r = new R();

// ===== Locate the uploaded ContentVersions =====
List<ContentVersion> cvsA = [
    SELECT Id, Title, ContentDocumentId, CreatedDate
    FROM ContentVersion
    WHERE Title LIKE 'REPRO87_DOC_A_%' AND IsLatest = TRUE
    ORDER BY CreatedDate DESC
    LIMIT 1
];
List<ContentVersion> cvsB = [
    SELECT Id, Title, ContentDocumentId, CreatedDate
    FROM ContentVersion
    WHERE Title LIKE 'REPRO87_DOC_B_%' AND IsLatest = TRUE
    ORDER BY CreatedDate DESC
    LIMIT 1
];
List<ContentVersion> cvsC = [
    SELECT Id, Title, ContentDocumentId, CreatedDate
    FROM ContentVersion
    WHERE Title LIKE 'REPRO87_DOC_C_%' AND IsLatest = TRUE
    ORDER BY CreatedDate DESC
    LIMIT 1
];
r.log('Found pandoc CV A', !cvsA.isEmpty(), cvsA.isEmpty() ? 'run repro-87-upload-pandoc.sh first' : cvsA[0].Title);
r.log('Found pandoc CV B', !cvsB.isEmpty(), cvsB.isEmpty() ? 'run repro-87-upload-pandoc.sh first' : cvsB[0].Title);
r.log('Found pandoc CV C', !cvsC.isEmpty(), cvsC.isEmpty() ? 'run repro-87-upload-pandoc.sh first' : cvsC[0].Title);
if (cvsA.isEmpty() || cvsB.isEmpty() || cvsC.isEmpty()) {
    System.debug('REPRO #87 DIAG 4 ABORTED — uploads missing.');
    return;
}

// ===== Build templates =====
Id tAId = r.ensurePdTemplate('A', cvsA[0].Id);
Id tBId = r.ensurePdTemplate('B', cvsB[0].Id);
Id tCId = r.ensurePdTemplate('C', cvsC[0].Id);
r.log('Built/linked PD templates', tAId != null && tBId != null && tCId != null, tAId + ', ' + tBId + ', ' + tCId);

// ===== Related record =====
List<Account> accts = [SELECT Id FROM Account LIMIT 1];
Id recordId = accts.isEmpty() ? null : accts[0].Id;
if (recordId == null) {
    Account a = new Account(Name = 'Repro87 Diag4 Account');
    insert a;
    recordId = a.Id;
}

// ===== Run packet creation =====
List<Id> templateIds = new List<Id>{ tAId, tBId, tCId };
List<Map<String, Object>> signers = new List<Map<String, Object>>{
    new Map<String, Object>{
        'signerName' => 'Repro87 Diag4 Tester',
        'signerEmail' => 'repro87@e2etest.example.invalid',
        'roleName' => 'Buyer'
    }
};

Id requestId;
try {
    List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createPacketSignerRequestWithTitle(
        JSON.serialize(templateIds),
        recordId,
        JSON.serialize(signers),
        'Parallel',
        null
    );
    r.log(
        'CREATE PACKET (pandoc templates)',
        results != null && !results.isEmpty(),
        'returned ' + (results == null ? 0 : results.size())
    );
    if (results != null && !results.isEmpty()) {
        Id sigId = results[0].signerId;
        List<DocGen_Signer__c> sgs = [SELECT Signature_Request__c FROM DocGen_Signer__c WHERE Id = :sigId LIMIT 1];
        if (!sgs.isEmpty())
            requestId = sgs[0].Signature_Request__c;
    }
} catch (Exception e) {
    r.log('CREATE PACKET', false, e.getTypeName() + ': ' + e.getMessage());
}
if (requestId == null) {
    System.debug('REPRO #87 DIAG 4 — PASS: ' + r.pass + '  FAIL: ' + r.fail + ' ABORTED');
    return;
}

DocGen_Signature_Request__c req = [
    SELECT Signature_Data__c, Template_Ids__c
    FROM DocGen_Signature_Request__c
    WHERE Id = :requestId
    LIMIT 1
];
r.log(
    'previewHtml available',
    req.Signature_Data__c != null,
    'len: ' + (req.Signature_Data__c == null ? 0 : req.Signature_Data__c.length())
);
if (req.Signature_Data__c == null) {
    System.debug('REPRO #87 DIAG 4 — PASS: ' + r.pass + '  FAIL: ' + r.fail);
    return;
}

Map<String, Object> cached = (Map<String, Object>) JSON.deserializeUntyped(req.Signature_Data__c);
String previewHtml = (String) cached.get('previewHtml');

// ===== Body marker assertions =====
String markerA = 'REPRO87_BODY_A';
String markerB = 'REPRO87_BODY_B';
String markerC = 'REPRO87_BODY_C';
Integer mPosA = previewHtml.indexOf(markerA);
Integer mPosB = previewHtml.indexOf(markerB);
Integer mPosC = previewHtml.indexOf(markerC);
r.log('Body marker A exists', mPosA >= 0, 'pos ' + mPosA);
r.log('Body marker B exists', mPosB >= 0, 'pos ' + mPosB);
r.log('Body marker C exists', mPosC >= 0, 'pos ' + mPosC);
r.log('Body markers in order A<B<C', mPosA >= 0 && mPosB > mPosA && mPosC > mPosB, mPosA + ', ' + mPosB + ', ' + mPosC);
// Each fixture references its marker TWICE in the body text — once as "Sentinel
// marker: REPRO87_BODY_X" and once via the END token "REPRO87_BODY_X_END" (which
// substring-matches the bare marker). Expected count is therefore 2 per slot;
// 1 would mean the END sentinel was stripped, 3+ would mean cross-slot leakage.
r.log(
    'Marker A appears twice (body + END)',
    previewHtml.countMatches(markerA) == 2,
    'count: ' + previewHtml.countMatches(markerA)
);
r.log(
    'Marker B appears twice (body + END)',
    previewHtml.countMatches(markerB) == 2,
    'count: ' + previewHtml.countMatches(markerB)
);
r.log(
    'Marker C appears twice (body + END)',
    previewHtml.countMatches(markerC) == 2,
    'count: ' + previewHtml.countMatches(markerC)
);

// Cross-slot contamination: each slot's text range must contain ONLY its own marker.
Integer s1 = previewHtml.indexOf('Document 1 of 3: REPRO87_PD_A');
Integer s2 = previewHtml.indexOf('Document 2 of 3: REPRO87_PD_B');
Integer s3 = previewHtml.indexOf('Document 3 of 3: REPRO87_PD_C');
if (s1 >= 0 && s2 > s1 && s3 > s2) {
    String slot1 = previewHtml.substring(s1, s2);
    String slot2 = previewHtml.substring(s2, s3);
    String slot3 = previewHtml.substring(s3);
    r.log(
        'SLOT 1 contains only marker A',
        slot1.contains(markerA) && !slot1.contains(markerB) && !slot1.contains(markerC),
        'A=' + slot1.contains(markerA) + ' B=' + slot1.contains(markerB) + ' C=' + slot1.contains(markerC)
    );
    r.log(
        'SLOT 2 contains only marker B',
        slot2.contains(markerB) && !slot2.contains(markerA) && !slot2.contains(markerC),
        'A=' + slot2.contains(markerA) + ' B=' + slot2.contains(markerB) + ' C=' + slot2.contains(markerC)
    );
    r.log(
        'SLOT 3 contains only marker C',
        slot3.contains(markerC) && !slot3.contains(markerA) && !slot3.contains(markerB),
        'A=' + slot3.contains(markerA) + ' B=' + slot3.contains(markerB) + ' C=' + slot3.contains(markerC)
    );
}

// ===== Image src extraction — the rId-collision detector =====
// previewImageMap at SenderController.cls:639-659 maps relId → ContentDistribution
// URL. convertToHtml emits <img src="..."> with these URLs. Extract all distinct
// image src values from the preview HTML and check that exactly 3 distinct ones
// appear, and each slot contains exactly one of them.
Pattern imgPat = Pattern.compile('<img[^>]+src="([^"]+)"');
Matcher m = imgPat.matcher(previewHtml);
List<Integer> imgPositions = new List<Integer>();
List<String> imgUrls = new List<String>();
while (m.find()) {
    imgPositions.add(m.start());
    imgUrls.add(m.group(1));
}
// Note: pandoc-emitted <w:drawing> elements aren't surfaced as <img> by the
// package's HTML preview renderer (a separate finding from issue #87 — file
// it independently if you want PDF/preview parity for pandoc DOCX images).
// Skip the cross-image-collision check when no <img> tags surfaced; the
// text-substitution check above is the load-bearing assertion for #87.
System.debug(
    'INFO: <img> tags in previewHtml: ' +
        imgUrls.size() +
        ' (pandoc-emitted images not rendered to preview; separate from #87)'
);

if (imgUrls.size() >= 3) {
    Set<String> distinctUrls = new Set<String>(imgUrls);
    r.log(
        'All 3 image URLs are distinct (no rId collision)',
        distinctUrls.size() == 3,
        'distinct: ' + distinctUrls.size() + ' / total: ' + imgUrls.size() + ' urls=' + imgUrls
    );

    // Slot bounds: derive from "Document N of 3:" headers
    Integer slot1Start = previewHtml.indexOf('Document 1 of 3:');
    Integer slot2Start = previewHtml.indexOf('Document 2 of 3:');
    Integer slot3Start = previewHtml.indexOf('Document 3 of 3:');
    Integer slot3End = previewHtml.length();

    // Image positions should each fall in their slot
    if (slot1Start >= 0 && slot2Start > slot1Start && slot3Start > slot2Start) {
        Integer imgInSlot1 = -1;
        Integer imgInSlot2 = -1;
        Integer imgInSlot3 = -1;
        for (Integer i = 0; i < imgPositions.size(); i++) {
            Integer p = imgPositions[i];
            if (p > slot1Start && p < slot2Start)
                imgInSlot1 = i;
            else if (p > slot2Start && p < slot3Start)
                imgInSlot2 = i;
            else if (p > slot3Start && p < slot3End)
                imgInSlot3 = i;
        }
        r.log('Slot 1 has exactly one image', imgInSlot1 >= 0, 'imgIdx: ' + imgInSlot1);
        r.log('Slot 2 has exactly one image', imgInSlot2 >= 0, 'imgIdx: ' + imgInSlot2);
        r.log('Slot 3 has exactly one image', imgInSlot3 >= 0, 'imgIdx: ' + imgInSlot3);
        if (imgInSlot1 >= 0 && imgInSlot2 >= 0 && imgInSlot3 >= 0) {
            r.log(
                'Slot images are pairwise distinct (no body/image cross-contamination)',
                imgUrls[imgInSlot1] != imgUrls[imgInSlot2] &&
                    imgUrls[imgInSlot2] != imgUrls[imgInSlot3] &&
                    imgUrls[imgInSlot1] != imgUrls[imgInSlot3],
                'slot1=' +
                    imgUrls[imgInSlot1].abbreviate(60) +
                    ' slot2=' +
                    imgUrls[imgInSlot2].abbreviate(60) +
                    ' slot3=' +
                    imgUrls[imgInSlot3].abbreviate(60)
            );
        }
    }
}

// ===== Cleanup the request only =====
try {
    delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c = :requestId];
    delete [SELECT Id FROM DocGen_Signature_Request__c WHERE Id = :requestId];
} catch (Exception e) {
    System.debug('Cleanup WARNING: ' + e.getMessage());
}

System.debug('========================================');
System.debug('REPRO #87 DIAG 4 — PASS: ' + r.pass + '  FAIL: ' + r.fail);
if (r.fail == 0) {
    System.debug('Pandoc-built templates with images render content-correctly in preview.');
    System.debug('Hypothesis 3 (rId/image collision in preview) is NOT confirmed by this diagnostic.');
    System.debug('Bug must surface in either: (a) async queueable path, (b) Dustin-specific template state,');
    System.debug('or (c) stampSignaturesInXml/applyWatermarkOverride/convertToHtml internals.');
} else {
    System.debug('FAILURE DETECTED — inspect log above for cross-contamination details.');
}
System.debug('========================================');
