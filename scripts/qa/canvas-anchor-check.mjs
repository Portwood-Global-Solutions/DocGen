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

    // WHICH box it points at, not merely that it points at something. The assertion
    // above passes even when the anchor has been re-pointed at an unrelated element.
    const ra = back.artboards[0].boxes.find((x) => x.kind === 'table');
    ok(rf && ra && rf.anchorTo === ra.id, 'and it still points at the TABLE, not just at some box');
}

// --- a chain, reopened and saved again ---------------------------------------
// The two-box case above cannot catch a re-pointed anchor: with one candidate, any
// surviving id is the right one. This is the shape that failed in the org — deserialize
// mints fresh sequential ids, so a saved `box_5` collided with a real but unrelated box
// and the chain silently rewired (summary→subtitle, note→rule) on a single save.
{
    const doc = m.blankDocument();
    const masthead = m.newTextBox(1, 0.5, 6, 0.4);
    masthead.text = 'Masthead';
    const rule = m.newTextBox(1, 1, 6, 0.02);
    rule.text = 'Rule';
    const table = tableBox(1, 1.5, 6);
    const summary = m.newTextBox(1, 3, 6, 0.4);
    summary.text = 'Summary';
    summary.positionMode = 'follows';
    summary.anchorTo = table.id;
    const note = m.newTextBox(1, 3.6, 6, 0.5);
    note.text = 'Note';
    note.positionMode = 'follows';
    note.anchorTo = summary.id;
    const sig = m.newTextBox(1, 4.4, 3, 0.7);
    sig.text = 'Signature';
    sig.positionMode = 'follows';
    sig.anchorTo = note.id;
    sig.keepTogether = true;
    doc.artboards[0].boxes.push(masthead, rule, table, summary, note, sig);

    const html1 = m.serialize(doc, geo);
    ok((html1.match(/class="dg-group"/g) || []).length === 1, 'the chain emits ONE group, not one per link');

    // Two full cycles: the org bug needed a save AFTER a load to show itself.
    let back = m.deserialize(html1);
    const html2 = m.serialize(back, geo);
    back = m.deserialize(html2);
    const html3 = m.serialize(back, geo);

    const byText = (t) => back.artboards[0].boxes.find((x) => (x.text || '').includes(t));
    const t2 = back.artboards[0].boxes.find((x) => x.kind === 'table');
    ok((html2.match(/class="dg-group"/g) || []).length === 1, 'still ONE group after a reopen-and-save');
    ok(byText('Summary') && byText('Summary').anchorTo === t2.id, 'summary still follows the table');
    ok(byText('Note') && byText('Note').anchorTo === byText('Summary').id, 'note still follows the summary');
    ok(byText('Signature') && byText('Signature').anchorTo === byText('Note').id, 'signature still follows the note');
    ok(byText('Masthead').positionMode !== 'follows', 'the masthead never joined the chain');
    ok(byText('Rule').positionMode !== 'follows', 'nor did the rule');
    // Ids are minted per load, so they legitimately renumber on every save. What must
    // NOT drift is anything else — geometry, grouping, or which box an anchor names.
    // Canonicalising by position in the document turns "box_12" into a stable label, so
    // a re-pointed anchor still shows up as a difference.
    const canon = (html) => {
        const order = [...html.matchAll(/data-dg-id="([^"]*)"/g)].map((x) => x[1]);
        const at = (id) => {
            const i = order.indexOf(id);
            return i === -1 ? 'UNRESOLVED' : '#' + i;
        };
        return html
            .replace(/data-dg-anchor="([^"]*)"/g, (_, id) => 'data-dg-anchor="' + at(id) + '"')
            .replace(/data-dg-id="([^"]*)"/g, (_, id) => 'data-dg-id="' + at(id) + '"');
    };
    ok(canon(html3) === canon(html2), 'and the document is a fixed point once ids are renumbered');
}

// --- an anchor that cannot be resolved ---------------------------------------
// Reverting to fixed is the deliberate choice: a box that stops moving is visible,
// where a box tied to the wrong neighbour is not.
{
    const doc = m.blankDocument();
    const a = m.newTextBox(1, 1, 3, 0.5);
    a.text = 'Anchor';
    const f = m.newTextBox(1, 2, 3, 0.5);
    f.text = 'Follower';
    f.positionMode = 'follows';
    f.anchorTo = a.id;
    doc.artboards[0].boxes.push(a, f);
    // Strip the ids a real save would have written, leaving only the anchor — and
    // break the group so the legacy sibling fallback cannot apply either.
    const mangled = m.serialize(doc, geo).replace(/ data-dg-id="[^"]*"/g, '').replace(/dg-anchored/g, 'dg-pin');
    const rf = m.deserialize(mangled).artboards[0].boxes.find((x) => (x.text || '').includes('Follower'));
    ok(rf && rf.positionMode === 'fixed', 'an unresolvable anchor reverts to fixed');
    ok(rf && !rf.anchorTo, 'and does not keep an id that means nothing');
}

// --- a document saved before data-dg-id existed -------------------------------
{
    const doc = m.blankDocument();
    const t = tableBox(1, 1.5, 6);
    const s = m.newTextBox(1, 3, 6, 0.4);
    s.text = 'Summary';
    s.positionMode = 'follows';
    s.anchorTo = t.id;
    const n = m.newTextBox(1, 3.6, 6, 0.4);
    n.text = 'Note';
    n.positionMode = 'follows';
    n.anchorTo = s.id;
    doc.artboards[0].boxes.push(t, s, n);
    const legacy = m.serialize(doc, geo).replace(/ data-dg-id="[^"]*"/g, '');
    const back = m.deserialize(legacy);
    const bt = back.artboards[0].boxes.find((x) => x.kind === 'table');
    const bs = back.artboards[0].boxes.find((x) => (x.text || '').includes('Summary'));
    const bn = back.artboards[0].boxes.find((x) => (x.text || '').includes('Note'));
    ok(bs && bs.anchorTo === bt.id, 'legacy chain recovers from group order — summary → table');
    ok(bn && bn.anchorTo === bs.id, 'legacy chain recovers from group order — note → summary');
}

console.log(fail ? `\n${fail} FAILED` : '\nanchors OK');
process.exit(fail ? 1 : 0);
