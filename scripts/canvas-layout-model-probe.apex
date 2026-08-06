// CANVAS LAYOUT MODEL — proving multipage + growing lists on a pixel-exact canvas.
//
// Absolute boxes are single-page (css-probe-positioning.apex). This probe establishes
// the adaptation that gets multipage AND flowing content without giving up pixel
// exactness, which is the whole question for a Canvas template type.
//
// THE MODEL (measured working, rendered output: docs/canvas-layout-model-p*.png)
//   artboard   position:relative block in NORMAL FLOW. One artboard = one page.
//              page-break-BEFORE:always on every artboard after the first.
//   pinned box position:absolute inside the artboard -> exact declared inch offsets.
//   flow region  a normal-flow block inside the artboard. Paginates like any block;
//              thead repeats via display:table-header-group + -fs-table-paginate.
//              Its artboard uses min-height, NOT height, or the flow overruns it.
//   chrome     @page margin boxes. These DO repeat on continuation pages; a pinned
//              box does NOT (it belongs to its artboard, which is one page).
//
// WHY page-break-BEFORE and not AFTER: with page-break-after on the artboard, a flow
// region that spilled onto the next page swallowed the break, and the FOLLOWING
// artboard drew its pinned boxes on top of the overflow table. Measured, see
// docs/canvas-layout-model-broken-after.png.
//
//   sf apex run --target-org <org> -f scripts/canvas-layout-model-probe.apex
//   # then base64-decode the B64> lines and pdftoppm the result

String rows = '';
for (Integer i = 1; i <= 60; i++) {
    rows += '<tr><td>Flowing line ' + i + '</td><td>$' + (i * 41) + '</td></tr>';
}

String html =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.5in; ' +
    '  @top-center { content: "RUNNING HEADER — should repeat on every page"; font-size: 8pt; color: #666; }' +
    '  @bottom-center { content: "page " counter(page) " of " counter(pages); font-size: 8pt; color: #666; } }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 9pt; color: #111; }' +
    // The artboard: in normal flow, so it starts a page; relative, so it is the
    // containing block for its pinned children.
    '.board { position: relative; width: 7.5in; height: 9.3in; border: 1pt solid #333; }' +
    '.board_flow { height: auto; min-height: 9.3in; }' +
    '.brk { page-break-before: always; }' +
    '.pin { position: absolute; border: 1pt solid #000; padding: 3pt; background: #ffd400; }' +
    '.p1 { left: 0.20in; top: 0.20in; width: 2.2in; }' +
    '.p2 { left: 4.60in; top: 0.20in; width: 2.5in; background: #9fd7ff; }' +
    '.p3 { left: 2.40in; top: 8.60in; width: 2.6in; background: #c8f7c5; }' +
    // The flowing region: NOT absolute. Normal flow inside the artboard.
    '.flow { position: relative; margin: 1.1in 0 0 0.20in; width: 4.0in; }' +
    'table { border-collapse: collapse; width: 100%; -fs-table-paginate: paginate; }' +
    'td { border: 0.5pt solid #999; padding: 1pt 3pt; }' +
    'thead { display: table-header-group; } th { border: 0.5pt solid #999; padding: 2pt 3pt; background: #eee; }' +
    '</style></head><body>' +
    // ---- Artboard 1: pinned only
    '<div class="board">' +
    '<div class="pin p1">BOARD 1 / PIN A &mdash; L0.20 T0.20</div>' +
    '<div class="pin p2">BOARD 1 / PIN B &mdash; L4.60 T0.20</div>' +
    '<div class="pin p3">BOARD 1 / PIN C &mdash; L2.40 T8.60</div>' +
    '</div>' +
    // ---- Artboard 2: pinned + a flowing table that cannot fit
    '<div class="board board_flow brk">' +
    '<div class="pin p1">BOARD 2 / PIN A &mdash; L0.20 T0.20</div>' +
    '<div class="pin p2">BOARD 2 / PIN B &mdash; L4.60 T0.20</div>' +
    '<div class="flow"><b>FLOWING TABLE (60 rows) — must spill to the next page</b>' +
    '<table><thead><tr><th>Item</th><th>Amount</th></tr></thead><tbody>' +
    rows +
    '</tbody></table></div>' +
    '</div>' +
    // ---- Artboard 3: pinned only again
    '<div class="board brk">' +
    '<div class="pin p1">BOARD 3 / PIN A &mdash; L0.20 T0.20</div>' +
    '<div class="pin p3">BOARD 3 / PIN C &mdash; L2.40 T8.60</div>' +
    '</div>' +
    '</body></html>';

Blob pdf = Blob.toPdf(html);
String b64 = EncodingUtil.base64Encode(pdf);
System.debug('SIZE ' + pdf.size());
for (Integer i = 0; i < b64.length(); i += 900) {
    System.debug('B64>' + b64.substring(i, Math.min(i + 900, b64.length())));
}
