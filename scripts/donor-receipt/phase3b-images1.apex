// Phase 3b: Create first 250 ContentVersion images

List<Account> accounts = [SELECT Id FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate, Id LIMIT 500];
List<Contact> contacts = [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE AccountId IN :accounts ORDER BY CreatedDate, Id LIMIT 250];

String pngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAAA40lEQVR42u3QMQEAAAgDINc/9Mzg0QSJdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dv4HAAD//9jQAQGH1FniAAAAAElFTkSuQmCC';
Blob imgBlob = EncodingUtil.base64Decode(pngB64);

List<ContentVersion> cvs = new List<ContentVersion>();
for (Contact c : contacts) {
    cvs.add(new ContentVersion(
        Title = 'Donor Photo ' + c.FirstName + ' ' + c.LastName,
        PathOnClient = 'donor_' + c.Id + '.png',
        VersionData = imgBlob,
        IsMajorVersion = true
    ));
}
insert cvs;
System.debug('Phase 3b DONE: Created ' + cvs.size() + ' images (batch 1/2)');
