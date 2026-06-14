// Sign the latest Waiver (Flow-path) request programmatically: fills each placement
// then finalizes via saveSignature → trigger → TemplateSignaturePdfQueueable (server-side
// stampSignaturesInHtml). Then we inspect the output CV separately.

DocGen_Signer__c signer = [
    SELECT Id, Secure_Token__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__r.Template__r.Name = 'Waiver' AND Status__c != 'Signed'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
String token = signer.Secure_Token__c;

List<Map<String, Object>> placements = DocGenSignatureController.getSignerPlacements(token);
System.debug('Placements to sign: ' + placements.size());
for (Map<String, Object> p : placements) {
    String type = (String) p.get('type');
    Id plcId = (Id) p.get('id');
    String value = (type == 'Date') ? System.now().format('MMMM d, yyyy') : 'Jordan Rivera';
    DocGenSignatureController.signPlacement(token, plcId, value);
    System.debug('Signed placement type=' + type + ' value=' + value);
}

DocGenSignatureController.SaveSignatureResult res = DocGenSignatureController.saveSignature(
    token,
    'Jordan Rivera',
    true,
    '203.0.113.10',
    'VerifyBot/1.0'
);
System.debug('=== SAVE RESULT isComplete=' + res.isComplete + ' remaining=' + res.remaining + ' ===');
