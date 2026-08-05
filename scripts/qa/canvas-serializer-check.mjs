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

const html = m.serialize(doc, geo);

const checks = [
    ['pinned box uses left/top in inches', html.includes('left: 2.4in; top: 3.1in; width: 2.5in;')],
    ['pinned box omits height (so it can grow)', !/class="dg-pin"[^>]*[^-]height:/.test(html)],
    ['flow box uses margin, not left/top', html.includes('margin: 5in 0 0 0.3in;')],
    ['second artboard carries the break class', html.includes('dg-artboard dg-artboard_break')],
    ['first artboard does NOT carry it', /<div class="dg-artboard" data-dg-artboard="1"/.test(html)],
    ['artboard uses min-height not height', html.includes('min-height: 10in')],
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
    ['no aggregate suggested for a non-numeric field', suggested[0] === '']
];

let bad = 0;
for (const [name, ok] of checks) {
    if (!ok) bad++;
    process.stdout.write((ok ? '  PASS  ' : '  FAIL  ') + name + '\n');
}
process.stdout.write(bad ? `\n${bad} FAILED\n` : '\nserializer OK\n');
process.exit(bad ? 1 : 0);
