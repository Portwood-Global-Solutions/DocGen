// #117 spike round 4 — known-good SVG sample (Mozilla MDN canonical shape).
// If THIS doesn't render via the CV-URL path, the SVG itself isn't the issue
// — Flying Saucer's image renderer just doesn't rasterize SVG.

// Canonical MDN SVG sample — simple shapes, no exotic features, well-formed.
// Anyone visiting https://developer.mozilla.org/en-US/docs/Web/SVG/Element/svg
// sees this rendered correctly in every modern browser.
String svg =
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' +
    '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" ' +
    'width="300" height="200" viewBox="0 0 300 200">' +
    '<rect width="100%" height="100%" fill="#f0f9ff"/>' +
    '<circle cx="150" cy="100" r="80" stroke="#1e40af" stroke-width="4" fill="#3b82f6"/>' +
    '<text x="150" y="105" font-family="Arial" font-size="24" fill="white" text-anchor="middle">OK</text>' +
    '</svg>';

ContentVersion svgCv = new ContentVersion(
    Title = 'spike-117-mdn-svg-' + System.now().getTime(),
    PathOnClient = 'mdn-canonical.svg',
    VersionData = Blob.valueOf(svg),
    IsMajorVersion = true
);
insert svgCv;
ContentVersion svgSaved = [SELECT Id, FileExtension, FileType FROM ContentVersion WHERE Id = :svgCv.Id LIMIT 1];
String svgUrl = '/sfc/servlet.shepherd/version/download/' + svgSaved.Id;
System.debug('SVG saved: ' + svgSaved.FileType + ' / ' + svgSaved.FileExtension + ' at ' + svgUrl);

// Same SVG, two reference forms — URL-via-CV and data-URI — in one PDF.
String b64 = EncodingUtil.base64Encode(Blob.valueOf(svg));

String html =
    '<html><head><meta charset="utf-8"/><style>' +
    '@page { size: letter; margin: 0.6in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; }' +
    '.box { border: 1px dashed #d1d5db; padding: 8pt; margin-bottom: 14pt; }' +
    '</style></head><body>' +
    '<h1>#117 spike round 4 — MDN-canonical SVG, two reference paths</h1>' +
    '<p>Same well-formed SVG (the canonical MDN sample), embedded two ways.</p>' +
    '<h2>Path A — via CV URL (' +
    svgUrl +
    ')</h2>' +
    '<div class="box"><img src="' +
    svgUrl +
    '" width="300" height="200" alt="svg-via-cv-url"/></div>' +
    '<h2>Path B — via data URI</h2>' +
    '<div class="box"><img src="data:image/svg+xml;base64,' +
    b64 +
    '" width="300" height="200" alt="svg-data-uri"/></div>' +
    '<h2>Control — same shape as PNG (visible red 100x50)</h2>' +
    '<div class="box">' +
    '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGQAAAAyCAYAAACqNX6+AAAAGUlEQVR42mP8z8DwHwAFBQIAXfa1KAAAAABJRU5ErkJggg==" ' +
    'width="100" height="50" alt="png-control"/></div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);
ContentVersion pdfCv = new ContentVersion(
    Title = 'spike-117-mdn-pdf-' + System.now().getTime(),
    PathOnClient = 'spike-117-mdn.pdf',
    VersionData = pdf,
    IsMajorVersion = true
);
insert pdfCv;
ContentVersion pdfSaved = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :pdfCv.Id LIMIT 1];

System.debug('=== Spike #117 round 4 ===');
System.debug('PDF size:    ' + pdf.size() + ' bytes');
System.debug('SVG CV URL:  ' + URL.getOrgDomainURL().toExternalForm() + svgUrl);
System.debug(
    'Open PDF:    ' +
        URL.getOrgDomainURL().toExternalForm() +
        '/lightning/r/ContentDocument/' +
        pdfSaved.ContentDocumentId +
        '/view'
);
