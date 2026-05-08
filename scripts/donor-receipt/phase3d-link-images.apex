// Phase 3d: Link ContentVersion IDs to Contact.Title fields

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

List<Account> accounts = [SELECT Id FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate, Id LIMIT 500];
List<Contact> contacts = [SELECT Id, FirstName, LastName FROM Contact WHERE AccountId IN :accounts ORDER BY CreatedDate, Id];

// Find all donor photo CVs, match by Title pattern
List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE Title LIKE 'Donor Photo %' ORDER BY CreatedDate, Id];
System.debug('Found ' + contacts.size() + ' contacts and ' + cvs.size() + ' image CVs');

// Build name→CV map (use first match for each contact)
Map<String, Id> nameToCvId = new Map<String, Id>();
for (ContentVersion cv : cvs) {
    String key = cv.Title.removeStart('Donor Photo ');
    if (!nameToCvId.containsKey(key)) {
        nameToCvId.put(key, cv.Id);
    }
}

// Update contacts
Integer updated = 0;
for (Contact c : contacts) {
    String key = c.FirstName + ' ' + c.LastName;
    Id cvId = nameToCvId.get(key);
    if (cvId != null) {
        c.Title = String.valueOf(cvId);
        updated++;
        nameToCvId.remove(key); // Use each CV only once
    }
}
Database.update(contacts, dml);
System.debug('Phase 3d DONE: Linked ' + updated + ' image CV IDs to Contact.Title');
