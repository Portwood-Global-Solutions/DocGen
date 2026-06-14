// Directly exercise the GUIDED finalize (saveCompositedSignedPdf) for a Flow-created
// Waiver request, to confirm: (a) it inserts the signed CV, and (b) the CV is named per
// the template's Document_Title_Format__c ("Waiver - {Name} {Today: MM/DD/YYYY}").

DocGen_Signer__c signer = [
    SELECT Secure_Token__c, Signature_Request__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__r.Template__r.Name = 'Waiver' AND Status__c != 'Signed'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
signer.PIN_Verified_At__c = Datetime.now();
update signer;
String token = signer.Secure_Token__c;

// A real (tiny) PDF blob to stand in for the client composite.
Blob pdf = Blob.toPdf('<html><body><p>Signed Waiver</p></body></html>');
String base64Pdf = EncodingUtil.base64Encode(pdf);

DocGenSignatureController.SavePdfSignatureResult res = DocGenSignatureController.saveCompositedSignedPdf(
    token,
    base64Pdf,
    true,
    '203.0.113.5',
    'VerifyBot/1.0'
);
System.debug('=== COMPOSITE SAVE: success=' + res.success + ' isComplete=' + res.isComplete + ' ===');

// What did it name the signed CV?
List<ContentVersion> signed = [
    SELECT Title, FileType
    FROM ContentVersion
    WHERE FileType = 'PDF' AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (!signed.isEmpty()) {
    System.debug('=== NEWEST PDF TITLE: "' + signed[0].Title + '" ===');
}
