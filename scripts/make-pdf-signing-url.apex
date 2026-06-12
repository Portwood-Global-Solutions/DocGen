// Dev helper: mint a test PDF signing request for the new DocGenSignaturePdf flow.
// Creates a real PDF ContentVersion, an Account to attach to, then calls the new
// createRequestFromContentVersion entry point and prints the signer URL + token.
// Run: sf apex run --target-org docgen-test -f scripts/make-pdf-signing-url.apex

Blob pdf = Blob.toPdf('<html><body><h1>Test Agreement</h1><p>Please review and sign below.</p></body></html>');
ContentVersion cv = new ContentVersion(Title = 'Test Agreement', PathOnClient = 'TestAgreement.pdf', VersionData = pdf);
insert cv;
Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;

Account a = new Account(Name = 'Signing Test Co');
insert a;

String signers = JSON.serialize(
    new List<Map<String, Object>>{
        new Map<String, Object>{
            'signerName' => 'Pat Tester',
            'signerEmail' => 'pat@example.com',
            'roleName' => 'Signer'
        }
    }
);

List<DocGenSignatureSenderController.SignerResult> res = DocGenSignatureSenderController.createRequestFromContentVersion(
    cvId,
    a.Id,
    signers,
    'Parallel',
    null
);

for (DocGenSignatureSenderController.SignerResult r : res) {
    System.debug('SIGNER_URL >>> ' + r.signerUrl);
    System.debug('SIGNER_ID  >>> ' + r.signerId);
}

// Raw token + the source CV, so a public URL can be built by hand if the
// generated signerUrl points at the internal domain instead of the Site domain.
for (DocGen_Signer__c s : [
    SELECT Secure_Token__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__c IN (SELECT Id FROM DocGen_Signature_Request__c WHERE Source_Document_Id__c = :cvId)
]) {
    System.debug('TOKEN >>> ' + s.Secure_Token__c);
}
System.debug('SOURCE_CV >>> ' + cvId);
