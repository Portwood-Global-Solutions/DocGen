/**
 * Diagnostic for issue #236 — "cannot create new templates after upgrading".
 *
 * Run as ANONYMOUS APEX in an affected (upgraded) subscriber org, as the user
 * who hits the error. Open the debug log and read the DIAG lines.
 *
 * Answers three questions in one pass:
 *   1. Does the restricted Type__c picklist actually contain 'HTML'?
 *      ('HTML' was added in v1.61.0 — orgs installed before that and upgraded
 *       are the reported population. The New Template wizard defaults to HTML.)
 *   2. Is every field the create wizard writes createable for this user?
 *      (Packaged fields ship invisible; access comes from DocGen_Admin.)
 *   3. What is the REAL DML error? The UI API flattens it to
 *      "An error occurred while trying to update the record."
 *
 * Read-only except for the final insert, which is rolled back unconditionally.
 */
String ns = 'portwoodglobal__';

System.debug('DIAG ===== 1. PICKLIST VALUES =====');
for (String fieldName : new List<String>{ 'Type__c', 'Output_Format__c', 'Page_Margins__c' }) {
    Schema.SObjectField f = Schema.getGlobalDescribe()
        .get(ns + 'DocGen_Template__c')
        .getDescribe()
        .fields.getMap()
        .get(ns + fieldName);
    if (f == null) {
        System.debug('DIAG   ' + fieldName + ' -> FIELD NOT FOUND');
        continue;
    }
    Schema.DescribeFieldResult d = f.getDescribe();
    List<String> vals = new List<String>();
    for (Schema.PicklistEntry pe : d.getPicklistValues()) {
        vals.add(pe.getValue() + (pe.isActive() ? '' : '(INACTIVE)'));
    }
    System.debug('DIAG   ' + fieldName + ' = ' + String.join(vals, ', '));
}
System.debug('DIAG   ^^ Type__c MUST contain HTML. If it does not, that is the bug.');

System.debug('DIAG ===== 2. FIELD-LEVEL CREATEABILITY =====');
// Exactly the fields docGenAdmin.createTemplate() writes on the default
// (HTML) path, plus the page fields it writes for non-HTML templates.
Map<String, Schema.SObjectField> fm = Schema.getGlobalDescribe()
    .get(ns + 'DocGen_Template__c')
    .getDescribe()
    .fields.getMap();
for (
    String fieldName : new List<String>{
        'Name',
        'Category__c',
        'Type__c',
        'Output_Format__c',
        'Base_Object_API__c',
        'Query_Config__c',
        'Description__c',
        'API_Name__c',
        'Test_Record_Id__c',
        'Page_Orientation__c',
        'Page_Size__c',
        'Page_Margins__c',
        'Custom_Margins__c'
    }
) {
    // Name is standard — no namespace prefix.
    String key = (fieldName == 'Name') ? 'Name' : ns + fieldName;
    Schema.SObjectField f = fm.get(key);
    if (f == null) {
        System.debug('DIAG   ' + fieldName + ' -> FIELD NOT FOUND (schema did not upgrade)');
        continue;
    }
    Schema.DescribeFieldResult d = f.getDescribe();
    if (!d.isCreateable()) {
        System.debug('DIAG   ' + fieldName + ' -> NOT CREATEABLE  <-- would fail the insert');
    } else {
        System.debug('DIAG   ' + fieldName + ' -> ok');
    }
}

System.debug('DIAG ===== 3. LIVE INSERT (rolled back) =====');
System.debug('DIAG   running as: ' + UserInfo.getUserName() + ' / profile ' + UserInfo.getProfileId());
Savepoint sp = Database.setSavepoint();
try {
    SObject t = Schema.getGlobalDescribe().get(ns + 'DocGen_Template__c').newSObject();
    // Mirror the wizard's defaults verbatim.
    t.put('Name', 'DIAG Probe Template');
    t.put(ns + 'Type__c', 'HTML');
    t.put(ns + 'Output_Format__c', 'PDF');
    t.put(ns + 'Base_Object_API__c', 'Account');
    t.put(ns + 'Query_Config__c', 'Id, Name');
    t.put(ns + 'Category__c', '');
    t.put(ns + 'Description__c', 'Temporary diagnostic record — rolled back.');
    t.put(ns + 'API_Name__c', 'DIAG_Probe_Template');
    insert t;
    System.debug('DIAG   INSERT SUCCEEDED — Apex path is clean.');
    System.debug('DIAG   If the wizard still fails, the cause is UI API / LDS specific, not DML.');
} catch (Exception e) {
    System.debug('DIAG   INSERT FAILED');
    System.debug('DIAG   type    : ' + e.getTypeName());
    System.debug('DIAG   message : ' + e.getMessage());
    if (e instanceof DmlException) {
        DmlException de = (DmlException) e;
        for (Integer i = 0; i < de.getNumDml(); i++) {
            System.debug('DIAG   statusCode: ' + de.getDmlType(i));
            System.debug('DIAG   fields    : ' + de.getDmlFieldNames(i));
            System.debug('DIAG   detail    : ' + de.getDmlMessage(i));
        }
    }
} finally {
    Database.rollback(sp);
    System.debug('DIAG   rolled back — no record was kept.');
}
System.debug('DIAG ===== END =====');
