// FONT + SHAPE capability probe. Rendered output: docs/css-probe-fonts.png and
// docs/css-probe-fonts-and-shapes.png.
//
// RESULT as of 2026-08-05 — only THREE faces exist:
//   sans-serif            a real sans face
//   serif                 the default; ALSO what every named family falls back to
//   monospace / Courier   monospace
// Helvetica, Arial, Georgia, Verdana, Tahoma, Impact, Times New Roman and Courier New
// ALL silently render as serif. A font picker offering them would quietly break
// WYSIWYG, so canvasModel.FONT_CHOICES offers only the three generics.
// (Existing templates saying "Helvetica, Arial, sans-serif" render sans only because
// the list falls through to the generic at the end.)
//
// SHAPES: border-radius and transform are ignored (a circle renders as a square), and
// the geometric characters U+25CF/25CB/25C6/25A0/25BC/2605 render as NOTHING in all
// three faces. Rectangles and lines are the only native shapes; anything curved has
// to be a rasterized image, the way DocGenChartRasterizer already builds chart PNGs.
//
// Unquoted family names + generics, to rule out a quoting artefact in the first probe.
String rows = '';
for (
    String f : new List<String>{
        'Helvetica',
        'Arial',
        'sans-serif',
        'Times',
        'Times New Roman',
        'serif',
        'Courier',
        'Courier New',
        'monospace',
        'Georgia',
        'Verdana',
        'Impact'
    }
) {
    rows +=
        '<tr><td style="width:2in">' +
        f +
        '</td><td style="font-family:' +
        f +
        '; font-size:14pt">Handgloves 123 Wq</td></tr>';
}
String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.4in; }' +
    'body { font-size: 9pt; }' +
    'table { border-collapse: collapse; width: 100%; } td { border: 0.5pt solid #ccc; padding: 2pt 4pt; }' +
    '</style></head><body>' +
    '<p><b>UNQUOTED FONT FAMILIES</b></p><table>' +
    rows +
    '</table>' +
    '<p style="margin-top:8pt"><b>GEOMETRIC GLYPHS</b> at 30pt, in the default face and in each generic</p>' +
    '<table><tr><td>default</td><td style="font-size:30pt">&#9679; &#9675; &#9670; &#9632; &#9660; &#9733;</td></tr>' +
    '<tr><td>sans-serif</td><td style="font-family:sans-serif; font-size:30pt">&#9679; &#9675; &#9670; &#9632; &#9660; &#9733;</td></tr>' +
    '<tr><td>serif</td><td style="font-family:serif; font-size:30pt">&#9679; &#9675; &#9670; &#9632; &#9660; &#9733;</td></tr></table>' +
    '</body></html>';
Blob pdf = Blob.toPdf(html);
String b64 = EncodingUtil.base64Encode(pdf);
for (Integer i = 0; i < b64.length(); i += 900) {
    System.debug('B64>' + b64.substring(i, Math.min(i + 900, b64.length())));
}
