// #117 spike round 3 — SVG as CV referenced by relative URL.
// Dave's insight: images render via URL in Blob.toPdf (the existing {%ImageField}
// path). So persist the SVG as a ContentVersion with the svg MIME type and
// reference its /sfc/servlet.shepherd/version/download/<cvId> URL in the HTML
// like any other image. This sidesteps the inline-<svg> drop AND the iffy
// data-URI path.

String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="120">' +
    '<rect x="0" y="0" width="500" height="120" fill="#fef3c7" stroke="#92400e" stroke-width="2"/>' +
    '<rect x="20" y="40" width="200" height="40" fill="#3b82f6"/>' +
    '<text x="120" y="65" font-family="Arial" font-size="20" fill="#fff" text-anchor="middle">BAR</text>' +
    '<circle cx="320" cy="60" r="30" fill="#10b981"/>' +
    '<text x="380" y="65" font-family="Arial" font-size="16" fill="#000">URL-referenced SVG</text>' +
    '</svg>';

// Save the SVG bytes as a CV. PathOnClient = .svg so Salesforce sets the
// FileType / ContentType correctly. (FileExtension is derived from PathOnClient.)
ContentVersion svgCv = new ContentVersion(
    Title = 'spike-117-svg-asset-' + System.now().getTime(),
    PathOnClient = 'chart.svg',
    VersionData = Blob.valueOf(svg),
    IsMajorVersion = true
);
insert svgCv;
ContentVersion svgSaved = [SELECT Id, FileExtension, FileType FROM ContentVersion WHERE Id = :svgCv.Id LIMIT 1];
System.debug('SVG CV file type: ' + svgSaved.FileType + ' / ext: ' + svgSaved.FileExtension);

String svgUrl = '/sfc/servlet.shepherd/version/download/' + svgSaved.Id;

String html =
    '<html><head><meta charset="utf-8"/><style>' +
    '@page { size: letter; margin: 0.6in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; }' +
    '.box { border: 1px dashed #d1d5db; padding: 8pt; margin-bottom: 14pt; min-height: 130px; }' +
    '</style></head><body>' +
    '<h1>#117 spike round 3 — SVG via CV URL</h1>' +
    '<p>If the SVG renders below, the URL-referenced approach works and the SVG ' +
    'serializer for the chart epic can persist its output as a CV and reference it ' +
    'the same way {%ImageField} already does.</p>' +
    '<p>SVG CV URL: <code>' +
    svgUrl +
    '</code></p>' +
    '<div class="box"><img src="' +
    svgUrl +
    '" width="500" height="120" alt="svg-via-url"/></div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);

ContentVersion pdfCv = new ContentVersion(
    Title = 'spike-117-svg-via-cv-url-' + System.now().getTime(),
    PathOnClient = 'spike-117-svg-via-cv-url.pdf',
    VersionData = pdf,
    IsMajorVersion = true
);
insert pdfCv;
ContentVersion pdfSaved = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :pdfCv.Id LIMIT 1];

System.debug('=== Spike #117 round 3 ===');
System.debug('PDF size: ' + pdf.size() + ' bytes');
System.debug('SVG CV:   ' + svgSaved.Id);
System.debug('PDF CV:   ' + pdfSaved.Id);
System.debug(
    'Open PDF: ' +
        URL.getOrgDomainURL().toExternalForm() +
        '/lightning/r/ContentDocument/' +
        pdfSaved.ContentDocumentId +
        '/view'
);
