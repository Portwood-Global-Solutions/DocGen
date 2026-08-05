// Canvas serializer check — asserts the SHIPPED canvasModel emits the layout
// contract that was measured to work (scripts/canvas-layout-model-probe.apex).
// Pure Node, no org needed:  node scripts/qa/canvas-serializer-check.mjs
//
// Guards the four rules that are counter-intuitive and would be "tidied" away:
// a pinned box must NOT emit height (it has to grow with merged content), a flow
// box uses margin rather than left/top, page-break lives on the artboard AFTER
// the first, and the artboard uses min-height.
// Exercise the SHIPPED serializer, not a copy of it.
import { readFileSync, writeFileSync } from 'node:fs';
const src = readFileSync(
    new URL('../../force-app/main/default/lwc/docGenCanvas/canvasModel.js', import.meta.url),
    'utf8'
);
writeFileSync('/tmp/canvasModel.mjs', src);
const m = await import('/tmp/canvasModel.mjs');

const geo = m.pageGeometry('Letter', 'Portrait');
const doc = m.blankDocument();

const pin = m.newTextBox(2.4, 3.1, 2.5, 0.4);
pin.html = '<b>{Name}</b><br/>Industry: {Industry}';
doc.artboards[0].boxes.push(pin);

const flow = m.newTextBox(0.5, 5.0, 5.0, 1.0);
flow.mode = 'flow';
flow.html =
    '<b>Line items</b><table><thead><tr><th>Item</th><th>Amt</th></tr></thead><tbody>{#Opportunities}<tr><td>{Name}</td><td>{Amount:currency:USD}</td></tr>{/Opportunities}</tbody></table>';
doc.artboards[0].boxes.push(flow);

doc.artboards.push(m.newArtboard());
const pin2 = m.newTextBox(1.0, 0.5, 3.0, 0.4);
pin2.html = 'Page two pinned box';
doc.artboards[1].boxes.push(pin2);

const html = m.serialize(doc, geo);
writeFileSync('serialized.html', html);

const checks = [
    ['pinned box uses left/top in inches', html.includes('left: 2.4in; top: 3.1in; width: 2.5in;')],
    ['pinned box omits height (so it can grow)', !/class="dg-pin"[^>]*height:/.test(html)],
    ['flow box uses margin, not left/top', html.includes('margin: 5in 0 0 0.5in; width: 5in;')],
    ['second artboard carries the break class', html.includes('dg-artboard dg-artboard_break')],
    ['first artboard does NOT carry it', /<div class="dg-artboard" data-dg-artboard="1"/.test(html)],
    [
        'artboard uses min-height not height',
        html.includes('min-height: 10in') && !/\.dg-artboard \{[^}]*[^-]height:/.test(html)
    ],
    ['merge tags survive verbatim', html.includes('{#Opportunities}') && html.includes('{Amount:currency:USD}')]
];
let bad = 0;
for (const [name, ok] of checks) {
    if (!ok) bad++;
    console.log((ok ? '  PASS  ' : '  FAIL  ') + name);
}
console.log(bad ? `\n${bad} FAILED` : '\nserializer OK');
