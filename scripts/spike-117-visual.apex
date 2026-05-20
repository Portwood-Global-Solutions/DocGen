// #117 spike — single PDF with three rendering paths for the same chart.
// Open the resulting PDF in Salesforce to see which (if any) actually rendered.
//
// Path A — inline <svg>
// Path B — <img src="data:image/svg+xml;base64,...">
// Path C — <img src="data:image/png;base64,...">  (real 200x80 red PNG)

String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="120">' +
    '<rect x="0" y="0" width="500" height="120" fill="#fef3c7" stroke="#92400e" stroke-width="2"/>' +
    '<rect x="20" y="40" width="200" height="40" fill="#3b82f6"/>' +
    '<text x="120" y="65" font-family="Arial" font-size="20" fill="#fff" text-anchor="middle">BAR</text>' +
    '<circle cx="320" cy="60" r="30" fill="#10b981"/>' +
    '<text x="400" y="65" font-family="Arial" font-size="18" fill="#000">If you see this, SVG works.</text>' +
    '</svg>';

String b64Svg = EncodingUtil.base64Encode(Blob.valueOf(svg));

// Solid red 100x50 PNG (visible, not 1x1 like before)
String pngBytes =
    'iVBORw0KGgoAAAANSUhEUgAAAGQAAAAyCAYAAACqNX6+AAAAGUlEQVR42mP8z8DwHwAFBQIAX' + 'fa1KAAAAABJRU5ErkJggg==';

String html =
    '<html><head><meta charset="utf-8"/><style>' +
    '@page { size: letter; margin: 0.6in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; }' +
    'h2 { font-size: 14pt; margin: 18pt 0 4pt 0; color: #1e40af; }' +
    '.label { color: #6b7280; font-size: 10pt; margin: 0 0 4pt 0; }' +
    '.box { border: 1px dashed #d1d5db; padding: 8pt; margin-bottom: 14pt; min-height: 130px; }' +
    '</style></head><body>' +
    '<h1>#117 spike — Flying Saucer SVG rendering paths</h1>' +
    '<p>Three rendering paths, same target chart. Whichever cell shows the colored bar + circle + text ' +
    '"If you see this, SVG works." renders correctly. Empty boxes mean Flying Saucer dropped the content.</p>' +
    '<h2>Path A — inline &lt;svg&gt;</h2>' +
    '<p class="label">Expected to fail per round-1 spike (silent drop).</p>' +
    '<div class="box">' +
    svg +
    '</div>' +
    '<h2>Path B — &lt;img src="data:image/svg+xml;base64,..."&gt;</h2>' +
    '<p class="label">Unknown — round-2 byte delta was suspicious.</p>' +
    '<div class="box"><img src="data:image/svg+xml;base64,' +
    b64Svg +
    '" width="500" height="120" alt="svg-as-img"/></div>' +
    '<h2>Path C — &lt;img src="data:image/png;base64,..."&gt; (control: 100x50 red PNG)</h2>' +
    '<p class="label">Should render — confirms the data-URI image path works at all.</p>' +
    '<div class="box"><img src="data:image/png;base64,' +
    pngBytes +
    '" width="100" height="50" alt="png-control"/></div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);

ContentVersion cv = new ContentVersion(
    Title = 'spike-117-visual-' + System.now().getTime(),
    PathOnClient = 'spike-117-visual.pdf',
    VersionData = pdf,
    IsMajorVersion = true
);
insert cv;
ContentVersion saved = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

System.debug('=== Spike #117 visual ===');
System.debug('PDF size: ' + pdf.size() + ' bytes');
System.debug('CV Id:    ' + saved.Id);
System.debug(
    'Open:     ' +
        URL.getOrgDomainURL().toExternalForm() +
        '/lightning/r/ContentDocument/' +
        saved.ContentDocumentId +
        '/view'
);
