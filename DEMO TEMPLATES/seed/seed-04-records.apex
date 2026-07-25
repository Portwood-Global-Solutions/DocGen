// ============================================================================
// Portwood DocGen DEMO — Seed 04: Properties, Certificates, Statements
//   Powers: real-estate purchase agreement & lease, certificates (completion /
//   award / verification), financial account statement.
// Idempotent: clears each Demo object then re-inserts.
// ============================================================================
delete [SELECT Id FROM Demo_Statement_Line__c];
delete [SELECT Id FROM Demo_Statement__c];
delete [SELECT Id FROM Demo_Property__c];
delete [SELECT Id FROM Demo_Certificate__c];

Date today = Date.today();

// ---- Properties (real estate) ----
List<Demo_Property__c> props = new List<Demo_Property__c>{
    new Demo_Property__c(Name='123 Maple Avenue — Lakeview', Address__c='123 Maple Avenue',
        City__c='Austin', State__c='TX', Postal_Code__c='78704', List_Price__c=685000,
        Sale_Price__c=672000, Bedrooms__c=4, Bathrooms__c=2.5, Square_Feet__c=2640,
        Lot_Size__c='0.28 acres', Year_Built__c=2014, Property_Type__c='Single Family',
        MLS_Number__c='ATX-884512', Buyer_Name__c='Jordan & Casey Rivera',
        Buyer_Email__c='jordan.rivera@example.com', Seller_Name__c='Patricia Howell',
        Seller_Email__c='p.howell@example.com', Agent_Name__c='Renata Cole, Lakeview Realty',
        Closing_Date__c=today.addDays(30), Earnest_Money__c=20000),
    new Demo_Property__c(Name='88 Harbor Lofts #5B', Address__c='88 Harbor Street, Unit 5B',
        City__c='Seattle', State__c='WA', Postal_Code__c='98101', List_Price__c=540000,
        Bedrooms__c=2, Bathrooms__c=2, Square_Feet__c=1180, Lot_Size__c='N/A (condo)',
        Year_Built__c=2019, Property_Type__c='Condominium', MLS_Number__c='SEA-220471',
        Buyer_Name__c='Morgan Lee', Buyer_Email__c='morgan.lee@example.com',
        Seller_Name__c='Harbor Lofts LLC', Agent_Name__c='Devin Park, Emerald Property Group',
        Closing_Date__c=today.addDays(45), Earnest_Money__c=15000)
};
insert props;

// ---- Certificates ----
List<Demo_Certificate__c> certs = new List<Demo_Certificate__c>{
    new Demo_Certificate__c(Name='Certificate of Completion', Recipient_Name__c='Maria Gonzalez',
        Recipient_Email__c='maria.gonzalez@example.com',
        Course_Name__c='Salesforce Document Automation — Professional Track',
        Issuer__c='Portwood Global Solutions', Issuer_Title__c='Director of Training',
        Issue_Date__c=today.addDays(-2), Expiration_Date__c=today.addDays(728),
        Certificate_Number__c='PWG-CERT-2026-00417',
        Verification_URL__c='https://verify.portwood.dev/c/PWG-CERT-2026-00417',
        Credential_Level__c='Professional', Score__c=94, Hours__c=40),
    new Demo_Certificate__c(Name='Certificate of Achievement', Recipient_Name__c='Andre Wallace',
        Recipient_Email__c='andre.wallace@example.com',
        Course_Name__c='Advanced Template Design Workshop',
        Issuer__c='Portwood Global Solutions', Issuer_Title__c='Lead Instructor',
        Issue_Date__c=today.addDays(-9), Certificate_Number__c='PWG-CERT-2026-00391',
        Verification_URL__c='https://verify.portwood.dev/c/PWG-CERT-2026-00391',
        Credential_Level__c='Expert', Score__c=99, Hours__c=24),
    new Demo_Certificate__c(Name='Safety Training Certificate', Recipient_Name__c='Dana Whitfield',
        Recipient_Email__c='dana.whitfield@northwindtraders.com',
        Course_Name__c='OSHA 10-Hour General Industry',
        Issuer__c='Northwind Safety Office', Issuer_Title__c='Safety Coordinator',
        Issue_Date__c=today.addDays(-15), Expiration_Date__c=today.addDays(1080),
        Certificate_Number__c='NW-OSHA-2026-1182',
        Verification_URL__c='https://verify.portwood.dev/c/NW-OSHA-2026-1182',
        Credential_Level__c='Foundation', Hours__c=10)
};
insert certs;

// ---- Financial statement + transaction lines ----
Demo_Statement__c stmt = new Demo_Statement__c(Name='STMT-2026-0531',
    Account_Holder__c='Dana Whitfield', Account_Number__c='****-****-4417',
    Account_Type__c='Checking', Statement_Period__c='May 1 – May 31, 2026',
    Statement_Date__c=Date.newInstance(2026,5,31), Opening_Balance__c=4820.55,
    Email__c='dana.whitfield@example.com', Address__c='240 Commerce Way',
    City_State_Zip__c='Cambridge, MA 02142');
insert stmt;

// date|desc|category|amount(+dep/-wd)
List<List<Object>> tx = new List<List<Object>>{
    new List<Object>{Date.newInstance(2026,5,2),'Payroll Deposit — Northwind Traders','Deposit',3250.00},
    new List<Object>{Date.newInstance(2026,5,3),'Mortgage Payment — Lakeview Bank','Withdrawal',-1840.00},
    new List<Object>{Date.newInstance(2026,5,5),'Whole Foods Market','Purchase',-156.42},
    new List<Object>{Date.newInstance(2026,5,7),'Transfer to Savings','Transfer',-500.00},
    new List<Object>{Date.newInstance(2026,5,9),'Shell Gas Station','Purchase',-58.10},
    new List<Object>{Date.newInstance(2026,5,12),'Electric Utility — EverSource','Withdrawal',-142.88},
    new List<Object>{Date.newInstance(2026,5,14),'Amazon.com','Purchase',-89.99},
    new List<Object>{Date.newInstance(2026,5,16),'ATM Withdrawal','Withdrawal',-200.00},
    new List<Object>{Date.newInstance(2026,5,16),'ATM Fee','Fee',-3.00},
    new List<Object>{Date.newInstance(2026,5,18),'Refund — Best Buy','Deposit',74.50},
    new List<Object>{Date.newInstance(2026,5,20),'Restaurant — Olive & Vine','Purchase',-112.30},
    new List<Object>{Date.newInstance(2026,5,23),'Interest Earned','Interest',2.14},
    new List<Object>{Date.newInstance(2026,5,25),'Phone Bill — Verizon','Withdrawal',-95.00},
    new List<Object>{Date.newInstance(2026,5,28),'Payroll Deposit — Northwind Traders','Deposit',3250.00},
    new List<Object>{Date.newInstance(2026,5,30),'Costco Wholesale','Purchase',-243.77}
};
Decimal bal = stmt.Opening_Balance__c;
Decimal deposits = 0, withdrawals = 0;
List<Demo_Statement_Line__c> lines = new List<Demo_Statement_Line__c>();
Integer ln = 1;
for (List<Object> t : tx) {
    Decimal amt = (Decimal) t[3];
    bal += amt;
    if (amt >= 0) deposits += amt; else withdrawals += amt;
    lines.add(new Demo_Statement_Line__c(Statement__c=stmt.Id, Transaction_Date__c=(Date)t[0],
        Description__c=(String)t[1], Category__c=(String)t[2], Amount__c=amt,
        Running_Balance__c=bal, Line_Order__c=ln++));
}
insert lines;
stmt.Closing_Balance__c = bal;
stmt.Total_Deposits__c = deposits;
stmt.Total_Withdrawals__c = withdrawals.abs();
update stmt;

System.debug('SEED-04 RECORDS DONE');
System.debug('Property (Maple Ave): ' + props[0].Id);
System.debug('Certificate (Maria): ' + certs[0].Id);
System.debug('Statement: ' + stmt.Id + '  lines=' + lines.size() + '  closing=' + bal);
