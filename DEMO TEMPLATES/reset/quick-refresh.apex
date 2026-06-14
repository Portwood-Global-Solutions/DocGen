// ============================================================================
// Portwood DocGen DEMO — QUICK REFRESH
//   Frees storage WITHOUT destroying the demo. Deletes:
//     • every generated document (PDF/DOCX/PPTX) attached to a demo base record
//     • all signature requests / signers / audits / placements for demo records
//     • DocGen job rows for the demo templates
//   KEEPS: all templates, template bodies, and seeded demo data.
// Run: sf apex run --target-org dave@portwood.dev.demo -f "DEMO TEMPLATES/reset/quick-refresh.apex"
// ============================================================================
String NS = 'portwoodglobal__';
Set<String> DEMO_ACCT_NAMES = new Set<String>{ 'Northwind Traders','Summit Components Inc.','Rivers Alliance Foundation' };

// ---- 1. Gather demo base-record ids (the records people generate against) ----
Set<Id> demoIds = new Set<Id>();
List<Account> accts = [SELECT Id FROM Account WHERE Name IN :DEMO_ACCT_NAMES];
Set<Id> acctIds = (new Map<Id,Account>(accts)).keySet();
demoIds.addAll(acctIds);
for (Contact c : [SELECT Id FROM Contact WHERE AccountId IN :acctIds]) demoIds.add(c.Id);
for (Opportunity o : [SELECT Id FROM Opportunity WHERE AccountId IN :acctIds]) demoIds.add(o.Id);
for (Pricebook2 p : [SELECT Id FROM Pricebook2 WHERE Name IN ('Portwood 2026 Wholesale Catalog','Portwood Mega Catalog (Giant Demo)')]) demoIds.add(p.Id);
for (Demo_Event__c e : [SELECT Id FROM Demo_Event__c]) demoIds.add(e.Id);
for (Demo_Attendee__c a : [SELECT Id FROM Demo_Attendee__c]) demoIds.add(a.Id);
for (Demo_Student__c s : [SELECT Id FROM Demo_Student__c]) demoIds.add(s.Id);
for (Demo_Property__c pr : [SELECT Id FROM Demo_Property__c]) demoIds.add(pr.Id);
for (Demo_Certificate__c ct : [SELECT Id FROM Demo_Certificate__c]) demoIds.add(ct.Id);
for (Demo_Statement__c st : [SELECT Id FROM Demo_Statement__c]) demoIds.add(st.Id);

// ---- 2. Delete generated documents linked to those records ----
Set<Id> cdIds = new Set<Id>();
for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :demoIds]) {
    cdIds.add(l.ContentDocumentId);
}
Integer docCount = 0;
if (!cdIds.isEmpty()) {
    List<ContentDocument> cds = [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
    docCount = cds.size();
    delete cds;
}
System.debug('QUICK-REFRESH generated documents deleted: ' + docCount);

// ---- 3. Delete signature artifacts for demo records ----
Integer sigReq = 0;
try {
    List<SObject> reqs = Database.query(
        'SELECT Id FROM ' + NS + 'DocGen_Signature_Request__c WHERE ' + NS + 'Related_Record_Id__c IN :demoIds');
    sigReq = reqs.size();
    if (!reqs.isEmpty()) {
        Set<Id> reqIds = new Set<Id>();
        for (SObject r : reqs) reqIds.add(r.Id);
        for (String child : new List<String>{ 'DocGen_Signature_Audit__c','DocGen_Signer__c','DocGen_Signature_Placement__c' }) {
            try {
                List<SObject> kids = Database.query(
                    'SELECT Id FROM ' + NS + child + ' WHERE ' + NS + 'Signature_Request__c IN :reqIds');
                if (!kids.isEmpty()) delete kids;
            } catch (Exception ignore) {}
        }
        delete reqs;
    }
} catch (Exception e) {
    System.debug('QUICK-REFRESH signature cleanup note: ' + e.getMessage());
}
System.debug('QUICK-REFRESH signature requests deleted: ' + sigReq);

// ---- 4. Delete DocGen job rows for demo templates ----
Integer jobs = 0;
try {
    List<SObject> demoTpls = Database.query(
        'SELECT Id FROM ' + NS + 'DocGen_Template__c WHERE ' + NS + 'Category__c IN ' +
        '(\'Financial Services\',\'Professional Services\',\'Manufacturing & Retail\',\'Real Estate & Legal\',\'Events\',\'Nonprofit\',\'Certificates\',\'Education\',\'Transcripts\')');
    Set<Id> tplIds = new Set<Id>();
    for (SObject t : demoTpls) tplIds.add(t.Id);
    if (!tplIds.isEmpty()) {
        List<SObject> j = Database.query('SELECT Id FROM ' + NS + 'DocGen_Job__c WHERE ' + NS + 'Template__c IN :tplIds');
        jobs = j.size();
        if (!j.isEmpty()) delete j;
    }
} catch (Exception e) {
    System.debug('QUICK-REFRESH job cleanup note: ' + e.getMessage());
}
System.debug('QUICK-REFRESH jobs deleted: ' + jobs);
System.debug('QUICK-REFRESH DONE — templates and seeded data preserved.');
