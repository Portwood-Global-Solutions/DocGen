// Phase 3a: Create OpportunityContactRoles

List<Account> accounts = [SELECT Id FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate, Id LIMIT 500];
Map<Id, Contact> accToContact = new Map<Id, Contact>();
for (Contact c : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accounts]) {
    accToContact.put(c.AccountId, c);
}
Map<Id, Opportunity> accToOpp = new Map<Id, Opportunity>();
for (Opportunity o : [SELECT Id, AccountId FROM Opportunity WHERE AccountId IN :accounts AND StageName = 'Closed Won']) {
    accToOpp.put(o.AccountId, o);
}

List<String> roles = new List<String>{'Decision Maker','Influencer','Champion','Executive Sponsor','End User'};
List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
Integer idx = 0;
for (Account a : accounts) {
    Contact c = accToContact.get(a.Id);
    Opportunity o = accToOpp.get(a.Id);
    if (c != null && o != null) {
        ocrs.add(new OpportunityContactRole(
            OpportunityId = o.Id, ContactId = c.Id,
            Role = roles[Math.mod(idx, 5)], IsPrimary = true
        ));
    }
    idx++;
}
insert ocrs;
System.debug('Phase 3a DONE: Created ' + ocrs.size() + ' OpportunityContactRoles');
