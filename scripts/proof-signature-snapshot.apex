// PROOF: template signatures sign the point-in-time snapshot, not live record data.
// Uses the REAL merge engine on a REAL record that we mutate mid-flight.
// Depends on e2e-02 (Account 'E2E Test Corp' + 'E2E Test Template').
Integer pass = 0, fail = 0;
String ORIGINAL = 'E2E Test Corp';
String MUTATED = 'MUTATED Corp 999';

Account acct = [SELECT Id, Name FROM Account WHERE Name = :ORIGINAL ORDER BY CreatedDate DESC LIMIT 1];
DocGen_Template__c tpl = [SELECT Id FROM DocGen_Template__c WHERE Name = 'E2E Test Template' LIMIT 1];

// 1) Create the signature request — this freezes the merged body at "send" time.
String signers = '[{"roleName":"Buyer","signerName":"Alice","signerEmail":"alice@proof.test","contactId":null}]';
DocGenSignatureSenderController.createTemplateSignerRequestWithOrder(tpl.Id, acct.Id, signers, 'Parallel');

DocGen_Signature_Request__c req = [
    SELECT Id, Frozen_Document__c, Snapshot_Hash__c, Snapshot_Taken_At__c
    FROM DocGen_Signature_Request__c
    WHERE Template__c = :tpl.Id AND Related_Record_Id__c = :acct.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];

// 2) The snapshot was frozen with the ORIGINAL account name.
if (String.isNotBlank(req.Frozen_Document__c) && req.Frozen_Document__c.contains(ORIGINAL)) {
    pass++;
    System.debug('FROZEN AT SEND contains "' + ORIGINAL + '": PASS');
} else {
    fail++;
    System.debug('FROZEN AT SEND: FAIL — snapshot missing original name');
}
if (String.isNotBlank(req.Snapshot_Hash__c) && req.Snapshot_Taken_At__c != null) {
    pass++;
    System.debug(
        'SNAPSHOT HASH + TIMESTAMP set: PASS (hash=' +
            req.Snapshot_Hash__c.left(12) +
            '…, at=' +
            req.Snapshot_Taken_At__c +
            ')'
    );
} else {
    fail++;
    System.debug('SNAPSHOT HASH/TIMESTAMP: FAIL');
}

// 3) MUTATE the record AFTER the request was sent.
acct.Name = MUTATED;
update acct;

// 4) A LIVE re-merge now reflects the change (proves the record really changed and the
//    old buggy behavior would have signed the mutated content).
Map<String, Object> liveMerge = DocGenService.mergeTemplateForSignature(tpl.Id, String.valueOf(acct.Id));
String liveBody = (String) liveMerge.get('combinedDocumentXml');
if (String.isBlank(liveBody))
    liveBody = (String) liveMerge.get('documentXml');
if (liveBody.contains(MUTATED) && !liveBody.contains(ORIGINAL)) {
    pass++;
    System.debug(
        'LIVE RE-MERGE reflects mutation ("' + MUTATED + '"): PASS — this is what the OLD code would have signed'
    );
} else {
    fail++;
    System.debug('LIVE RE-MERGE: FAIL — expected mutated name in live merge');
}

// 5) The stored snapshot is UNCHANGED — still the reviewed content. This is what the
//    sign path (renderTemplateSignaturePdf → loadFrozenMergeData) now stamps + renders.
DocGen_Signature_Request__c after = [SELECT Frozen_Document__c FROM DocGen_Signature_Request__c WHERE Id = :req.Id];
Boolean frozenStillOriginal =
    after.Frozen_Document__c.contains(ORIGINAL) && !after.Frozen_Document__c.contains(MUTATED);
if (frozenStillOriginal) {
    pass++;
    System.debug(
        'FROZEN AFTER MUTATION still "' + ORIGINAL + '", NOT "' + MUTATED + '": PASS — signer signs what was reviewed'
    );
} else {
    fail++;
    System.debug('FROZEN AFTER MUTATION: FAIL — snapshot drifted');
}

// 6) Restore the account so e2e data stays valid.
acct.Name = ORIGINAL;
update acct;

System.debug('========================================');
System.debug(
    'SNAPSHOT PROOF — PASS: ' +
        pass +
        '  FAIL: ' +
        fail +
        (fail == 0 ? '  POINT-IN-TIME INTEGRITY PROVEN' : '  FAILURES')
);
System.debug('========================================');
