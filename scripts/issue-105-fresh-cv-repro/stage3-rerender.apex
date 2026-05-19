// Re-render against the *existing* TEST3 Property Demo template (no upload, no
// extraction, no version churn). If the broken logo is a timing issue with
// fresh-uploaded CVs and the shepherd servlet, the image CV has now been
// committed long enough to render cleanly.

DocGen_Template__c t = [SELECT Id FROM DocGen_Template__c WHERE Name = 'TEST3 Property Demo' LIMIT 1];
List<DocGen_Template_Version__c> vs = [
    SELECT Id, CreatedDate
    FROM DocGen_Template_Version__c
    WHERE Template__c = :t.Id AND Is_Active__c = TRUE
    LIMIT 1
];
System.debug(
    'Template: ' +
        t.Id +
        ', active version: ' +
        (vs.isEmpty() ? 'NONE' : vs[0].Id + ' (created ' + vs[0].CreatedDate + ')')
);

Map<String, Object> wrapper = new Map<String, Object>{
    'Property_Name__c' => 'Sunset Ridge Apartments',
    'Property_City__c' => 'Santa Monica',
    'Property_State__c' => 'CA',
    'Name' => 'Sunset Ridge Apartments'
};

Map<String, Object> result = DocGenService.generatePdfBlobFromData(t.Id, wrapper);
Blob pdf = (Blob) result.get('blob');
String html = DocGenService.lastRenderedHtml;
System.debug('PDF: ' + pdf.size() + ' bytes');

// Save fresh artefacts on the same anchor
Account a = [SELECT Id FROM Account WHERE Name = 'TEST3 Property Demo Anchor' LIMIT 1];
insert new ContentVersion(
    Title = 'TEST3 Output PDF (rerender)',
    PathOnClient = 'TEST3_rerender.pdf',
    VersionData = pdf,
    FirstPublishLocationId = a.Id
);
System.debug('Saved rerender PDF to ' + a.Id);

// Print head/tail of HTML to confirm image src URL pattern
System.debug('IMG src present? ' + (html != null && html.contains('/sfc/servlet.shepherd/version/download/')));
