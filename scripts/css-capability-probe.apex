// CSS capability probe — what Flying Saucer (Blob.toPdf) actually honours.
//
// Renders a labelled swatch per property and stores the PDF as a ContentVersion.
// Each swatch is compared against a CONTROL row: a swatch identical to the
// control means the property was silently ignored. Answers "can I round the
// corners of this table?" by MEASURING rather than by reading a spec, which
// matters because Flying Saucer is CSS 2.1 plus an idiosyncratic subset of
// CSS 3 that no document lists exactly.
//
//   sf apex run --target-org <org> -f scripts/css-capability-probe.apex
//   # then, using the OUTCV id it prints:
//   curl -sS -H "Authorization: Bearer $TOKEN" \
//     "$URL/services/data/v62.0/sobjects/ContentVersion/<id>/VersionData" -o probe.pdf
//   pdftoppm -png -r 150 probe.pdf probe
//
// RESULT as of 2026-07-25 (rendered output: docs/css-capability-probe.png):
//   IGNORED — border-radius in every form, including on a <td> and on a
//             border-collapse:separate <table>; -fs-border-radius; box-shadow;
//             opacity; transform; calc(); outline.
//   WORKS   — border: dashed, border: dotted (both CSS 2.1).
//   linear-gradient() is discarded at PARSE time, so the cascade falls back to
//   any earlier solid background — harmless.
//   rgba() is NOT: it resolves to nothing and the background disappears
//   entirely. A tinted panel silently becomes invisible. Use a pre-computed
//   flat hex instead.
//
// Re-run this after any Salesforce release that might move the engine version.
String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.5in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 9pt; color: #111; }' +
    'h1 { font-size: 14pt; margin: 0 0 2pt 0; }' +
    'p.sub { color: #555; margin: 0 0 10pt 0; font-size: 8pt; }' +
    'table.probe { border-collapse: collapse; width: 100%; }' +
    'table.probe td { border: 0.5pt solid #ccc; padding: 6pt; vertical-align: middle; }' +
    'td.lbl { width: 38%; font-size: 8pt; }' +
    'code { font-family: Courier, monospace; font-size: 7.5pt; color: #036; }' +
    '.box { width: 130pt; height: 26pt; background: #2b6cb0; color: #fff; ' +
    'text-align: center; line-height: 26pt; font-size: 8pt; }' +
    // --- the properties under test -------------------------------------------
    '.r6   { border-radius: 6pt; }' +
    '.r14  { border-radius: 14pt; }' +
    '.pill { border-radius: 13pt; }' +
    '.corner { border-radius: 12pt 0 12pt 0; }' +
    '.fsr  { -fs-border-radius: 8pt; }' +
    '.shadow { box-shadow: 3pt 3pt 4pt #888; }' +
    '.op   { opacity: 0.45; }' +
    '.rgba { background: rgba(43,108,176,0.35); color:#111; }' +
    '.grad { background: linear-gradient(90deg,#2b6cb0,#63b3ed); }' +
    '.rot  { transform: rotate(-4deg); }' +
    '.calcw { width: calc(100% - 40pt); }' +
    '.dash { border: 2pt dashed #2b6cb0; background: #fff; color:#111; }' +
    '.dot  { border: 2pt dotted #b02b2b; background: #fff; color:#111; }' +
    '.outl { outline: 2pt solid #b02b2b; background:#fff; color:#111; }' +
    // A rounded CELL, not a div — the specific thing asked about.
    'td.roundcell { border: 2pt solid #2b6cb0; border-radius: 10pt; background: #eaf2fb; }' +
    // Rounded table with separated borders (the usual way it is attempted).
    'table.rt { border-collapse: separate; border-spacing: 0; border: 2pt solid #2b6cb0; ' +
    'border-radius: 10pt; width: 220pt; }' +
    'table.rt td { border: 0; padding: 5pt; font-size: 8pt; }' +
    '</style></head><body>' +
    '<h1>Flying Saucer CSS capability probe</h1>' +
    '<p class="sub">Rendered by Blob.toPdf. A swatch that looks like the plain control ' +
    'means the property was ignored.</p>' +
    '<table class="probe">' +
    '<tr><td class="lbl"><b>CONTROL</b> — plain square box</td><td><div class="box">control</div></td></tr>' +
    '<tr><td class="lbl"><code>border-radius: 6pt</code></td><td><div class="box r6">radius 6</div></td></tr>' +
    '<tr><td class="lbl"><code>border-radius: 14pt</code></td><td><div class="box r14">radius 14</div></td></tr>' +
    '<tr><td class="lbl"><code>border-radius: 13pt</code> (pill)</td><td><div class="box pill">pill</div></td></tr>' +
    '<tr><td class="lbl"><code>border-radius: 12pt 0 12pt 0</code></td><td><div class="box corner">two corners</div></td></tr>' +
    '<tr><td class="lbl"><code>-fs-border-radius: 8pt</code> (FS-proprietary)</td><td><div class="box fsr">fs radius</div></td></tr>' +
    '<tr><td class="lbl"><code>box-shadow</code></td><td><div class="box shadow">shadow</div></td></tr>' +
    '<tr><td class="lbl"><code>opacity: 0.45</code></td><td><div class="box op">opacity</div></td></tr>' +
    '<tr><td class="lbl"><code>rgba() background</code></td><td><div class="box rgba">rgba 35%</div></td></tr>' +
    '<tr><td class="lbl"><code>linear-gradient()</code></td><td><div class="box grad">gradient</div></td></tr>' +
    '<tr><td class="lbl"><code>transform: rotate(-4deg)</code></td><td><div class="box rot">rotated</div></td></tr>' +
    '<tr><td class="lbl"><code>width: calc(100% - 40pt)</code></td><td><div class="box calcw">calc</div></td></tr>' +
    '<tr><td class="lbl"><code>border: dashed</code> (CSS 2.1)</td><td><div class="box dash">dashed</div></td></tr>' +
    '<tr><td class="lbl"><code>border: dotted</code> (CSS 2.1)</td><td><div class="box dot">dotted</div></td></tr>' +
    '<tr><td class="lbl"><code>outline</code> (CSS 2.1)</td><td><div class="box outl">outline</div></td></tr>' +
    '<tr><td class="lbl"><code>border-radius</code> on a <b>TD</b></td><td class="roundcell">rounded table cell</td></tr>' +
    '<tr><td class="lbl"><code>border-radius</code> on a <b>TABLE</b><br/>(border-collapse: separate)</td>' +
    '<td><table class="rt"><tr><td>rounded table, row 1</td></tr><tr><td>row 2</td></tr></table></td></tr>' +
    '</table></body></html>';

// Minimal template: HTML in, PDF out. Named so the reset scripts leave it alone.
String nm = 'ZZ CSS Probe';
delete [SELECT Id FROM DocGen_Template__c WHERE Name = :nm];
Account a = [SELECT Id FROM Account LIMIT 1];
DocGen_Template__c t = new DocGen_Template__c(
    Name = nm,
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Base_Object_API__c = 'Account',
    Query_Config__c = 'Name',
    Is_Active__c = true,
    Test_Record_Id__c = a.Id
);
insert t;
ContentVersion cv = new ContentVersion(
    Title = 'zz_css_probe_body',
    PathOnClient = 'probe.html',
    VersionData = Blob.valueOf(html),
    FirstPublishLocationId = t.Id
);
insert cv;
cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
insert new DocGen_Template_Version__c(Template__c = t.Id, Content_Version_Id__c = cv.Id, Is_Active__c = true);

Map<String, Object> res = DocGenService.processDocument(t.Id, a.Id, null, null);
Blob pdf = (Blob) res.get('blob');
ContentVersion outCv = new ContentVersion(
    Title = 'zz_css_probe_output',
    PathOnClient = 'css-probe.pdf',
    VersionData = pdf
);
insert outCv;
System.debug('PDFBYTES=' + pdf.size());
System.debug('OUTCV=' + [SELECT Id FROM ContentVersion WHERE Id = :outCv.Id].Id);
