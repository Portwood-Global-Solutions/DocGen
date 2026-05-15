// Create a real DocGen_Template__c against Survey__c in the org, using the
// new {Chart:...} tag. After this runs, the template appears in the DocGen
// runner and can be generated from any Survey__c record.
//
// Structure (the right one — answers belong to a specific question):
//   - Cover page (survey name, question count)
//   - TOC of all questions
//   - For each question: a bar chart of THAT question's answer distribution
//   - One cross-tab showcase pinned to Q1 (bar/pivot/clustered/stacked styles)
//
// Charts use the per-question child relationship Survey_Question__c
// → Survey_Responses__r, so each chart only aggregates that question's
// responses. Inside the {#Survey_Questions__r} loop, "Survey_Responses__r"
// resolves against the iterating Survey_Question__c, not the outer Survey.
//
// Run: sf apex run --target-org portwood-staging -f scripts/demo-create-survey-template.apex

// ─── 1. template HTML body ────────────────────────────────────────────
String body =
    '<html><head><style>' +
    '@page { size: Letter; margin: 22mm 18mm; }' +
    'body { font-family: Helvetica, Arial, sans-serif; color: #1f2937; font-size: 11pt; line-height: 1.5; }' +
    'h1 { color: #1e3a8a; font-size: 28pt; margin: 0 0 8px 0; line-height: 1.15; }' +
    'h2 { color: #1e3a8a; font-size: 18pt; font-weight: bold; margin: 18px 0 10px 0; line-height: 1.25; }' +
    'h3 { color: #1e3a8a; font-size: 14pt; font-weight: bold; margin: 14px 0 6px 0; }' +
    '.eyebrow { color: #b45309; font-size: 9pt; font-weight: bold; letter-spacing: 2px; text-transform: uppercase; margin: 0 0 6px 0; }' +
    '.subtitle { color: #6b7280; font-size: 12pt; margin: 0 0 32px 0; }' +
    '.meta { color: #6b7280; font-size: 10pt; }' +
    '.page { page-break-before: always; }' +
    '.cover { padding-top: 60px; text-align: center; }' +
    'table.toc { width: 100%; border-collapse: collapse; margin: 12px 0 0 0; }' +
    'table.toc td { padding: 6px 4px; border-bottom: 1px dotted #d1d5db; font-size: 11pt; vertical-align: top; }' +
    'table.toc td.num { width: 36px; color: #b45309; font-weight: bold; text-align: right; padding-right: 10px; }' +
    '</style></head><body>' +
    // ─── cover ─────────────────────────────────────────────────────────
    '<div class="cover">' +
    '<p class="eyebrow">SURVEY RESPONSE REPORT</p>' +
    '<h1>{Name}</h1>' +
    '<p class="subtitle">Question-by-question answer analysis</p>' +
    '<p class="meta"><strong>{COUNT:Survey_Questions__r}</strong> questions &mdash; aggregated server-side<br/>' +
    'Prepared by {RunningUser.Name}<br/>{today:MMMM d, yyyy}</p>' +
    '</div>' +
    // ─── TOC ───────────────────────────────────────────────────────────
    '<div class="page">' +
    '<h2>Contents</h2>' +
    '<table class="toc">' +
    '{#Survey_Questions__r}' +
    '<tr><td class="num">{Display_Order__c}.</td><td>{Question_Text__c}</td></tr>' +
    '{/Survey_Questions__r}' +
    '</table>' +
    '</div>' +
    // ─── per-question pages ────────────────────────────────────────────
    '{#Survey_Questions__r}' +
    '<div class="page">' +
    '<p class="eyebrow">QUESTION {Display_Order__c}</p>' +
    '<h2>{Question_Text__c}</h2>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:bar}' +
    '</div>' +
    '{/Survey_Questions__r}' +
    // ─── cross-tab showcase (pinned to Q1 — "How satisfied are you with your current role?") ──
    '<div class="page">' +
    '<p class="eyebrow">CROSS-TAB SHOWCASE</p>' +
    '<h2>How does department affect Q1 answers?</h2>' +
    '<p class="meta">All three cross-tab styles below visualize the same Q1 data sliced by department.</p>' +
    '<h3>Pivot &mdash; percent per department column</h3>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:pivot:where=Survey_Question__r.Display_Order__c=1&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
    '</div>' +
    '<div class="page">' +
    '<p class="eyebrow">CROSS-TAB SHOWCASE</p>' +
    '<h3>Vertical clustered &mdash; one column per answer, bars per department</h3>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:clustered:where=Survey_Question__r.Display_Order__c=1&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
    '</div>' +
    '<div>' +
    '<p class="eyebrow">CROSS-TAB SHOWCASE</p>' +
    '<h3>Stacked horizontal &mdash; departmental composition per answer</h3>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:stacked:where=Survey_Question__r.Display_Order__c=1&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support,Operations}' +
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
String queryConfig = 'Name, (SELECT Id, Question_Text__c, Display_Order__c FROM Survey_Questions__r ORDER BY Display_Order__c ASC)';

if (existing.isEmpty()) {
    tpl = new DocGen_Template__c(
        Name = templateName,
        Type__c = 'HTML',
        Base_Object_API__c = 'Survey__c',
        Is_Active__c = true,
        Description__c = 'Per-question bar chart loop + a cross-tab showcase pinned to Q1. ' +
            'Demonstrates the {Chart:...} tag against any Survey record.',
        Output_Format__c = 'PDF',
        Query_Config__c = queryConfig,
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
        Query_Config__c = queryConfig,
        Page_Size__c = 'Letter',
        Page_Orientation__c = 'Portrait'
    );
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
    System.debug('Reusing template: ' + tpl.Id + ' (deactivated ' + oldVersions.size() + ' old versions)');
}

// ─── 4. create an active version pointing at the body ContentVersion ──
DocGen_Template_Version__c ver = new DocGen_Template_Version__c(
    Template__c = tpl.Id,
    Type__c = 'HTML',
    Is_Active__c = true,
    Content_Version_Id__c = cv.Id,
    Page_Size__c = 'Letter',
    Page_Orientation__c = 'Portrait',
    Description__c = 'Generated by demo-create-survey-template.apex — per-question loop'
);
insert ver;

// ─── 5. report ────────────────────────────────────────────────────────
String orgUrl = URL.getOrgDomainUrl().toExternalForm();
System.debug('========================================');
System.debug('TEMPLATE UPDATED — ' + templateName);
System.debug('========================================');
System.debug('Template:  ' + orgUrl + '/lightning/r/DocGen_Template__c/' + tpl.Id + '/view');
System.debug('Version:   ' + ver.Id);
System.debug('Body CV:   ' + cv.Id);
System.debug('');
System.debug('Pages produced per generation:');
System.debug('  1.    Cover');
System.debug('  2.    Contents (auto-numbered TOC of all questions)');
System.debug('  3..N. One page per question, with a bar chart of that question&rsquo;s answers');
System.debug('  N+1.. Cross-tab showcase (pivot/clustered/stacked, all pinned to Q1 by department)');
System.debug('');
System.debug('Per-question chart SOQL cost = 1 GROUP BY per question (under the 50-chart budget).');
System.debug('');
System.debug('TO GENERATE — pick a Survey record, click DocGen Generate, choose "' + templateName + '":');
List<Survey__c> surveys = [SELECT Id, Name FROM Survey__c ORDER BY Name LIMIT 5];
for (Survey__c s : surveys) {
    System.debug('  ' + s.Name + ' — ' + orgUrl + '/lightning/r/Survey__c/' + s.Id + '/view');
}
System.debug('========================================');
