import { readFileSync, writeFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';
const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.document = dom.window.document;
globalThis.window = dom.window;
globalThis.Node = dom.window.Node;
const src = readFileSync(
    new URL('../../force-app/main/default/lwc/docGenCanvas/canvasModel.js', import.meta.url),
    'utf8'
);
writeFileSync('/tmp/cm.rt.mjs', src);
const m = await import('/tmp/cm.rt.mjs?v=' + Date.now());

let fail = 0;
const ok = (c, msg) => {
    console.log((c ? '  ok  ' : ' FAIL ') + msg);
    if (!c) fail++;
};
const geo = m.pageGeometry('Letter', 'Portrait');

const doc = m.blankDocument();
const t = m.newTextBox(1, 1, 3, 0.5);
t.text = 'Hello {Name}';
const ch = m.newChartBox(1, 2, 5, 3);
ch.chart.relationship = 'Contacts';
ch.chart.field = 'Description';
ch.chart.style = 'donut';
ch.chart.title = 'Commute Mode';
ch.chart.colors = '#8FD3EA,#40B9D2';
const tb = m.newTableBox(0.5, 6, 6);
tb.table.relationship = 'Opportunities';
tb.table.columns = [
    { label: 'Name', tag: '{Name}', width: '60%' },
    { label: 'Amt', tag: '{Amount:currency}', width: '40%' }
];
doc.artboards[0].boxes.push(t, ch, tb);

// Export -> import -> export again. The second export must equal the first,
// or something was lost or invented on the way through.
const exported = m.serialize(doc, geo);
const reimported = m.deserialize(exported);
const exportedAgain = m.serialize(reimported, geo);

ok(exported === exportedAgain, 'export -> import -> export is byte-identical');
if (exported !== exportedAgain) {
    for (let i = 0; i < Math.max(exported.length, exportedAgain.length); i++) {
        if (exported[i] !== exportedAgain[i]) {
            console.log(
                '   first diff at',
                i,
                JSON.stringify(exported.slice(i - 80, i + 80)),
                '\n   vs\n  ',
                JSON.stringify(exportedAgain.slice(i - 80, i + 80))
            );
            break;
        }
    }
}
const rb = reimported.artboards[0].boxes.find((b) => b.kind === 'chart');
ok(!!rb && rb.chart.style === 'donut' && rb.chart.title === 'Commute Mode', 'chart config survives the round trip');
ok(
    reimported.artboards[0].boxes.some((b) => b.kind === 'table'),
    'table survives the round trip'
);
console.log(fail ? `\n${fail} FAILED` : '\nround trip OK');
process.exit(fail ? 1 : 0);
