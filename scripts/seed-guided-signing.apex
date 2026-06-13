// Seed a guided-signing demo: a flat PDF whose body carries per-placement sentinels,
// plus a PIN-verified signer with 3 placements (Full / Initials / Date) pointed at
// the PDF-viewer signing page. Lets us visually test the sign-spot overlay end-to-end.
// Scratch org is --no-namespace, so bare API names are used.

String s1 = '@@SIG-1@@'; // Full signature
String s2 = '@@SIG-2@@'; // Initials
String s3 = '@@SIG-3@@'; // Date

String html =
    '<html><head><style>' +
    '@page { size: letter; margin: 0.85in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color:#222; }' +
    'h1 { color:#0176d3; margin-bottom:2px; }' +
    '.sub { color:#706e6b; font-size:10pt; margin-bottom:18px; }' +
    '.terms { text-align:justify; margin:14px 0; }' +
    'table.sig { width:100%; margin-top:40px; border-collapse:collapse; }' +
    'table.sig td { width:50%; padding:28px 14px 0 14px; vertical-align:bottom; }' +
    '.line { border-top:1px solid #333; padding-top:4px; font-size:9pt; color:#706e6b; }' +
    '.spot { font-weight:bold; color:#92400e; }' +
    '.gap { height:120px; }' +
    '</style></head><body>' +
    '<h1>Master Services Agreement</h1>' +
    '<div class="sub">Northwind Athletics Club &middot; Guided-signing demo</div>' +
    '<div class="terms">This Agreement is entered into by the parties identified below. ' +
    'By signing, each party acknowledges they have read and agree to the terms herein. ' +
    'Initials are required on this page to confirm review of the liability provisions.</div>' +
    '<p>Reviewed and acknowledged (initial here): <span class="spot">' +
    s2 +
    '</span></p>' +
    '<div class="gap"></div>' +
    '<div class="terms">The undersigned agrees to the full terms of this Agreement as of the date of signature.</div>' +
    '<table class="sig"><tr>' +
    '<td><div class="spot">' +
    s1 +
    '</div><div class="line">Signature</div></td>' +
    '<td><div class="spot">' +
    s3 +
    '</div><div class="line">Date</div></td>' +
    '</tr></table>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);

ContentVersion cv = new ContentVersion();
cv.Title = 'Guided Signing Demo - MSA';
cv.PathOnClient = 'guided-demo.pdf';
cv.VersionData = pdf;
insert cv;
Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

DocGen_Signature_Request__c req = new DocGen_Signature_Request__c();
req.Source_Document_Id__c = cvId;
req.Status__c = 'Sent';
req.Signing_Order__c = 'Parallel';
insert req;

String token = EncodingUtil.convertToHex(
    Crypto.generateDigest('SHA-256', Blob.valueOf('guided-demo-' + req.Id + '-' + Datetime.now().getTime()))
);

DocGen_Signer__c signer = new DocGen_Signer__c();
signer.Signature_Request__c = req.Id;
signer.Signer_Name__c = 'Jordan Rivera';
signer.Signer_Email__c = 'jordan.rivera@example.com';
signer.Role_Name__c = 'Buyer';
signer.Status__c = 'Pending';
signer.Sort_Order__c = 1;
signer.Secure_Token__c = token;
signer.PIN_Verified_At__c = Datetime.now(); // bypass email PIN in the demo org
insert signer;

List<DocGen_Signature_Placement__c> plcs = new List<DocGen_Signature_Placement__c>{
    new DocGen_Signature_Placement__c(
        Signer__c = signer.Id,
        Signature_Request__c = req.Id,
        Tag_Text__c = s2,
        Placement_Type__c = 'Initials',
        Sequence_Order__c = 1,
        Document_Index__c = 0,
        Status__c = 'Pending'
    ),
    new DocGen_Signature_Placement__c(
        Signer__c = signer.Id,
        Signature_Request__c = req.Id,
        Tag_Text__c = s1,
        Placement_Type__c = 'Full',
        Sequence_Order__c = 2,
        Document_Index__c = 0,
        Status__c = 'Pending'
    ),
    new DocGen_Signature_Placement__c(
        Signer__c = signer.Id,
        Signature_Request__c = req.Id,
        Tag_Text__c = s3,
        Placement_Type__c = 'Date',
        Sequence_Order__c = 3,
        Document_Index__c = 0,
        Status__c = 'Pending'
    )
};
insert plcs;

System.debug('=== GUIDED SIGNING DEMO READY ===');
System.debug('Request:   ' + req.Id);
System.debug('Signer:    ' + signer.Id);
System.debug('TOKEN:     ' + token);
System.debug('Open:      /apex/DocGenSignaturePdf?token=' + token);
