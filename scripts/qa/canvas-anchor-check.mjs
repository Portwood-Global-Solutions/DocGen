/**
 * Element linking — anchor groups.
 *
 *   node scripts/qa/canvas-anchor-check.mjs
 *
 * A follower must be emitted IN FLOW inside its group, not absolutely
 * positioned. That is the whole mechanism: an absolute follower holds its offset
 * while the anchor grows and gets overrun, which is the bug this feature exists
 * to fix. The spike measured that (docs/element-linking-spike.md, probe 2).
 *
 * Also covers the two ways a link can go wrong from the UI — a deleted anchor
 * and a cycle — because both are one click away and neither may reach the
 * serializer.
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
writeFileSync('/tmp/cm.anchor.mjs', src);
const m = await import('/tmp/cm.anchor.mjs?v=' + Date.now());

let fail = 0;
const ok = (c, msg) => {
    console.log((c ? '  ok  ' : ' FAIL ') + msg);
    if (!c) fail++;
};
const geo = m.pageGeometry('Letter', 'Portrait');

function tableBox(x, y, w) {
    const b = m.newTableBox(x, y, w);
    b.table.relationship = 'Contacts';
    b.table.columns = [{ label: 'Name', tag: '{LastName}', width: '100%' }];
    return b;
}

// --- a follower travels with its anchor -----------------------------------
{
    const doc = m.blankDocument();
    const anchor = tableBox(1, 2, 5);
    const follower = m.newTextBox(1, 5, 5, 0.4);
    follower.text = 'Total: {Amount}';
    follower.positionMode = 'follows';
    follower.anchorTo = anchor.id;
    doc.artboards[0].boxes.push(anchor, follower);

    const html = m.serialize(doc, geo);
    ok(html.includes('class="dg-group"'), 'anchor set emits a single group container');
    ok(/class="dg-group" style="position: relative;/.test(html), 'group is a positioned flow container');

    // The critical assertion: members must NOT be absolutely positioned.
    const groupHtml = html.slice(html.indexOf('dg-group'));
    ok(!/dg-anchored[^>]*position:\s*absolute/.test(groupHtml), 'members are in flow, never absolute');
    ok((groupHtml.match(/class="dg-anchored"/g) || []).length === 2, 'both members are inside the group');

    // The follower's gap is measured from the anchor's authored BOTTOM (2 + h),
    // not from the anchor's top — otherwise it overlaps as soon as it renders.
    const anchorBottom = anchor.y + anchor.h;
    const expectedGap = Math.max(0, 5 - anchorBottom);
    ok(
        groupHtml.includes('margin: ' + expectedGap + 'in 0 0 0in'),
        `follower gap is measured from the anchor's bottom (${expectedGap}in)`
    );
}

// --- keepTogether -----------------------------------------------------------
{
    const doc = m.blankDocument();
    const a = tableBox(1, 2, 5);
    const f = m.newTextBox(1, 5, 5, 0.4);
    f.positionMode = 'follows';
    f.anchorTo = a.id;
    f.keepTogether = true;
    doc.artboards[0].boxes.push(a, f);
    ok(m.serialize(doc, geo).includes('page-break-inside: avoid'), 'keepTogether emits page-break-inside: avoid');
}

// --- an unlinked box is untouched ------------------------------------------
{
    const doc = m.blankDocument();
    const solo = m.newTextBox(1, 2, 3, 0.5);
    solo.text = 'Stays put';
    doc.artboards[0].boxes.push(solo);
    const html = m.serialize(doc, geo);
    ok(!html.includes('dg-group'), 'a box with no anchor emits no group');
    ok(html.includes('dg-pin'), 'and stays pinned — Fixed remains the default');
}

// --- broken and cyclic links -----------------------------------------------
{
    const doc = m.blankDocument();
    const orphan = m.newTextBox(1, 2, 3, 0.5);
    orphan.text = 'Anchor was deleted';
    orphan.positionMode = 'follows';
    orphan.anchorTo = 'box-that-no-longer-exists';
    doc.artboards[0].boxes.push(orphan);
    const html = m.serialize(doc, geo);
    ok(html.includes('Anchor was deleted'), 'a dangling anchor still renders the box, never drops it');
}
{
    const doc = m.blankDocument();
    const a = m.newTextBox(1, 2, 3, 0.5);
    const b = m.newTextBox(1, 3, 3, 0.5);
    a.text = 'A';
    b.text = 'B';
    a.positionMode = 'follows';
    a.anchorTo = b.id;
    b.positionMode = 'follows';
    b.anchorTo = a.id;
    doc.artboards[0].boxes.push(a, b);
    let html = null;
    const t = setTimeout(() => {}, 0);
    clearTimeout(t);
    html = m.serialize(doc, geo); // must not hang
    ok(html.includes('>A<') && html.includes('>B<'), 'a cycle terminates and still renders both boxes');
}

// --- round trip -------------------------------------------------------------
{
    const doc = m.blankDocument();
    const a = tableBox(1, 2, 5);
    const f = m.newTextBox(1, 5, 5, 0.4);
    f.text = 'Follower';
    f.positionMode = 'follows';
    f.anchorTo = a.id;
    f.keepTogether = true;
    doc.artboards[0].boxes.push(a, f);

    const back = m.deserialize(m.serialize(doc, geo));
    const rf = back.artboards[0].boxes.find((x) => (x.text || '').includes('Follower'));
    ok(!!rf, 'follower survives the round trip');
    ok(rf && rf.positionMode === 'follows', 'position mode survives');
    ok(rf && !!rf.anchorTo, 'anchor id survives');
    ok(rf && rf.keepTogether === true, 'keepTogether survives');
}

console.log(fail ? `\n${fail} FAILED` : '\nanchors OK');
process.exit(fail ? 1 : 0);
