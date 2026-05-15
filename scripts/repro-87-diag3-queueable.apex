// DocGen Repro #87 — Diagnostic 3: invoke TemplateSignaturePdfQueueable synchronously
// Run: sf apex run --target-org <org> -f scripts/repro-87-diag3-queueable.apex
//
// Prereq: DocGenSignatureService.cls has the [REPRO87-D3] instrumentation
// block (3 System.debug calls inside renderPacketSignaturePdf's loop body).
// Deploy that to staging before running this. Revert before any commit.
//
// What this diagnostic does:
//   1. Uses the REPRO87_PD_A/B/C templates from Diagnostic 4 (pandoc-built)
//   2. Builds a packet via createPacketSignerRequestWithTitle
//   3. Calls TemplateSignaturePdfQueueable.execute(null) SYNCHRONOUSLY
//      (queueable's execute is public; we bypass the async queue runtime)
//   4. The instrumentation emits 3 debug lines per iteration:
//      - [REPRO87-D3] postMerge  : marker state in mergeData.documentXml
//      - [REPRO87-D3] postStamp  : marker state after stampSignaturesInXml
//      - [REPRO87-D3] postHtml   : marker state after convertToHtml
//
// Expected if Loop B is clean: each slot's lines show only its own marker.
// If markerA=true appears in slot 1's postX line AND in slot 2's postX line,
// cross-iteration contamination has been confirmed at that step.

List<DocGen_Template__c> tmpls = [
    SELECT Id, Name
    FROM DocGen_Template__c
    WHERE Name IN ('REPRO87_PD_A', 'REPRO87_PD_B', 'REPRO87_PD_C')
    ORDER BY Name ASC
];
if (tmpls.size() != 3) {
    System.debug(
        'ABORTED: need REPRO87_PD_A/B/C templates. Run repro-87-upload-pandoc.sh + repro-87-diag4-images.apex first.'
    );
    return;
}

Id tA = tmpls[0].Id;
Id tB = tmpls[1].Id;
Id tC = tmpls[2].Id;
List<Id> templateIds = new List<Id>{ tA, tB, tC };

List<Account> accts = [SELECT Id FROM Account LIMIT 1];
Id recordId = accts.isEmpty() ? null : accts[0].Id;
if (recordId == null) {
    Account a = new Account(Name = 'Repro87 D3 Account');
    insert a;
    recordId = a.Id;
}

List<Map<String, Object>> signers = new List<Map<String, Object>>{
    new Map<String, Object>{ 'signerName' => 'Repro87 D3', 'signerEmail' => 'r@e.invalid', 'roleName' => 'Buyer' }
};

System.debug('===== Creating packet =====');
List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createPacketSignerRequestWithTitle(
    JSON.serialize(templateIds),
    recordId,
    JSON.serialize(signers),
    'Parallel',
    null
);
Id sigId = results[0].signerId;
Id requestId = [SELECT Signature_Request__c FROM DocGen_Signer__c WHERE Id = :sigId LIMIT 1][0].Signature_Request__c;
System.debug('Request created: ' + requestId);

// renderPacketSignaturePdf queries DocGen_Signer__c WHERE Status='Signed'.
// Flip the signer to Signed so the loop runs through the same signers/placements path.
update new DocGen_Signer__c(Id = sigId, Status__c = 'Signed', Signature_Data__c = 'Repro87 D3 Tester');

System.debug('===== Invoking TemplateSignaturePdfQueueable.execute(null) synchronously =====');
try {
    new DocGenSignatureService.TemplateSignaturePdfQueueable(requestId).execute(null);
    System.debug('===== execute() returned =====');
} catch (Exception e) {
    System.debug('execute() threw: ' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
}

// Cleanup the request + signer
try {
    delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c = :requestId];
    delete [SELECT Id FROM DocGen_Signature_Request__c WHERE Id = :requestId];
} catch (Exception e) {
    System.debug('Cleanup WARNING: ' + e.getMessage());
}
System.debug('===== Done =====');
