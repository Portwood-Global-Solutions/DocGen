// Canvas serializer check — asserts the SHIPPED canvasModel emits the layout contract
// that was measured to work (scripts/canvas-layout-model-probe.apex).
// Pure Node, no org needed:  node scripts/qa/canvas-serializer-check.mjs
//
// Guards the rules that are counter-intuitive and would otherwise be "tidied" away:
// a pinned box must NOT emit height (it has to grow with merged content), a flow box
// uses margin rather than left/top, page-break lives on the artboard AFTER the first,
// the artboard uses min-height, the table loop wraps the <tr> inside <tbody>, and
// merge tags survive escaping.
import { readFileSync, writeFileSync } from 'node:fs';

const src = readFileSync(
    new URL('../../force-app/main/default/lwc/docGenCanvas/canvasModel.js', import.meta.url),
    'utf8'
);
writeFileSync('/tmp/canvasModel.check.mjs', src);
const m = await import('/tmp/canvasModel.check.mjs?v=' + Date.now());

const geo = m.pageGeometry('Letter', 'Portrait');
const doc = m.blankDocument();

const pin = m.newTextBox(2.4, 3.1, 2.5, 0.4);
pin.text = '{Name}\nIndustry: {Industry}';
doc.artboards[0].boxes.push(pin);

const marks = m.newTextBox(0.5, 3.6, 3, 0.4);
marks.text = 'Terms: **Net/30** //rush// __signed__ ~~void~~ {Name} 5 < 10';
doc.artboards[0].boxes.push(marks);

const cond = m.newTextBox(0.5, 4.2, 3, 0.4);
cond.text = '{#IF Amount > 100000}Large deal{/IF}';
doc.artboards[0].boxes.push(cond);

const tbl = m.newTableBox(0.3, 5.0, 6.9);
tbl.table.relationship = 'Opportunities';
tbl.table.columns = [
    { label: 'Opportunity', tag: '{Name}', width: '45%' },
    { label: 'Amount', tag: '{Amount:currency:USD}', width: '55%' }
];
doc.artboards[0].boxes.push(tbl);

// Static rows + a totals row, plus what the totals suggester proposes.
tbl.table.rows = [['Note', '']];
const suggested = m.suggestTotals(tbl.table);
tbl.table.totals = { enabled: true, cells: suggested };

doc.artboards.push(m.newArtboard());
const p2 = m.newTextBox(1.0, 0.5, 3.0, 0.4);
p2.text = 'Page two';
doc.artboards[1].boxes.push(p2);

// A second FLOW box below the table, to pin down the stacking maths.
const below = m.newTextBox(0.5, 7.5, 4, 0.4);
below.mode = 'flow';
below.text = 'Below the table';
doc.artboards[0].boxes.push(below);

// --- fixtures for rich text, images, shapes and page setup ------------------
const rich = m.newTextBox(0.5, 5.2, 3, 0.4);
rich.html = '<p><b>Rich</b> text with {Owner.Name} and a &#123;braced&#125; entity</p>';
doc.artboards[0].boxes.push(rich);

const logo = m.newImageBox(0.5, 0.2, 1.5, 0.75);
logo.image.src = '/sfc/servlet.shepherd/version/download/068000000000001';
logo.image.keepRatio = true;
doc.artboards[0].boxes.push(logo);

const assetLogo = m.newImageBox(3, 0.2, 1.5, 0.75);
assetLogo.image.assetKey = 'company-logo';
assetLogo.image.keepRatio = true;
doc.artboards[0].boxes.push(assetLogo);

const fieldImg = m.newImageBox(5, 0.2, 1, 1);
fieldImg.image.tag = '{%Logo__c}';
doc.artboards[0].boxes.push(fieldImg);

const rect = m.newShapeBox(0.5, 6, 2, 0.5);
doc.artboards[0].boxes.push(rect);

const rule = m.newShapeBox(0.5, 6.8, 6, 0.02);
rule.shape.type = 'hline';
doc.artboards[0].boxes.push(rule);

const qr = m.newCodeBox(4.5, 6);
qr.code = { field: 'Name', type: 'qr', size: 192, height: 80 };
doc.artboards[0].boxes.push(qr);

const bar = m.newCodeBox(0.5, 7.6);
bar.code = { field: 'AccountNumber', type: 'code128', size: 288, height: 96 };
doc.artboards[0].boxes.push(bar);

const a4Geo = m.pageGeometry('A4', 'Landscape', { top: 1, right: 0.75, bottom: 1, left: 0.75 });
const a4Html = m.serialize(doc, a4Geo);

// A custom size emits two lengths, and the default zero margin makes the artboard the
// whole page so a box at 0,0 is at the paper corner.
const customGeo = m.pageGeometry('Custom', 'Portrait', undefined, { w: 5.5, h: 8.5 });
const customHtml = m.serialize(doc, customGeo);

const html = m.serialize(doc, geo);

const checks = [
    ['pinned box uses left/top in inches', html.includes('left: 2.4in; top: 3.1in; width: 2.5in;')],
    ['pinned box omits height (so it can grow)', !/class="dg-pin"[^>]*[^-]height:/.test(html)],
    ['flow box uses margin, not left/top', html.includes('margin: 5in 0 0 0.3in;')],
    ['second artboard carries the break class', html.includes('dg-artboard dg-artboard_break')],
    ['first artboard does NOT carry it', /<div class="dg-artboard" data-dg-artboard="1"/.test(html)],
    // min-height, never height: a pinned height is OVERRUN by growing merge content
    // instead of growing with it. 11in because margins now default to zero, so the
    // artboard IS the paper — that is what makes canvas coordinates page coordinates.
    [
        'artboard uses min-height not height',
        html.includes('min-height: 11in') && !/\.dg-artboard \{[^}]*[^-]height: 11in/.test(html)
    ],
    ['newlines become <br>', html.includes('{Name}<br />Industry: {Industry}')],
    ['merge tags survive escaping', html.includes('{Amount:currency:USD}') && html.includes('{Industry}')],
    // The engine un-escapes these itself (Word escapes the same characters), so a
    // conditional written with > still evaluates.
    ['conditional angle bracket is escaped, not dropped', html.includes('{#IF Amount &gt; 100000}')],
    ['table loop wraps the row inside tbody', /<tbody>\{#Opportunities\}<tr data-dg-row="loop">/.test(html)],
    // Roles are explicit so a round-trip cannot mistake one row for another and
    // duplicate it — the bug that made rows multiply on every open.
    ['every body row declares its role', !/<tbody>[\s\S]*?<tr(?![^>]*data-dg-row)/.test(html)],
    ['table loop closes right after the row', /<\/tr>\{\/Opportunities\}/.test(html)],
    ['table head repeats on continuation pages', html.includes('display: table-header-group')],
    ['table paginates', html.includes('-fs-table-paginate: paginate')],
    ['table is a FLOW box so it can grow', /class="dg-flow"[^>]*>\s*<table/.test(html)],
    ['literal rows land after the repeating row', html.indexOf('Note') > html.indexOf('{/Opportunities}')],
    // <tfoot> is a table-footer-group: it would repeat on EVERY page, and a grand
    // total on every page of a long invoice is wrong.
    ['totals row is NOT in tfoot', !html.includes('<tfoot')],
    // Both learned from reading the suggester's own output rather than trusting it.
    ['totals carry the column format through', suggested[1] === '{SUM:Opportunities.Amount:currency:USD}'],
    ['no aggregate suggested for a non-numeric field', suggested[0] === ''],
    // Inline marks live in the plain text and expand on serialize. This is what lets
    // the box stay a <textarea> — a contenteditable would hand Lightning's "/" hotkey
    // the chance to steal focus mid-typing, which was measured, not feared.
    ['bold mark expands', html.includes('<b>Net/30</b>')],
    ['italic mark expands', html.includes('<i>rush</i>')],
    ['underline mark expands', html.includes('<u>signed</u>')],
    ['strike mark expands', html.includes('<s>void</s>')],
    ['a slash inside a mark survives', html.includes('<b>Net/30</b>')],
    ['merge tag beside marks is untouched', html.includes('{Name}')],
    ['a literal < stays escaped, not turned into markup', html.includes('5 &lt; 10')],
    // A flow box's margin is the GAP from the previous flow box, never its absolute y.
    // Emitting y put a box authored at 7.5in seven and a half inches BELOW the table
    // instead of that far down the page, and the error compounded per box. Getting
    // this right is what makes a growing table push what is under it down.
    ['flow boxes stack by gap, not by absolute y', !/class="dg-flow"[^>]*margin: 7.5in/.test(html)],
    ['pinned boxes are emitted before flow ones', html.indexOf('dg-pin') < html.indexOf('dg-flow')],
    // The CSS is a rendering instruction, not a record of what the author did — a flow
    // box's margin is the GAP from the previous one, not its position. Reading the
    // margin back as y collapsed flow boxes toward the top on every reload, and with
    // height unstored the next save recomputed gaps from wrong heights and compounded.
    ['authoring coordinates are stored explicitly', /data-dg-x="0.5" data-dg-y="7.5"/.test(html)],
    [
        'every box records its mode',
        (html.match(/data-dg-mode="/g) || []).length === doc.artboards.reduce((n, b) => n + b.boxes.length, 0)
    ],
    ['height is stored, not just implied', /data-dg-h="/.test(html)],

    // --- Rich text ---------------------------------------------------------
    // A text box edited in the rich-text editor carries `html`. Serializing `text`
    // instead silently dropped every bold, bullet and MERGE TAG the author typed, while
    // the canvas went on showing them — the editor stopped being WYSIWYG and nothing
    // reported it.
    ['rich-text html is what gets serialized', html.includes('<b>Rich</b>')],
    ['merge tags typed in rich text survive', html.includes('{Owner.Name}')],
    // A brace that comes back from an editor as &#123; produces a tag the engine never
    // matches, and the reader gets {Name} printed literally.
    ['brace entities are decoded back to real braces', !/&#0*123;/.test(html)],

    // --- Images ------------------------------------------------------------
    // Flying Saucer computes a replaced element's size ONCE PER URL, so the same image
    // at two sizes collapses to the first one's size unless each size gets its own URL.
    ['images carry the size-keyed cache-bust', /dgsz=w144/.test(html)],
    ['keep-ratio images size by width and let height follow', /width: 144px; height: auto/.test(html)],
    ['a field-bound image emits the engine token, not styled markup', html.includes('{%Logo__c:')],
    // An asset is referenced by KEY. Baking the ContentVersion Id in would pin the
    // document to whichever version was current the day it was authored, and replacing
    // the asset would silently not reach it.
    ['a Portwood asset emits {%asset:key}, never a baked CV id', html.includes('{%asset:company-logo:144}')],
    ['no asset image is serialized as a raw shepherd URL', !/<img[^>]*company-logo/.test(html)],

    // --- Shapes ------------------------------------------------------------
    ['shapes are marked so they read back as shapes', /data-dg-shape="rect"/.test(html)],
    ['a horizontal line is one border side', /data-dg-shape="hline"[^>]*border-top:/.test(html)],
    // rgba() renders NOTHING in this engine rather than degrading to a solid colour.
    ['no rgba anywhere in the output', !/rgba?\(/.test(html)],

    // --- Page setup --------------------------------------------------------
    ['margins reach the @page rule', /@page \{ size: A4 landscape; margin: 1in 0.75in 1in 0.75in; \}/.test(a4Html)],
    // The artboard is the CONTENT area, so a pinned coordinate is measured inside the
    // margins. A4 landscape is 11.69 x 8.27in of paper.
    ['the artboard is paper minus margins', a4Geo.w === 10.19 && a4Geo.h === 6.27],
    ['page setup round-trips through the saved @page', /size: A4 landscape/.test(a4Html)],
    // --- QR / barcode ------------------------------------------------------
    // The engine replaces the whole tag with the drawn symbol, so a code box emits the
    // tag and nothing else — markup wrapped around it would describe a box that no
    // longer exists.
    ['a QR box emits the engine tag with its size', html.includes('{*Name:qr:192}')],
    ['a 1D barcode emits width x height', html.includes('{*AccountNumber:code128:288x96}')],
    // The tag alone cannot be read back into a type and a size, so the authoring
    // settings ride along as data attributes the engine ignores.
    ['code settings round-trip as data attributes', /data-dg-code-type="qr"[^>]*data-dg-code-field="Name"/.test(html)],
    ['a QR box is square at the requested pixel size', m.codeBoxSize({ type: 'qr', size: 192 }).w === 2],

    ['a custom size emits two lengths', /@page \{ size: 5.5in 8.5in;/.test(customHtml)],
    // Zero margins are what make the canvas and the page share an origin.
    ['margins default to zero', /margin: 0in 0in 0in 0in/.test(customHtml)],
    ['with no margin the artboard is the whole page', customGeo.w === 5.5 && customGeo.h === 8.5]
];

let bad = 0;

for (const [name, ok] of checks) {
    if (!ok) bad++;
    process.stdout.write((ok ? '  PASS  ' : '  FAIL  ') + name + '\n');
}
process.stdout.write(bad ? `\n${bad} FAILED\n` : '\nserializer OK\n');
process.exit(bad ? 1 : 0);
