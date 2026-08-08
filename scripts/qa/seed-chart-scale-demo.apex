/**
 * Seeds the fixture for the client-side (Chart.js) chart path.
 *
 *   sf apex run --target-org <org> -f scripts/qa/seed-chart-scale-demo.apex
 *
 * WHY THE DATA LOOKS LIKE THIS
 * ----------------------------
 * The chart work exists because two Apex bucket-resolution paths each hit a
 * wall, and the fixture has to reproduce BOTH walls or it proves nothing:
 *
 *   1. TOO MANY ROWS for the in-memory path. The scout estimates peak heap as
 *      base + rows * 2000 against 6MB * 0.6, so PowerPoint/Excel is refused
 *      somewhere north of ~1,800 child rows. "Chart Scale - Large" carries
 *      2,600 Contacts, comfortably past it.
 *
 *   2. A FIELD SOQL CANNOT GROUP. Contact.Description is a Long Text Area:
 *      not groupable, not filterable, not sortable — exactly like the
 *      VMR_Tracker Answer_N columns that started this. No GROUP BY aggregate
 *      can ever run against it, at any row count.
 *
 *      Contact.Department is a plain text field and IS groupable, so it sits
 *      alongside as the control: it works on the old path and the new one, and
 *      if the two disagree the bug is in the aggregation, not the plumbing.
 *
 * Bucket values are deliberately UNEVEN. Equal buckets hide off-by-one errors
 * in percentage rounding and make a sort-order bug invisible, because every
 * order looks the same.
 *
 * "Chart Scale - Small" (24 Contacts) is the same shape under the threshold, so
 * the in-memory path and the client path can be compared on identical data.
 *
 * The template's Query_Config is deliberately just `Name` — it does NOT preload
 * Contacts. That is the whole point: Apex never sees the rows, the scout finds
 * no child relationship to refuse, and the browser pages them itself.
 *
 * Idempotent: re-running replaces the seed rather than piling up duplicates.
 */

// ---------------------------------------------------------------------------
// 0. Clear any previous run
// ---------------------------------------------------------------------------
List<Account> old = [SELECT Id FROM Account WHERE Name LIKE 'Chart Scale - %'];
if (!old.isEmpty()) {
    delete old; // cascades to Contacts
    System.debug('Removed ' + old.size() + ' previous seed account(s).');
}

// ---------------------------------------------------------------------------
// 1. Accounts
// ---------------------------------------------------------------------------
Account big = new Account(Name = 'Chart Scale - Large', AccountNumber = 'CS-LARGE');
Account small = new Account(Name = 'Chart Scale - Small', AccountNumber = 'CS-SMALL');
insert new List<Account>{ big, small };

// ---------------------------------------------------------------------------
// 2. Contacts
//
// Weights are the point: a flat distribution would make a broken sort or a
// rounding slip look correct.
// ---------------------------------------------------------------------------
List<String> modes = new List<String>{ 'Drove Alone', 'Transit', 'Telework', 'Carpool', 'Bike', 'Day Off' };
List<Integer> weights = new List<Integer>{ 34, 24, 18, 12, 8, 4 }; // sums to 100
List<String> departments = new List<String>{ 'Engineering', 'Sales', 'Operations', 'Finance' };

// Expand the weights into a 100-slot picking table so the mix is exact rather
// than approximate — a chart that says 34% should be 34%.
List<String> pickTable = new List<String>();
for (Integer i = 0; i < modes.size(); i++) {
    for (Integer n = 0; n < weights[i]; n++) {
        pickTable.add(modes[i]);
    }
}

List<Contact> rows = new List<Contact>();
Integer LARGE_COUNT = 2600;
for (Integer i = 0; i < LARGE_COUNT; i++) {
    rows.add(
        new Contact(
            AccountId = big.Id,
            FirstName = 'Rider',
            LastName = 'Large-' + String.valueOf(i).leftPad(4, '0'),
            // NOT groupable — the case that has no SOQL aggregate at all.
            Description = pickTable[Math.mod(i * 7, 100)],
            // Groupable — the control.
            Department = departments[Math.mod(i, departments.size())],
            LeadSource = Math.mod(i, 3) == 0 ? 'Web' : 'Referral'
        )
    );
}
Integer SMALL_COUNT = 24;
for (Integer i = 0; i < SMALL_COUNT; i++) {
    rows.add(
        new Contact(
            AccountId = small.Id,
            FirstName = 'Rider',
            LastName = 'Small-' + String.valueOf(i).leftPad(3, '0'),
            Description = pickTable[Math.mod(i * 13, 100)],
            Department = departments[Math.mod(i, departments.size())],
            LeadSource = Math.mod(i, 3) == 0 ? 'Web' : 'Referral'
        )
    );
}
insert rows;
System.debug('Inserted ' + rows.size() + ' contacts (' + LARGE_COUNT + ' large / ' + SMALL_COUNT + ' small).');

// ---------------------------------------------------------------------------
// 3. An HTML template that charts both fields
// ---------------------------------------------------------------------------
String body =
    '<html><body style="font-family: Helvetica, Arial, sans-serif; color:#1f2933;">' +
    '<h1 style="font-size:20pt; margin:0 0 4pt 0;">{Name}</h1>' +
    '<p style="color:#5b6a7d; margin:0 0 18pt 0;">Client-side chart fixture &mdash; {COUNT:Contacts:number} contacts</p>' +
    '<h2 style="font-size:13pt;">Commute mode &mdash; Long Text Area (no SOQL GROUP BY possible)</h2>' +
    '{Chart:Contacts:Description:bar:title=Commute Mode&width=720&height=360}' +
    '<h2 style="font-size:13pt;">The same data as a table</h2>' +
    '<table cellspacing="0" cellpadding="6" style="border-collapse:collapse; width:100%;">' +
    '<tr style="background:#14566d; color:#fff; text-align:left;">' +
    '<th>Mode</th><th>Percent</th><th>Count</th></tr>' +
    '{#ChartBucket:Contacts:Description}' +
    '<tr><td>{key_label}</td><td>{percent}%</td><td>{count}</td></tr>' +
    '{:else}' +
    '<tr><td colspan="3">No contacts found.</td></tr>' +
    '{/ChartBucket}' +
    '</table>' +
    '<h2 style="font-size:13pt; margin-top:20pt;">Department &mdash; groupable control</h2>' +
    '{Chart:Contacts:Department:donut:title=Department Mix&width=720&height=320}' +
    '</body></html>';

DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Chart Scale Demo (client-side)',
    API_Name__c = 'Chart_Scale_Demo',
    Base_Object_API__c = 'Account',
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Category__c = 'QA Fixtures',
    Is_Active__c = true,
    Test_Record_Id__c = big.Id,
    Description__c = 'Charts a Long Text Area (no GROUP BY) over 2,600 contacts. Query_Config omits Contacts on purpose.',
    // Deliberately NOT '(SELECT ... FROM Contacts)'. Preloading is what trips the
    // scout and blows heap; the browser pages the rows instead.
    Query_Config__c = 'Name'
);
insert tpl;

ContentVersion bodyCv = new ContentVersion(
    Title = 'Chart Scale Demo body',
    PathOnClient = 'chart-scale-demo.html',
    VersionData = Blob.valueOf(body)
);
insert bodyCv;
bodyCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :bodyCv.Id];

DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
    Template__c = tpl.Id,
    Is_Active__c = true,
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Base_Object_API__c = 'Account',
    Query_Config__c = tpl.Query_Config__c,
    Content_Version_Id__c = bodyCv.Id
);
insert ver;

// The Command Hub lists a template's body through the record's files.
insert new ContentDocumentLink(
    ContentDocumentId = bodyCv.ContentDocumentId,
    LinkedEntityId = tpl.Id,
    ShareType = 'V',
    Visibility = 'AllUsers'
);

System.debug('=== SEED COMPLETE ===');
System.debug('Large account (2,600 contacts): ' + big.Id);
System.debug('Small account (24 contacts):    ' + small.Id);
System.debug('Template:                       ' + tpl.Id);
System.debug('Expected mix: Drove Alone 34%, Transit 24%, Telework 18%, Carpool 12%, Bike 8%, Day Off 4%');
