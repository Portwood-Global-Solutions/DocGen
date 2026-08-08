/**
 * Fragment intake — toFragment + sanitizeInline.
 *
 *   node scripts/qa/canvas-fragment-sanitize-check.mjs
 *
 * Anything that arrives as "the markup for one box" goes through here: Agentforce's
 * per-element rewrite, and a paste into the box's HTML source editor.
 *
 * The bug this pins down: sanitizeInline's rule is "unwrap, never delete", which is
 * right for a stray <section> — the words inside are what the author wrote — and wrong
 * for <style>, whose text is CSS source. A whole document handed to it printed
 * "@page { size: Letter portrait; ... }" on the artboard as body text. Seen for real
 * when a model ignored a fragment instruction and returned a complete file.
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
writeFileSync('/tmp/cm.frag.mjs', src);
const m = await import('/tmp/cm.frag.mjs?v=' + Date.now());

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

// --- a whole document reduced to its body ------------------------------------
{
    const frag = m.toFragment(WHOLE_DOC);
    ok(!/<style/i.test(frag), 'toFragment drops the style element');
    ok(!/@page/.test(frag), 'and the @page rule with it');
    ok(!/<title/i.test(frag) && !/<head/i.test(frag), 'and the head');
    ok(frag.includes('Invoice {Account.Name}'), 'while keeping the body content');
    ok(frag.includes('{Amount:currency}'), 'and every merge tag in it');
}

// --- the sanitizer alone must not print CSS ----------------------------------
// Belt and braces: toFragment runs first on the AI path, but the source editor hands
// pasted markup straight to sanitizeInline.
{
    const clean = m.sanitizeInline(WHOLE_DOC);
    ok(!clean.includes('@page'), 'sanitizeInline never renders CSS source as text');
    ok(!clean.includes('font-family: Helvetica'), 'nor any other declaration from a style block');
    ok(!clean.includes('Invoice</title>') && !/Invoice<\/title>/.test(clean), 'nor the title text');
    ok(clean.includes('{Account.Name}'), 'and the real content still survives');
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

// --- a real fragment passes through unharmed ---------------------------------
{
    const frag = '<strong>Total</strong> {SUM:Lines.Amount:currency}';
    ok(m.toFragment(frag) === frag, 'toFragment is a no-op on something already a fragment');
    const clean = m.sanitizeInline(frag);
    ok(clean.includes('<strong>') && clean.includes('{SUM:Lines.Amount:currency}'), 'and it sanitizes unchanged');
}
{
    ok(m.toFragment('') === '', 'empty input is empty output, not a throw');
    ok(m.toFragment(null) === '', 'and so is null');
}

console.log(fail ? `\n${fail} FAILED` : '\nfragment intake OK');
process.exit(fail ? 1 : 0);
