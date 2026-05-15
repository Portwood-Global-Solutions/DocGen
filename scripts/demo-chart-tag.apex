// DocGen Demo — {Chart:...} tag end-to-end render
// Run: sf apex run --target-org portwood-staging -f scripts/demo-chart-tag.apex
//
// Renders all four chart styles via the new {Chart:...} expander against
// inline survey data, then saves the result as a downloadable HTML AND PDF
// ContentVersion. No SObjects needed; works in any org with DocGen deployed.
//
// Output:
//   - System.debug logs a Files URL for the rendered HTML and PDF
//   - Open either in your browser to see the charts

// ─── inline survey data ───────────────────────────────────────────────
Map<String, Object> data = new Map<String, Object>{
    'Name' => 'Q2 Employee Engagement Survey',
    'Survey_Responses__r' => new List<Object>{
        new Map<String, Object>{ 'Selected_Answer__c' => 'Strongly Agree', 'Department__c' => 'Engineering' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Agree', 'Department__c' => 'Engineering' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Agree', 'Department__c' => 'Engineering' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Agree', 'Department__c' => 'Sales' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Neutral', 'Department__c' => 'Sales' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Disagree', 'Department__c' => 'Sales' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Strongly Agree', 'Department__c' => 'Marketing' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Agree', 'Department__c' => 'Marketing' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Disagree', 'Department__c' => 'Support' },
        new Map<String, Object>{ 'Selected_Answer__c' => 'Strongly Disagree', 'Department__c' => 'Support' }
    }
};

// ─── template using the {Chart:...} tag ───────────────────────────────
String template =
    '<html><head><style>' +
    '@page { size: Letter; margin: 22mm 18mm; }' +
    'body { font-family: Helvetica, Arial, sans-serif; color: #1f2937; font-size: 11pt; line-height: 1.5; }' +
    'h1 { color: #1e3a8a; font-size: 24pt; margin: 0 0 6px 0; }' +
    '.subtitle { color: #6b7280; font-size: 11pt; margin-bottom: 24px; }' +
    '.page { page-break-after: always; }' +
    '</style></head><body>' +
    '<h1>{Name}</h1>' +
    '<p class="subtitle">Demo of all four chart-tag styles against inline data.</p>' +
    '<div class="page">' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Style 1 — Simple Bar (default)}' +
    '</div>' +
    '<div class="page">' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:pivot:title=Style 2 — Pivot (cross-tab by department)&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support}' +
    '</div>' +
    '<div class="page">' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:clustered:title=Style 3 — Vertical Clustered Bars&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support}' +
    '</div>' +
    '<div>' +
    '{Chart:Survey_Responses__r:Selected_Answer__c:stacked:title=Style 4 — Stacked Horizontal&groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support}' +
    '</div>' +
    '</body></html>';

// ─── render via the test entry point (HTML mode) ──────────────────────
String rendered;
try {
    // The 3-arg overload is @TestVisible private, so reflection isn't possible
    // from anon Apex. Use the 2-arg version after manually setting type via
    // the public-but-undocumented init pattern: expand the chart tag first
    // (which only needs templateType string), then run processXmlForTest.
    String expanded = DocGenChartTagExpander.expand(template, 'HTML');
    rendered = DocGenService.processXmlForTest(expanded, data);
    System.debug('Rendered HTML length: ' + rendered.length() + ' chars');
} catch (Exception e) {
    System.debug('RENDER FAILED: ' + e.getMessage());
    System.debug(e.getStackTraceString());
    return;
}

// ─── save HTML to Files ───────────────────────────────────────────────
ContentVersion htmlCv = new ContentVersion(
    Title = 'Chart Tag Demo — Rendered HTML',
    PathOnClient = 'chart-tag-demo.html',
    VersionData = Blob.valueOf(rendered),
    IsMajorVersion = true
);
insert htmlCv;

// ─── render to PDF and save ───────────────────────────────────────────
Blob pdfBlob;
try {
    pdfBlob = Blob.toPdf(rendered);
} catch (Exception e) {
    System.debug('PDF RENDER FAILED: ' + e.getMessage());
}

ContentVersion pdfCv;
if (pdfBlob != null) {
    pdfCv = new ContentVersion(
        Title = 'Chart Tag Demo — PDF',
        PathOnClient = 'chart-tag-demo.pdf',
        VersionData = pdfBlob,
        IsMajorVersion = true
    );
    insert pdfCv;
}

// ─── log download links ───────────────────────────────────────────────
ContentVersion htmlReloaded = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :htmlCv.Id];
String orgUrl = URL.getOrgDomainUrl().toExternalForm();

System.debug('========================================');
System.debug('CHART TAG DEMO — open these in your browser:');
System.debug('========================================');
System.debug('HTML preview (charts render with full styling):');
System.debug('  ' + orgUrl + '/sfc/servlet.shepherd/version/download/' + htmlCv.Id);
System.debug(
    '  or browse Files: ' + orgUrl + '/lightning/r/ContentDocument/' + htmlReloaded.ContentDocumentId + '/view'
);
if (pdfCv != null) {
    ContentVersion pdfReloaded = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :pdfCv.Id];
    System.debug('PDF (same content rendered by Blob.toPdf, Flying-Saucer-flavored):');
    System.debug('  ' + orgUrl + '/sfc/servlet.shepherd/version/download/' + pdfCv.Id);
    System.debug(
        '  or browse Files: ' + orgUrl + '/lightning/r/ContentDocument/' + pdfReloaded.ContentDocumentId + '/view'
    );
}
System.debug('========================================');
