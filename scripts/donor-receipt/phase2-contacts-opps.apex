// Phase 2: Create 500 Contacts + 500 Opportunities for DONOR_BATCH Accounts

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

List<Account> accounts = [SELECT Id, Name FROM Account WHERE Website = 'DONOR_BATCH' ORDER BY CreatedDate, Id LIMIT 500];
System.debug('Found ' + accounts.size() + ' DONOR_BATCH accounts');

List<String> fn = new List<String>{
    'James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda',
    'David','Elizabeth','William','Barbara','Richard','Susan','Joseph','Jessica',
    'Thomas','Sarah','Charles','Karen','Christopher','Lisa','Daniel','Nancy',
    'Matthew','Betty','Anthony','Margaret','Mark','Sandra','Donald','Ashley',
    'Steven','Dorothy','Paul','Kimberly','Andrew','Emily','Joshua','Donna',
    'Kenneth','Michelle','Kevin','Carol','Brian','Amanda','George','Melissa'
};
List<String> ln = new List<String>{
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
    'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
    'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
    'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker',
    'Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill',
    'Flores','Green','Adams','Nelson','Baker','Hall','Rivera','Campbell'
};

// Contacts
List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < accounts.size(); i++) {
    String f = fn[Math.mod(i + Math.mod(i, 13), fn.size())];
    String l = ln[Math.mod(i + Math.mod(i, 7), ln.size())];
    contacts.add(new Contact(
        AccountId = accounts[i].Id,
        FirstName = f,
        LastName = l,
        Email = f.toLowerCase() + '.' + l.toLowerCase() + '.' + i + '@example.com'
    ));
}
Database.insert(contacts, dml);
System.debug('Created ' + contacts.size() + ' Contacts');

// Opportunities
List<Decimal> amts = new List<Decimal>{25,50,100,250,500,1000,2500,5000,10000,25000,50000};
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < accounts.size(); i++) {
    Decimal amt = amts[Math.mod(i, 11)] + Math.mod(i * 17, Integer.valueOf(Math.max(amts[Math.mod(i, 11)] * 0.2, 1)));
    opps.add(new Opportunity(
        Name = 'Donation - ' + accounts[i].Name.left(40),
        AccountId = accounts[i].Id,
        Amount = amt,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-Math.mod(i, 365))
    ));
}
Database.insert(opps, dml);
System.debug('Phase 2 DONE: Created ' + contacts.size() + ' Contacts + ' + opps.size() + ' Opportunities');
