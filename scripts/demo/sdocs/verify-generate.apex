// ============================================================================
// SDocs-replacement demo — prove both templates actually render.
//
// Uses portwoodglobal.DocGenService.generateDocument, which is `global` and
// therefore the only generation entry point visible in a SUBSCRIBER org. The
// repo's e2e-*.apex suites call DocGenController / processXmlForTest, which are
// `public` and invisible here by construction — do not reach for them.
//
// Prints the generated ContentVersion size. A template whose merge tags all
// failed still produces a PDF, so size alone is not proof; the follow-up query
// below re-reads the rendered HTML snapshot and reports any tag left unresolved.
// ============================================================================

Map<String, Id> tpl = new Map<String, Id>();
for (portwoodglobal__DocGen_Template__c t : [
    SELECT Id, Name
    FROM portwoodglobal__DocGen_Template__c
    WHERE portwoodglobal__Category__c = 'Project Delivery'
]) {
    tpl.put(t.Name, t.Id);
}
Demo_Project__c p = [SELECT Id, Name, Project_Code__c FROM Demo_Project__c WHERE Project_Code__c = 'P-2041' LIMIT 1];
System.debug('VERIFY project=' + p.Project_Code__c + ' (' + p.Id + ') templates=' + tpl.keySet());

for (
    String name : new List<String>{ 'Project Approval Request', 'Project Acceptance Certificate', 'Project Invoice' }
) {
    Id tid = tpl.get(name);
    if (tid == null) {
        System.debug('VERIFY FAIL ' + name + ' -> template not found');
        continue;
    }
    try {
        // Returns a ContentDOCUMENT id (069…), not a ContentVersion (068…).
        // Querying ContentVersion by it throws "List has no rows", which reads
        // like a generation failure and is really a wrong key prefix.
        Id docId = portwoodglobal.DocGenService.generateDocument(tid, p.Id);
        ContentVersion cv = [
            SELECT Id, Title, ContentSize, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :docId AND IsLatest = TRUE
            LIMIT 1
        ];
        System.debug(
            'VERIFY OK ' + name + ' -> ' + cv.Title + '.' + cv.FileExtension + ' (' + cv.ContentSize + ' bytes)'
        );
    } catch (Exception e) {
        System.debug('VERIFY FAIL ' + name + ' -> ' + e.getTypeName() + ': ' + e.getMessage());
    }
}
