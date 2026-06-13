// Prove context/global merge tags ({RunningUser.X}, {Today}) resolve in the guided
// PDF path (merged + frozen point-in-time at send). Prints the viewing CV id to render.

String html =
    '<html><head><style>@page{size:letter;margin:0.85in;}' +
    'body{font-family:Helvetica,Arial,sans-serif;font-size:11pt;color:#222;}h1{color:#0176d3;}' +
    'table{width:100%;border-collapse:collapse;margin:10px 0;}td{border:1px solid #e0e0e0;padding:6px 8px;}' +
    'td.l{background:#f4f6f9;font-weight:bold;width:38%;}</style></head><body>' +
    '<h1>Context Tag Check</h1>' +
    '<table>' +
    '<tr><td class="l">Member</td><td>{FirstName} {LastName}</td></tr>' +
    '<tr><td class="l">Prepared by (RunningUser.Name)</td><td>{RunningUser.Name}</td></tr>' +
    '<tr><td class="l">Prepared by email (RunningUser.Email)</td><td>{RunningUser.Email}</td></tr>' +
    '<tr><td class="l">Generated (Today)</td><td>{Today:MMMM d, yyyy}</td></tr>' +
    '</table>' +
    '<p>Member signature: {@Signature_Member:1:Full}</p>' +
    '</body></html>';

ContentVersion cv = new ContentVersion(
    Title = 'Context Tag Check body',
    PathOnClient = 'ctx.html',
    VersionData = Blob.valueOf(html)
);
insert cv;
Id bodyCvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Context Tag Check',
    Type__c = 'HTML',
    Base_Object_API__c = 'Contact',
    Query_Config__c = 'Name, FirstName, LastName, Email'
);
insert tpl;
insert new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true, Content_Version_Id__c = bodyCvId);

Id contactId = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1].Id;
String signersJson = '[{"signerName":"Jordan Rivera","signerEmail":"jordan.rivera@example.com","roleName":"Member"}]';
DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tpl.Id, contactId, signersJson, 'Parallel', null);

DocGen_Signature_Request__c req = [
    SELECT Source_Document_Id__c
    FROM DocGen_Signature_Request__c
    WHERE Template__c = :tpl.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.debug('VIEWING_CV: ' + req.Source_Document_Id__c);
