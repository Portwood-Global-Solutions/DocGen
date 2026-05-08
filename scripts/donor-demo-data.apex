// =====================================================================
// Donor Demo — 500 Accounts + 500 Closed Won Opportunities + Template
// Non-profit donation receipt demo for Compass Community Foundation
// Run: sf apex run --target-org pdf-merger-test -f scripts/donor-demo-data.apex
// =====================================================================

System.debug('=== Donor Demo Data Setup ===');

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

// =====================================================================
// 1. NAME POOLS — realistic diverse donor names
// =====================================================================

List<String> firstNames = new List<String>{
    'James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda',
    'David','Elizabeth','William','Barbara','Richard','Susan','Joseph','Jessica',
    'Thomas','Sarah','Charles','Karen','Christopher','Lisa','Daniel','Nancy',
    'Matthew','Betty','Anthony','Margaret','Mark','Sandra','Donald','Ashley',
    'Steven','Kimberly','Paul','Emily','Andrew','Donna','Joshua','Michelle',
    'Kenneth','Carol','Kevin','Amanda','Brian','Dorothy','George','Melissa',
    'Timothy','Deborah','Ronald','Stephanie','Edward','Rebecca','Jason','Sharon',
    'Jeffrey','Laura','Ryan','Cynthia','Jacob','Kathleen','Gary','Amy',
    'Nicholas','Angela','Eric','Shirley','Jonathan','Anna','Stephen','Brenda',
    'Larry','Pamela','Justin','Emma','Scott','Nicole','Brandon','Helen',
    'Benjamin','Samantha','Samuel','Katherine','Raymond','Christine','Gregory','Debra',
    'Frank','Rachel','Alexander','Carolyn','Patrick','Janet','Jack','Catherine',
    'Dennis','Maria','Jerry','Heather','Tyler','Diane','Aaron','Ruth',
    'Jose','Julie','Adam','Olivia','Nathan','Joyce','Henry','Virginia',
    'Douglas','Victoria','Zachary','Kelly','Peter','Lauren','Kyle','Christina',
    'Alejandro','Priya','Hiroshi','Fatima','Wei','Olga','Raj','Ingrid',
    'Omar','Yuki','Carlos','Mei','Dmitri','Aisha','Sanjay','Freya',
    'Ibrahim','Lena','Takeshi','Camille','Pavel','Lucia','Ravi','Astrid',
    'Hassan','Bianca','Kenji','Elena','Mateo','Nadia','Arjun','Svetlana',
    'Chen','Amara','Koji','Isla','Vikram','Maren','Tariq','Sofia'
};

List<String> lastNames = new List<String>{
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
    'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas',
    'Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson','White',
    'Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker','Young',
    'Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores',
    'Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell',
    'Carter','Roberts','Gomez','Phillips','Evans','Turner','Diaz','Parker',
    'Cruz','Edwards','Collins','Reyes','Stewart','Morris','Morales','Murphy',
    'Cook','Rogers','Gutierrez','Ortiz','Morgan','Cooper','Peterson','Bailey',
    'Reed','Kelly','Howard','Ramos','Kim','Cox','Ward','Richardson',
    'Watson','Brooks','Chavez','Wood','James','Bennett','Gray','Mendoza',
    'Ruiz','Hughes','Price','Alvarez','Castillo','Sanders','Patel','Myers',
    'Long','Ross','Foster','Jimenez','Powell','Jenkins','Perry','Russell',
    'Sullivan','Bell','Coleman','Butler','Henderson','Barnes','Gonzales','Fisher',
    'Vasquez','Simmons','Griffin','McDaniel','Nakamura','Johansson','Müller','O\'Brien',
    'Tanaka','Petrova','Sharma','Lindgren','Dubois','Kowalski','Yamamoto','Eriksson',
    'Fernandez','Volkov','Gupta','Andersen','Moreau','Novak','Takahashi','Bergström',
    'Romero','Kuznetsov','Mehta','Larsson','Laurent','Horvat','Watanabe','Olsson'
};

List<String> streets = new List<String>{
    '100 Main St','245 Oak Ave','789 Elm Dr','1200 Park Blvd','55 Cedar Ln',
    '330 Maple Way','412 Pine St','678 Birch Rd','901 Walnut Ave','150 Spruce Ct',
    '2100 Lake Dr','88 River Rd','1650 Hill St','420 Valley Way','3300 Forest Ave',
    '777 Harbor Blvd','1800 Ocean Dr','225 Mountain Rd','500 Sunrise Ln','915 Sunset Blvd',
    '1100 Broadway','640 Commerce St','1475 Garden Way','280 College Ave','3600 Church St',
    '445 Liberty Ave','720 Franklin St','1350 Washington Blvd','2200 Jefferson Dr','160 Lincoln Way'
};

List<String> cities = new List<String>{
    'San Francisco','Los Angeles','Chicago','Houston','Phoenix','Philadelphia',
    'San Antonio','San Diego','Dallas','Austin','Jacksonville','Fort Worth',
    'Columbus','Charlotte','Indianapolis','Seattle','Denver','Boston',
    'Nashville','Portland','Las Vegas','Memphis','Louisville','Baltimore',
    'Milwaukee','Albuquerque','Tucson','Fresno','Sacramento','Mesa',
    'Atlanta','Omaha','Raleigh','Miami','Minneapolis','Tampa',
    'New Orleans','Cleveland','Honolulu','Anchorage'
};

List<String> states = new List<String>{
    'CA','CA','IL','TX','AZ','PA',
    'TX','CA','TX','TX','FL','TX',
    'OH','NC','IN','WA','CO','MA',
    'TN','OR','NV','TN','KY','MD',
    'WI','NM','AZ','CA','CA','AZ',
    'GA','NE','NC','FL','MN','FL',
    'LA','OH','HI','AK'
};

// =====================================================================
// 2. CREATE 500 ACCOUNTS
// =====================================================================

List<Account> accounts = new List<Account>();
Set<String> usedNames = new Set<String>();

Integer fSize = firstNames.size();
Integer lSize = lastNames.size();
Integer sSize = streets.size();
Integer cSize = cities.size();

for (Integer i = 0; i < 500; i++) {
    // Generate unique name combination
    String fName = firstNames[Math.mod(i, fSize)];
    String lName = lastNames[Math.mod(i / 3 + i, lSize)];
    String fullName = fName + ' ' + lName;

    // Ensure uniqueness by appending suffix if needed
    if (usedNames.contains(fullName)) {
        fullName = fName + ' ' + String.valueOf(Math.mod(i, 9) + 1).trim() + '. ' + lName;
    }
    if (usedNames.contains(fullName)) {
        fullName += ' ' + String.valueOf(i);
    }
    usedNames.add(fullName);

    Integer cityIdx = Math.mod(i, cSize);
    String zip = String.valueOf(10001 + Math.mod(i * 197, 89999)).leftPad(5, '0');

    accounts.add(new Account(
        Name = fullName,
        BillingStreet = streets[Math.mod(i, sSize)],
        BillingCity = cities[cityIdx],
        BillingState = states[cityIdx],
        BillingPostalCode = zip
    ));
}
Database.insert(accounts, dml);
System.debug('Inserted ' + accounts.size() + ' Accounts');

// =====================================================================
// 3. CREATE 500 CLOSED WON OPPORTUNITIES (varying amounts)
// =====================================================================

List<Opportunity> opps = new List<Opportunity>();

// Realistic donation amount distribution:
// 60% small ($25-$500), 25% medium ($500-$5,000), 10% large ($5,000-$25,000), 5% major ($25,000-$100,000)
List<Decimal> amounts = new List<Decimal>();
for (Integer i = 0; i < 500; i++) {
    Decimal amt;
    Integer bucket = Math.mod(i * 7 + i / 3, 100);
    if (bucket < 60) {
        // Small: $25 - $500
        amt = 25 + Math.mod(i * 31 + 7, 476);
    } else if (bucket < 85) {
        // Medium: $500 - $5,000
        amt = 500 + Math.mod(i * 47 + 13, 4501);
    } else if (bucket < 95) {
        // Large: $5,000 - $25,000
        amt = 5000 + Math.mod(i * 73 + 29, 20001);
    } else {
        // Major: $25,000 - $100,000
        amt = 25000 + Math.mod(i * 97 + 41, 75001);
    }
    amounts.add(amt);
}

// Spread close dates across the last 12 months
Date baseDate = Date.today();

for (Integer i = 0; i < 500; i++) {
    Integer daysBack = Math.mod(i * 3 + i / 5, 365);
    Date closeDate = baseDate.addDays(-daysBack);

    opps.add(new Opportunity(
        Name = 'Donation - ' + accounts[i].Name,
        AccountId = accounts[i].Id,
        Amount = amounts[i],
        StageName = 'Closed Won',
        CloseDate = closeDate
    ));
}
Database.insert(opps, dml);
System.debug('Inserted ' + opps.size() + ' Opportunities');

// =====================================================================
// 3b. CREATE 500 CONTACTS (one per Account — the donor contact)
// =====================================================================

List<String> emailDomains = new List<String>{
    'gmail.com','yahoo.com','outlook.com','icloud.com','hotmail.com',
    'aol.com','protonmail.com','mail.com','zoho.com','fastmail.com'
};

List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < 500; i++) {
    // Use different name indices than Account to get a realistic contact name
    String cFirst = firstNames[Math.mod(i * 3 + 7, fSize)];
    String cLast = lastNames[Math.mod(i * 2 + 11, lSize)];
    // But for ~60% of donors, contact last name matches the account last name (family donor)
    if (Math.mod(i, 5) < 3) {
        // Extract last name from account name (format: "FirstName LastName")
        String accName = accounts[i].Name;
        Integer spaceIdx = accName.lastIndexOf(' ');
        if (spaceIdx > 0) {
            cLast = accName.substring(spaceIdx + 1);
        }
    }
    String domain = emailDomains[Math.mod(i, emailDomains.size())];
    String emailLocal = cFirst.toLowerCase() + '.' + cLast.toLowerCase().replaceAll('[^a-z]', '') + Math.mod(i, 99);

    contacts.add(new Contact(
        AccountId = accounts[i].Id,
        FirstName = cFirst,
        LastName = cLast,
        Email = emailLocal + '@' + domain,
        Phone = '(' + String.valueOf(200 + Math.mod(i, 800)).leftPad(3, '0') + ') ' +
                String.valueOf(200 + Math.mod(i * 7, 800)).leftPad(3, '0') + '-' +
                String.valueOf(1000 + Math.mod(i * 13, 9000)).leftPad(4, '0'),
        Title = (Math.mod(i, 4) == 0 ? 'Executive Director' :
                 Math.mod(i, 4) == 1 ? 'President' :
                 Math.mod(i, 4) == 2 ? 'Philanthropist' : 'Board Member')
    ));
}
Database.insert(contacts, dml);
System.debug('Inserted ' + contacts.size() + ' Contacts');

// =====================================================================
// 3c. CREATE 500 OPPORTUNITY CONTACT ROLES (link Contact → Opp)
// =====================================================================

List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
for (Integer i = 0; i < 500; i++) {
    ocrs.add(new OpportunityContactRole(
        OpportunityId = opps[i].Id,
        ContactId = contacts[i].Id,
        Role = 'Decision Maker',
        IsPrimary = true
    ));
}
Database.insert(ocrs, dml);
System.debug('Inserted ' + ocrs.size() + ' OpportunityContactRoles');

// =====================================================================
// 4. CREATE DOCX TEMPLATE + DOCGEN TEMPLATE RECORD
// =====================================================================

// V3 query config: Opportunity with Account parent fields
String v3Config = '{"v":3,"root":"Opportunity","nodes":[' +
    '{"id":"n0","object":"Opportunity",' +
    '"fields":["Name","Amount","CloseDate","StageName"],' +
    '"parentFields":["Account.Name","Account.BillingStreet","Account.BillingCity","Account.BillingState","Account.BillingPostalCode"],' +
    '"parentNode":null,"lookupField":null,"relationshipName":null}' +
    ']}';

DocGen_Template__c tmpl = new DocGen_Template__c(
    Name = 'Donor Thank You Letter',
    Base_Object_API__c = 'Opportunity',
    Type__c = 'Word',
    Output_Format__c = 'PDF',
    Query_Config__c = v3Config,
    Test_Record_Id__c = opps[0].Id,
    Description__c = 'Official donation receipt and thank-you letter for Compass Community Foundation donors.'
);
insert tmpl;

// Donor thank-you letter DOCX template
String docxB64 = ''
    + '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';

ContentVersion docxCv = new ContentVersion(
    Title = 'Donor Thank You Letter Template',
    PathOnClient = 'Donor_Thank_You_Letter.docx',
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
// 5. SUMMARY
// =====================================================================

// Quick stats on amounts
Decimal totalDonations = 0;
Decimal minAmt = amounts[0];
Decimal maxAmt = amounts[0];
for (Decimal a : amounts) {
    totalDonations += a;
    if (a < minAmt) minAmt = a;
    if (a > maxAmt) maxAmt = a;
}

System.debug('');
System.debug('============================================');
System.debug('   DONOR DEMO DATA — SETUP COMPLETE');
System.debug('============================================');
System.debug('');
System.debug('Accounts:       ' + accounts.size());
System.debug('Contacts:       ' + contacts.size() + ' (1 per Account)');
System.debug('Contact Roles:  ' + ocrs.size() + ' (1 per Opp, Decision Maker, Primary)');
System.debug('Opportunities:  ' + opps.size() + ' (all Closed Won)');
System.debug('');
System.debug('Donation Range: $' + minAmt.setScale(0) + ' — $' + maxAmt.setScale(0));
System.debug('Total Donated:  $' + totalDonations.format());
System.debug('Average Gift:   $' + (totalDonations / 500).setScale(2));
System.debug('');
System.debug('Template:       ' + tmpl.Id + ' (' + tmpl.Name + ')');
System.debug('Version:        ' + ver.Id);
System.debug('DOCX CV:        ' + docxCv.Id);
System.debug('Test Record:    ' + opps[0].Id + ' (' + opps[0].Name + ')');
System.debug('');
System.debug('Base Object:    Opportunity');
System.debug('Output Format:  PDF');
System.debug('');
System.debug('To generate: Open any Opportunity → DocGen → Select "Donor Thank You Letter"');
System.debug('For bulk:    DocGen Command Hub → Bulk Generate → Select template + list view');
System.debug('============================================');
