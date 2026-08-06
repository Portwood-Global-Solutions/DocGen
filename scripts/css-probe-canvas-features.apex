// Canvas feature-set capability probe. Rendered output: docs/css-probe-canvas-features.png
//
// RESULT as of 2026-08-05 — everything here was MEASURED, not assumed:
//   z-index                WORKS. Declared stacking is honoured, so element layering
//                          (bring forward / send backward) is buildable.
//   text-decoration        underline AND line-through both work.
//   bold / italic          work, and combine with underline.
//   text-transform         uppercase works.
//   letter-spacing         works.
//   vertical-align: super  works (pair with a smaller font-size).
//   nested tables          work, including per-cell borders on the inner table.
//   table in an absolute box  works.
//   rgba(...)              renders NOTHING — the background vanishes entirely rather
//                          than degrading. Always emit a flat hex.
//   opacity                IGNORED — the element paints at full strength. There is no
//                          transparency; fake it with a lighter hex.
//
// Re-run after any Salesforce release that might move the engine version.
// Open questions from the canvas feature list, answered by rendering rather than guessing:
// z-index layering, strikethrough, nested tables, per-cell borders, and a table
// inside an absolutely positioned box.
String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.4in; }' +
    'body { font-family: sans-serif; font-size: 10pt; }' +
    '.stage { position: relative; height: 2.2in; border: 1pt solid #ccc; }' +
    '.z { position: absolute; width: 1.6in; height: 1in; padding: 4pt; border: 1pt solid #000; }' +
    '.zA { left: 0.2in; top: 0.2in; background: #ffd400; z-index: 1; }' +
    '.zB { left: 0.9in; top: 0.5in; background: #9fd7ff; z-index: 5; }' +
    '.zC { left: 1.6in; top: 0.8in; background: #c8f7c5; z-index: 3; }' +
    'table { border-collapse: collapse; } td { border: 0.5pt solid #666; padding: 3pt; }' +
    '.outer td { background: #f4f4f4; }' +
    '.inner td { border: 0.5pt dashed #c00; background: #fff; }' +
    '.boxed { position: absolute; left: 4.2in; top: 0.2in; width: 3in; border: 2pt solid #06c; padding: 4pt; }' +
    '</style></head><body>' +
    '<p><b>Z-INDEX</b> — if honoured, blue (z:5) is on top, green (z:3) middle, yellow (z:1) bottom.</p>' +
    '<div class="stage">' +
    '<div class="z zA">A z-index 1</div><div class="z zB">B z-index 5</div><div class="z zC">C z-index 3</div>' +
    '<div class="boxed"><b>Table inside an absolute box</b>' +
    '<table class="outer"><tr><td>Cell</td><td>Cell</td></tr></table></div>' +
    '</div>' +
    '<p style="margin-top:8pt"><b>TEXT DECORATION</b>: ' +
    '<span style="text-decoration: underline">underline</span> &middot; ' +
    '<span style="text-decoration: line-through">line-through</span> &middot; ' +
    '<span style="font-weight:bold">bold</span> &middot; ' +
    '<span style="font-style:italic">italic</span> &middot; ' +
    '<span style="font-weight:bold; font-style:italic; text-decoration:underline">all three</span> &middot; ' +
    '<span style="text-transform: uppercase">uppercase</span> &middot; ' +
    '<span style="letter-spacing: 2pt">spaced</span> &middot; ' +
    '<span style="vertical-align: super; font-size: 7pt">super</span></p>' +
    '<p><b>NESTED TABLE</b></p>' +
    '<table class="outer"><tr><td>Outer left</td>' +
    '<td><table class="inner"><tr><td>in 1</td><td>in 2</td></tr><tr><td>in 3</td><td>in 4</td></tr></table></td>' +
    '</tr></table>' +
    '<p><b>COLOUR FORMS</b>: ' +
    '<span style="background:#ffd400">flat hex</span> ' +
    '<span style="background:rgba(255,0,0,0.35)">rgba</span> ' +
    '<span style="background:#f00; opacity:0.4">opacity 0.4</span></p>' +
    '</body></html>';
Blob pdf = Blob.toPdf(html);
String b64 = EncodingUtil.base64Encode(pdf);
for (Integer i = 0; i < b64.length(); i += 900) {
    System.debug('B64>' + b64.substring(i, Math.min(i + 900, b64.length())));
}
