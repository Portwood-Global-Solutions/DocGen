// ============================================================================
// SDocs-replacement demo — reset between runs.
//
// Clears everything a rehearsal or a live demo generates — signature requests,
// signers, generated PDFs — and puts the projects back to "In Flight" with the
// approval stamps cleared, so the auto-send Flow's "changed to meet criteria"
// entry condition can fire again.
//
// Leaves templates, schema and seed data alone. Run this right before you
// present, not after: a demo org that has been clicked through twice shows
// three copies of the same document in the Files list.
// ============================================================================

// Generated documents linked to the demo projects.
Set<Id> projIds = new Set<Id>();
for (Demo_Project__c p : [SELECT Id FROM Demo_Project__c WHERE Project_Code__c LIKE 'P-2%']) {
    projIds.add(p.Id);
}
Set<Id> docIds = new Set<Id>();
for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :projIds]) {
    docIds.add(l.ContentDocumentId);
}
// Frozen signing copies are NOT linked to the project, so they have to be found
// by title instead — otherwise they accumulate invisibly, one per rehearsal.
for (ContentVersion cv : [
    SELECT ContentDocumentId
    FROM ContentVersion
    WHERE Title LIKE 'Project A%' OR Title LIKE 'Approval Request%' OR Title LIKE 'Acceptance Certificate%'
]) {
    docIds.add(cv.ContentDocumentId);
}
Integer docCount = 0;
if (!docIds.isEmpty()) {
    List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
    docCount = docs.size();
    delete docs;
}

// Signature requests (signers cascade with the master-detail).
List<portwoodglobal__DocGen_Signature_Request__c> reqs = [
    SELECT Id
    FROM portwoodglobal__DocGen_Signature_Request__c
    WHERE portwoodglobal__Related_Record_Id__c IN :projIds
];
Integer reqCount = reqs.size();
delete reqs;

// Projects back to a pre-approval state.
List<Demo_Project__c> ps = [
    SELECT Id, Status__c, Approval_Sent_On__c, Last_Signature_Request_Id__c
    FROM Demo_Project__c
    WHERE Id IN :projIds
];
for (Demo_Project__c p : ps) {
    p.Status__c = 'In Flight';
    p.Approval_Sent_On__c = null;
    p.Last_Signature_Request_Id__c = null;
}
update ps;

System.debug('RESET documents=' + docCount + ' signatureRequests=' + reqCount + ' projects=' + ps.size());
