// Phase 1: Create 500 Accounts with realistic nonprofit names
// Tag: Website = 'DONOR_BATCH' for cross-phase lookups

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

List<String> pre = new List<String>{
    'Pacific','Golden','Heritage','Sunrise','Evergreen','Summit','Horizon',
    'Liberty','Beacon','Pinnacle','Harmony','Coastal','Mountain','Valley',
    'Northern','Southern','Western','Eastern','Central','National',
    'United','Global','Premier','Sterling','Crestview','Lakeshore','Riverdale',
    'Oakwood','Cedarwood','Brookfield','Highland','Meadow','Prairie','Cascade',
    'Canyon','Crystal','Diamond','Emerald','Sapphire','Silver','Cedar',
    'Redwood','Sequoia','Maple','Birch','Willow','Aspen','Magnolia','Coral','Amber'
};
List<String> mid = new List<String>{
    'Community','Family','Hope','Heart','Health','Education','Arts',
    'Youth','Children','Senior','Veterans','Animal','Environmental',
    'Housing','Food','Medical','Science','Music','Cultural','Civic',
    'Literacy','Wildlife','Marine','Garden','Heritage','Faith','Grace',
    'Vision','Dream','Future','Bridge','Compass','Anchor','Shield',
    'Star','Light','Path','Way','Circle','Stone','River','Lake','Oak',
    'Rose','Sage','Terra','Nova','Vita','Luna','Sol'
};
List<String> suf = new List<String>{
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

List<Account> accounts = new List<Account>();
for (Integer i = 0; i < 500; i++) {
    Integer ci = Math.mod(i, 20);
    accounts.add(new Account(
        Name = pre[Math.mod(i + Math.mod(i, 7), 50)] + ' ' + mid[Math.mod(i + Math.mod(i, 11), 50)] + ' ' + suf[Math.mod(i, 20)],
        Phone = '(' + String.valueOf(200 + Math.mod(i, 800)) + ') ' + String.valueOf(200 + Math.mod(i * 3, 800)) + '-' + String.valueOf(1000 + Math.mod(i * 7, 9000)),
        BillingStreet = String.valueOf(100 + Math.mod(i * 13, 9900)) + ' ' + streets[Math.mod(i, 20)],
        BillingCity = cities[ci],
        BillingState = states[ci],
        BillingPostalCode = zips[ci],
        Industry = 'Not For Profit',
        Website = 'DONOR_BATCH'
    ));
}
Database.insert(accounts, dml);
System.debug('Phase 1 DONE: Created ' + accounts.size() + ' Accounts');
