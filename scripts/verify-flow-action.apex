// Invoke the REAL Flow action (DocGenSignatureFlowAction.generate) the way a subscriber
// Flow does, and confirm: (a) it now routes tag-templates to the GUIDED page
// (DocGenSignaturePdf), and (b) the request inherits the template's Document_Title_Format.

String html =
    '<html><head><style>body{font-family:Helvetica,Arial,sans-serif;font-size:11pt;}' +
    'h1{color:#0176d3;} .line{border-top:1px solid #333;padding-top:4px;font-size:9pt;color:#706e6b;}' +
    'table.sig{width:100%;margin-top:40px;} table.sig td{width:50%;padding:30px 14px 0 14px;vertical-align:bottom;}' +
    '</style></head><body>' +
    '<h1>Liability Waiver</h1>' +
    '<p>I, {Name}, accept the terms of this waiver as of the date signed below.</p>' +
    '<table class="sig"><tr>' +
    '<td><div>{@Signature_Signer:1:Full}</div><div class="line">Signature</div></td>' +
    '<td><div>{@Signature_Signer:2:Date}</div><div class="line">Date</div></td>' +
    '</tr></table></body></html>';

ContentVersion cv = new ContentVersion(
    Title = 'Waiver body',
    PathOnClient = 'waiver.html',
    VersionData = Blob.valueOf(html)
);
insert cv;
Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Waiver',
    Type__c = 'HTML',
    Base_Object_API__c = 'Contact',
    Query_Config__c = 'Name, FirstName, LastName',
    Document_Title_Format__c = 'Waiver - {Name} {Today: MM/DD/YYYY}'
);
insert tpl;
insert new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true, Content_Version_Id__c = cvId);

Id contactId = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1].Id;

DocGenSignatureFlowAction.Request req = new DocGenSignatureFlowAction.Request();
req.templateId = tpl.Id;
req.relatedRecordId = contactId;
req.signerNames = new List<String>{ 'Jordan Rivera' };
req.signerEmails = new List<String>{ 'jordan.rivera@example.com' };
req.signerRoles = new List<String>{ 'Signer' };
req.sendEmails = false;
req.signingOrder = 'Single';

List<DocGenSignatureFlowAction.Result> results = DocGenSignatureFlowAction.generate(
    new List<DocGenSignatureFlowAction.Request>{ req }
);

DocGenSignatureFlowAction.Result r = results[0];
System.debug('=== FLOW ACTION RESULT ===');
System.debug('success: ' + r.success);
System.debug('requestId: ' + r.signatureRequestId);
String url = (r.signerUrls != null && !r.signerUrls.isEmpty()) ? r.signerUrls[0] : '(none)';
System.debug('signerUrl: ' + url);
System.debug('ROUTED_TO_GUIDED: ' + (url.contains('DocGenSignaturePdf')));

DocGen_Signature_Request__c saved = [
    SELECT Status__c, Signing_Order__c, Document_Title_Format__c
    FROM DocGen_Signature_Request__c
    WHERE Id = :r.signatureRequestId
];
System.debug('req.Signing_Order__c: ' + saved.Signing_Order__c);
System.debug('req.Document_Title_Format__c: ' + saved.Document_Title_Format__c);

DocGen_Signer__c signer = [
    SELECT Secure_Token__c
    FROM DocGen_Signer__c
    WHERE Signature_Request__c = :r.signatureRequestId
    LIMIT 1
];
signer.PIN_Verified_At__c = Datetime.now();
update signer;
System.debug('TOKEN: ' + signer.Secure_Token__c);
