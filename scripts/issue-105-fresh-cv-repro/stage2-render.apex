// Stage 2 of TEST (3).docx repro — runs the render against the template that
// stage 1 set up. Run only AFTER the orchestrator has confirmed
// Pre_Decomposition_Status__c='Complete' on the version and slept long enough
// (~30s) for Salesforce's shepherd servlet to publish the extracted image CVs
// cross-domain. Calling this too soon makes Flying Saucer embed a 48×48
// broken-image placeholder instead of the real logo.

Integer pass = 0;
Integer fail = 0;
Id tmplId;
Id versionId;
Id anchorId;
String preDecompStatus;

try {
    DocGen_Template__c t = [SELECT Id FROM DocGen_Template__c WHERE Name = 'TEST3 Property Demo' LIMIT 1];
    tmplId = t.Id;
    DocGen_Template_Version__c v = [
        SELECT Id, Pre_Decomposition_Status__c
        FROM DocGen_Template_Version__c
        WHERE Template__c = :tmplId AND Is_Active__c = TRUE
        LIMIT 1
    ];
    versionId = v.Id;
    preDecompStatus = v.Pre_Decomposition_Status__c;
    Account a = [SELECT Id FROM Account WHERE Name = 'TEST3 Property Demo Anchor' LIMIT 1];
    anchorId = a.Id;
    pass++;
    System.debug(
        'LOOKED UP: template=' +
            tmplId +
            ' version=' +
            versionId +
            ' anchor=' +
            anchorId +
            ' preDecomp=' +
            preDecompStatus
    );
} catch (Exception e) {
    fail++;
    System.debug('LOOKUP FAIL: ' + e.getMessage());
    return;
}

if (preDecompStatus != 'Complete') {
    System.debug(
        'WARNING: Pre_Decomposition_Status__c=' + preDecompStatus + ' — render may produce broken-image placeholder'
    );
}

// In-memory wrapper for the three Property_*__c merge tags
Map<String, Object> wrapper = new Map<String, Object>{
    'Property_Name__c' => 'Sunset Ridge Apartments',
    'Property_City__c' => 'Santa Monica',
    'Property_State__c' => 'CA',
    'Name' => 'Sunset Ridge Apartments'
};

Blob pdfBlob;
String renderedHtml;
try {
    Map<String, Object> result = DocGenService.generatePdfBlobFromData(tmplId, wrapper);
    pdfBlob = (Blob) result.get('blob');
    renderedHtml = DocGenService.lastRenderedHtml;
    String hex = pdfBlob == null ? '' : EncodingUtil.convertToHex(pdfBlob).substring(0, 4).toUpperCase();
    if (pdfBlob != null && pdfBlob.size() > 500 && hex == '2550') {
        pass++;
        System.debug('RENDER: PASS — valid PDF, ' + pdfBlob.size() + ' bytes');
    } else {
        fail++;
        System.debug('RENDER: FAIL — size=' + (pdfBlob == null ? 0 : pdfBlob.size()) + ' hex=' + hex);
    }
} catch (Exception e) {
    fail++;
    System.debug('RENDER EXCEPTION: ' + e.getTypeName() + ' — ' + e.getMessage());
    System.debug('  at line ' + e.getLineNumber());
    renderedHtml = DocGenService.lastRenderedHtml;
}

if (renderedHtml != null) {
    System.debug('HTML length: ' + renderedHtml.length());
    System.debug('Resolved {Property_Name__c}? ' + renderedHtml.contains('Sunset Ridge Apartments'));
    System.debug('Resolved {Property_City__c}? ' + renderedHtml.contains('Santa Monica'));
    System.debug('Resolved {Property_State__c}? ' + (renderedHtml.contains('>CA<') || renderedHtml.contains(', CA')));
    System.debug('Any __DGTXBX_ leakage? ' + renderedHtml.contains('__DGTXBX'));
}

try {
    if (pdfBlob != null && pdfBlob.size() > 0) {
        insert new ContentVersion(
            Title = 'TEST3 Output PDF',
            PathOnClient = 'TEST3_output.pdf',
            VersionData = pdfBlob,
            FirstPublishLocationId = anchorId
        );
        System.debug('SAVED PDF → Account ' + anchorId);
    }
    if (renderedHtml != null) {
        insert new ContentVersion(
            Title = 'TEST3 Rendered HTML',
            PathOnClient = 'TEST3_rendered.html',
            VersionData = Blob.valueOf(renderedHtml),
            FirstPublishLocationId = anchorId
        );
        System.debug('SAVED HTML → Account ' + anchorId);
    }
} catch (Exception e) {
    System.debug('ARTEFACT SAVE NOTE: ' + e.getMessage());
}

System.debug('════════════════════════════════════════');
System.debug('TEST3 RENDER — PASS: ' + pass + '  FAIL: ' + fail);
System.debug('════════════════════════════════════════');
