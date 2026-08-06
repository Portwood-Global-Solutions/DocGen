/**
 * Demo data and a worked Canvas template, so the canvas editor opens onto something
 * real rather than a blank artboard.
 *
 *   sf apex run --target-org <org> -f scripts/qa/seed-canvas-demo.apex
 *
 * WHY THE DATA LOOKS LIKE THIS
 * ----------------------------
 * Every field seeded here is one the demo template actually renders, and the shape of
 * the data is chosen to exercise the parts of the engine that go wrong quietly:
 *
 *   - Accounts with DIFFERENT numbers of Opportunities (0, 1, 3, 12), because a loop
 *     that works at 3 rows and breaks at 0 or at a page boundary is the common bug.
 *   - Amounts that are not round, so a currency-formatted total is visibly a total and
 *     not a coincidence.
 *   - An AccountNumber on every account, because the QR/barcode tool needs a field with
 *     a scannable value rather than a name full of spaces.
 *   - A logo asset, so the Image tool has something to list. Without one the panel is
 *     correct but empty, which reads as broken.
 *
 * Idempotent: re-running updates the seed rather than piling up duplicates.
 */

// ---------------------------------------------------------------------------
// 1. Accounts + children
// ---------------------------------------------------------------------------
String TAG = 'Portwood Demo';
// Matched by NAME, not by the Description tag: Description is a long text area and
// long text cannot appear in a WHERE clause at all.
List<String> SEED_NAMES = new List<String>{
    'Northwind Traders',
    'Kestrel Analytics',
    'Harbourline Logistics',
    'Quiet Bay Consulting'
};

// Delete previous seed rows first. Upserting would leave orphaned children from an
// earlier run attached to the same account and silently inflate every total. Contacts
// and Opportunities go with their account, so this is the only delete needed.
List<Account> priorSeed = [SELECT Id FROM Account WHERE Name IN :SEED_NAMES];
if (!priorSeed.isEmpty()) {
    delete priorSeed;
}

List<Account> accts = new List<Account>{
    new Account(
        Name = 'Northwind Traders',
        AccountNumber = 'NW-100241',
        Industry = 'Manufacturing',
        Rating = 'Hot',
        Phone = '(312) 555-0142',
        Website = 'www.northwind.example',
        BillingStreet = '4400 N Ravenswood Ave',
        BillingCity = 'Chicago',
        BillingState = 'IL',
        BillingPostalCode = '60640',
        BillingCountry = 'USA',
        NumberOfEmployees = 480,
        AnnualRevenue = 18750000,
        Description = TAG
    ),
    new Account(
        Name = 'Kestrel Analytics',
        AccountNumber = 'KA-200317',
        Industry = 'Technology',
        Rating = 'Warm',
        Phone = '(415) 555-0198',
        Website = 'www.kestrel.example',
        BillingStreet = '55 Market St Suite 900',
        BillingCity = 'San Francisco',
        BillingState = 'CA',
        BillingPostalCode = '94105',
        BillingCountry = 'USA',
        NumberOfEmployees = 92,
        AnnualRevenue = 6400000,
        Description = TAG
    ),
    new Account(
        Name = 'Harbourline Logistics',
        AccountNumber = 'HL-300884',
        Industry = 'Transportation',
        Rating = 'Hot',
        Phone = '(206) 555-0111',
        Website = 'www.harbourline.example',
        BillingStreet = '1201 Alaskan Way',
        BillingCity = 'Seattle',
        BillingState = 'WA',
        BillingPostalCode = '98101',
        BillingCountry = 'USA',
        NumberOfEmployees = 1350,
        AnnualRevenue = 42300000,
        Description = TAG
    ),
    // Deliberately childless: an empty loop must render an empty table, not break.
    new Account(
        Name = 'Quiet Bay Consulting',
        AccountNumber = 'QB-400002',
        Industry = 'Consulting',
        Rating = 'Cold',
        Phone = '(617) 555-0170',
        BillingCity = 'Boston',
        BillingState = 'MA',
        BillingCountry = 'USA',
        NumberOfEmployees = 12,
        AnnualRevenue = 850000,
        Description = TAG
    )
};
insert accts;

Map<String, Id> acctByName = new Map<String, Id>();
for (Account a : accts) {
    acctByName.put(a.Name, a.Id);
}

List<Contact> contacts = new List<Contact>{
    new Contact(
        FirstName = 'Dana',
        LastName = 'Whitfield',
        Title = 'VP Operations',
        Email = 'dana.whitfield@northwind.example',
        Phone = '(312) 555-0143',
        AccountId = acctByName.get('Northwind Traders'),
        Description = TAG
    ),
    new Contact(
        FirstName = 'Marcus',
        LastName = 'Ilori',
        Title = 'Procurement Lead',
        Email = 'marcus.ilori@northwind.example',
        AccountId = acctByName.get('Northwind Traders'),
        Description = TAG
    ),
    new Contact(
        FirstName = 'Priya',
        LastName = 'Raghunathan',
        Title = 'Chief Data Officer',
        Email = 'priya.r@kestrel.example',
        Phone = '(415) 555-0199',
        AccountId = acctByName.get('Kestrel Analytics'),
        Description = TAG
    ),
    new Contact(
        FirstName = 'Tomas',
        LastName = 'Erikson',
        Title = 'Fleet Director',
        Email = 'tomas.erikson@harbourline.example',
        AccountId = acctByName.get('Harbourline Logistics'),
        Description = TAG
    )
};
insert contacts;

// Opportunity counts chosen to hit the interesting cases: one, a handful, and enough
// to spill a table past a page break.
Map<String, Integer> oppCount = new Map<String, Integer>{
    'Northwind Traders' => 12,
    'Kestrel Analytics' => 3,
    'Harbourline Logistics' => 1,
    'Quiet Bay Consulting' => 0
};
List<String> lineNames = new List<String>{
    'Annual platform licence',
    'Onboarding and migration',
    'Premium support tier',
    'Additional user seats',
    'Data warehouse connector',
    'Custom report pack',
    'Training workshop',
    'Sandbox environment',
    'API rate-limit uplift',
    'Single sign-on add-on',
    'Archival storage',
    'Quarterly health check'
};
List<String> stages = new List<String>{ 'Prospecting', 'Value Proposition', 'Negotiation/Review', 'Closed Won' };
List<Opportunity> opps = new List<Opportunity>();
for (String name : oppCount.keySet()) {
    Integer n = oppCount.get(name);
    for (Integer i = 0; i < n; i++) {
        // Non-round amounts so a currency total is obviously computed.
        Decimal amount = 4250 + Math.mod(i * 3617, 21) * 1175.25 + i * 890.5;
        opps.add(
            new Opportunity(
                Name = lineNames[Math.mod(i, lineNames.size())],
                AccountId = acctByName.get(name),
                Amount = amount.setScale(2),
                StageName = stages[Math.mod(i, stages.size())],
                CloseDate = Date.today().addDays(15 + i * 9),
                Description = TAG
            )
        );
    }
}
insert opps;

System.debug('SEED accounts=' + accts.size() + ' contacts=' + contacts.size() + ' opportunities=' + opps.size());

// ---------------------------------------------------------------------------
// 2. A logo asset, so the Image tool lists something
// ---------------------------------------------------------------------------
// A 4x1 PNG of solid blue. Tiny on purpose: the Image tool needs a REAL asset to prove
// {%asset:key} resolves and sizes, and the picture itself is irrelevant to that.
String LOGO_PNG_B64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAABCAYAAACiba1hAAAAF0lEQVQIHWNkYGD4z8DAwMgABXAGNgEA' + 'GDsBAV0lRhIAAAAASUVORK5CYII=';

List<DocGen_Asset__c> logo = [SELECT Id FROM DocGen_Asset__c WHERE Asset_Key__c = 'demo-logo' LIMIT 1];
if (logo.isEmpty()) {
    DocGen_Asset__c a = new DocGen_Asset__c(Name = 'Demo Logo', Asset_Key__c = 'demo-logo', Is_Active__c = true);
    insert a;
    ContentVersion cv = new ContentVersion(
        Title = 'demo-logo',
        PathOnClient = 'demo-logo.png',
        VersionData = EncodingUtil.base64Decode(LOGO_PNG_B64),
        FirstPublishLocationId = a.Id
    );
    insert cv;
    System.debug('SEED asset=demo-logo created');
} else {
    System.debug('SEED asset=demo-logo already present');
}

// ---------------------------------------------------------------------------
// 3. A worked Canvas template
// ---------------------------------------------------------------------------
// Written in the exact shape canvasModel.serialize() emits, so opening it in the editor
// round-trips cleanly: authoring attributes on every box, zero page margins, artboard
// as the whole page, a flow table that can grow, and pinned chrome that cannot.
String NAME = 'Demo — Account Summary (Canvas)';
String QUERY =
    'Name, AccountNumber, Industry, Rating, Phone, BillingCity, BillingState, ' +
    'AnnualRevenue, NumberOfEmployees, (SELECT Name, Amount, StageName, CloseDate FROM Opportunities)';

String css =
    '@page { size: Letter portrait; margin: 0in 0in 0in 0in; }\n' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color: #1a1a1a; margin: 0; }\n' +
    '.dg-artboard { position: relative; width: 8.5in; min-height: 11in; }\n' +
    '.dg-artboard_break { page-break-before: always; }\n' +
    '.dg-pin { position: absolute; }\n' +
    '.dg-flow { position: relative; }\n' +
    'table { border-collapse: collapse; width: 100%; -fs-table-paginate: paginate; }\n' +
    'thead { display: table-header-group; }\n' +
    'td, th { border: 0.5pt solid #999; padding: 2pt 4pt; }\n';

String boxes =
    // Header band
    '<div class="dg-pin" data-dg-x="0" data-dg-y="0" data-dg-w="8.5" data-dg-h="1.1" data-dg-mode="pinned"' +
    ' style="left: 0in; top: 0in; width: 8.5in; font-family: sans-serif; font-size: 11pt; color: #1a1a1a;' +
    ' text-align: left; padding: 0pt; background: #1d4ed8;">' +
    '<div data-dg-shape="rect" style="width: 100%; height: 1.1in; background: #1d4ed8;' +
    ' font-size: 0; line-height: 0;"></div></div>\n  ' +
    '<div class="dg-pin" data-dg-x="0.6" data-dg-y="0.3" data-dg-w="5" data-dg-h="0.5" data-dg-mode="pinned"' +
    ' style="left: 0.6in; top: 0.3in; width: 5in; font-family: sans-serif; font-size: 20pt; color: #ffffff;' +
    ' text-align: left; padding: 0pt;"><p><b>{Name}</b></p></div>\n  ' +
    '<div class="dg-pin" data-dg-x="0.6" data-dg-y="0.72" data-dg-w="5" data-dg-h="0.25" data-dg-mode="pinned"' +
    ' style="left: 0.6in; top: 0.72in; width: 5in; font-family: sans-serif; font-size: 10pt; color: #dbeafe;' +
    ' text-align: left; padding: 0pt;">{Industry} · {BillingCity}, {BillingState}</div>\n  ' +
    // Logo asset, top right
    '<div class="dg-pin" data-dg-x="6.7" data-dg-y="0.32" data-dg-w="1.2" data-dg-h="0.45" data-dg-mode="pinned"' +
    ' style="left: 6.7in; top: 0.32in; width: 1.2in; padding: 0pt;">{%asset:demo-logo:115x}</div>\n  ' +
    // Detail block
    '<div class="dg-pin" data-dg-x="0.6" data-dg-y="1.5" data-dg-w="4" data-dg-h="1.1" data-dg-mode="pinned"' +
    ' style="left: 0.6in; top: 1.5in; width: 4in; font-family: sans-serif; font-size: 11pt; color: #1a1a1a;' +
    ' text-align: left; padding: 0pt;"><p><b>Account number:</b> {AccountNumber}<br />' +
    '<b>Rating:</b> {Rating}<br /><b>Phone:</b> {Phone}<br />' +
    '<b>Employees:</b> {NumberOfEmployees}<br />' +
    '<b>Annual revenue:</b> {AnnualRevenue:currency:USD}</p></div>\n  ' +
    // QR of the account number
    '<div class="dg-pin" data-dg-x="6.5" data-dg-y="1.5" data-dg-w="1.5" data-dg-h="1.5" data-dg-mode="pinned"' +
    ' data-dg-code-type="qr" data-dg-code-field="AccountNumber" data-dg-code-size="144" data-dg-code-height="80"' +
    ' style="left: 6.5in; top: 1.5in; width: 1.5in; padding: 0pt;">{*AccountNumber:qr:144}</div>\n  ' +
    // Rule
    '<div class="dg-pin" data-dg-x="0.6" data-dg-y="2.9" data-dg-w="7.3" data-dg-h="0.02" data-dg-mode="pinned"' +
    ' style="left: 0.6in; top: 2.9in; width: 7.3in; padding: 0pt;">' +
    '<div data-dg-shape="hline" style="width: 100%; height: 0; border-top: 1pt solid #1d4ed8;' +
    ' font-size: 0; line-height: 0;"></div></div>\n  ' +
    '<div class="dg-pin" data-dg-x="0.6" data-dg-y="3.05" data-dg-w="4" data-dg-h="0.3" data-dg-mode="pinned"' +
    ' style="left: 0.6in; top: 3.05in; width: 4in; font-family: sans-serif; font-size: 13pt; color: #1a1a1a;' +
    ' text-align: left; padding: 0pt;"><p><b>Open opportunities</b></p></div>\n  ' +
    // Flow table — grows and paginates
    '<div class="dg-flow" data-dg-x="0.6" data-dg-y="3.5" data-dg-w="7.3" data-dg-h="1" data-dg-mode="flow"' +
    ' style="margin: 3.5in 0 0 0.6in; width: 7.3in; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; padding: 0pt;">' +
    '<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">' +
    '<thead style="display: table-header-group;"><tr>' +
    '<th style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: bold; background: #eeeeee;">Opportunity</th>' +
    '<th style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: bold; background: #eeeeee;">Stage</th>' +
    '<th style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: bold; background: #eeeeee;">Close date</th>' +
    '<th style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: right; font-weight: bold; background: #eeeeee;">Amount</th>' +
    '</tr></thead><tbody>{#Opportunities}<tr data-dg-row="loop">' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: normal;">{Name}</td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: normal;">{StageName}</td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: normal;">{CloseDate:date}</td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: right; font-weight: normal;">{Amount:currency:USD}</td>' +
    '</tr>{/Opportunities}' +
    '<tr data-dg-row="totals">' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: left; font-weight: bold;">Total</td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt;"></td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt;"></td>' +
    '<td style="border: 0.5pt solid #999999; padding: 3pt; font-family: sans-serif; font-size: 11pt;' +
    ' color: #1a1a1a; text-align: right; font-weight: bold;">{SUM:Opportunities.Amount:currency:USD}</td>' +
    '</tr></tbody></table></div>';

String body =
    '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8" />\n<style>\n' +
    css +
    '</style>\n</head>\n<body>\n<div class="dg-artboard" data-dg-artboard="1">\n  ' +
    boxes +
    '\n</div>\n</body>\n</html>';

Id sampleId = acctByName.get('Northwind Traders');
List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = :NAME LIMIT 1];
DocGen_Template__c tpl;
if (existing.isEmpty()) {
    tpl = new DocGen_Template__c(
        Name = NAME,
        Type__c = 'Canvas',
        Base_Object_API__c = 'Account',
        Query_Config__c = QUERY,
        Output_Format__c = 'PDF',
        Document_Title_Format__c = 'Account Summary - {Name}',
        Test_Record_Id__c = sampleId,
        Is_Active__c = true
    );
    insert tpl;
} else {
    tpl = existing[0];
    tpl.Type__c = 'Canvas';
    tpl.Base_Object_API__c = 'Account';
    tpl.Query_Config__c = QUERY;
    tpl.Test_Record_Id__c = sampleId;
    update tpl;
}

// Publish through the real controller so the body lands exactly where generation reads
// it — a hand-inserted ContentVersion with no active version pointing at it is the
// divergence this editor was built to stop.
Map<String, Object> saved = DocGenController.saveAndPublishHtmlBody(tpl.Id, 'canvas.html', body, true);
System.debug('SEED template=' + tpl.Id + ' version=' + saved.get('versionId'));

// Prove it renders before handing it over. A seed that looks right in the editor and
// throws on generation wastes the first ten minutes of anyone's session.
Map<String, Object> pdf = DocGenController.generatePdf(tpl.Id, sampleId, false, null);
String b64 = (String) pdf.get('base64');
System.debug('SEED render bytes=' + (b64 == null ? -1 : EncodingUtil.base64Decode(b64).size()));
System.debug('SEED OK — open "' + NAME + '" in the Portwood Designer');
