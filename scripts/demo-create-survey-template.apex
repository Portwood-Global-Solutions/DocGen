// Create a real DocGen_Template__c against Survey__c in the org, using the
// new {Chart:...} tag. After this runs, the template appears in the DocGen
// runner and can be generated from any Survey__c record.
//
// Run: sf apex run --target-org portwood-staging -f scripts/demo-create-survey-template.apex

// ─── 1. template HTML body ────────────────────────────────────────────
// Charts run against Survey_Responses__r (omitted from Query_Config so
// they aggregate server-side via SOQL fallback — works for any survey size).
String body =
    '<html><head><style>' +
    '@page { size: Letter; margin: 22mm 18mm; }' +
    'body { font-family: Helvetica, Arial, sans-serif; color: #1f2937; font-size: 11pt; line-height: 1.5; }' +
    'h1 { color: #1e3a8a; font-size: 28pt; margin: 0 0 8px 0; line-height: 1.15; }' +
    'h2 { color: #1e3a8a; font-size: 18pt; font-weight: bold; margin: 18px 0 10px 0; line-height: 1.25; }' +
    '.eyebrow { color: #b45309; font-size: 9pt; font-weight: bold; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 6px 0; }' +
    '.subtitle { color: #6b7280; font-size: 12pt; margin: 0 0 32px 0; }' +
    '.meta { color: #6b7280; font-size: 10pt; }' +
    '.page { page-break-before: always; }' +
    '.cover { padding-top: 60px; text-align: center; }' +
    '</style></head><body>' +
    // ─── cover ─────────────────────────────────────────────────────────
    '<div class="cover">' +
    '<p class="eyebrow">SURVEY RESPONSE REPORT</p>' +
    '<h1>{Name}</h1>' +
    '<p class="subtitle">Aggregated response analysis &mdash; all chart styles</p>' +
    '<p class="meta">Prepared by {RunningUser.Name}<br/>{today:MMMM d, yyyy}</p>' +
    '</div>' +
    // ─── style 1: simple bar ───────────────────────────────────────────
    '<div class="page">' +
    '<p class="eyebrow">Style 1 — Simple Bar</p>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Overall answer distribution}' +
    '<p class="meta">Bars are colored by palette, sized by percentage of total responses. ' +
    'Aggregated server-side via SOQL GROUP BY — works at any survey size.</p>' +
    '</div>' +
    // ─── style 2: pivot cross-tab ──────────────────────────────────────
    '<div class="page">' +
    '<p class="eyebrow">Style 2 — Pivot Cross-Tab</p>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:pivot:title=Answers by department&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
    '<p class="meta">Each cell shows that answer&rsquo;s percent within the department column. ' +
    'colSort controls header order; a synthetic Total column appears at the end.</p>' +
    '</div>' +
    // ─── style 3: vertical clustered bars ──────────────────────────────
    '<div class="page">' +
    '<p class="eyebrow">Style 3 — Vertical Clustered Bars</p>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:clustered:title=Departmental clustering by answer&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
    '<p class="meta">Each answer is a column; the inner bars compare departments. Heights use percent_int (column percentage).</p>' +
    '</div>' +
    // ─── style 4: stacked horizontal ───────────────────────────────────
    '<div>' +
    '<p class="eyebrow">Style 4 — Stacked Horizontal</p>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:stacked:title=Departmental composition per answer&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
    '<p class="meta">Each row is one answer; segments show the departmental mix. Uses percent_of_row for segment widths.</p>' +
    '</div>' +
    '</body></html>';

// ─── 2. save template body as a ContentVersion ────────────────────────
ContentVersion cv = new ContentVersion(
    Title = 'Survey Chart Demo — Template Body',
    PathOnClient = 'survey-chart-demo.html',
    VersionData = Blob.valueOf(body),
    IsMajorVersion = true
);
insert cv;
ContentVersion reloaded = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
System.debug('Template body ContentVersion: ' + cv.Id);

// ─── 3. create / update the template parent record ────────────────────
String templateName = 'Survey Chart Demo';
List<DocGen_Template__c> existing = [
    SELECT Id
    FROM DocGen_Template__c
    WHERE Name = :templateName
    LIMIT 1
];
DocGen_Template__c tpl;
if (existing.isEmpty()) {
    tpl = new DocGen_Template__c(
        Name = templateName,
        Type__c = 'HTML',
        Base_Object_API__c = 'Survey__c',
        Is_Active__c = true,
        Description__c = 'Demo of all four {Chart:...} styles against any Survey record. ' +
            'Charts aggregate server-side via SOQL fallback.',
        Output_Format__c = 'PDF',
        Query_Config__c = 'Name',
        Page_Size__c = 'Letter',
        Page_Orientation__c = 'Portrait'
    );
    insert tpl;
    System.debug('Created template: ' + tpl.Id);
} else {
    tpl = existing[0];
    update new DocGen_Template__c(
        Id = tpl.Id,
        Type__c = 'HTML',
        Base_Object_API__c = 'Survey__c',
        Is_Active__c = true,
        Output_Format__c = 'PDF',
        Query_Config__c = 'Name',
        Page_Size__c = 'Letter',
        Page_Orientation__c = 'Portrait'
    );
    // Deactivate prior versions so the new one is the active body.
    List<DocGen_Template_Version__c> oldVersions = [
        SELECT Id
        FROM DocGen_Template_Version__c
        WHERE Template__c = :tpl.Id AND Is_Active__c = TRUE
    ];
    for (DocGen_Template_Version__c v : oldVersions) {
        v.Is_Active__c = false;
    }
    if (!oldVersions.isEmpty()) {
        update oldVersions;
    }
    System.debug('Reusing template: ' + tpl.Id);
}

// ─── 4. create an active version pointing at the body ContentVersion ──
DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
    Template__c = tpl.Id,
    Type__c = 'HTML',
    Is_Active__c = true,
    Content_Version_Id__c = cv.Id,
    Page_Size__c = 'Letter',
    Page_Orientation__c = 'Portrait',
    Description__c = 'Generated by demo-create-survey-template.apex'
);
insert ver;

// ─── 5. report ────────────────────────────────────────────────────────
String orgUrl = URL.getOrgDomainUrl().toExternalForm();
System.debug('========================================');
System.debug('TEMPLATE CREATED — ' + templateName);
System.debug('========================================');
System.debug('Template:  ' + orgUrl + '/lightning/r/DocGen_Template__c/' + tpl.Id + '/view');
System.debug('Version:   ' + ver.Id);
System.debug('Body CV:   ' + cv.Id + '  (open in Files to inspect raw HTML)');
System.debug('');
System.debug('TO GENERATE A PDF:');
System.debug('  1. Open any Survey record, e.g.:');
List<Survey__c> surveys = [SELECT Id, Name FROM Survey__c ORDER BY Name LIMIT 5];
for (Survey__c s : surveys) {
    System.debug('       ' + s.Name + ' — ' + orgUrl + '/lightning/r/Survey__c/' + s.Id + '/view');
}
System.debug('  2. Click the DocGen Generate action / Lightning page button');
System.debug('  3. Pick "' + templateName + '" from the runner');
System.debug('  4. PDF generates with all four chart styles against that survey&rsquo;s responses');
System.debug('========================================');
