// Seed a real HTML template with {@Signature_Role:Order:Type} placement tags,
// then create a guided PDF-signing request via the new creation path
// (DocGenSignatureSenderController.createGuidedPdfSignatureRequest). Verifies the
// end-to-end path: parse tags -> invisible sentinels -> viewing PDF + frozen body
// -> placements -> PDF-viewer signing page. Scratch org is --no-namespace.

// --- 1. Template body (HTML) with merge fields + placement tags ---
String html =
    '<html><head><style>' +
    '@page { size: letter; margin: 0.85in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color:#222; }' +
    'h1 { color:#0176d3; margin-bottom:2px; }' +
    '.sub { color:#706e6b; font-size:10pt; margin-bottom:18px; }' +
    'table.f { width:100%; border-collapse:collapse; margin:12px 0 18px 0; }' +
    'table.f td { border:1px solid #e0e0e0; padding:6px 8px; font-size:10.5pt; }' +
    'table.f td.l { background:#f4f6f9; font-weight:bold; width:32%; }' +
    '.terms { text-align:justify; margin:14px 0; }' +
    'table.sig { width:100%; margin-top:40px; border-collapse:collapse; }' +
    'table.sig td { width:50%; padding:28px 14px 0 14px; vertical-align:bottom; }' +
    '.line { border-top:1px solid #333; padding-top:4px; font-size:9pt; color:#706e6b; }' +
    '.gap { height:90px; }' +
    '</style></head><body>' +
    '<h1>Membership Agreement</h1>' +
    '<div class="sub">{Account.Name} &middot; Guided PDF signing (real template)</div>' +
    '<table class="f">' +
    '<tr><td class="l">Member</td><td>{FirstName} {LastName}</td></tr>' +
    '<tr><td class="l">Email</td><td>{Email}</td></tr>' +
    '</table>' +
    '<div class="terms">The member named above agrees to the terms of this Membership Agreement. ' +
    'Please initial to confirm you have reviewed the cancellation policy.</div>' +
    // Initials on their own right-aligned line with room — not inline in the paragraph.
    '<div style="text-align:right; margin:16px 0;">Initials: {@Signature_Member:1:Initials}</div>' +
    '<div class="gap"></div>' +
    '<div class="terms">By signing below, the member accepts the full terms as of the date of signature.</div>' +
    '<table class="sig"><tr>' +
    '<td><div>{@Signature_Member:2:Full}</div><div class="line">Member Signature</div></td>' +
    '<td><div>{@Signature_Member:3:Date}</div><div class="line">Date</div></td>' +
    '</tr></table>' +
    '</body></html>';

ContentVersion bodyCv = new ContentVersion();
bodyCv.Title = 'Membership Agreement (guided) body';
bodyCv.PathOnClient = 'membership-agreement.html';
bodyCv.VersionData = Blob.valueOf(html);
insert bodyCv;
Id bodyCvId = [SELECT Id FROM ContentVersion WHERE Id = :bodyCv.Id].Id;

// --- 2. Template + active version ---
DocGen_Template__c tpl = new DocGen_Template__c();
tpl.Name = 'Membership Agreement (Guided PDF)';
tpl.Type__c = 'HTML';
tpl.Base_Object_API__c = 'Contact';
tpl.Query_Config__c = 'Name, FirstName, LastName, Email, Account.Name';
insert tpl;

DocGen_Template_Version__c ver = new DocGen_Template_Version__c();
ver.Template__c = tpl.Id;
ver.Is_Active__c = true;
ver.Content_Version_Id__c = bodyCvId;
insert ver;

// --- 3. A Contact to merge against ---
List<Contact> contacts = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1];
Id contactId;
if (contacts.isEmpty()) {
    Contact c = new Contact(FirstName = 'Jordan', LastName = 'Rivera', Email = 'jordan.rivera@example.com');
    insert c;
    contactId = c.Id;
} else {
    contactId = contacts[0].Id;
}

// --- 4. Create the guided PDF signing request ---
String signersJson = '[{"signerName":"Jordan Rivera","signerEmail":"jordan.rivera@example.com","roleName":"Member"}]';
DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tpl.Id, contactId, signersJson, 'Parallel', null);

// --- 5. Find the signer, pre-verify PIN, print token ---
DocGen_Signer__c signer = [
    SELECT Id, Secure_Token__c, Signature_Request__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__r.Template__c = :tpl.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];
signer.PIN_Verified_At__c = Datetime.now();
update signer;

Integer plcCount = [SELECT COUNT() FROM DocGen_Signature_Placement__c WHERE Signer__c = :signer.Id];

System.debug('=== GUIDED TEMPLATE DEMO READY ===');
System.debug('Template:  ' + tpl.Id);
System.debug('Request:   ' + signer.Signature_Request__c);
System.debug('Placements:' + plcCount);
System.debug('TOKEN:     ' + signer.Secure_Token__c);
System.debug('Open:      /apex/DocGenSignaturePdf?token=' + signer.Secure_Token__c);
