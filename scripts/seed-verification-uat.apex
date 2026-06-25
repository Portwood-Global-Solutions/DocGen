// #verification UAT seed — creates an Account-based guided-signing template and mints
// three signature requests, one per verification scenario, printing the signing URLs.
// Run:  sf apex run --target-org docgen-test --file scripts/seed-verification-uat.apex
//
// The PIN (scenarios 2 & 3) is emailed to SIGNER_EMAIL — set it to a real inbox you
// control once email sending works in the org (see notes at the bottom of the run).

String SIGNER_EMAIL = UserInfo.getUserEmail(); // ← change to your real inbox for PIN tests
String SIGNER_NAME = 'UAT Signer';

// 1. An Account to sign against (reuse the first one, or create a throwaway).
List<Account> accts = [SELECT Id, Name FROM Account ORDER BY CreatedDate ASC LIMIT 1];
Id acctId;
if (accts.isEmpty()) {
    Account a = new Account(Name = 'Verification UAT Co');
    insert a;
    acctId = a.Id;
} else {
    acctId = accts[0].Id;
}

// 2. A reusable HTML template on Account with one signature placement tag.
String tname = 'Verification UAT Template';
List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = :tname LIMIT 1];
Id tplId;
if (existing.isEmpty()) {
    DocGen_Template__c t = new DocGen_Template__c(
        Name = tname,
        Type__c = 'HTML',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Account',
        Query_Config__c = 'Name'
    );
    insert t;
    String body =
        '<html><body><h1>{Name}</h1><p>Please review and sign below.</p>' +
        '<p>Signature: {@Signature_Signer:1:Full}</p></body></html>';
    ContentVersion cv = new ContentVersion(
        Title = tname + ' Body',
        PathOnClient = 'body.html',
        VersionData = Blob.valueOf(body),
        FirstPublishLocationId = t.Id
    );
    insert cv;
    insert new DocGen_Template_Version__c(Template__c = t.Id, Content_Version_Id__c = cv.Id, Is_Active__c = true);
    tplId = t.Id;
} else {
    tplId = existing[0].Id;
}

String signers = '[{"signerName":"' + SIGNER_NAME + '","signerEmail":"' + SIGNER_EMAIL + '","roleName":"Signer"}]';

// 3. Mint the three scenarios via per-send overrides (require, prefill).
Map<String, List<Boolean>> scenarios = new Map<String, List<Boolean>>{
    '1) NO PIN  (verification OFF)' => new List<Boolean>{ false, null },
    '2) PIN + PREFILL email' => new List<Boolean>{ true, true },
    '3) PIN + TYPE email (original behaviour)' => new List<Boolean>{ true, false }
};

for (String label : scenarios.keySet()) {
    Boolean req = scenarios.get(label)[0];
    Boolean pre = scenarios.get(label)[1];
    List<DocGenSignatureSenderController.SignerResult> res = DocGenSignatureSenderController.createGuidedPdfSignatureRequest(
        tplId,
        acctId,
        signers,
        'Parallel',
        null,
        req,
        pre
    );
    System.debug('=== ' + label + ' ===');
    for (DocGenSignatureSenderController.SignerResult sr : res) {
        System.debug('   SIGN URL: ' + sr.signerUrl);
    }
}

// 4. Confirm the resolved verification config landed on each request.
for (DocGen_Signature_Request__c r : [
    SELECT Id, Require_Email_Verification__c, Prefill_Signer_Email__c
    FROM DocGen_Signature_Request__c
    WHERE Template__c = :tplId
    ORDER BY CreatedDate DESC
    LIMIT 3
]) {
    System.debug(
        '   REQUEST ' + r.Id + ' → require=' + r.Require_Email_Verification__c + ' prefill=' + r.Prefill_Signer_Email__c
    );
}
