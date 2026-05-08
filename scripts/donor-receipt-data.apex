// =====================================================================
// Donor Receipt Data Setup — 500 Accounts, Contacts, Opps, Images + Template
// Creates realistic nonprofit/donor data with contact images and a
// 1-page donation receipt template ready for DocGen.
// Run: sf apex run --target-org <org> -f scripts/donor-receipt-data.apex
// =====================================================================

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
String uid = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 100000));

// =====================================================================
// NAME POOLS — realistic first names, last names, and org names
// =====================================================================

List<String> firstNames = new List<String>{
    'James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda',
    'David','Elizabeth','William','Barbara','Richard','Susan','Joseph','Jessica',
    'Thomas','Sarah','Charles','Karen','Christopher','Lisa','Daniel','Nancy',
    'Matthew','Betty','Anthony','Margaret','Mark','Sandra','Donald','Ashley',
    'Steven','Dorothy','Paul','Kimberly','Andrew','Emily','Joshua','Donna',
    'Kenneth','Michelle','Kevin','Carol','Brian','Amanda','George','Melissa'
};
List<String> lastNames = new List<String>{
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
    'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
    'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
    'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker',
    'Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill',
    'Flores','Green','Adams','Nelson','Baker','Hall','Rivera','Campbell'
};

// Nonprofit / foundation / company name parts
List<String> orgPrefixes = new List<String>{
    'Pacific','Golden','Heritage','Sunrise','Evergreen','Summit','Horizon',
    'Liberty','Beacon','Pinnacle','Harmony','Coastal','Mountain','Valley',
    'Northern','Southern','Western','Eastern','Central','National',
    'United','Global','Premier','Sterling','Crestview','Lakeshore','Riverdale',
    'Oakwood','Cedarwood','Brookfield','Highland','Meadow','Prairie','Cascade',
    'Canyon','Crystal','Diamond','Emerald','Sapphire','Silver','Cedar',
    'Redwood','Sequoia','Maple','Birch','Willow','Aspen','Magnolia','Coral','Amber'
};
List<String> orgMiddles = new List<String>{
    'Community','Family','Hope','Heart','Health','Education','Arts',
    'Youth','Children','Senior','Veterans','Animal','Environmental',
    'Housing','Food','Medical','Science','Music','Cultural','Civic',
    'Literacy','Wildlife','Marine','Garden','Heritage','Faith','Grace',
    'Vision','Dream','Future','Bridge','Compass','Anchor','Shield',
    'Star','Light','Path','Way','Circle','Stone','River','Lake','Oak',
    'Rose','Sage','Terra','Nova','Vita','Luna','Sol'
};
List<String> orgSuffixes = new List<String>{
    'Foundation','Trust','Fund','Alliance','Society','Institute',
    'Association','Collective','Partners','Initiative','Network','Guild',
    'Consortium','Coalition','Council','Group','Center','Project',
    'Mission','Outreach'
};

List<String> streets = new List<String>{
    'Main St','Oak Ave','Elm St','Park Blvd','Cedar Ln','Maple Dr',
    'Pine St','Washington Ave','Lincoln Blvd','Jefferson Dr',
    'Broadway','Market St','Church St','Mill Rd','River Rd',
    'Lake Dr','Hill St','Forest Ave','Spring St','Sunset Blvd'
};
List<String> cities = new List<String>{
    'San Francisco','Los Angeles','Seattle','Portland','Denver',
    'Austin','Chicago','Boston','New York','Miami',
    'Atlanta','Dallas','Phoenix','Nashville','Minneapolis',
    'Charlotte','San Diego','Sacramento','Raleigh','Tampa'
};
List<String> states = new List<String>{
    'CA','CA','WA','OR','CO','TX','IL','MA','NY','FL',
    'GA','TX','AZ','TN','MN','NC','CA','CA','NC','FL'
};
List<String> zips = new List<String>{
    '94105','90001','98101','97201','80201','73301','60601','02101','10001','33101',
    '30301','75201','85001','37201','55401','28201','92101','95814','27601','33601'
};

// =====================================================================
// 1. CREATE 500 ACCOUNTS
// =====================================================================

List<Account> accounts = new List<Account>();
for (Integer i = 0; i < 500; i++) {
    Integer pi = Math.mod(i, orgPrefixes.size());
    Integer mi = Math.mod(i, orgMiddles.size());
    Integer si = Math.mod(i, orgSuffixes.size());
    // Rotate through combinations for unique-ish names
    // Use i/size to shift which pool index we use
    Integer piShift = Math.mod(i + Math.mod(i, 7), orgPrefixes.size());
    Integer miShift = Math.mod(i + Math.mod(i, 11), orgMiddles.size());
    Integer siShift = Math.mod(i, orgSuffixes.size());
    String orgName = orgPrefixes[piShift] + ' ' + orgMiddles[miShift] + ' ' + orgSuffixes[siShift];

    Integer ci = Math.mod(i, cities.size());
    accounts.add(new Account(
        Name = orgName,
        Phone = '(' + String.valueOf(200 + Math.mod(i, 800)).leftPad(3, '0') + ') ' +
                String.valueOf(200 + Math.mod(i * 3, 800)).leftPad(3, '0') + '-' +
                String.valueOf(1000 + Math.mod(i * 7, 9000)).leftPad(4, '0'),
        BillingStreet = String.valueOf(100 + Math.mod(i * 13, 9900)) + ' ' + streets[Math.mod(i, streets.size())],
        BillingCity = cities[ci],
        BillingState = states[ci],
        BillingPostalCode = zips[ci],
        Industry = 'Not For Profit'
    ));
}
Database.insert(accounts, dml);
System.debug('Created ' + accounts.size() + ' Accounts');

// =====================================================================
// 2. CREATE 500 CONTACTS (1 per Account)
// =====================================================================

List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < 500; i++) {
    Integer fi = Math.mod(i + Math.mod(i, 13), firstNames.size());
    Integer li = Math.mod(i + Math.mod(i, 7), lastNames.size());
    String fn = firstNames[fi];
    String ln = lastNames[li];
    contacts.add(new Contact(
        AccountId = accounts[i].Id,
        FirstName = fn,
        LastName = ln,
        Email = fn.toLowerCase() + '.' + ln.toLowerCase() + '.' + i + '@example.com'
    ));
}
Database.insert(contacts, dml);
System.debug('Created ' + contacts.size() + ' Contacts');

// =====================================================================
// 3. CREATE 500 OPPORTUNITIES (Closed Won, 1 per Account)
// =====================================================================

List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < 500; i++) {
    // Realistic donation amounts: $25 - $50,000
    List<Decimal> amounts = new List<Decimal>{
        25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000
    };
    Decimal amt = amounts[Math.mod(i, amounts.size())];
    // Add some variation
    amt = amt + Math.mod(i * 17, Integer.valueOf(Math.max(amt * 0.2, 1)));

    opps.add(new Opportunity(
        Name = 'Donation - ' + accounts[i].Name.left(40),
        AccountId = accounts[i].Id,
        Amount = amt,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-Math.mod(i, 365))
    ));
}
Database.insert(opps, dml);
System.debug('Created ' + opps.size() + ' Opportunities');

// =====================================================================
// 4. CREATE 500 OPPORTUNITY CONTACT ROLES
// =====================================================================

List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
List<String> roles = new List<String>{'Decision Maker','Influencer','Champion','Executive Sponsor','End User'};
for (Integer i = 0; i < 500; i++) {
    ocrs.add(new OpportunityContactRole(
        OpportunityId = opps[i].Id,
        ContactId = contacts[i].Id,
        Role = roles[Math.mod(i, roles.size())],
        IsPrimary = true
    ));
}
insert ocrs;
System.debug('Created ' + ocrs.size() + ' OpportunityContactRoles');

// =====================================================================
// 5. CREATE 500 CONTENT VERSIONS (donor images)
// Each contact gets a unique image stored as ContentVersion.
// The CV ID is stored in Contact.Title for {%Title} rendering.
// =====================================================================

// Small 100x100 colored PNG — minimal valid PNG
String pngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAAA40lEQVR42u3QMQEAAAgDINc/9Mzg0QSJdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dv4HAAD//9jQAQGH1FniAAAAAElFTkSuQmCC';
Blob imgBlob = EncodingUtil.base64Decode(pngB64);

List<ContentVersion> imgCvs = new List<ContentVersion>();
for (Integer i = 0; i < 500; i++) {
    imgCvs.add(new ContentVersion(
        Title = 'Donor Photo ' + contacts[i].FirstName + ' ' + contacts[i].LastName + ' ' + i,
        PathOnClient = 'donor_photo_' + i + '.png',
        VersionData = imgBlob,
        IsMajorVersion = true
    ));
}
insert imgCvs;

// Re-query to get committed IDs
imgCvs = [SELECT Id FROM ContentVersion WHERE Id IN :imgCvs ORDER BY CreatedDate, Id];
System.debug('Created ' + imgCvs.size() + ' image ContentVersions');

// Store CV ID in each Contact's Title field
for (Integer i = 0; i < 500; i++) {
    contacts[i].Title = String.valueOf(imgCvs[i].Id);
}
Database.update(contacts, dml);
System.debug('Updated ' + contacts.size() + ' Contacts with image CV IDs in Title field');

// =====================================================================
// 6. CREATE DONATION RECEIPT TEMPLATE + DOCX + VERSION
// =====================================================================

// V3 query config: Account → Contacts + Opportunities
String v3Config = '{"v":3,"root":"Account","nodes":['
    + '{"id":"n0","object":"Account","fields":["Name","BillingStreet","BillingCity","BillingState","BillingPostalCode","Phone"],"parentFields":[],"parentNode":null,"lookupField":null,"relationshipName":null},'
    + '{"id":"n1","object":"Contact","fields":["FirstName","LastName","Email","Title"],"parentFields":[],"parentNode":"n0","lookupField":"AccountId","relationshipName":"Contacts"},'
    + '{"id":"n2","object":"Opportunity","fields":["Name","Amount","CloseDate","StageName"],"parentFields":[],"parentNode":"n0","lookupField":"AccountId","relationshipName":"Opportunities"}'
    + ']}';

DocGen_Template__c tmpl = new DocGen_Template__c(
    Name = 'Donation Receipt',
    Base_Object_API__c = 'Account',
    Type__c = 'Word',
    Output_Format__c = 'PDF',
    Query_Config__c = v3Config,
    Test_Record_Id__c = accounts[0].Id
);
insert tmpl;

// Minimal DOCX with donation receipt layout (ZIP_STORED, verified roundtrip)
// Contains: {Name}, {BillingStreet}, {BillingCity}, {BillingState}, {BillingPostalCode}, {Phone}
//           {#Contacts}{FirstName} {LastName}, {Email}, {%Title}{/Contacts}
//           {#Opportunities}{Name}, {Amount}, {CloseDate}, {StageName}{/Opportunities}
//           {SUM:Opportunities.Amount:currency}
String docxB64 = ''
    + 'UEsDBBQAAAAAALyud1zXeYTquAEAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbDw/eG1sIHZlcnNpb249IjEuMCIgZW5jb2Rpbmc9IlVURi04IiBzdGFuZGFsb25lPSJ5ZXMiPz4KPFR5cGVzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5v'
    + 'cmcvcGFja2FnZS8yMDA2L2NvbnRlbnQtdHlwZXMiPgogIDxEZWZhdWx0IEV4dGVuc2lvbj0icmVscyIgQ29udGVudFR5cGU9ImFwcGxpY2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1wYWNrYWdlLnJlbGF0aW9uc2hpcHMreG1sIi8+CiAgPERlZmF1bHQgRXh0ZW5z'
    + 'aW9uPSJ4bWwiIENvbnRlbnRUeXBlPSJhcHBsaWNhdGlvbi94bWwiLz4KICA8T3ZlcnJpZGUgUGFydE5hbWU9Ii93b3JkL2RvY3VtZW50LnhtbCIgQ29udGVudFR5cGU9ImFwcGxpY2F0aW9uL3ZuZC5vcGVueG1sZm9ybWF0cy1vZmZpY2Vkb2N1bWVudC53b3JkcHJv'
    + 'Y2Vzc2luZ21sLmRvY3VtZW50Lm1haW4reG1sIi8+CjwvVHlwZXM+UEsDBBQAAAAAALyud1wgG4bqLgEAAC4BAAALAAAAX3JlbHMvLnJlbHM8P3htbCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+CjxSZWxhdGlvbnNoaXBz'
    + 'IHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvcGFja2FnZS8yMDA2L3JlbGF0aW9uc2hpcHMiPgogIDxSZWxhdGlvbnNoaXAgSWQ9InJJZDEiIFR5cGU9Imh0dHA6Ly9zY2hlbWFzLm9wZW54bWxmb3JtYXRzLm9yZy9vZmZpY2VEb2N1bWVu'
    + 'dC8yMDA2L3JlbGF0aW9uc2hpcHMvb2ZmaWNlRG9jdW1lbnQiIFRhcmdldD0id29yZC9kb2N1bWVudC54bWwiLz4KPC9SZWxhdGlvbnNoaXBzPlBLAwQUAAAAAAC8rndcjA6F0J0AAACdAAAAHAAAAHdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHM8P3htbCB2ZXJz'
    + 'aW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+CjxSZWxhdGlvbnNoaXBzIHhtbG5zPSJodHRwOi8vc2NoZW1hcy5vcGVueG1sZm9ybWF0cy5vcmcvcGFja2FnZS8yMDA2L3JlbGF0aW9uc2hpcHMiPgo8L1JlbGF0aW9uc2hpcHM+UEsD'
    + 'BBQAAAAAALyud1zUFLewQQ4AAEEOAAARAAAAd29yZC9kb2N1bWVudC54bWw8P3htbCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+Cjx3OmRvY3VtZW50IHhtbG5zOndwYz0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNv'
    + 'bS9vZmZpY2Uvd29yZC8yMDEwL3dvcmRwcm9jZXNzaW5nQ2FudmFzIgogICAgICAgICAgICB4bWxuczptYz0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL21hcmt1cC1jb21wYXRpYmlsaXR5LzIwMDYiCiAgICAgICAgICAgIHhtbG5zOm89InVybjpz'
    + 'Y2hlbWFzLW1pY3Jvc29mdC1jb206b2ZmaWNlOm9mZmljZSIKICAgICAgICAgICAgeG1sbnM6cj0iaHR0cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvcmVsYXRpb25zaGlwcyIKICAgICAgICAgICAgeG1sbnM6bT0iaHR0'
    + 'cDovL3NjaGVtYXMub3BlbnhtbGZvcm1hdHMub3JnL29mZmljZURvY3VtZW50LzIwMDYvbWF0aCIKICAgICAgICAgICAgeG1sbnM6dj0idXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTp2bWwiCiAgICAgICAgICAgIHhtbG5zOndwPSJodHRwOi8vc2NoZW1hcy5vcGVu'
    + 'eG1sZm9ybWF0cy5vcmcvZHJhd2luZ21sLzIwMDYvd29yZHByb2Nlc3NpbmdEcmF3aW5nIgogICAgICAgICAgICB4bWxuczp3MTA9InVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206b2ZmaWNlOndvcmQiCiAgICAgICAgICAgIHhtbG5zOnc9Imh0dHA6Ly9zY2hlbWFz'
    + 'Lm9wZW54bWxmb3JtYXRzLm9yZy93b3JkcHJvY2Vzc2luZ21sLzIwMDYvbWFpbiIKICAgICAgICAgICAgeG1sbnM6d25lPSJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL29mZmljZS93b3JkLzIwMDYvd29yZG1sIgogICAgICAgICAgICBtYzpJZ25vcmFibGU9'
    + 'IncxNCB3cDE0Ij4KICA8dzpib2R5PgogICAgPHc6cD48dzpwUHI+PHc6amMgdzp2YWw9ImNlbnRlciIvPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjUyIi8+PHc6c3pDcyB3OnZhbD0iNTIiLz48L3c6clByPjx3OnQ+RE9OQVRJT04gUkVD'
    + 'RUlQVDwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpwUHI+PHc6cEJkcj48dzpib3R0b20gdzp2YWw9InNpbmdsZSIgdzpzej0iNiIgdzpzcGFjZT0iMSIgdzpjb2xvcj0iMzMzMzMzIi8+PC93OnBCZHI+PC93OnBQcj48L3c6cD4KICAgIDx3OnAvPgogICAg'
    + 'PHc6cD48dzpyPjx3OnJQcj48dzpiLz48dzpzeiB3OnZhbD0iMjgiLz48dzpzekNzIHc6dmFsPSIyOCIvPjwvdzpyUHI+PHc6dD57TmFtZX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzp0PntCaWxsaW5nU3RyZWV0fTwvdzp0PjwvdzpyPjwvdzpw'
    + 'PgogICAgPHc6cD48dzpyPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+e0JpbGxpbmdDaXR5fSwge0JpbGxpbmdTdGF0ZX0ge0JpbGxpbmdQb3N0YWxDb2RlfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+e1Bob25lfTwvdzp0PjwvdzpyPjwv'
    + 'dzpwPgogICAgPHc6cC8+CiAgICA8dzpwPjx3OnBQcj48dzpwQmRyPjx3OmJvdHRvbSB3OnZhbD0ic2luZ2xlIiB3OnN6PSI0IiB3OnNwYWNlPSIxIiB3OmNvbG9yPSI5OTk5OTkiLz48L3c6cEJkcj48L3c6cFByPjx3OnI+PHc6clByPjx3OmIvPjx3OnN6IHc6dmFs'
    + 'PSIyNCIvPjx3OnN6Q3Mgdzp2YWw9IjI0Ii8+PC93OnJQcj48dzp0PkRPTk9SIElORk9STUFUSU9OPC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6dD57I0NvbnRhY3RzfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnJQcj48dzpi'
    + 'Lz48L3c6clByPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+e0ZpcnN0TmFtZX0ge0xhc3ROYW1lfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+e0VtYWlsfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnQ+eyVUaXRsZX08'
    + 'L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzp0PnsvQ29udGFjdHN9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwLz4KICAgIDx3OnA+PHc6cFByPjx3OnBCZHI+PHc6Ym90dG9tIHc6dmFsPSJzaW5nbGUiIHc6c3o9IjQiIHc6c3BhY2U9IjEiIHc6'
    + 'Y29sb3I9Ijk5OTk5OSIvPjwvdzpwQmRyPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjI0Ii8+PHc6c3pDcyB3OnZhbD0iMjQiLz48L3c6clByPjx3OnQ+RE9OQVRJT04gREVUQUlMUzwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpy'
    + 'Pjx3OnQ+eyNPcHBvcnR1bml0aWVzfTwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpyPjx3OnJQcj48dzpiLz48L3c6clByPjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+RGVzY3JpcHRpb246IDwvdzp0PjwvdzpyPjx3OnI+PHc6dD57TmFtZX08L3c6dD48'
    + 'L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzpyUHI+PHc6Yi8+PC93OnJQcj48dzp0IHhtbDpzcGFjZT0icHJlc2VydmUiPkFtb3VudDogPC93OnQ+PC93OnI+PHc6cj48dzp0PntBbW91bnR9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6clBy'
    + 'Pjx3OmIvPjwvdzpyUHI+PHc6dCB4bWw6c3BhY2U9InByZXNlcnZlIj5EYXRlOiA8L3c6dD48L3c6cj48dzpyPjx3OnQ+e0Nsb3NlRGF0ZX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnA+PHc6cj48dzpyUHI+PHc6Yi8+PC93OnJQcj48dzp0IHhtbDpzcGFjZT0i'
    + 'cHJlc2VydmUiPlN0YXR1czogPC93OnQ+PC93OnI+PHc6cj48dzp0PntTdGFnZU5hbWV9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwPjx3OnI+PHc6dD57L09wcG9ydHVuaXRpZXN9PC93OnQ+PC93OnI+PC93OnA+CiAgICA8dzpwLz4KICAgIDx3OnA+PHc6cFBy'
    + 'Pjx3OnBCZHI+PHc6dG9wIHc6dmFsPSJkb3VibGUiIHc6c3o9IjYiIHc6c3BhY2U9IjEiIHc6Y29sb3I9IjMzMzMzMyIvPjwvdzpwQmRyPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6Yi8+PHc6c3ogdzp2YWw9IjI4Ii8+PHc6c3pDcyB3OnZhbD0iMjgiLz48L3c6clBy'
    + 'Pjx3OnQgeG1sOnNwYWNlPSJwcmVzZXJ2ZSI+VG90YWwgRG9uYXRlZDoge1NVTTpPcHBvcnR1bml0aWVzLkFtb3VudDpjdXJyZW5jeX08L3c6dD48L3c6cj48L3c6cD4KICAgIDx3OnAvPgogICAgPHc6cD48dzpwUHI+PHc6amMgdzp2YWw9ImNlbnRlciIvPjwvdzpw'
    + 'UHI+PHc6cj48dzpyUHI+PHc6aS8+PHc6c3ogdzp2YWw9IjI0Ii8+PHc6c3pDcyB3OnZhbD0iMjQiLz48L3c6clByPjx3OnQ+VGhhbmsgeW91IGZvciB5b3VyIGdlbmVyb3VzIGRvbmF0aW9uITwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6cD48dzpwUHI+PHc6amMg'
    + 'dzp2YWw9ImNlbnRlciIvPjwvdzpwUHI+PHc6cj48dzpyUHI+PHc6aS8+PHc6c3ogdzp2YWw9IjE4Ii8+PHc6c3pDcyB3OnZhbD0iMTgiLz48L3c6clByPjx3OnQ+VGhpcyByZWNlaXB0IGlzIGZvciB5b3VyIHRheCByZWNvcmRzLiBQbGVhc2UgcmV0YWluIGZvciB5'
    + 'b3VyIGZpbGVzLjwvdzp0PjwvdzpyPjwvdzpwPgogICAgPHc6c2VjdFByPgogICAgICA8dzpwZ1N6IHc6dz0iMTIyNDAiIHc6aD0iMTU4NDAiLz4KICAgICAgPHc6cGdNYXIgdzp0b3A9IjE0NDAiIHc6cmlnaHQ9IjE0NDAiIHc6Ym90dG9tPSIxNDQwIiB3OmxlZnQ9'
    + 'IjE0NDAiIHc6aGVhZGVyPSI3MjAiIHc6Zm9vdGVyPSI3MjAiIHc6Z3V0dGVyPSIwIi8+CiAgICA8L3c6c2VjdFByPgogIDwvdzpib2R5Pgo8L3c6ZG9jdW1lbnQ+UEsBAhQDFAAAAAAAvK53XNd5hOq4AQAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5'
    + 'cGVzXS54bWxQSwECFAMUAAAAAAC8rndcIBuG6i4BAAAuAQAACwAAAAAAAAAAAAAAgAHpAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAAAAC8rndcjA6F0J0AAACdAAAAHAAAAAAAAAAAAAAAgAFAAwAAd29yZC9fcmVscy9kb2N1bWVudC54bWwucmVsc1BLAQIUAxQAAAAA'
    + 'ALyud1zUFLewQQ4AAEEOAAARAAAAAAAAAAAAAACAARcEAAB3b3JkL2RvY3VtZW50LnhtbFBLBQYAAAAABAAEAAMBAACHEgAAAAA=';

ContentVersion docxCv = new ContentVersion(
    Title = 'Donation Receipt Template',
    PathOnClient = 'donation_receipt.docx',
    VersionData = EncodingUtil.base64Decode(docxB64),
    IsMajorVersion = true,
    FirstPublishLocationId = tmpl.Id
);
insert docxCv;
docxCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :docxCv.Id];

DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
    Template__c = tmpl.Id,
    Content_Version_Id__c = docxCv.Id,
    Is_Active__c = true
);
insert ver;

// =====================================================================
// SUMMARY
// =====================================================================

System.debug('');
System.debug('==========================================================');
System.debug('  DONOR RECEIPT DATA SETUP COMPLETE');
System.debug('==========================================================');
System.debug('  Accounts:       ' + accounts.size());
System.debug('  Contacts:       ' + contacts.size());
System.debug('  Opportunities:  ' + opps.size());
System.debug('  Contact Roles:  ' + ocrs.size());
System.debug('  Contact Images: ' + imgCvs.size());
System.debug('  Template:       ' + tmpl.Name + ' (' + tmpl.Id + ')');
System.debug('  Template Ver:   ' + ver.Id);
System.debug('  DOCX CV:        ' + docxCv.Id);
System.debug('  Test Record:    ' + accounts[0].Name + ' (' + accounts[0].Id + ')');
System.debug('==========================================================');
System.debug('  Template uses Account as base object.');
System.debug('  Each Account has 1 Contact (with image in Title) and 1 Opportunity (Closed Won).');
System.debug('  Contacts linked to Opportunities via OpportunityContactRoles.');
System.debug('  Run from Command Hub: select "Donation Receipt" template,');
System.debug('  pick any Account, generate as PDF.');
System.debug('==========================================================');
