// What happens to an absolutely positioned box when merged content OUTGROWS it,
// and when it sits past the bottom of page 1? This decides how a pixel-exact
// canvas can host {#Loop} content, which is the whole point of Portwood.
String rows = '';
for (Integer i = 1; i <= 40; i++) {
    rows += '<tr><td>Line item ' + i + '</td><td>$' + (i * 37) + '</td></tr>';
}
String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.5in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 9pt; }' +
    '.stage { position: relative; width: 7.5in; height: 9.5in; border: 1pt solid #333; }' +
    '.box { position: absolute; border: 1pt solid #000; padding: 3pt; }' +
    '.grow { left: 0.2in; top: 0.4in; width: 3.2in; height: 1.2in; background: #ffd400; }' +
    '.past { left: 0.2in; top: 10.5in; width: 3in; background: #ffb3b3; }' +
    '.tall { left: 4.0in; top: 0.4in; width: 3.0in; background: #c8f7c5; }' +
    'table { border-collapse: collapse; width: 100%; } td { border: 0.5pt solid #999; padding: 1pt 3pt; }' +
    '</style></head><body><div class="stage">' +
    '<div class="box grow"><b>FIXED-HEIGHT BOX (1.2in) with 40 rows</b><table>' +
    rows +
    '</table></div>' +
    '<div class="box tall"><b>AUTO-HEIGHT BOX with 40 rows</b><table>' +
    rows +
    '</table></div>' +
    '<div class="box past">BOX POSITIONED AT TOP:10.5in (past page 1)</div>' +
    '</div></body></html>';
Blob pdf = Blob.toPdf(html);
String b64 = EncodingUtil.base64Encode(pdf);
System.debug('PAGESIZE ' + pdf.size());
for (Integer i = 0; i < b64.length(); i += 900) {
    System.debug('B64>' + b64.substring(i, Math.min(i + 900, b64.length())));
}
