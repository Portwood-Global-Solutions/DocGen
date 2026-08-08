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
writeFileSync('/tmp/canvasModel.chart.mjs', src);
const m = await import('/tmp/canvasModel.chart.mjs?v=' + Date.now());

let failures = 0;
const ok = (cond, msg) => {
    console.log((cond ? '  ok  ' : ' FAIL ') + msg);
    if (!cond) failures++;
};

const doc = m.blankDocument();
const box = m.newChartBox(1, 2, 5.0, 3.0);
box.chart.relationship = 'VMR_Tracker__Survey_Question_Answers__r';
box.chart.field = 'VMR_Tracker__Answer3__c';
box.chart.style = 'column';
box.chart.title = 'Monday Commute Mode';
box.chart.colors = '#8FD3EA,#40B9D2';
doc.artboards[0].boxes.push(box);

const html = m.serialize(doc, m.pageGeometry('Letter', 'Portrait'));

ok(
    html.includes('{Chart:VMR_Tracker__Survey_Question_Answers__r:VMR_Tracker__Answer3__c:column:'),
    'emits a {Chart:...} tag with relationship, field and style'
);
ok(html.includes('title=Monday Commute Mode'), 'carries the title modifier');
ok(html.includes('colors=#8FD3EA,#40B9D2'), 'carries the colors modifier');
ok(/width=\d+&height=\d+/.test(html), 'derives width/height from the drawn box');

// Aspect ratio of the tag must match the box the author drew (5.0 x 3.0).
const mm = html.match(/width=(\d+)&height=(\d+)/);
const aspect = mm ? Number(mm[1]) / Number(mm[2]) : 0;
ok(Math.abs(aspect - 5.0 / 3.0) < 0.02, `tag aspect ${aspect.toFixed(3)} matches box aspect ${(5 / 3).toFixed(3)}`);

// Round trip
const back = m.deserialize(html);
const rb = back.artboards[0].boxes.find((b) => b.kind === 'chart');
ok(!!rb, 'reloads as kind=chart');
if (rb) {
    ok(rb.chart.relationship === 'VMR_Tracker__Survey_Question_Answers__r', 'relationship survives reload');
    ok(rb.chart.field === 'VMR_Tracker__Answer3__c', 'field survives reload');
    ok(rb.chart.style === 'column', 'style survives reload');
    ok(rb.chart.title === 'Monday Commute Mode', 'title survives reload');
    ok(rb.chart.colors === '#8FD3EA,#40B9D2', 'colors survive reload');
    ok(Math.abs(rb.w - 5.0) < 0.01 && Math.abs(rb.h - 3.0) < 0.01, 'geometry survives reload');
}

// Unconfigured chart must not emit a malformed tag.
const empty = m.blankDocument();
empty.artboards[0].boxes.push(m.newChartBox(1, 1, 4, 2));
const emptyHtml = m.serialize(empty, m.pageGeometry('Letter', 'Portrait'));
ok(!emptyHtml.includes('{Chart:'), 'unconfigured chart emits no tag');

console.log(failures ? `\n${failures} FAILED` : '\nall passed');
process.exit(failures ? 1 : 0);
