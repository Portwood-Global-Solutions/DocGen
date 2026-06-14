// Reproduce Sarah's setup: single-signer HTML waiver created via the FLOW path
// (DocGenSignatureSenderController.createTemplateSignerRequestWithOrder — exactly what
// DocGenSignatureFlowAction calls), with a template Document_Title_Format__c set.
// Verifies (1) signature/date STAMP into the final doc (no raw {@Signature} tags), and
// (2) whether the signed doc name follows the template's naming pattern.

String html =
    '<html><head><style>' +
    'body{font-family:Helvetica,Arial,sans-serif;font-size:11pt;color:#222;}' +
    'h1{color:#0176d3;} .line{border-top:1px solid #333;padding-top:4px;font-size:9pt;color:#706e6b;}' +
    'table.sig{width:100%;margin-top:40px;border-collapse:collapse;} table.sig td{width:50%;padding:30px 14px 0 14px;vertical-align:bottom;}' +
    '</style></head><body>' +
    '<h1>Liability Waiver</h1>' +
    '<p>I, {Name}, acknowledge and accept the terms of this waiver as of the date signed below.</p>' +
    '<table class="sig"><tr>' +
    '<td><div>{@Signature_Signer:1:Full}</div><div class="line">Signature</div></td>' +
    '<td><div>{@Signature_Signer:2:Date}</div><div class="line">Date</div></td>' +
    '</tr></table>' +
    '</body></html>';

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
String signersJson = '[{"signerName":"Jordan Rivera","signerEmail":"jordan.rivera@example.com","roleName":"Signer"}]';

// THE FLOW PATH:
List<DocGenSignatureSenderController.SignerResult> results = DocGenSignatureSenderController.createTemplateSignerRequestWithOrder(
    tpl.Id,
    contactId,
    signersJson,
    'Parallel'
);

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
System.debug('=== FLOW WAIVER READY ===');
System.debug('Request:   ' + signer.Signature_Request__c);
System.debug('Placements:' + plcCount);
System.debug('TOKEN:     ' + signer.Secure_Token__c);
