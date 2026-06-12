// M2 helper: mint a SNAPSHOT signing request. Snapshots the record's merge data
// now; on completion the document is re-rendered from that snapshot, a signing
// certificate page is appended, and the combined PDF is attached to the record.
// Run: sf apex run --target-org docgen-test -f scripts/make-snapshot-signing-url.apex
Id templateId = 'a09Pu00000S9y2jIAB'; // Account-Test (HTML + images)
Id recordId = '001Pu00000pUEOPIA4'; // E2E Test Corp

String signers = JSON.serialize(
    new List<Map<String, Object>>{
        new Map<String, Object>{
            'signerName' => 'Pat Tester',
            'signerEmail' => 'pat@example.com',
            'roleName' => 'Signer'
        }
    }
);
List<DocGenSignatureSenderController.SignerResult> res = DocGenSignatureSenderController.createTemplateSnapshotRequest(
    templateId,
    recordId,
    signers,
    'Parallel',
    null
);

// Pre-verify the signer's PIN so the scratch org (no outbound email) skips the email step.
DocGen_Signer__c s = [SELECT Id, Secure_Token__c FROM DocGen_Signer__c WHERE Id = :res[0].signerId];
s.PIN_Verified_At__c = System.now();
update s;

for (DocGenSignatureSenderController.SignerResult r : res) {
    System.debug('SIGNER_URL >>> ' + r.signerUrl);
}
