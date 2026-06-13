// Multi-signer guided PDF test: a 2-role template (Buyer + Seller), each role with
// its own placements. Verifies role->signer mapping, per-signer chip scoping, and a
// final PDF that stamps BOTH signers' values. Scratch org is --no-namespace.

String html =
    '<html><head><style>' +
    '@page { size: letter; margin: 0.85in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color:#222; }' +
    'h1 { color:#0176d3; }' +
    '.sub { color:#706e6b; font-size:10pt; margin-bottom:18px; }' +
    '.terms { text-align:justify; margin:14px 0; }' +
    'table.sig { width:100%; margin-top:30px; border-collapse:collapse; }' +
    'table.sig td { width:50%; padding:26px 14px 0 14px; vertical-align:bottom; }' +
    '.line { border-top:1px solid #333; padding-top:4px; font-size:9pt; color:#706e6b; }' +
    '.gap { height:70px; }' +
    '</style></head><body>' +
    '<h1>Purchase Agreement</h1>' +
    '<div class="sub">{Account.Name} &middot; Multi-signer guided PDF test</div>' +
    '<div class="terms">This Purchase Agreement is between the Buyer and the Seller for the property described herein. ' +
    'Buyer initials to acknowledge the inspection clause: {@Signature_Buyer:1:Initials} &nbsp;&nbsp; ' +
    'Seller initials to acknowledge the disclosure clause: {@Signature_Seller:1:Initials}</div>' +
    '<div class="gap"></div>' +
    '<div class="terms">Each party agrees to the full terms as of the date of signature below.</div>' +
    '<table class="sig"><tr>' +
    '<td><div>{@Signature_Buyer:2:Full}</div><div class="line">Buyer Signature</div></td>' +
    '<td><div>{@Signature_Seller:2:Full}</div><div class="line">Seller Signature</div></td>' +
    '</tr></table>' +
    '</body></html>';

ContentVersion bodyCv = new ContentVersion(
    Title = 'Purchase Agreement (multi) body',
    PathOnClient = 'purchase-agreement.html',
    VersionData = Blob.valueOf(html)
);
insert bodyCv;
Id bodyCvId = [SELECT Id FROM ContentVersion WHERE Id = :bodyCv.Id].Id;

DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Purchase Agreement (Guided Multi-Signer)',
    Type__c = 'HTML',
    Base_Object_API__c = 'Contact',
    Query_Config__c = 'Name, FirstName, LastName, Email, Account.Name'
);
insert tpl;
insert new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true, Content_Version_Id__c = bodyCvId);

Id contactId = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1].Id;

// Two signers, two roles.
String signersJson =
    '[' +
    '{"signerName":"Bailey Buyer","signerEmail":"bailey.buyer@example.com","roleName":"Buyer"},' +
    '{"signerName":"Sam Seller","signerEmail":"sam.seller@example.com","roleName":"Seller"}' +
    ']';
DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tpl.Id, contactId, signersJson, 'Parallel', null);

// Pre-verify PINs; print both tokens + each signer's placement count.
List<DocGen_Signer__c> signers = [
    SELECT Id, Role_Name__c, Secure_Token__c, Signature_Request__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__r.Template__c = :tpl.Id
    ORDER BY Sort_Order__c
];
for (DocGen_Signer__c s : signers) {
    s.PIN_Verified_At__c = Datetime.now();
}
update signers;

System.debug('=== MULTI-SIGNER GUIDED DEMO READY ===');
System.debug('Template: ' + tpl.Id);
if (!signers.isEmpty())
    System.debug('Request:  ' + signers[0].Signature_Request__c);
for (DocGen_Signer__c s : signers) {
    Integer cnt = [SELECT COUNT() FROM DocGen_Signature_Placement__c WHERE Signer__c = :s.Id];
    System.debug(s.Role_Name__c + ' (' + cnt + ' placements) TOKEN: ' + s.Secure_Token__c);
}
