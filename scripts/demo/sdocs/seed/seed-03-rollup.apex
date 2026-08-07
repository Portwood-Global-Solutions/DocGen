// ============================================================================
// SDocs-replacement demo — derive Revised_Contract_Value__c.
//
// Original contract + APPROVED change orders only. Requested and rejected ones
// are deliberately excluded, which is the same rule the acceptance certificate
// applies through its `where` clause on the change-order node — so the number in
// the summary box and the rows in the table can never disagree.
//
// Re-run this after editing any change order on stage.
// ============================================================================

Map<Id, Decimal> approved = new Map<Id, Decimal>();
for (AggregateResult ar : [
    SELECT Project__c pid, SUM(Amount__c) total
    FROM Demo_Change_Order__c
    WHERE Status__c = 'Approved'
    GROUP BY Project__c
]) {
    approved.put((Id) ar.get('pid'), (Decimal) ar.get('total'));
}

List<Demo_Project__c> ups = new List<Demo_Project__c>();
for (Demo_Project__c p : [
    SELECT Id, Project_Code__c, Contract_Value__c
    FROM Demo_Project__c
    WHERE Project_Code__c LIKE 'P-2%'
]) {
    Decimal base = p.Contract_Value__c == null ? 0 : p.Contract_Value__c;
    Decimal delta = approved.containsKey(p.Id) ? approved.get(p.Id) : 0;
    p.Revised_Contract_Value__c = base + delta;
    ups.add(p);
    System.debug(
        'SEED-03 ' + p.Project_Code__c + ' base=' + base + ' approvedCO=' + delta + ' revised=' + (base + delta)
    );
}
update ups;
System.debug('SEED-03 updated=' + ups.size());
