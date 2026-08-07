// ============================================================================
// SDocs-replacement demo — give the two templates stable API Names.
//
// The Flow references its template by API_Name__c, not by record Id. That is
// the whole point: a record Id is different in every org, so a Flow built in a
// sandbox breaks the moment it is deployed to production. An API Name survives
// the move, which matters a great deal to a team replacing a tool whose
// automation broke on every refresh.
//
// The installer does not set this field, so it is stamped here.
// ============================================================================

Map<String, String> apiNames = new Map<String, String>{
    'Project Approval Request' => 'Project_Approval_Request',
    'Project Acceptance Certificate' => 'Project_Acceptance_Certificate'
};

List<portwoodglobal__DocGen_Template__c> ups = new List<portwoodglobal__DocGen_Template__c>();
for (portwoodglobal__DocGen_Template__c t : [
    SELECT Id, Name, portwoodglobal__API_Name__c
    FROM portwoodglobal__DocGen_Template__c
    WHERE Name IN :apiNames.keySet()
]) {
    t.portwoodglobal__API_Name__c = apiNames.get(t.Name);
    ups.add(t);
    System.debug('SEED-04 ' + t.Name + ' -> API_Name=' + apiNames.get(t.Name) + ' (' + t.Id + ')');
}
update ups;
System.debug('SEED-04 stamped=' + ups.size());
