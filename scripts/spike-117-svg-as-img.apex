// #117 spike round 2 — does Flying Saucer accept SVG via <img src="data:image/svg+xml;base64,...">?
// Inline <svg>...</svg> is silently dropped (spike round 1). SVG-as-img is the
// fallback dance some PDF engines (xmlworker, PDFBox-backed) accept.

String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="180">' +
    '<rect x="0" y="0" width="500" height="180" fill="#3b82f6"/>' +
    '<rect x="50" y="50" width="400" height="80" fill="#10b981"/>' +
    '<text x="250" y="100" font-family="Arial" font-size="32" fill="#fff" text-anchor="middle">SVG IMG</text>' +
    '<circle cx="100" cy="150" r="20" fill="#ef4444"/>' +
    '</svg>';

String b64Svg = EncodingUtil.base64Encode(Blob.valueOf(svg));
String svgImg = '<img src="data:image/svg+xml;base64,' + b64Svg + '" width="500" height="180" alt="svg"/>';
String pngImg =
    '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=" ' +
    'width="500" height="180" alt="png"/>';

String shell = '<html><head><style>@page { size: letter; margin: 0.75in; }</style></head><body><p>X</p>';
String tail = '</body></html>';

Blob pdfControl = Blob.toPdf(shell + tail);
Blob pdfSvgImg = Blob.toPdf(shell + svgImg + tail);
Blob pdfPngImg = Blob.toPdf(shell + pngImg + tail);
Blob pdfSvgInline = Blob.toPdf(shell + '<div>' + svg + '</div>' + tail);

System.debug('=== Spike #117 round 2 ===');
System.debug('Control (just <p>X</p>):                       ' + pdfControl.size() + ' bytes');
System.debug('+ <img src="data:image/svg+xml;base64,...">:   ' + pdfSvgImg.size() + ' bytes');
System.debug('+ <img src="data:image/png;base64,...">:       ' + pdfPngImg.size() + ' bytes');
System.debug('+ inline <svg>...</svg> (round 1 control):     ' + pdfSvgInline.size() + ' bytes');
System.debug('');
System.debug('Delta SVG-as-img vs control: ' + (pdfSvgImg.size() - pdfControl.size()));
System.debug('Delta PNG-as-img vs control: ' + (pdfPngImg.size() - pdfControl.size()));
System.debug('Delta inline-svg vs control: ' + (pdfSvgInline.size() - pdfControl.size()));
