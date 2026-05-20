// Spike for #117 — verify Flying Saucer renders inline SVG inside Blob.toPdf
// Run: sf apex run --target-org portwood-staging -f scripts/spike-117-svg-flying-saucer.apex
// Output: ContentVersion with the rendered PDF — URL is logged at the end.
//
// Five test cards, each a self-contained SVG. If the resulting PDF shows all
// five renderings correctly, the SVG serializer path (issue #117) is unblocked
// for the PDF output target. Failures isolate which SVG features Flying Saucer
// drops so the serializer can avoid them.

// ---- Card 1 — minimal horizontal bar (the v1 chart shape) ----
String card1 =
    '<svg width="500" height="180" xmlns="http://www.w3.org/2000/svg">' +
    '<text x="0" y="15" font-family="Arial" font-size="11" fill="#000">Very Satisfied</text>' +
    '<rect x="120" y="3" width="320" height="15" fill="#3b82f6"/>' +
    '<text x="445" y="15" font-family="Arial" font-size="11" fill="#000">42 (80%)</text>' +
    '<text x="0" y="40" font-family="Arial" font-size="11" fill="#000">Satisfied</text>' +
    '<rect x="120" y="28" width="200" height="15" fill="#10b981"/>' +
    '<text x="325" y="40" font-family="Arial" font-size="11" fill="#000">27 (52%)</text>' +
    '<text x="0" y="65" font-family="Arial" font-size="11" fill="#000">Neutral</text>' +
    '<rect x="120" y="53" width="80" height="15" fill="#f59e0b"/>' +
    '<text x="205" y="65" font-family="Arial" font-size="11" fill="#000">11 (21%)</text>' +
    '<text x="0" y="90" font-family="Arial" font-size="11" fill="#000">Dissatisfied</text>' +
    '<rect x="120" y="78" width="40" height="15" fill="#ef4444"/>' +
    '<text x="165" y="90" font-family="Arial" font-size="11" fill="#000">5 (10%)</text>' +
    '</svg>';

// ---- Card 2 — same shape but grouped via <g> ----
String card2 =
    '<svg width="500" height="100" xmlns="http://www.w3.org/2000/svg">' +
    '<g font-family="Arial" font-size="11" fill="#000">' +
    '<text x="0" y="15">Engineering</text>' +
    '<rect x="120" y="3" width="280" height="15" fill="#8b5cf6"/>' +
    '<text x="405" y="15">35</text>' +
    '<text x="0" y="40">Sales</text>' +
    '<rect x="120" y="28" width="160" height="15" fill="#ec4899"/>' +
    '<text x="285" y="40">20</text>' +
    '</g>' +
    '</svg>';

// ---- Card 3 — vertical clustered bars (column chart) ----
String card3 =
    '<svg width="500" height="200" xmlns="http://www.w3.org/2000/svg">' +
    '<line x1="40" y1="180" x2="480" y2="180" stroke="#000" stroke-width="1"/>' +
    '<rect x="60" y="80" width="40" height="100" fill="#3b82f6"/>' +
    '<rect x="105" y="50" width="40" height="130" fill="#10b981"/>' +
    '<rect x="170" y="120" width="40" height="60" fill="#3b82f6"/>' +
    '<rect x="215" y="100" width="40" height="80" fill="#10b981"/>' +
    '<rect x="280" y="60" width="40" height="120" fill="#3b82f6"/>' +
    '<rect x="325" y="40" width="40" height="140" fill="#10b981"/>' +
    '<text x="60" y="195" font-family="Arial" font-size="10" fill="#000">Q1</text>' +
    '<text x="170" y="195" font-family="Arial" font-size="10" fill="#000">Q2</text>' +
    '<text x="280" y="195" font-family="Arial" font-size="10" fill="#000">Q3</text>' +
    '</svg>';

// ---- Card 4 — stacked horizontal bar (composition) ----
String card4 =
    '<svg width="500" height="80" xmlns="http://www.w3.org/2000/svg">' +
    '<text x="0" y="20" font-family="Arial" font-size="11" fill="#000">2026 Q1 Mix</text>' +
    '<rect x="100" y="8" width="180" height="20" fill="#3b82f6"/>' +
    '<rect x="280" y="8" width="120" height="20" fill="#10b981"/>' +
    '<rect x="400" y="8" width="60" height="20" fill="#f59e0b"/>' +
    '<text x="0" y="55" font-family="Arial" font-size="11" fill="#000">2026 Q2 Mix</text>' +
    '<rect x="100" y="43" width="220" height="20" fill="#3b82f6"/>' +
    '<rect x="320" y="43" width="90" height="20" fill="#10b981"/>' +
    '<rect x="410" y="43" width="50" height="20" fill="#f59e0b"/>' +
    '</svg>';

// ---- Card 5 — feature stress test (transform + opacity + nested g) ----
String card5 =
    '<svg width="500" height="120" xmlns="http://www.w3.org/2000/svg">' +
    '<g transform="translate(20,20)">' +
    '<rect x="0" y="0" width="100" height="60" fill="#3b82f6" opacity="0.8"/>' +
    '<text x="50" y="35" font-family="Arial" font-size="14" fill="#fff" text-anchor="middle">SVG</text>' +
    '</g>' +
    '<g transform="translate(140,20)">' +
    '<circle cx="50" cy="30" r="30" fill="#10b981"/>' +
    '<text x="50" y="35" font-family="Arial" font-size="14" fill="#fff" text-anchor="middle">Circle</text>' +
    '</g>' +
    '<g transform="translate(260,20)">' +
    '<polygon points="50,0 100,60 0,60" fill="#f59e0b"/>' +
    '<text x="50" y="50" font-family="Arial" font-size="14" fill="#000" text-anchor="middle">Tri</text>' +
    '</g>' +
    '</svg>';

String html =
    '<html><head><meta charset="utf-8"/><style>' +
    '@page { size: letter; margin: 0.75in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; }' +
    'h2 { font-size: 13pt; margin: 16pt 0 4pt 0; }' +
    '.card { border: 1px solid #ccc; padding: 8pt; margin-bottom: 10pt; }' +
    '</style></head><body>' +
    '<h1>SVG-in-PDF spike for #117 (Flying Saucer / Blob.toPdf)</h1>' +
    '<p>If each card below renders its SVG correctly, the SVG serializer for the chart epic (#116) ' +
    'is unblocked for the PDF output target.</p>' +
    '<h2>Card 1 — Horizontal bar (the v1 chart shape)</h2>' +
    '<div class="card">' +
    card1 +
    '</div>' +
    '<h2>Card 2 — Grouped via &lt;g&gt;</h2>' +
    '<div class="card">' +
    card2 +
    '</div>' +
    '<h2>Card 3 — Vertical clustered (columns)</h2>' +
    '<div class="card">' +
    card3 +
    '</div>' +
    '<h2>Card 4 — Stacked horizontal</h2>' +
    '<div class="card">' +
    card4 +
    '</div>' +
    '<h2>Card 5 — Feature stress (transform, opacity, circle, polygon, text-anchor)</h2>' +
    '<div class="card">' +
    card5 +
    '</div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);

ContentVersion cv = new ContentVersion(
    Title = 'spike-117-svg-flying-saucer-' + System.now().getTime(),
    PathOnClient = 'spike-117-svg.pdf',
    VersionData = pdf,
    IsMajorVersion = true
);
insert cv;

ContentVersion saved = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
System.debug('SPIKE PDF SAVED');
System.debug('CV Id:    ' + saved.Id);
System.debug('Doc Id:   ' + saved.ContentDocumentId);
System.debug('PDF size: ' + pdf.size() + ' bytes');
System.debug('URL:      /sfc/servlet.shepherd/version/download/' + saved.Id);
System.debug(
    'Or open:  ' +
        URL.getOrgDomainURL().toExternalForm() +
        '/lightning/r/ContentDocument/' +
        saved.ContentDocumentId +
        '/view'
);
