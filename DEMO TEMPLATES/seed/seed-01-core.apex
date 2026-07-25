// ============================================================================
// Portwood DocGen DEMO — Seed 01: Core standard-object data
//   Accounts, Contacts, Opportunities (B2B pipeline + nonprofit donations),
//   Product catalog (Product2 + Pricebook2 + entries), Orders + OrderItems.
// Idempotent: deletes prior demo records (marker = [DOCGEN-DEMO]) then re-inserts.
// Bare API names (these are standard / org-default-namespace objects).
// Run: sf apex run --target-org dave@portwood.dev.demo -f "DEMO TEMPLATES/seed/seed-01-core.apex"
// ============================================================================
String MARK = '[DOCGEN-DEMO]'; // human-readable marker stored in Description (note: Description is not SOQL-filterable)
Set<String> DEMO_ACCT_NAMES = new Set<String>{
    'Northwind Traders', 'Summit Components Inc.', 'Rivers Alliance Foundation'
};

// ---- 0. Cleanup prior demo data (children first) ----
List<Account> oldAccts = [SELECT Id FROM Account WHERE Name IN :DEMO_ACCT_NAMES];
if (!oldAccts.isEmpty()) {
    Set<Id> acctIds = (new Map<Id, Account>(oldAccts)).keySet();
    delete [SELECT Id FROM Opportunity WHERE AccountId IN :acctIds]; // cascades OpportunityLineItems
    delete [SELECT Id FROM Contact WHERE AccountId IN :acctIds];
    delete oldAccts;
}
delete [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode LIKE 'PWG-%' AND Pricebook2.IsStandard = false];
delete [SELECT Id FROM Pricebook2 WHERE Name = 'Portwood 2026 Wholesale Catalog'];
delete [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode LIKE 'PWG-%'];
delete [SELECT Id FROM Product2 WHERE ProductCode LIKE 'PWG-%'];

// ---- 1. Product catalog ----
// {name, code, family, price, uom, description}
List<List<Object>> prodDefs = new List<List<Object>>{
    new List<Object>{'Hex Bolt M10 x 50mm Grade 8.8','PWG-1001','Fasteners',0.42,'Each','Zinc-plated structural hex bolt, metric coarse thread.'},
    new List<Object>{'Hex Nut M10 Grade 8','PWG-1002','Fasteners',0.11,'Each','Zinc-plated finished hex nut, metric coarse thread.'},
    new List<Object>{'Flat Washer M10 Stainless','PWG-1003','Fasteners',0.07,'Each','304 stainless flat washer.'},
    new List<Object>{'Socket Head Cap Screw M8 x 30','PWG-1004','Fasteners',0.58,'Each','Black oxide alloy steel SHCS.'},
    new List<Object>{'Self-Tapping Screw #8 x 1in','PWG-1005','Fasteners',0.05,'Box of 100','Phillips pan head, zinc.'},
    new List<Object>{'Industrial Ball Bearing 6204-2RS','PWG-2001','Bearings',6.85,'Each','Sealed deep-groove ball bearing, 20mm bore.'},
    new List<Object>{'Tapered Roller Bearing 30205','PWG-2002','Bearings',12.40,'Each','Single-row tapered roller bearing.'},
    new List<Object>{'Linear Bearing LM12UU','PWG-2003','Bearings',3.95,'Each','12mm linear motion ball bearing.'},
    new List<Object>{'V-Belt A42 Wrapped','PWG-3001','Power Transmission',7.20,'Each','Classical wrapped V-belt, 42in.'},
    new List<Object>{'Roller Chain #40 10ft','PWG-3002','Power Transmission',18.50,'Box','ANSI #40 single-strand roller chain.'},
    new List<Object>{'Timing Pulley 20T GT2','PWG-3003','Power Transmission',4.10,'Each','Aluminium 20-tooth GT2 pulley, 5mm bore.'},
    new List<Object>{'Spur Gear 1.0 Module 40T','PWG-3004','Power Transmission',9.75,'Each','Steel spur gear, 1.0 module, 40 teeth.'},
    new List<Object>{'NEMA 23 Stepper Motor','PWG-4001','Electrical',16.90,'Each','1.9 Nm bipolar stepper, 4-wire.'},
    new List<Object>{'24V DC Power Supply 10A','PWG-4002','Electrical',34.00,'Each','DIN-rail switching PSU, 240W.'},
    new List<Object>{'Cat6 Ethernet Cable 50ft','PWG-4003','Electrical',11.25,'Each','Shielded Cat6 patch cable.'},
    new List<Object>{'Industrial Relay 24VDC DPDT','PWG-4004','Electrical',5.40,'Each','Plug-in relay with LED indicator.'},
    new List<Object>{'Terminal Block 12-Position','PWG-4005','Electrical',2.80,'Each','Screw terminal barrier strip, 30A.'},
    new List<Object>{'Safety Glasses Clear (12pk)','PWG-5001','Safety',18.00,'Pack','ANSI Z87.1 anti-fog safety glasses.'},
    new List<Object>{'Nitrile Gloves L (box 100)','PWG-5002','Safety',9.50,'Box','5-mil powder-free nitrile gloves.'},
    new List<Object>{'Hi-Vis Safety Vest Class 2','PWG-5003','Safety',7.95,'Each','Mesh hi-visibility vest, reflective tape.'},
    new List<Object>{'Hard Hat Type 1 White','PWG-5004','Safety',12.30,'Each','4-point ratchet suspension hard hat.'},
    new List<Object>{'Ear Plugs Foam (200 pair)','PWG-5005','Safety',22.00,'Box','NRR 32dB disposable foam ear plugs.'},
    new List<Object>{'Cordless Drill 20V Brushless','PWG-6001','Tools',79.00,'Each','1/2in brushless drill/driver, bare tool.'},
    new List<Object>{'Impact Driver 20V','PWG-6002','Tools',69.00,'Each','1/4in hex impact driver, bare tool.'},
    new List<Object>{'Digital Caliper 6in','PWG-6003','Tools',24.50,'Each','Stainless digital caliper, 0.01mm.'},
    new List<Object>{'Torque Wrench 1/2in 30-250 ft-lb','PWG-6004','Tools',41.00,'Each','Click-type torque wrench with case.'},
    new List<Object>{'Socket Set 40pc Metric','PWG-6005','Tools',38.00,'Each','1/4 and 3/8 drive socket set.'},
    new List<Object>{'Tape Measure 25ft','PWG-6006','Tools',9.99,'Each','Magnetic hook tape measure.'},
    new List<Object>{'Cutting Fluid 1 Gallon','PWG-7001','Consumables',16.75,'Each','Semi-synthetic metalworking coolant.'},
    new List<Object>{'Threadlocker Blue 50ml','PWG-7002','Consumables',8.40,'Each','Medium-strength removable threadlocker.'},
    new List<Object>{'Shop Towels (Roll)','PWG-7003','Consumables',4.25,'Each','Heavy-duty blue shop towel roll.'},
    new List<Object>{'Aluminium Sheet 12x12 .063','PWG-8001','Raw Materials',6.10,'Each','5052 aluminium sheet.'},
    new List<Object>{'Steel Round Bar 1in x 36in','PWG-8002','Raw Materials',11.80,'Each','1018 cold-rolled steel round bar.'},
    new List<Object>{'Acrylic Sheet 12x24 1/4in','PWG-8003','Raw Materials',14.60,'Each','Clear cast acrylic sheet.'},
    new List<Object>{'PVC Pipe 2in x 10ft Sch 40','PWG-8004','Raw Materials',8.90,'Each','Schedule 40 PVC pipe.'},
    new List<Object>{'Welding Wire ER70S-6 .035 33lb','PWG-9001','Welding',58.00,'Spool','Mild steel MIG welding wire.'},
    new List<Object>{'Tungsten Electrode 2% 3/32 (10pk)','PWG-9002','Welding',24.00,'Pack','Ceriated TIG tungsten electrodes.'},
    new List<Object>{'Welding Helmet Auto-Darkening','PWG-9003','Welding',64.00,'Each','Variable shade 9-13 ADF helmet.'},
    new List<Object>{'Anti-Spatter Spray 16oz','PWG-9004','Welding',7.30,'Each','Non-flammable weld anti-spatter.'}
};

List<Product2> prods = new List<Product2>();
for (List<Object> d : prodDefs) {
    prods.add(new Product2(
        Name = (String) d[0], ProductCode = (String) d[1], Family = (String) d[2],
        Description = (String) d[5], QuantityUnitOfMeasure = (String) d[4],
        IsActive = true
    ));
}
insert prods;

Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
Pricebook2 catalog = new Pricebook2(Name = 'Portwood 2026 Wholesale Catalog', IsActive = true,
    Description = MARK + ' Manufacturing demo catalog');
insert catalog;

List<PricebookEntry> stdPbe = new List<PricebookEntry>();
for (Integer i = 0; i < prods.size(); i++) {
    stdPbe.add(new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = prods[i].Id,
        UnitPrice = (Decimal) prodDefs[i][3], IsActive = true));
}
insert stdPbe;
List<PricebookEntry> catPbe = new List<PricebookEntry>();
for (Integer i = 0; i < prods.size(); i++) {
    catPbe.add(new PricebookEntry(Pricebook2Id = catalog.Id, Product2Id = prods[i].Id,
        UnitPrice = (Decimal) prodDefs[i][3], IsActive = true));
}
insert catPbe;
Map<Id, PricebookEntry> stdPbeByProd = new Map<Id, PricebookEntry>();
for (PricebookEntry pe : stdPbe) stdPbeByProd.put(pe.Product2Id, pe);

// ---- 2. Accounts + Contacts ----
Account northwind = new Account(Name='Northwind Traders', Industry='Manufacturing',
    AnnualRevenue=48000000, Phone='(617) 555-0142', Website='www.northwindtraders.com',
    BillingStreet='240 Commerce Way', BillingCity='Cambridge', BillingState='MA',
    BillingPostalCode='02142', BillingCountry='USA', Description=MARK + ' B2B hero account');
Account summit = new Account(Name='Summit Components Inc.', Industry='Manufacturing',
    AnnualRevenue=12500000, Phone='(312) 555-0190', Website='www.summitcomponents.com',
    BillingStreet='1100 Industrial Pkwy', BillingCity='Chicago', BillingState='IL',
    BillingPostalCode='60607', BillingCountry='USA', Description=MARK + ' B2B account');
Account rivers = new Account(Name='Rivers Alliance Foundation', Industry='Nonprofit',
    Phone='(503) 555-0177', Website='www.riversalliance.org',
    BillingStreet='88 Waterfront Dr', BillingCity='Portland', BillingState='OR',
    BillingPostalCode='97204', BillingCountry='USA', Description=MARK + ' Nonprofit account');
insert new List<Account>{northwind, summit, rivers};

List<Contact> cons = new List<Contact>{
    new Contact(FirstName='Dana', LastName='Whitfield', AccountId=northwind.Id, Title='VP of Operations',
        Email='dana.whitfield@northwindtraders.com', Phone='(617) 555-0143'),
    new Contact(FirstName='Marcus', LastName='Reyes', AccountId=northwind.Id, Title='Procurement Manager',
        Email='marcus.reyes@northwindtraders.com', Phone='(617) 555-0144'),
    new Contact(FirstName='Priya', LastName='Anand', AccountId=summit.Id, Title='CFO',
        Email='priya.anand@summitcomponents.com', Phone='(312) 555-0191'),
    new Contact(FirstName='Evelyn', LastName='Brooks', AccountId=rivers.Id, Title='Development Director',
        Email='evelyn.brooks@riversalliance.org', Phone='(503) 555-0178')
};
insert cons;

// ---- 3. Opportunities (B2B pipeline for charts + nonprofit donations) ----
Date today = Date.today();
// opps[0] is the invoice/quote hero — carries OpportunityLineItems below (needs a pricebook).
List<Opportunity> opps = new List<Opportunity>{
    new Opportunity(Name='Northwind — Annual Supply Agreement', AccountId=northwind.Id,
        StageName='Proposal/Price Quote', CloseDate=today.addDays(40), Pricebook2Id=stdPbId,
        Type='New Business', Description=MARK),
    new Opportunity(Name='Northwind — Automation Upgrade', AccountId=northwind.Id,
        Amount=92000, StageName='Negotiation/Review', CloseDate=today.addDays(20), Type='Upsell', Description=MARK),
    new Opportunity(Name='Northwind — Safety Equipment Refresh', AccountId=northwind.Id,
        Amount=27500, StageName='Closed Won', CloseDate=today.addDays(-10), Type='Existing Business', Description=MARK),
    new Opportunity(Name='Northwind — Tooling Expansion', AccountId=northwind.Id,
        Amount=64000, StageName='Qualification', CloseDate=today.addDays(75), Type='New Business', Description=MARK),
    new Opportunity(Name='Summit — Bearings Bulk Order', AccountId=summit.Id,
        Amount=43000, StageName='Closed Won', CloseDate=today.addDays(-25), Type='New Business', Description=MARK)
};
// Nonprofit donations (modeled as Opportunities) for impact report + receipt
String[] funds = new String[]{'River Restoration Fund','Clean Water Program','Education Outreach','General Fund','River Restoration Fund','Clean Water Program'};
Decimal[] gifts = new Decimal[]{2500,1000,500,250,5000,750};
for (Integer i = 0; i < funds.size(); i++) {
    opps.add(new Opportunity(Name='Donation — ' + funds[i] + ' #' + (1001+i), AccountId=rivers.Id,
        Amount=gifts[i], StageName='Closed Won', CloseDate=today.addDays(-(5+i*7)),
        Type='Donation', Designation__c=funds[i], Description=MARK + ' ' + funds[i]));
}
insert opps;

// ---- 4. OpportunityLineItems on the invoice hero opp (invoice / packing slip) ----
Opportunity invoiceOpp = opps[0];
Integer[] lineIdx = new Integer[]{0,1,2,5,8,12,17,22,27,34};
Integer[] qtys    = new Integer[]{500,500,500,40,12,4,6,2,3,1};
List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
for (Integer i = 0; i < lineIdx.size(); i++) {
    Product2 p = prods[lineIdx[i]];
    PricebookEntry pe = stdPbeByProd.get(p.Id);
    olis.add(new OpportunityLineItem(OpportunityId=invoiceOpp.Id, PricebookEntryId=pe.Id,
        Quantity=qtys[i], UnitPrice=pe.UnitPrice, Description=p.Name));
}
insert olis;

System.debug('SEED-01 CORE DONE');
System.debug('Northwind Account: ' + northwind.Id);
System.debug('Rivers (Nonprofit) Account: ' + rivers.Id);
System.debug('Catalog Pricebook: ' + catalog.Id);
System.debug('Invoice Opportunity: ' + invoiceOpp.Id);
System.debug('Products: ' + prods.size() + '  LineItems: ' + olis.size() + '  Opps: ' + opps.size());
