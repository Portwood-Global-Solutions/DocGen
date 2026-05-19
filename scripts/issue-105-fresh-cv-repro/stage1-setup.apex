// Stage 1 of TEST (3).docx repro — sets up template + version and enqueues the
// pre-decomposition queueable. The queueable boundary is load-bearing: it
// commits image CVs in a SEPARATE transaction so Salesforce's shepherd servlet
// has time to publish them across the cross-domain boundary Flying Saucer
// fetches from at render time. Without that delay the engine embeds a
// 48×48 broken-image placeholder instead of the real logo.
//
// Run via scripts/repro-test3-docx.sh — the orchestrator polls
// Pre_Decomposition_Status__c='Complete' and sleeps before invoking the
// companion render stage.
//
// Prerequisites: ContentVersion titled 'TEST3 Source DOCX' already uploaded.

Integer pass = 0;
Integer fail = 0;
Id anchorId;
Id tmplId;
Id versionId;
Id sourceCvId;

// ── 0. Find the pre-uploaded source DOCX ──────────────────────────────────────
try {
    List<ContentVersion> srcCvs = [
        SELECT Id, ContentDocumentId, FileExtension, ContentSize
        FROM ContentVersion
        WHERE Title = 'TEST3 Source DOCX' AND IsLatest = TRUE
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];
    if (srcCvs.isEmpty()) {
        System.debug('ABORT: No ContentVersion with Title=\'TEST3 Source DOCX\' found. Upload first:');
        System.debug('  sf data create file -f "Triage Docs/TEST (3).docx" -t "TEST3 Source DOCX"');
        return;
    }
    sourceCvId = srcCvs[0].Id;
    pass++;
    System.debug(
        'FOUND SOURCE CV: ' + sourceCvId + ' (' + srcCvs[0].FileExtension + ', ' + srcCvs[0].ContentSize + ' bytes)'
    );
} catch (Exception e) {
    fail++;
    System.debug('SOURCE LOOKUP FAIL: ' + e.getMessage());
    return;
}

// ── 1. Clean prior run ────────────────────────────────────────────────────────
try {
    List<DocGen_Template__c> priorTmpls = [SELECT Id FROM DocGen_Template__c WHERE Name = 'TEST3 Property Demo'];
    if (!priorTmpls.isEmpty()) {
        delete priorTmpls;
    }
    List<Account> priorAccts = [SELECT Id FROM Account WHERE Name = 'TEST3 Property Demo Anchor'];
    if (!priorAccts.isEmpty()) {
        delete priorAccts;
    }
    pass++;
    System.debug('CLEANUP PRIOR RUN: PASS');
} catch (Exception e) {
    fail++;
    System.debug('CLEANUP FAIL: ' + e.getMessage());
}

// ── 2. Anchor account (for attaching the output PDF later) ────────────────────
try {
    Account a = new Account(Name = 'TEST3 Property Demo Anchor');
    insert a;
    anchorId = a.Id;
    pass++;
    System.debug('ANCHOR ACCT: ' + anchorId);
} catch (Exception e) {
    fail++;
    System.debug('ANCHOR FAIL: ' + e.getMessage());
    return;
}

// ── 3. Build the template ─────────────────────────────────────────────────────
try {
    DocGen_Template__c t = new DocGen_Template__c(
        Name = 'TEST3 Property Demo',
        Description__c = 'Repro: TEST (3).docx Confidentiality Agreement → PDF',
        Type__c = 'Word',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Account',
        Query_Config__c = 'Name', // arbitrary — overridden by dataMap
        Category__c = 'Repro'
    );
    insert t;
    tmplId = t.Id;
    pass++;
    System.debug('TEMPLATE INSERTED: ' + tmplId);
} catch (Exception e) {
    fail++;
    System.debug('TEMPLATE INSERT FAIL: ' + e.getMessage());
    return;
}

// ── 4. Link the uploaded CV to the template ───────────────────────────────────
try {
    Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :sourceCvId].ContentDocumentId;
    List<ContentDocumentLink> existing = [
        SELECT Id
        FROM ContentDocumentLink
        WHERE ContentDocumentId = :cdId AND LinkedEntityId = :tmplId
    ];
    if (existing.isEmpty()) {
        insert new ContentDocumentLink(
            ContentDocumentId = cdId,
            LinkedEntityId = tmplId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }
    pass++;
    System.debug('LINKED CV → TEMPLATE');
} catch (Exception e) {
    fail++;
    System.debug('CDL LINK FAIL: ' + e.getMessage());
}

// ── 5. Activate the version ───────────────────────────────────────────────────
try {
    DocGen_Template_Version__c v = new DocGen_Template_Version__c(
        Template__c = tmplId,
        Content_Version_Id__c = sourceCvId,
        Is_Active__c = true,
        Type__c = 'Word',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Account'
    );
    insert v;
    versionId = v.Id;
    pass++;
    System.debug('VERSION ACTIVATED: ' + versionId);
} catch (Exception e) {
    fail++;
    System.debug('VERSION ACTIVATE FAIL: ' + e.getMessage());
    return;
}

// ── 6. Enqueue pre-decomposition ──────────────────────────────────────────────
//   This is the production path. The Queueable boundary forces image CV inserts
//   to commit in a SEPARATE transaction from this anonymous-apex run, which
//   gives Salesforce's shepherd servlet time to publish them cross-domain.
//   Calling the sync `extractAndSaveTemplateImages` directly in this script
//   would put the inserts in the same transaction and Flying Saucer would
//   fetch them before they're shepherd-reachable — broken-image placeholder.
try {
    DocGenService.enqueueTemplateImageExtraction(tmplId, versionId);
    pass++;
    System.debug('PRE-DECOMP QUEUEABLE ENQUEUED');
} catch (Exception e) {
    fail++;
    System.debug('ENQUEUE FAIL: ' + e.getMessage());
}

// ── Summary — orchestrator parses these ───────────────────────────────────────
System.debug('════════════════════════════════════════');
System.debug('TEST3 SETUP — PASS: ' + pass + '  FAIL: ' + fail);
System.debug('STAGE1_TEMPLATE_ID=' + tmplId);
System.debug('STAGE1_VERSION_ID=' + versionId);
System.debug('STAGE1_ANCHOR_ID=' + anchorId);
System.debug('Next: orchestrator polls Pre_Decomposition_Status__c on version ' + versionId);
System.debug('════════════════════════════════════════');
