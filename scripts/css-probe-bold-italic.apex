// Do bold and italic actually reach the PDF in each family? Checked because a low-DPI
// raster made them look like they had been ignored, and "looks the same" is exactly
// how a silently-dropped property presents.
//
// RESULT as of 2026-08-05 — YES, in all three families. pdffonts on the output lists
// every one of the PDF base-14 faces as used:
//   Helvetica, Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique
//   Times-Roman, Times-Bold, Times-Italic, Times-BoldItalic
//   Courier, Courier-Bold, Courier-Oblique, Courier-BoldOblique
//
// So <b>, <i>, font-weight and font-style all select a real face. Verify this way —
// pdffonts, not eyeballing a PNG — because at 11-14pt the weight difference between
// these faces is genuinely hard to see in a screenshot.
// Does <b>/<i> actually render in each of the three families? Bold and italic need a
// real bold/italic FACE for the family; if the engine only has a regular face for one
// of them, the tag is honoured in the markup and invisible on the page.
String row =
    '<td style="font-family:FAM">Regular <b>BOLD</b> <i>italic</i> <b><i>bold-italic</i></b> ' +
    '<span style="font-weight:bold">span-bold</span> <span style="font-weight:700">700</span></td>';
String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.5in; }' +
    'body { font-size: 11pt; } table { border-collapse: collapse; width: 100%; }' +
    'td { border: 0.5pt solid #ccc; padding: 5pt; font-size: 13pt; }' +
    '</style></head><body><table>' +
    '<tr><td style="width:1.2in">sans-serif</td>' +
    row.replace('FAM', 'sans-serif') +
    '</tr>' +
    '<tr><td>serif</td>' +
    row.replace('FAM', 'serif') +
    '</tr>' +
    '<tr><td>monospace</td>' +
    row.replace('FAM', 'monospace') +
    '</tr>' +
    '</table></body></html>';
Blob pdf = Blob.toPdf(html);
String b = EncodingUtil.base64Encode(pdf);
for (Integer i = 0; i < b.length(); i += 900) {
    System.debug('B64>' + b.substring(i, Math.min(i + 900, b.length())));
}
