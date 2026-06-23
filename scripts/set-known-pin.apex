// #verification UAT helper — sets a KNOWN verification code (123456) on the UAT signers
// so you can complete the PIN scenarios without receiving the email.
//
// Order of operations (because the page's "Send Code" regenerates a random PIN):
//   1. Open the scenario 2 or 3 signing URL and reach the code-entry screen
//      (scenario 2 auto-sends; scenario 3: type your email → Send Code).
//   2. Run this script.
//   3. Enter  123456  on the screen → it verifies and you proceed to sign.
//   (Do NOT click "Resend" afterwards — that would replace the known code again.)
//
// Run:  sf apex run --target-org docgen-test --file scripts/set-known-pin.apex

String KNOWN_PIN = '123456';
String hash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(KNOWN_PIN)));

List<DocGen_Signer__c> signers = [
    SELECT Id, Signer_Email__c, PIN_Verified_At__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__r.Template__r.Name = 'Verification UAT Template' AND Status__c IN ('Pending', 'Viewed')
];
for (DocGen_Signer__c s : signers) {
    s.PIN_Hash__c = hash;
    s.PIN_Expires_At__c = System.now().addHours(24);
    s.PIN_Attempts__c = 0;
    s.PIN_Verified_At__c = null; // force the code step (in case a prior run verified)
}
update signers;
System.debug('Set known PIN ' + KNOWN_PIN + ' on ' + signers.size() + ' UAT signer(s). Enter it on the screen.');
