// Phase 3: Create OpportunityContactRoles + ContentVersion images + update Contact.Title

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

List<Account> accounts = [SELECT Id FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate, Id LIMIT 500];
// Get contacts and opps in matching order
List<Contact> contacts = [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE AccountId IN :accounts ORDER BY AccountId, Id];
List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE AccountId IN :accounts AND StageName = 'Closed Won' ORDER BY AccountId, Id];

System.debug('Found: ' + accounts.size() + ' accounts, ' + contacts.size() + ' contacts, ' + opps.size() + ' opps');

// Build Account→Contact and Account→Opp maps
Map<Id, Contact> accToContact = new Map<Id, Contact>();
for (Contact c : contacts) { accToContact.put(c.AccountId, c); }
Map<Id, Opportunity> accToOpp = new Map<Id, Opportunity>();
for (Opportunity o : opps) { accToOpp.put(o.AccountId, o); }

// OpportunityContactRoles
List<String> roles = new List<String>{'Decision Maker','Influencer','Champion','Executive Sponsor','End User'};
List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
Integer idx = 0;
for (Account a : accounts) {
    Contact c = accToContact.get(a.Id);
    Opportunity o = accToOpp.get(a.Id);
    if (c != null && o != null) {
        ocrs.add(new OpportunityContactRole(
            OpportunityId = o.Id,
            ContactId = c.Id,
            Role = roles[Math.mod(idx, 5)],
            IsPrimary = true
        ));
    }
    idx++;
}
insert ocrs;
System.debug('Created ' + ocrs.size() + ' OpportunityContactRoles');

// ContentVersion images (small 100x100 PNG)
String pngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAAA40lEQVR42u3QMQEAAAgDINc/9Mzg0QSJdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dv4HAAD//9jQAQGH1FniAAAAAElFTkSuQmCC';
Blob imgBlob = EncodingUtil.base64Decode(pngB64);

List<ContentVersion> imgCvs = new List<ContentVersion>();
List<Contact> orderedContacts = new List<Contact>();
for (Account a : accounts) {
    Contact c = accToContact.get(a.Id);
    if (c != null) {
        orderedContacts.add(c);
        imgCvs.add(new ContentVersion(
            Title = 'Donor Photo ' + c.FirstName + ' ' + c.LastName,
            PathOnClient = 'donor_photo_' + c.Id + '.png',
            VersionData = imgBlob,
            IsMajorVersion = true
        ));
    }
}
insert imgCvs;

// Re-query to get committed IDs (insertion order preserved)
imgCvs = [SELECT Id FROM ContentVersion WHERE Id IN :imgCvs ORDER BY CreatedDate, Id];
System.debug('Created ' + imgCvs.size() + ' image ContentVersions');

// Store CV ID in Contact.Title
for (Integer i = 0; i < orderedContacts.size(); i++) {
    orderedContacts[i].Title = String.valueOf(imgCvs[i].Id);
}
Database.update(orderedContacts, dml);
System.debug('Phase 3 DONE: ' + ocrs.size() + ' OCRs + ' + imgCvs.size() + ' images assigned to Contact.Title');
