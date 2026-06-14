// ============================================================================
// Portwood DocGen DEMO — Seed 05: Giant catalog (giant-query scale demo)
//   Creates a 2,200-line price book so the PricebookEntries child loop crosses
//   DocGen's >2000-row "giant query" threshold. Powers the giant price-list
//   HTML template (repeating headers, constant-cost rendering at scale).
// Idempotent: clears GIANT-* products/entries and the giant pricebook.
// ============================================================================
Integer GIANT_COUNT = 2200;

delete [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode LIKE 'GIANT-%'];
delete [SELECT Id FROM Product2 WHERE ProductCode LIKE 'GIANT-%'];
delete [SELECT Id FROM Pricebook2 WHERE Name = 'Portwood Mega Catalog (Giant Demo)'];

Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
Pricebook2 mega = new Pricebook2(Name='Portwood Mega Catalog (Giant Demo)', IsActive=true,
    Description='2,200-line catalog for the DocGen giant-query scale demo.');
insert mega;

String[] families = new String[]{'Fasteners','Bearings','Electrical','Safety','Tools',
    'Consumables','Raw Materials','Welding','Power Transmission','Hydraulics'};
String[] adjs = new String[]{'Standard','Heavy-Duty','Industrial','Precision','Premium',
    'Economy','Stainless','Galvanized','High-Temp','Compact'};
String[] nouns = new String[]{'Bracket','Coupling','Valve','Gasket','Fitting','Clamp',
    'Connector','Spacer','Bushing','Adapter','Mount','Flange','Seal','Pin','Sleeve'};

List<Product2> prods = new List<Product2>();
for (Integer i = 0; i < GIANT_COUNT; i++) {
    String fam = families[Math.mod(i,10)];
    String nm = adjs[Math.mod(i,10)] + ' ' + nouns[Math.mod(i,15)] + ' Type ' + (Math.mod(i,90)+10);
    prods.add(new Product2(Name=nm, ProductCode='GIANT-' + String.valueOf(100000+i),
        Family=fam, IsActive=true, QuantityUnitOfMeasure='Each'));
}
insert prods;

List<PricebookEntry> stdPbe = new List<PricebookEntry>();
List<PricebookEntry> megaPbe = new List<PricebookEntry>();
for (Integer i = 0; i < prods.size(); i++) {
    Decimal price = (Math.mod(i*37,9000) + 99) / 100.0; // $0.99 .. ~$90
    stdPbe.add(new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=prods[i].Id, UnitPrice=price, IsActive=true));
}
insert stdPbe;
for (Integer i = 0; i < prods.size(); i++) {
    Decimal price = (Math.mod(i*37,9000) + 99) / 100.0;
    megaPbe.add(new PricebookEntry(Pricebook2Id=mega.Id, Product2Id=prods[i].Id, UnitPrice=price, IsActive=true));
}
insert megaPbe;

System.debug('SEED-05 GIANT DONE');
System.debug('Mega Catalog: ' + mega.Id + '  entries=' + megaPbe.size());
