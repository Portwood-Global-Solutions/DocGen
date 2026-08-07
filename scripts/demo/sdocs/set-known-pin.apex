// ============================================================================
// SDocs-replacement demo — set a KNOWN email-verification PIN (123456).
//
// WHY: the "Send for Signature" component on the record page leaves email PIN
// verification ON (the demo Flow turns it off, because a Flow run cannot be
// interrupted to read a code). A scratch org has no Org-Wide Email Address, so
// the PIN is never delivered and the signer is stuck on "Verify your email to
// continue". This plants a code you already know.
//
// This is the namespaced, demo-scoped sibling of scripts/set-known-pin.apex —
// that one targets the "Verification UAT Template" using BARE API names, which
// do not compile in a subscriber org where everything is portwoodglobal__.
//
// ORDER OF OPERATIONS (the page regenerates a random PIN when you click Send):
//   1. Open the signing URL and reach the code-entry screen
//      (type the signer's email → "Send Verification Code").
//   2. Run this script.
//   3. Enter 123456 on screen.
//   Do NOT click "Resend" afterwards — that replaces the known code.
//
//   sf apex run --target-org portwood-sdocs -f scripts/demo/sdocs/set-known-pin.apex
// ============================================================================

String KNOWN_PIN = '123456';
String hash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(KNOWN_PIN)));

Set<Id> projIds = new Set<Id>();
for (Demo_Project__c p : [SELECT Id FROM Demo_Project__c WHERE Project_Code__c LIKE 'P-2%']) {
    projIds.add(p.Id);
}

List<portwoodglobal__DocGen_Signer__c> signers = [
    SELECT Id, portwoodglobal__Signer_Name__c, portwoodglobal__Signer_Email__c
    FROM portwoodglobal__DocGen_Signer__c
    WHERE
        portwoodglobal__Signature_Request__r.portwoodglobal__Related_Record_Id__c IN :projIds
        AND portwoodglobal__Status__c IN ('Pending', 'Viewed')
];
for (portwoodglobal__DocGen_Signer__c s : signers) {
    s.portwoodglobal__PIN_Hash__c = hash;
    s.portwoodglobal__PIN_Expires_At__c = System.now().addHours(24);
    s.portwoodglobal__PIN_Attempts__c = 0;
    // Null it out so the code step is forced even if a prior run verified.
    s.portwoodglobal__PIN_Verified_At__c = null;
    System.debug('PIN set for ' + s.portwoodglobal__Signer_Name__c + ' <' + s.portwoodglobal__Signer_Email__c + '>');
}
update signers;
System.debug('KNOWN-PIN ' + KNOWN_PIN + ' set on ' + signers.size() + ' pending signer(s).');
