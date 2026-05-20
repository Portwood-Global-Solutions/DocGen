// #117 spike — compare PDF sizes with vs without SVG to detect silent drop.
// If withSvgSize ≈ withoutSvgSize, Flying Saucer is ignoring the SVG.

String headerHtml =
    '<html><head><meta charset="utf-8"/><style>' +
    '@page { size: letter; margin: 0.75in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; }' +
    '</style></head><body>';

String footerHtml = '</body></html>';

String svgBlock =
    '<svg width="500" height="180" xmlns="http://www.w3.org/2000/svg">' +
    '<rect x="0" y="0" width="500" height="180" fill="#3b82f6"/>' +
    '<rect x="50" y="50" width="400" height="80" fill="#10b981"/>' +
    '<text x="250" y="100" font-family="Arial" font-size="32" fill="#fff" text-anchor="middle">SVG TEST</text>' +
    '<circle cx="100" cy="150" r="20" fill="#ef4444"/>' +
    '<circle cx="200" cy="150" r="20" fill="#f59e0b"/>' +
    '<circle cx="300" cy="150" r="20" fill="#8b5cf6"/>' +
    '<circle cx="400" cy="150" r="20" fill="#ec4899"/>' +
    '</svg>';

String body = '<p>Some text paragraph that contributes to PDF size with text glyphs.</p>';

String withSvg = headerHtml + body + '<div>' + svgBlock + '</div>' + body + footerHtml;
String withoutSvg = headerHtml + body + '<div>(no svg here)</div>' + body + footerHtml;
String withImg =
    headerHtml +
    body +
    '<div><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=" ' +
    'width="500" height="180" alt="placeholder"/></div>' +
    body +
    footerHtml;

Blob pdfWith = Blob.toPdf(withSvg);
Blob pdfWithout = Blob.toPdf(withoutSvg);
Blob pdfImg = Blob.toPdf(withImg);

System.debug('PDF size with SVG:    ' + pdfWith.size() + ' bytes');
System.debug('PDF size without SVG: ' + pdfWithout.size() + ' bytes');
System.debug('PDF size with <img>:  ' + pdfImg.size() + ' bytes');
System.debug('Delta SVG vs control: ' + (pdfWith.size() - pdfWithout.size()) + ' bytes');
System.debug('Delta IMG vs control: ' + (pdfImg.size() - pdfWithout.size()) + ' bytes');

// PDF bytes are not UTF-8; base64-encode and search for hex signatures instead.
String b64With = EncodingUtil.base64Encode(pdfWith);
String b64Without = EncodingUtil.base64Encode(pdfWithout);
System.debug('b64 size with SVG:    ' + b64With.length() + ' chars');
System.debug('b64 size without SVG: ' + b64Without.length() + ' chars');
// PDF "SVG TEST" text would be encoded in font glyphs, hard to grep. Size delta
// is the signal — if SVG was rendered, the page content stream gains rect/text
// operators and the base64 length grows by hundreds of bytes per shape.
