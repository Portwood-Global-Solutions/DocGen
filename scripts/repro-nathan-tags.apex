// Reproduce Nathan's template: bare-role {@Signature_Customer} + {@Signature_Customer:1:Date}
// inside <div class="sig-line">. Check (1) placement detection, (2) guided creation.
String html =
    '<html><head><style>.sig-line{border-top:1px solid #333;}</style></head><body>' +
    '<h1>{FirstName} {LastName}</h1>' +
    '<table class="sig-table"><tr>' +
    '<td><strong>Signature:</strong><div class="sig-line">{@Signature_Customer}</div></td>' +
    '<td><strong>Date:</strong><div class="sig-line">{@Signature_Customer:1:Date}</div></td>' +
    '</tr></table></body></html>';

ContentVersion cv = new ContentVersion(
    Title = 'Nathan Repro body',
    PathOnClient = 'nathan.html',
    VersionData = Blob.valueOf(html)
);
insert cv;
Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Nathan Repro',
    Type__c = 'HTML',
    Base_Object_API__c = 'Contact',
    Query_Config__c = 'Name, FirstName, LastName'
);
insert tpl;
insert new DocGen_Template_Version__c(Template__c = tpl.Id, Is_Active__c = true, Content_Version_Id__c = cvId);

// (1) Detection
List<DocGenSignatureSenderController.PlacementInfo> placements = DocGenSignatureSenderController.getTemplateSignaturePlacements(
    tpl.Id
);
System.debug('=== PLACEMENTS FOUND: ' + placements.size() + ' ===');
for (DocGenSignatureSenderController.PlacementInfo p : placements) {
    System.debug('  role=' + p.role + ' seq=' + p.sequence + ' type=' + p.placementType + ' tag=' + p.tagText);
}

// (2) Guided creation
Id contactId = [SELECT Id FROM Contact WHERE LastName = 'Rivera' LIMIT 1].Id;
String signersJson = '[{"signerName":"Cust One","signerEmail":"c1@example.com","roleName":"Customer"}]';
try {
    DocGenSignatureSenderController.createGuidedPdfSignatureRequest(tpl.Id, contactId, signersJson, 'Parallel', null);
    DocGen_Signer__c signer = [
        SELECT Secure_Token__c, Signature_Request__c
        FROM DocGen_Signer__c
        WHERE Signature_Request__r.Template__c = :tpl.Id
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];
    Integer plcCount = [SELECT COUNT() FROM DocGen_Signature_Placement__c WHERE Signer__c = :signer.Id];
    System.debug('=== GUIDED OK: ' + plcCount + ' placements created ===');
    System.debug('TOKEN: ' + signer.Secure_Token__c);
} catch (Exception e) {
    System.debug('=== GUIDED FAILED: ' + e.getMessage() + ' ===');
}
