// M3 demo: builds a throwaway HTML template containing a styled {#Signatures} loop
// block, then snapshot-sends it to TWO signers against a record. Sign both in the
// browser; the completed "... - Signed" PDF attached to the record should show TWO
// styled signature blocks inline (where the {#Signatures} block sits) + the cert page.
// Re-run with one signer in the `signers` list to confirm the SAME template renders
// exactly one block.
//
// Run: sf apex run --target-org docgen-test -f scripts/make-m3-signatures-demo.apex
Id recordId = '001Pu00000pUEOPIA4'; // E2E Test Corp (Account)

// --- Build a demo template with a {#Signatures} loop block ----------------------
// Styled with CSS 2.1 only (Flying Saucer subset): no flex/grid/gradients.
// The name renders italic on a ruled line to read like a signature.
String body =
    '<html><head><style>' +
    'body{font-family:Helvetica,Arial,sans-serif;color:#222;font-size:11pt;}' +
    'h1{color:#0176D3;font-size:18pt;}' +
    '.sig{margin:18px 0;padding:10px 0;border-top:1px solid #ddd;}' +
    '.sig .name{font-style:italic;font-size:16pt;border-bottom:1px solid #333;' +
    'padding-bottom:2px;display:inline-block;min-width:260px;}' +
    '.sig .meta{color:#555;font-size:9pt;margin-top:4px;}' +
    '</style></head><body>' +
    '<h1>Service Agreement</h1>' +
    '<p>This agreement is entered into by <b>{Name}</b> ' +
    '(Industry: {Industry}).</p>' +
    '<p>The parties below have signed electronically:</p>' +
    '{#Signatures}' +
    '<div class="sig">' +
    '<span class="name">{Name}</span>' +
    '<div class="meta">{Role} &middot; {Email}<br/>' +
    'Electronically signed on {SignedDate} &middot; Status: {Status}</div>' +
    '</div>' +
    '{/Signatures}' +
    '</body></html>';

DocGen_Template__c tmpl = new DocGen_Template__c(
    Name = 'M3 Signatures Demo',
    Base_Object_API__c = 'Account',
    Query_Config__c = 'Name, Industry',
    Type__c = 'HTML',
    Output_Format__c = 'PDF'
);
insert tmpl;

ContentVersion bodyCv = new ContentVersion(
    Title = 'M3 Signatures Demo Body',
    PathOnClient = 'm3-demo.html',
    VersionData = Blob.valueOf(body),
    FirstPublishLocationId = tmpl.Id
);
insert bodyCv;

insert new DocGen_Template_Version__c(Template__c = tmpl.Id, Is_Active__c = true, Content_Version_Id__c = bodyCv.Id);

// --- Snapshot-send to TWO signers ----------------------------------------------
String signers = JSON.serialize(
    new List<Map<String, Object>>{
        new Map<String, Object>{
            'signerName' => 'Pat Tester',
            'signerEmail' => 'pat@example.com',
            'roleName' => 'Buyer'
        },
        new Map<String, Object>{
            'signerName' => 'Sam Counter',
            'signerEmail' => 'sam@example.com',
            'roleName' => 'Seller'
        }
    }
);

List<DocGenSignatureSenderController.SignerResult> res = DocGenSignatureSenderController.createTemplateSnapshotRequest(
    tmpl.Id,
    recordId,
    signers,
    'Parallel', // both can sign independently; 'Sequential' to enforce order
    null
);

// Pre-verify each signer's PIN so the scratch org (no outbound email) skips the email step.
Set<Id> signerIds = new Set<Id>();
for (DocGenSignatureSenderController.SignerResult r : res) {
    signerIds.add(r.signerId);
}
List<DocGen_Signer__c> toVerify = [SELECT Id FROM DocGen_Signer__c WHERE Id IN :signerIds];
for (DocGen_Signer__c s : toVerify) {
    s.PIN_Verified_At__c = System.now();
}
update toVerify;

System.debug('TEMPLATE_ID >>> ' + tmpl.Id);
for (DocGenSignatureSenderController.SignerResult r : res) {
    System.debug('SIGNER_URL (' + r.signerId + ') >>> ' + r.signerUrl);
}
