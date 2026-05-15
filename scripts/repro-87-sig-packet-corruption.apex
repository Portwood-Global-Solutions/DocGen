// DocGen Repro — Issue #87: signature packets (3+ templates) render wrong source document
// Run: sf apex run --target-org <org> -f scripts/repro-87-sig-packet-corruption.apex
//
// This script is fully self-contained: it builds 3 minimal Word templates with
// distinct marker text (REPRO87_BODY_A/B/C) in their bodies, then runs the
// signature packet creation through createPacketSignerRequestWithTitle (the LWC
// path) and asserts that each marker appears in its expected slot of the cached
// preview HTML. If a marker leaks into the wrong slot — or any marker is
// missing or duplicated — Loop A is the bug surface (preview cache build in
// DocGenSignatureSenderController.cls:632).
//
// Diagnostic 2 (renderPacketSignaturePdf, the queueable PDF assembly loop) is
// a follow-up that needs the request to be fully signed first; skipped here.

// Inner class because anonymous Apex doesn't support top-level function declarations.
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

    // Builds a minimal valid .docx Blob with `marker` text in the body and a
    // {@Signature_Buyer} tag so signature placement detection has something to find.
    Blob buildDocx(String marker) {
        String doc =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<w:body>' +
            '<w:p><w:r><w:t xml:space="preserve">Repro 87 — body marker: ' +
            marker +
            '</w:t></w:r></w:p>' +
            '<w:p><w:r><w:t>{@Signature_Buyer}</w:t></w:r></w:p>' +
            '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>' +
            '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080"/>' +
            '</w:sectPr></w:body></w:document>';
        String rels =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
            '</Relationships>';
        String ct =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
            '</Types>';
        Compression.ZipWriter zw = new Compression.ZipWriter();
        zw.addEntry('[Content_Types].xml', Blob.valueOf(ct));
        zw.addEntry('_rels/.rels', Blob.valueOf(rels));
        zw.addEntry('word/document.xml', Blob.valueOf(doc));
        return zw.getArchive();
    }

    // Idempotent setup: returns the template Id for `name`, creating template +
    // active version + body ContentVersion if missing.
    Id ensureTemplate(String name, String marker) {
        List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = :name LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        DocGen_Template__c t = new DocGen_Template__c(
            Name = name,
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Query_Config__c = 'Name',
            Description__c = 'Issue #87 repro template (' + marker + ')',
            Category__c = 'Repro87'
        );
        insert t;

        DocGen_Template_Version__c v = new DocGen_Template_Version__c(
            Template__c = t.Id,
            Is_Active__c = true,
            Type__c = 'Word',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name',
            Category__c = 'Repro87',
            Description__c = 'v1 — ' + marker
        );
        insert v;

        ContentVersion cv = new ContentVersion(
            Title = name,
            PathOnClient = name + '.docx',
            VersionData = buildDocx(marker),
            FirstPublishLocationId = t.Id
        );
        insert cv;

        v.Content_Version_Id__c = cv.Id;
        update v;
        return t.Id;
    }
}

// Instance handle — anonymous Apex doesn't allow static on inner-class fields.
R r = new R();

// ===== SETUP — build 3 templates if missing =====
Id tAId;
Id tBId;
Id tCId;
try {
    tAId = r.ensureTemplate('REPRO87_DOC_A', 'REPRO87_BODY_A');
    tBId = r.ensureTemplate('REPRO87_DOC_B', 'REPRO87_BODY_B');
    tCId = r.ensureTemplate('REPRO87_DOC_C', 'REPRO87_BODY_C');
    r.log('SETUP templates exist', tAId != null && tBId != null && tCId != null, tAId + ', ' + tBId + ', ' + tCId);
} catch (Exception e) {
    r.log('SETUP', false, e.getTypeName() + ': ' + e.getMessage());
    System.debug('========================================');
    System.debug('REPRO #87 — PASS: ' + r.pass + '  FAIL: ' + r.fail + '  ABORTED (setup failed)');
    System.debug('========================================');
    return;
}

DocGen_Template__c tA = [SELECT Id, Name FROM DocGen_Template__c WHERE Id = :tAId LIMIT 1];
DocGen_Template__c tB = [SELECT Id, Name FROM DocGen_Template__c WHERE Id = :tBId LIMIT 1];
DocGen_Template__c tC = [SELECT Id, Name FROM DocGen_Template__c WHERE Id = :tCId LIMIT 1];
System.debug('Templates: A=' + tA.Name + ' B=' + tB.Name + ' C=' + tC.Name);

// ===== Find a related record =====
Id recordId;
List<Account> accts = [SELECT Id FROM Account LIMIT 1];
if (accts.isEmpty()) {
    Account a = new Account(Name = 'Repro87 Test Account');
    insert a;
    recordId = a.Id;
} else {
    recordId = accts[0].Id;
}
System.debug('Related record: ' + recordId);

// ===== Build packet payload =====
List<Id> templateIds = new List<Id>{ tA.Id, tB.Id, tC.Id };
String templateIdsJson = JSON.serialize(templateIds);

// Signer-input keys per DocGenSignatureSenderController.cls:1224-1227:
//   signerName, signerEmail, roleName, contactId (optional)
// NOTE: packet creation will attempt a branded email to this signer. Use a
// clearly-fake address; non-OWA orgs may throw on send.
List<Map<String, Object>> signers = new List<Map<String, Object>>{
    new Map<String, Object>{
        'signerName' => 'Repro87 Tester',
        'signerEmail' => 'repro87@e2etest.example.invalid',
        'roleName' => 'Buyer'
    }
};
String signersJson = JSON.serialize(signers);

// ===== Call the LWC creation path =====
Id requestId;
try {
    List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createPacketSignerRequestWithTitle(
        templateIdsJson,
        recordId,
        signersJson,
        'Parallel',
        null
    );
    r.log(
        'CREATE PACKET (LWC path)',
        results != null && !results.isEmpty(),
        'returned ' + (results == null ? 0 : results.size()) + ' signer result(s)'
    );
    if (results != null && !results.isEmpty()) {
        Id sigId = results[0].signerId;
        List<DocGen_Signer__c> sgs = [SELECT Signature_Request__c FROM DocGen_Signer__c WHERE Id = :sigId LIMIT 1];
        if (!sgs.isEmpty()) {
            requestId = sgs[0].Signature_Request__c;
        }
    }
} catch (Exception e) {
    r.log('CREATE PACKET (LWC path)', false, e.getTypeName() + ': ' + e.getMessage());
}

if (requestId == null) {
    System.debug('========================================');
    System.debug('REPRO #87 — PASS: ' + r.pass + '  FAIL: ' + r.fail + '  ABORTED (no requestId)');
    System.debug('========================================');
    return;
}

// ===== Inspect Signature_Data__c.previewHtml =====
DocGen_Signature_Request__c req;
try {
    req = [
        SELECT Id, Template_Ids__c, Signature_Data__c
        FROM DocGen_Signature_Request__c
        WHERE Id = :requestId
        LIMIT 1
    ];
    r.log(
        'LOAD REQUEST',
        req.Signature_Data__c != null,
        'Signature_Data__c len: ' + (req.Signature_Data__c == null ? 0 : req.Signature_Data__c.length())
    );
    r.log(
        'Template_Ids__c PERSISTED',
        req.Template_Ids__c != null &&
            req.Template_Ids__c.contains(tA.Id) &&
            req.Template_Ids__c.contains(tB.Id) &&
            req.Template_Ids__c.contains(tC.Id),
        req.Template_Ids__c
    );
} catch (Exception e) {
    r.log('LOAD REQUEST', false, e.getMessage());
}

if (req == null || req.Signature_Data__c == null) {
    System.debug('========================================');
    System.debug('REPRO #87 — PASS: ' + r.pass + '  FAIL: ' + r.fail + '  ABORTED');
    System.debug('========================================');
    return;
}

Map<String, Object> cached = (Map<String, Object>) JSON.deserializeUntyped(req.Signature_Data__c);
String previewHtml = (String) cached.get('previewHtml');
r.log(
    'previewHtml NOT BLANK',
    String.isNotBlank(previewHtml),
    'len: ' + (previewHtml == null ? 0 : previewHtml.length())
);

if (String.isBlank(previewHtml)) {
    System.debug('========================================');
    System.debug('REPRO #87 — PASS: ' + r.pass + '  FAIL: ' + r.fail + '  ABORTED');
    System.debug('========================================');
    return;
}

// ===== Diagnostic — slot header positions =====
// Doc title format from DocGenSignatureSenderController.cls:669-677: "Document <N> of 3: <NAME>"
String hdrA = 'Document 1 of 3: ' + tA.Name.escapeHtml4();
String hdrB = 'Document 2 of 3: ' + tB.Name.escapeHtml4();
String hdrC = 'Document 3 of 3: ' + tC.Name.escapeHtml4();
Integer posA = previewHtml.indexOf(hdrA);
Integer posB = previewHtml.indexOf(hdrB);
Integer posC = previewHtml.indexOf(hdrC);
r.log('SLOT 1 header is template A', posA >= 0, hdrA + ' @ ' + posA);
r.log('SLOT 2 header is template B', posB >= 0, hdrB + ' @ ' + posB);
r.log('SLOT 3 header is template C', posC >= 0, hdrC + ' @ ' + posC);
r.log(
    'SLOTS IN ORDER (A < B < C)',
    posA >= 0 && posB > posA && posC > posB,
    'positions: ' + posA + ', ' + posB + ', ' + posC
);
r.log('HEADER A appears exactly once', previewHtml.countMatches(hdrA) == 1, 'count: ' + previewHtml.countMatches(hdrA));
r.log('HEADER B appears exactly once', previewHtml.countMatches(hdrB) == 1, 'count: ' + previewHtml.countMatches(hdrB));
r.log('HEADER C appears exactly once', previewHtml.countMatches(hdrC) == 1, 'count: ' + previewHtml.countMatches(hdrC));

// ===== Diagnostic — body marker positions (the real corruption check) =====
String markerA = 'REPRO87_BODY_A';
String markerB = 'REPRO87_BODY_B';
String markerC = 'REPRO87_BODY_C';
Integer mPosA = previewHtml.indexOf(markerA);
Integer mPosB = previewHtml.indexOf(markerB);
Integer mPosC = previewHtml.indexOf(markerC);
r.log('BODY A marker exists', mPosA >= 0, 'pos: ' + mPosA);
r.log('BODY B marker exists', mPosB >= 0, 'pos: ' + mPosB);
r.log('BODY C marker exists', mPosC >= 0, 'pos: ' + mPosC);
if (posA >= 0 && posB > posA && mPosA >= 0) {
    r.log(
        'BODY A is inside SLOT 1',
        mPosA > posA && mPosA < posB,
        'bodyA @ ' + mPosA + ', slot1 = [' + posA + ', ' + posB + ')'
    );
}
if (posB >= 0 && posC > posB && mPosB >= 0) {
    r.log(
        'BODY B is inside SLOT 2',
        mPosB > posB && mPosB < posC,
        'bodyB @ ' + mPosB + ', slot2 = [' + posB + ', ' + posC + ')'
    );
}
if (posC >= 0 && mPosC >= 0) {
    r.log('BODY C is inside SLOT 3', mPosC > posC, 'bodyC @ ' + mPosC + ', slot3 starts @ ' + posC);
}
r.log(
    'BODY A marker exactly once',
    previewHtml.countMatches(markerA) == 1,
    'count: ' + previewHtml.countMatches(markerA)
);
r.log(
    'BODY B marker exactly once',
    previewHtml.countMatches(markerB) == 1,
    'count: ' + previewHtml.countMatches(markerB)
);
r.log(
    'BODY C marker exactly once',
    previewHtml.countMatches(markerC) == 1,
    'count: ' + previewHtml.countMatches(markerC)
);

// ===== Cleanup the request so re-runs don't pile up =====
// Leaves the 3 templates in place so subsequent runs are fast and side-effect-free.
try {
    delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c = :requestId];
    delete [SELECT Id FROM DocGen_Signature_Request__c WHERE Id = :requestId];
    System.debug('Cleanup: deleted request ' + requestId);
} catch (Exception e) {
    System.debug('Cleanup WARNING: ' + e.getMessage());
}

System.debug('========================================');
System.debug('REPRO #87 — PASS: ' + r.pass + '  FAIL: ' + r.fail);
if (r.fail == 0) {
    System.debug('No corruption detected in preview-loop layer.');
    System.debug('Next: diagnose Loop B (renderPacketSignaturePdf in TemplateSignaturePdfQueueable).');
} else {
    System.debug('CORRUPTION DETECTED in preview-loop layer.');
    System.debug('Inspect DocGenSignatureSenderController.cls:632 (the for-docIdx loop).');
}
System.debug('========================================');
