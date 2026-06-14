# Portwood DocGen DEMO — Data Dictionary & Authoring Rules

Every template merges against records seeded by `seed/seed-01..05.apex`. Use these
**exact** API names. Relationship (child-loop) names end in `__r`.

## Hard authoring rules (Flying Saucer / server-side generation)

- **HTML → PDF only.** Layout with `<table>`. NO flex/grid/gap/calc/CSS-vars/linear-gradient/box-shadow/transform — they silently collapse.
- Solid colors only. Fixed units (pt/px/in). `:nth-child(even)` zebra is OK. Fonts: Helvetica/Arial/Times/Courier only.
- **Charts: use only `bar`, `stacked`, `clustered`, `pivot`** (CSS-bar styles render server-side). NEVER `pie`/`donut`/`line`/`area` (need the UI LWC). Chart field = **API name** (e.g. `Category__c`).
- `{PageNumber}`/`{TotalPages}` go in the template **footer field** (set via manifest), never the body.
- Currency `{F:currency}`, date `{F:MMMM d, yyyy}`, number `{F:#,##0}`, percent `{F:percent}`, picklist label `{F:label}`.
- Aggregates over a child rel: `{SUM:Rel__r.Field:currency}`, `{COUNT:Rel__r}`, `{AVG:…}`, `{MIN:…}`, `{MAX:…}`.
- Child loop: `{#Rel__r}…{/Rel__r}`. Conditional: `{#IF Field > 0}…{/IF}` / `{^Field}…{/Field}`. Today: `{Today:MMMM d, yyyy}`. Running user: `{RunningUser.Name}`.
- **Barcodes/QR** `{*Field:qr}` `{*Field:code128}` work in **both Word and HTML** templates (HTML support added in v3.15; render as CSS in the PDF).
- Signature tags (work in HTML + DOCX): `{@Signature_Role:Order:Type}` where Type ∈ Full|Initials|Date|DatePick. Put each on its own line/cell.

## Standard objects

### Account (records: "Northwind Traders" mfg, "Summit Components Inc." mfg, "Rivers Alliance Foundation" nonprofit)

`Name, Industry, AnnualRevenue, Phone, Website, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry`
Children: `Contacts` (Contact), `Opportunities` (Opportunity).

### Contact (under each account; e.g. Dana Whitfield, Marcus Reyes @ Northwind; Evelyn Brooks @ Rivers)

`FirstName, LastName, Title, Email, Phone, Account.Name`

### Opportunity

`Name, Amount, StageName, CloseDate, Type, Designation__c, Account.Name, Account.BillingCity` …

- **Invoice hero** (has line items): Name = `Northwind — Annual Supply Agreement`. Child `OpportunityLineItems`.
- **Pipeline** (for charts, base=Account Northwind): 4 Northwind opps, varied StageName (Proposal/Price Quote, Negotiation/Review, Closed Won, Qualification).
- **Donations** (base=Account Rivers, Type='Donation'): 6 opps, `Designation__c` ∈ {River Restoration Fund, Clean Water Program, Education Outreach, General Fund}, Amount 250–5000.
- Child **OpportunityLineItems**: `Quantity, UnitPrice, TotalPrice, ListPrice, Description, Product2.Name, Product2.ProductCode, Product2.Family`.

### Pricebook2 (records: "Portwood 2026 Wholesale Catalog" = 39 entries; "Portwood Mega Catalog (Giant Demo)" = 2,200 entries)

`Name, Description`. Child **PricebookEntries**: `UnitPrice, Product2.Name, Product2.ProductCode, Product2.Family, Product2.Description, Product2.QuantityUnitOfMeasure`.
ProductCodes look like `PWG-1001` (catalog) / `GIANT-100000` (mega).

## Custom demo objects (bare names; child rels end \_\_r)

### Demo_Statement\_\_c (record: STMT-2026-0531)

`Name, Account_Holder__c, Account_Number__c, Account_Type__c, Statement_Period__c, Statement_Date__c, Opening_Balance__c, Closing_Balance__c, Total_Deposits__c, Total_Withdrawals__c, Email__c, Address__c, City_State_Zip__c`
Child **Lines\_\_r** (Demo_Statement_Line**c): `Transaction_Date**c, Description**c, Category**c (Deposit/Withdrawal/Fee/Interest/Transfer/Purchase), Amount**c, Running_Balance**c, Line_Order\_\_c`. 15 lines.

### Demo_Event\_\_c (records: "Portwood Summit 2026" SF conf, "Riverside Conservation Gala 2026" PDX gala)

`Name, Event_Date__c, End_Date__c, Venue__c, Address__c, City__c, State__c, Postal_Code__c, Organizer__c, Contact_Email__c, Capacity__c, Registration_URL__c, Description__c`
Child **Attendees\_\_r** (Demo_Attendee**c): `Name, Email**c, Company**c, Title**c, Ticket_Type**c (General Admission/VIP/Speaker/Sponsor/Staff), Ticket_Code**c (e.g. PSUMMIT26-00001), Seat**c, Amount_Paid**c, Checked_In\_\_c`. Summit=12, Gala=8.

### Demo_Attendee**c (base for ticket/badge; parent via Event**r)

all above + `Event__r.Name, Event__r.Event_Date__c, Event__r.Venue__c, Event__r.City__c, Event__r.State__c`.

### Demo_Student\_\_c (records: "Ava Thompson" CS senior GPA 3.78; "Liam Carter" Econ junior 3.42)

`Name, Student_ID__c, Program__c, Major__c, Minor__c, Email__c, Enrollment_Date__c, Expected_Graduation__c, GPA__c, Total_Credits__c, Class_Standing__c, Advisor__c, Honors__c`
Child **Enrollments\_\_r** (Demo_Enrollment**c): `Course_Code**c, Course_Name**c, Term**c (e.g. "Fall 2025"), Term_Order**c, Credits**c, Grade**c (A/A-/B+; blank if in progress), Grade_Points**c, Quality_Points**c, Instructor**c, Status\_\_c (Completed/In Progress)`. Ava=19, Liam=13.

### Demo_Property\_\_c (records: "123 Maple Avenue — Lakeview" Austin SFH; "88 Harbor Lofts #5B" Seattle condo)

`Name, Address__c, City__c, State__c, Postal_Code__c, List_Price__c, Sale_Price__c, Bedrooms__c, Bathrooms__c, Square_Feet__c, Lot_Size__c, Year_Built__c, Property_Type__c, MLS_Number__c, Buyer_Name__c, Buyer_Email__c, Seller_Name__c, Seller_Email__c, Agent_Name__c, Closing_Date__c, Earnest_Money__c`

### Demo_Certificate\_\_c (records: Maria Gonzalez "Professional"; Andre Wallace "Expert"; Dana Whitfield OSHA)

`Name, Recipient_Name__c, Recipient_Email__c, Course_Name__c, Issuer__c, Issuer_Title__c, Issue_Date__c, Expiration_Date__c, Certificate_Number__c, Verification_URL__c, Credential_Level__c (Foundation/Associate/Professional/Expert), Score__c, Hours__c`
