/**
 * sanitizeInline — what a box's markup is allowed to contain.
 *
 *   node scripts/qa/canvas-inline-sanitize-check.mjs
 *
 * Everything that becomes the content of a canvas box goes through here, and the way
 * in is the box's HTML source editor: paste markup, leave the field, this runs.
 *
 * The bug it pins down: the rule is "unwrap, never delete", which is right for a stray
 * <section> — the words inside are what the author wrote — and wrong for <style>, whose
 * text is CSS source. Pasting a whole HTML document printed
 * "@page { size: Letter portrait; ... }" on the artboard as body text.
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
writeFileSync('/tmp/cm.inline.mjs', src);
const m = await import('/tmp/cm.inline.mjs?v=' + Date.now());

let fail = 0;
const ok = (c, msg) => {
    console.log((c ? '  ok  ' : ' FAIL ') + msg);
    if (!c) fail++;
};

const WHOLE_DOC = [
    '<!DOCTYPE html><html><head><title>Invoice</title>',
    '<style>@page { size: Letter portrait; margin: 0.6in; }',
    'body { font-family: Helvetica; } .band { background: #0b3d91; }</style>',
    '</head><body><div class="band">Invoice {Account.Name}</div>',
    '<p>Total {Amount:currency}</p></body></html>'
].join('\n');

// --- a pasted document must not print its own stylesheet ---------------------
{
    const clean = m.sanitizeInline(WHOLE_DOC);
    ok(!clean.includes('@page'), 'CSS source is never rendered as text');
    ok(!clean.includes('font-family: Helvetica'), 'nor any other declaration from a style block');
    ok(!clean.includes('Invoice</title>'), 'nor the title text');
    ok(clean.includes('{Account.Name}'), 'and the real content still survives');
    ok(clean.includes('{Amount:currency}'), 'with every merge tag in it');
}
{
    const clean = m.sanitizeInline('<p>Before</p><style>.x{color:red}</style><p>After</p>');
    ok(!clean.includes('color:red'), 'a style block among real content is dropped whole');
    ok(clean.includes('Before') && clean.includes('After'), 'and the content either side is kept');
}
{
    const clean = m.sanitizeInline('<p>Safe</p><script>alert(1)</script>');
    ok(!clean.toLowerCase().includes('alert'), 'script contents never survive as text');
    ok(clean.includes('Safe'), 'and the surrounding content does');
}

// --- unwrapping is still the rule for everything else ------------------------
// The fix must not turn into "delete unknown tags", which would eat authored text.
{
    const clean = m.sanitizeInline('<section><p>Kept text</p></section>');
    ok(clean.includes('Kept text'), 'an unknown wrapper is still unwrapped, not deleted');
    ok(!clean.includes('<section'), 'and the wrapper itself goes');
}

// --- ordinary box content passes through unharmed ----------------------------
{
    const clean = m.sanitizeInline('<strong>Total</strong> {SUM:Lines.Amount:currency}');
    ok(clean.includes('<strong>'), 'inline formatting is kept');
    ok(clean.includes('{SUM:Lines.Amount:currency}'), 'and so is the merge tag');
}

console.log(fail ? `\n${fail} FAILED` : '\ninline sanitize OK');
process.exit(fail ? 1 : 0);
