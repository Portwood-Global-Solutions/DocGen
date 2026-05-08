// DocGen Stress Test — Quote with 15 Products + Images
System.debug('=== Stress Test Data Generator ===');

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;

// 1. Account
Account acc = new Account(Name='Portwood Global Industries', Industry='Manufacturing', Phone='(555) 800-1234', Website='www.portwoodglobal.com', BillingStreet='500 Innovation Blvd', BillingCity='Austin', BillingState='TX', BillingPostalCode='78701');
Database.insert(acc, dml);

// 2. Contacts
List<Contact> cons = new List<Contact>{
    new Contact(AccountId=acc.Id, FirstName='Dave', LastName='Moudy', Title='CEO', Email='dave@portwoodglobal.com', Phone='(555) 800-0001'),
    new Contact(AccountId=acc.Id, FirstName='Amanda', LastName='Moudy', Title='CFO', Email='amanda@portwoodglobal.com', Phone='(555) 800-0002'),
    new Contact(AccountId=acc.Id, FirstName='Sarah', LastName='Chen', Title='VP Engineering', Email='sarah@portwoodglobal.com', Phone='(555) 800-0003')
};
Database.insert(cons, dml);

// 3. Opportunity
Opportunity opp = new Opportunity(Name='PGI Enterprise License 2026', AccountId=acc.Id, Amount=500000, StageName='Proposal/Price Quote', CloseDate=Date.today().addDays(45));
Database.insert(opp, dml);

// 4. Test image
String pngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAAA40lEQVR42u3QMQEAAAgDINc/9Mzg0QSJdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dnZ2dv4HAAD//9jQAQGH1FniAAAAAElFTkSuQmCC';

// 5. Products
List<String> names = new List<String>{
    'Enterprise Platform License', 'Premium Support Package', 'Advanced Analytics Module',
    'Cloud Storage (1TB)', 'API Gateway Pro', 'Single Sign-On Module',
    'Data Encryption Suite', 'Compliance Dashboard', 'Mobile SDK License',
    'Integration Hub', 'Custom Reporting Engine', 'Workflow Automation Pack',
    'AI/ML Processing Credits', 'Disaster Recovery Module', 'Training & Certification'
};
List<String> codes = new List<String>{
    'ENT-PLT-001', 'SUP-PRM-001', 'ANA-ADV-001', 'STR-CLD-001', 'API-GW-001',
    'SSO-MOD-001', 'ENC-SEC-001', 'CMP-DSH-001', 'MOB-SDK-001', 'INT-HUB-001',
    'RPT-ENG-001', 'WRK-AUT-001', 'AIM-CRD-001', 'DST-RCV-001', 'TRN-CRT-001'
};
List<Decimal> prices = new List<Decimal>{
    25000, 8000, 15000, 3000, 12000, 5000, 7500, 6000, 4500, 9000, 11000, 8500, 20000, 10000, 3500
};

List<Product2> products = new List<Product2>();
for (Integer i = 0; i < names.size(); i++) {
    products.add(new Product2(Name=names[i], ProductCode=codes[i], Description='Enterprise-grade ' + names[i].toLowerCase() + '. Includes support and quarterly updates.', IsActive=true));
}
insert products;

// 6. Image CVs for each product
List<ContentVersion> imgCvs = new List<ContentVersion>();
for (Integer i = 0; i < products.size(); i++) {
    imgCvs.add(new ContentVersion(Title='Img-' + products[i].Name, PathOnClient='prod_' + i + '.png', VersionData=EncodingUtil.base64Decode(pngB64), IsMajorVersion=true));
}
insert imgCvs;
imgCvs = [SELECT Id, Title FROM ContentVersion WHERE Id IN :imgCvs ORDER BY CreatedDate];
for (Integer i = 0; i < Math.min(products.size(), imgCvs.size()); i++) {
    products[i].Product_Image__c = String.valueOf(imgCvs[i].Id);
}
update products;
System.debug('Products + images: ' + products.size());

// 7. Pricebook entries
Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
List<PricebookEntry> pbes = new List<PricebookEntry>();
for (Integer i = 0; i < products.size(); i++) {
    pbes.add(new PricebookEntry(Pricebook2Id=pbId, Product2Id=products[i].Id, UnitPrice=prices[i], IsActive=true));
}
insert pbes;

// 8. Quote
// Set pricebook on opportunity first
opp.Pricebook2Id = pbId;
update opp;

Quote q = new Quote(Name='PGI-Q-2026-001', OpportunityId=opp.Id, Pricebook2Id=pbId, Status='Draft', ExpirationDate=Date.today().addDays(30));
insert q;
System.debug('Quote: ' + q.Id);

// 9. QuoteLineItems
List<QuoteLineItem> qlis = new List<QuoteLineItem>();
Decimal total = 0;
for (Integer i = 0; i < products.size(); i++) {
    Integer qty = Math.mod(i, 5) + 1;
    total += prices[i] * qty;
    qlis.add(new QuoteLineItem(QuoteId=q.Id, PricebookEntryId=pbes[i].Id, Product2Id=products[i].Id, Quantity=qty, UnitPrice=prices[i]));
}
insert qlis;
System.debug('QuoteLineItems: ' + qlis.size());

// 10. Template
String qc = 'Name, Status, GrandTotal, ExpirationDate, Opportunity.Account.Name, Opportunity.Account.Industry, Opportunity.Account.Phone, Opportunity.Account.BillingStreet, Opportunity.Account.BillingCity, Opportunity.Account.BillingState, Opportunity.Account.BillingPostalCode, (SELECT Product2.Name, Product2.ProductCode, Product2.Description, Product2.Product_Image__c, Quantity, UnitPrice, TotalPrice FROM QuoteLineItems)';

List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = 'Sales Quote - Stress Test' LIMIT 1];
DocGen_Template__c tmpl;
if (!existing.isEmpty()) {
    tmpl = existing[0];
    tmpl.Query_Config__c = qc;
    tmpl.Base_Object_API__c = 'Quote';
    update tmpl;
} else {
    tmpl = new DocGen_Template__c(Name='Sales Quote - Stress Test', Base_Object_API__c='Quote', Query_Config__c=qc, Output_Format__c='PDF', Type__c='Word');
    insert tmpl;
}

System.debug('');
System.debug('=== STRESS TEST DATA READY ===');
System.debug('Account:     ' + acc.Id + ' (Portwood Global Industries)');
System.debug('Opportunity: ' + opp.Id);
System.debug('Quote:       ' + q.Id + ' (PGI-Q-2026-001)');
System.debug('Products:    ' + products.size() + ' with images');
System.debug('Line Items:  ' + qlis.size());
System.debug('Grand Total: $' + total);
System.debug('Template:    ' + tmpl.Id);
System.debug('');
System.debug('NEXT: Upload "Sales Quote Template.docx" to template ' + tmpl.Id);
System.debug('THEN: Navigate to Quote ' + q.Id + ' and generate!');
