// DocGen E2E Test 03b — Page Setup (size × orientation matrix + margins preset)
// Run: sf apex run --target-org <org> -f scripts/e2e-03b-page-setup.apex
// Depends on: e2e-02 (Account 'E2E Test Corp')
// Split out of e2e-03 so each script stays under the 100-SOQL synchronous
// governor limit: every full generateDocument costs ~10 SOQL, and the 6-combo
// matrix plus the margins preset is 7 generations on its own — stacked on
// e2e-03's other generations it exceeded 100 in a single anonymous transaction.
// Expected: PASS: N  FAIL: 0

Integer pass = 0;
Integer fail = 0;

Id acctId;
try {
    List<Account> accts = [SELECT Id FROM Account WHERE Name = 'E2E Test Corp' LIMIT 1];
    if (accts.isEmpty()) {
        System.debug('========================================');
        System.debug('E2E-03B PAGE SETUP — PASS: 0  FAIL: 0  ABORTED (missing test data — run e2e-02 first)');
        System.debug('========================================');
        return;
    }
    acctId = accts[0].Id;
    pass++;
    System.debug('LOOKUP ACCOUNT: PASS — ' + acctId);
} catch (Exception e) {
    System.debug('E2E-03B LOOKUP: FAIL — ' + e.getMessage());
    return;
}

// ===== 1.68: page size × orientation matrix (Letter/Legal/A4 × Portrait/Landscape) =====
// Verifies Page_Size__c + Page_Orientation__c drive correct PDF MediaBox dims.
// Critical: do NOT delete generated ContentDocuments inside the loop — it
// poisons the platform state and the next generateDocument throws a SOAP-level
// "entity is deleted" fault. Cleanup happens after the loop.
try {
    DocGen_Template__c psTmpl = new DocGen_Template__c(
        Name = 'E2E PageSetup ' + Datetime.now().getTime(),
        Type__c = 'HTML',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Account',
        Query_Config__c = '{"v":3,"root":"Account","nodes":[{"id":"n0","object":"Account","fields":["Name"],"parentNode":null,"lookupField":null,"relationshipName":null}]}'
    );
    insert psTmpl;
    ContentVersion psCv = new ContentVersion(
        Title = psTmpl.Name,
        PathOnClient = 'b.html',
        VersionData = Blob.valueOf('<html><body><p>Page setup matrix</p></body></html>'),
        FirstPublishLocationId = psTmpl.Id
    );
    insert psCv;
    psCv = [SELECT Id FROM ContentVersion WHERE Id = :psCv.Id];
    insert new DocGen_Template_Version__c(
        Template__c = psTmpl.Id,
        Content_Version_Id__c = psCv.Id,
        Is_Active__c = true
    );

    List<List<Object>> mtx = new List<List<Object>>{
        new List<Object>{ 'Letter', 'Portrait', 612, 792 },
        new List<Object>{ 'Letter', 'Landscape', 792, 612 },
        new List<Object>{ 'Legal', 'Portrait', 612, 1008 },
        new List<Object>{ 'Legal', 'Landscape', 1008, 612 },
        new List<Object>{ 'A4', 'Portrait', 595, 842 },
        new List<Object>{ 'A4', 'Landscape', 842, 595 }
    };
    Pattern mbPat = Pattern.compile('\\[\\s*([0-9.\\-]+)\\s+([0-9.\\-]+)\\s+([0-9.\\-]+)\\s+([0-9.\\-]+)\\s*\\]');
    Integer mtxPass = 0;
    Integer mtxFail = 0;
    for (List<Object> row : mtx) {
        psTmpl.Page_Size__c = (String) row[0];
        psTmpl.Page_Orientation__c = (String) row[1];
        psTmpl.Page_Margins__c = 'Default';
        update psTmpl;
        Id psDocId = DocGenService.generateDocument(psTmpl.Id, acctId);
        ContentVersion psPdfCv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :psDocId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        String hex = EncodingUtil.convertToHex(psPdfCv.VersionData);
        Decimal w = -1;
        Decimal h = -1;
        // Walk every /MediaBox occurrence — Salesforce's Blob.toPdf() can place
        // a hex-coincidental match inside a compressed FlateDecode stream where
        // the trailing bytes are binary (not valid UTF-8). The dictionary entry
        // we want is ASCII like "/MediaBox [0 0 612 792]"; skip any occurrence
        // whose chunk fails to decode or doesn't match the regex. Use a tight
        // ~30-byte window since "/MediaBox " plus four numbers fits inside that.
        Integer hi = hex.indexOf('2f4d65646961426f78');
        while (hi >= 0 && w < 0) {
            try {
                String chunk = EncodingUtil.convertFromHex(hex.substring(hi + 18, Math.min(hi + 80, hex.length())))
                    .toString();
                Matcher mm = mbPat.matcher(chunk);
                if (mm.find()) {
                    w = Decimal.valueOf(mm.group(3));
                    h = Decimal.valueOf(mm.group(4));
                }
            } catch (Exception decodeErr) {
                // Binary chunk — try the next /MediaBox occurrence
            }
            hi = hex.indexOf('2f4d65646961426f78', hi + 18);
        }
        Integer expW = (Integer) row[2];
        Integer expH = (Integer) row[3];
        if (w > 0 && Math.abs(w - expW) <= 2 && Math.abs(h - expH) <= 2) {
            mtxPass++;
        } else {
            mtxFail++;
            System.debug(
                '  MATRIX FAIL ' + row[0] + '/' + row[1] + ' got ' + w + 'x' + h + ' expected ' + expW + 'x' + expH
            );
        }
    }
    if (mtxFail == 0) {
        pass++;
        System.debug('PAGE SETUP MATRIX (6 combos): PASS');
    } else {
        fail++;
        System.debug('PAGE SETUP MATRIX: FAIL — ' + mtxFail + '/' + (mtxPass + mtxFail) + ' combos failed');
    }

    // Margins preset check — generate one PDF with Wide preset and verify it embeds
    psTmpl.Page_Size__c = 'Letter';
    psTmpl.Page_Orientation__c = 'Portrait';
    psTmpl.Page_Margins__c = 'Wide';
    update psTmpl;
    Id wDocId = DocGenService.generateDocument(psTmpl.Id, acctId);
    if (wDocId != null) {
        pass++;
        System.debug('MARGIN PRESET (Wide) RENDER: PASS');
    } else {
        fail++;
        System.debug('MARGIN PRESET (Wide) RENDER: FAIL');
    }

    delete psTmpl;
} catch (Exception e) {
    fail++;
    System.debug('PAGE SETUP MATRIX: FAIL — ' + e.getMessage() + ' line ' + e.getLineNumber());
}

System.debug('========================================');
System.debug(
    'E2E-03B PAGE SETUP — PASS: ' +
        pass +
        '  FAIL: ' +
        fail +
        (fail == 0 ? '  ALL TESTS PASSED' : '  FAILURES DETECTED')
);
System.debug('========================================');
