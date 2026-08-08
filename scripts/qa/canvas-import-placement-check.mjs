/**
 * htmlToCanvas — placed vs flowing blocks.
 *
 *   node scripts/qa/canvas-import-placement-check.mjs
 *
 * Import HTML honours `position: absolute` and pins the block at its declared inch
 * coordinates. That is what lets an existing laid-out document arrive laid out rather
 * than as a stack, and a regression here would quietly turn every placed block into a
 * flowing one with no error anywhere.
 *
 * The bug this also covers: only flow boxes advanced the import cursor, so a document
 * that placed a title and then let a table flow put the table at y=0 — printed on top
 * of the title.
 */
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
writeFileSync('/tmp/cm.place.mjs', src);
const m = await import('/tmp/cm.place.mjs?v=' + Date.now());

let fail = 0;
const ok = (c, msg) => {
    console.log((c ? '  ok  ' : ' FAIL ') + msg);
    if (!c) fail++;
};
const doc = (body) =>
    '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' + body + '</body></html>';

// --- a placed block keeps its coordinates ------------------------------------
{
    const { doc: d } = m.htmlToCanvas(
        doc('<h1 style="position: absolute; left: 1.25in; top: 0.75in; width: 3in">{Name}</h1>')
    );
    const b = d.artboards[0].boxes[0];
    ok(!!b, 'a placed block imports');
    ok(b && b.mode === 'pinned', 'as a PINNED box');
    ok(b && b.x === 1.25, 'keeping its left, to the inch (' + (b && b.x) + ')');
    ok(b && b.y === 0.75, 'and its top (' + (b && b.y) + ')');
    ok(b && b.w === 3, 'and its width (' + (b && b.w) + ')');
}

// --- an unpositioned block still flows ---------------------------------------
{
    const { doc: d } = m.htmlToCanvas(doc('<p>First</p><table><tr><td>x</td></tr></table>'));
    const modes = d.artboards[0].boxes.map((b) => b.mode);
    ok(
        modes.every((x) => x === 'flow'),
        'blocks with no position still import as flow: ' + modes.join(',')
    );
}

// --- side by side, which flow cannot express ---------------------------------
{
    const { doc: d } = m.htmlToCanvas(
        doc(
            '<h1 style="position: absolute; left: 0.75in; top: 0.6in; width: 4.5in">{Name}</h1>' +
                '<div style="position: absolute; left: 5.75in; top: 0.65in; width: 2in">{Today}</div>'
        )
    );
    const [a, b] = d.artboards[0].boxes;
    ok(d.artboards[0].boxes.length === 2, 'two placed blocks import as two boxes');
    ok(a && b && Math.abs(a.y - b.y) < 0.1, 'they sit on the same line — side by side, not stacked');
    ok(a && b && b.x > a.x + a.w - 0.01, 'and the second starts clear of the first');
}

// --- mixed: flowing content must land BELOW what is placed -------------------
{
    const { doc: d } = m.htmlToCanvas(
        doc(
            '<h1 style="position: absolute; left: 0.75in; top: 0.6in; width: 4.5in; height: 0.5in">Title</h1>' +
                '<table><tr><td>{LastName}</td></tr></table>'
        )
    );
    const pinned = d.artboards[0].boxes.find((b) => b.mode === 'pinned');
    const flowed = d.artboards[0].boxes.find((b) => b.mode === 'flow');
    ok(!!pinned && !!flowed, 'a mixed document imports both kinds');
    ok(flowed && flowed.y > 0, 'the flowing block does not land at y=0 (' + (flowed && flowed.y) + ')');
    ok(
        pinned && flowed && flowed.y >= pinned.y + pinned.h - 0.01,
        'it starts at or below the placed block, so nothing overlaps'
    );
}

// --- a pure-flow document is unchanged by that rule --------------------------
// Tables, not paragraphs: consecutive inline-ish blocks are deliberately grouped into
// one box, so a <p><p><p> document yields a single box and would assert nothing.
{
    const tbl = '<table><tr><td>x</td></tr></table>';
    const { doc: d } = m.htmlToCanvas(doc(tbl + tbl + tbl));
    const ys = d.artboards[0].boxes.map((b) => b.y);
    ok(ys.length === 3, 'three tables import as three separate boxes (' + ys.length + ')');
    ok(ys[0] === 0, 'the first flowing block still starts at the top');
    ok(
        ys.every((y, i) => i === 0 || y > ys[i - 1]),
        'and each following one is strictly below the last: ' + ys.join(',')
    );
}

// --- placed blocks survive a save and reload ---------------------------------
{
    const { doc: d } = m.htmlToCanvas(
        doc('<h1 style="position: absolute; left: 2in; top: 3in; width: 4in">{Name}</h1>')
    );
    const geo = m.pageGeometry('Letter', 'Portrait');
    const back = m.deserialize(m.serialize(d, geo));
    const b = back.artboards[0].boxes[0];
    ok(b && b.x === 2 && b.y === 3, 'a placed block round-trips at its coordinates');
    ok(b && b.mode === 'pinned', 'and stays pinned');
}

console.log(fail ? `\n${fail} FAILED` : '\nplacement OK');
process.exit(fail ? 1 : 0);
