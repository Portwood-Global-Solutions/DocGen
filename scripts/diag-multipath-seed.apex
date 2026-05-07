// DocGen Diagnostic Seed — Multipath Signature Duplicate Documents
// Run: sf apex run --target-org <org> -f scripts/diag-multipath-seed.apex
//
// Creates 4 distinct Word templates with unique sentinel markers
// (DIAG_ALPHA, DIAG_BRAVO, DIAG_CHARLIE, DIAG_DELTA) and an Account
// "Diag Multipath Acct". The companion script diag-multipath.apex picks
// these up by name prefix and asserts each rendered output contains its
// own marker and ONLY its own.
//
// Idempotent: re-running deletes prior Diag Multipath templates first.

Integer pass = 0;
Integer fail = 0;

String[] markers = new List<String>{ 'ALPHA', 'BRAVO', 'CHARLIE', 'DELTA', 'ECHO' };

// ───────── Cleanup prior runs ─────────
try {
    List<DocGen_Template__c> prior = [SELECT Id FROM DocGen_Template__c WHERE Name LIKE 'Diag Multipath %'];
    if (!prior.isEmpty()) {
        Set<Id> ids = new Set<Id>();
        for (DocGen_Template__c t : prior) {
            ids.add(t.Id);
        }
        delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :ids];
        delete prior;
        System.debug('CLEANUP: removed ' + prior.size() + ' prior Diag Multipath templates');
    }
} catch (Exception e) {
    System.debug('CLEANUP: WARN — ' + e.getMessage());
}

// ───────── Account ─────────
Id acctId;
try {
    List<Account> existing = [SELECT Id FROM Account WHERE Name = 'Diag Multipath Acct' LIMIT 1];
    if (!existing.isEmpty()) {
        acctId = existing[0].Id;
        System.debug('ACCT: reusing existing — ' + acctId);
    } else {
        Account a = new Account(Name = 'Diag Multipath Acct', Industry = 'Technology', Phone = '555-0100');
        insert a;
        acctId = a.Id;
        System.debug('ACCT: created — ' + acctId);
    }
    pass++;
} catch (Exception e) {
    fail++;
    System.debug('ACCT: FAIL — ' + e.getMessage());
}

// ───────── Templates ─────────
String relsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
    '</Relationships>';

String contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
    '</Types>';

String wordRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>';

for (String marker : markers) {
    try {
        String docXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<w:body>' +
            '<w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr>' +
            '<w:t>DIAG_' +
            marker +
            ' Title</w:t></w:r></w:p>' +
            '<w:p><w:r><w:t>DIAG_' +
            marker +
            ' body content for {Name}</w:t></w:r></w:p>' +
            '<w:p><w:r><w:t>Marker repeats: DIAG_' +
            marker +
            ' / DIAG_' +
            marker +
            '</w:t></w:r></w:p>' +
            '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>' +
            '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="360" w:footer="360"/>' +
            '</w:sectPr></w:body></w:document>';

        Compression.ZipWriter zw = new Compression.ZipWriter();
        zw.addEntry('[Content_Types].xml', Blob.valueOf(contentTypes));
        zw.addEntry('_rels/.rels', Blob.valueOf(relsXml));
        zw.addEntry('word/_rels/document.xml.rels', Blob.valueOf(wordRels));
        zw.addEntry('word/document.xml', Blob.valueOf(docXml));
        Blob docxBlob = zw.getArchive();

        DocGen_Template__c t = new DocGen_Template__c(
            Name = 'Diag Multipath ' + marker,
            Base_Object_API__c = 'Account',
            Type__c = 'Word',
            Output_Format__c = 'PDF',
            Query_Config__c = 'Name',
            Description__c = 'Sentinel template DIAG_' + marker,
            Category__c = 'Diag'
        );
        insert t;

        DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
            Template__c = t.Id,
            Is_Active__c = true,
            Type__c = 'Word',
            Base_Object_API__c = 'Account',
            Category__c = 'Diag',
            Description__c = 'DIAG_' + marker + ' v1',
            Query_Config__c = 'Name'
        );
        insert ver;

        ContentVersion cv = new ContentVersion(
            Title = 'Diag Multipath ' + marker,
            PathOnClient = 'diag_' + marker.toLowerCase() + '.docx',
            VersionData = docxBlob,
            FirstPublishLocationId = t.Id
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ver.Content_Version_Id__c = cv.Id;
        update ver;

        pass++;
        System.debug('TEMPLATE ' + marker + ': created tid=' + t.Id + ' cvId=' + cv.Id + ' size=' + docxBlob.size());
    } catch (Exception e) {
        fail++;
        System.debug('TEMPLATE ' + marker + ': FAIL — ' + e.getMessage());
    }
}

System.debug('────────────────────────────────────');
System.debug('SEED PASS: ' + pass + '  FAIL: ' + fail);
if (fail == 0) {
    System.debug('SEED COMPLETE — now run scripts/diag-multipath.apex');
}
