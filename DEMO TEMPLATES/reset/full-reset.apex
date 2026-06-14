// ============================================================================
// Portwood DocGen DEMO — FULL RESET
//   Returns the org to clone-clean DATA state. Deletes EVERYTHING the demo
//   created: generated documents, signature artifacts, all demo templates +
//   template bodies, and all seeded demo data (standard + custom).
//   KEEPS: the custom Demo_*__c schema, the DocGen_Demo permset/app, and the
//          installed managed package. (To remove the schema too, see README.)
// Run: sf apex run --target-org dave@portwood.dev.demo -f "DEMO TEMPLATES/reset/full-reset.apex"
// ============================================================================
String NS = 'portwoodglobal__';
Set<String> DEMO_ACCT_NAMES = new Set<String>{ 'Northwind Traders','Summit Components Inc.','Rivers Alliance Foundation' };

// ---- 1. Gather demo base-record ids ----
Set<Id> demoIds = new Set<Id>();
List<Account> accts = [SELECT Id FROM Account WHERE Name IN :DEMO_ACCT_NAMES];
Set<Id> acctIds = (new Map<Id,Account>(accts)).keySet();
demoIds.addAll(acctIds);
for (Contact c : [SELECT Id FROM Contact WHERE AccountId IN :acctIds]) demoIds.add(c.Id);
List<Opportunity> demoOpps = [SELECT Id FROM Opportunity WHERE AccountId IN :acctIds];
for (Opportunity o : demoOpps) demoIds.add(o.Id);
List<Pricebook2> cats = [SELECT Id FROM Pricebook2 WHERE Name IN ('Portwood 2026 Wholesale Catalog','Portwood Mega Catalog (Giant Demo)')];
for (Pricebook2 p : cats) demoIds.add(p.Id);
for (Demo_Event__c e : [SELECT Id FROM Demo_Event__c]) demoIds.add(e.Id);
for (Demo_Attendee__c a : [SELECT Id FROM Demo_Attendee__c]) demoIds.add(a.Id);
for (Demo_Student__c s : [SELECT Id FROM Demo_Student__c]) demoIds.add(s.Id);
for (Demo_Property__c pr : [SELECT Id FROM Demo_Property__c]) demoIds.add(pr.Id);
for (Demo_Certificate__c ct : [SELECT Id FROM Demo_Certificate__c]) demoIds.add(ct.Id);
for (Demo_Statement__c st : [SELECT Id FROM Demo_Statement__c]) demoIds.add(st.Id);

// ---- 2. Delete generated documents linked to demo records ----
Set<Id> cdIds = new Set<Id>();
for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :demoIds]) cdIds.add(l.ContentDocumentId);
if (!cdIds.isEmpty()) delete [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
System.debug('FULL-RESET generated docs deleted: ' + cdIds.size());

// ---- 3. Delete signature artifacts ----
try {
    List<SObject> reqs = Database.query('SELECT Id FROM ' + NS + 'DocGen_Signature_Request__c WHERE ' + NS + 'Related_Record_Id__c IN :demoIds');
    Set<Id> reqIds = new Set<Id>();
    for (SObject r : reqs) reqIds.add(r.Id);
    for (String child : new List<String>{ 'DocGen_Signature_Audit__c','DocGen_Signer__c','DocGen_Signature_Placement__c' }) {
        try { List<SObject> k = Database.query('SELECT Id FROM ' + NS + child + ' WHERE ' + NS + 'Signature_Request__c IN :reqIds'); if (!k.isEmpty()) delete k; } catch (Exception ig) {}
    }
    if (!reqs.isEmpty()) delete reqs;
} catch (Exception e) { System.debug('FULL-RESET signature note: ' + e.getMessage()); }

// ---- 4. Delete demo templates, versions, jobs, and body CVs ----
try {
    List<SObject> tpls = Database.query('SELECT Id FROM ' + NS + 'DocGen_Template__c WHERE ' + NS +
        'Category__c IN (\'Financial Services\',\'Professional Services\',\'Manufacturing & Retail\',\'Real Estate & Legal\',\'Events\',\'Nonprofit\',\'Certificates\',\'Education\',\'Transcripts\')');
    Set<Id> tplIds = new Set<Id>();
    for (SObject t : tpls) tplIds.add(t.Id);
    if (!tplIds.isEmpty()) {
        try { List<SObject> jb = Database.query('SELECT Id FROM ' + NS + 'DocGen_Job__c WHERE ' + NS + 'Template__c IN :tplIds'); if (!jb.isEmpty()) delete jb; } catch (Exception ig) {}
        try { List<SObject> sq = Database.query('SELECT Id FROM ' + NS + 'DocGen_Saved_Query__c WHERE ' + NS + 'DocGen_Template__c IN :tplIds'); if (!sq.isEmpty()) delete sq; } catch (Exception ig) {}
        List<SObject> vers = Database.query('SELECT Id FROM ' + NS + 'DocGen_Template_Version__c WHERE ' + NS + 'Template__c IN :tplIds');
        if (!vers.isEmpty()) delete vers;
        delete tpls;
    }
    System.debug('FULL-RESET templates deleted: ' + tplIds.size());
} catch (Exception e) { System.debug('FULL-RESET template note: ' + e.getMessage()); }

// Template body CVs (uploaded with title "DEMO <name> body")
try {
    List<ContentDocument> bodyDocs = [SELECT Id FROM ContentDocument WHERE Title LIKE 'DEMO %body'];
    if (!bodyDocs.isEmpty()) delete bodyDocs;
    System.debug('FULL-RESET template body files deleted: ' + bodyDocs.size());
} catch (Exception e) { System.debug('FULL-RESET body-cv note: ' + e.getMessage()); }

// ---- 5. Delete seeded demo data (children first) ----
delete [SELECT Id FROM Demo_Statement_Line__c];
delete [SELECT Id FROM Demo_Statement__c];
delete [SELECT Id FROM Demo_Enrollment__c];
delete [SELECT Id FROM Demo_Student__c];
delete [SELECT Id FROM Demo_Attendee__c];
delete [SELECT Id FROM Demo_Event__c];
delete [SELECT Id FROM Demo_Property__c];
delete [SELECT Id FROM Demo_Certificate__c];
// Delete line items FIRST so no OpportunityLineItem references the standard
// PricebookEntry (otherwise the product delete throws DELETE_FAILED).
Set<Id> demoOppIds = new Set<Id>();
for (Opportunity o : demoOpps) demoOppIds.add(o.Id);
if (!demoOppIds.isEmpty()) delete [SELECT Id FROM OpportunityLineItem WHERE OpportunityId IN :demoOppIds];
if (!demoOpps.isEmpty()) delete demoOpps;
if (!accts.isEmpty()) {
    delete [SELECT Id FROM Contact WHERE AccountId IN :acctIds];
    delete accts;
}
// Curated catalog (small — safe in this transaction). Delete the custom catalog
// entries + pricebook, then the products — deleting Product2 cascades its
// standard PricebookEntries automatically (no explicit std-PBE delete needed).
// The 2,200-line GIANT catalog is removed separately in chunks by
// full-reset-giant.apex (driven by reset.sh) to stay under the CPU limit.
delete [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode LIKE 'PWG-%' AND Pricebook2.IsStandard = false];
delete [SELECT Id FROM Pricebook2 WHERE Name = 'Portwood 2026 Wholesale Catalog'];
delete [SELECT Id FROM Product2 WHERE ProductCode LIKE 'PWG-%'];

System.debug('FULL-RESET DONE (core) — run full-reset-giant.apex in a loop to remove the giant catalog. Schema kept.');
