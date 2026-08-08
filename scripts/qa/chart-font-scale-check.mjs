/**
 * Chart label sizing.
 *
 *   node scripts/qa/chart-font-scale-check.mjs
 *
 * Sizes are ABSOLUTE canvas pixels, and one wrong turn is worth recording so it is not
 * taken twice.
 *
 * Chart.js sizes text in canvas pixels and PowerPoint stretches the PNG to whatever its
 * shape is — so a fixed size does not survive that trip, and raising `width=` to sharpen
 * a chart shrinks its labels. That argues for scaling the fonts with the canvas.
 *
 * It is wrong for the Canvas designer. There `chartToHtml` emits
 * `width=inToCssPx(box.w)`: the tag's width IS the block's physical width and the image
 * is placed at exactly that size, so 12px has always meant a steady ~9pt. Scaling would
 * have made a 3-inch chart print ~5pt labels — fixing PowerPoint by breaking the case
 * that already worked.
 *
 * `width=` means different things on the two paths, so no single automatic rule is
 * right. The default stays absolute; `fontSize=` is the explicit knob, exposed in the
 * Canvas chart properties as "Label size".
 */
import { readFileSync, writeFileSync } from 'node:fs';

// The module imports three Apex methods at the top, which plain node cannot resolve.
// Stubbing them keeps this harness runnable in CI with no org — the sizing arithmetic
// under test does not touch them.
const src = readFileSync(
    new URL('../../force-app/main/default/lwc/docGenChartJs/docGenChartJs.js', import.meta.url),
    'utf8'
).replace(/^import\s+(\w+)\s+from\s+'@salesforce\/apex\/[^']+';$/gm, 'const $1 = async () => null;');
writeFileSync('/tmp/cjs.font.mjs', src);
const m = await import('/tmp/cjs.font.mjs?v=' + Date.now());

let fail = 0;
const ok = (c, msg) => {
    console.log((c ? '  ok  ' : ' FAIL ') + msg);
    if (!c) fail++;
};

// The module keeps the resolvers private, so drive them through the public builder.
const buckets = [
    { key_label: 'Alpha', count: 4, percent: 40, color: '#1e40af' },
    { key_label: 'Beta', count: 6, percent: 60, color: '#b91c1c' }
];
const tickOf = (opts) => {
    const cfg = m.buildChartConfigForTest ? m.buildChartConfigForTest('column', buckets, opts) : null;
    if (!cfg) return null;
    return cfg.options.scales.x.ticks.font.size;
};
// The title block only carries a font when there IS a title — with none, Chart.js is
// handed { display: false } and nothing to size.
const titleOf = (opts) => {
    const cfg = m.buildChartConfigForTest
        ? m.buildChartConfigForTest('column', buckets, { title: 'A title', ...opts })
        : null;
    return cfg ? cfg.options.plugins.title.font.size : null;
};

if (!m.buildChartConfigForTest) {
    console.log(' FAIL  buildChartConfigForTest is not exported — this harness cannot see the config');
    process.exit(1);
}

// --- the default is absolute, and does not move with the canvas ---------------
{
    ok(tickOf({ width: 540 }) === 12, 'the default tick is 12px');
    ok(tickOf({ width: 1080 }) === 12, 'and stays 12px on a wider canvas');
    ok(tickOf({ width: 288 }) === 12, 'and on a narrower one');
    ok(tickOf({}) === 12, 'and when no width is given at all');
    // The regression this guards: scaling here silently shrank every Canvas chart,
    // because on that path width= is the block's real width and 12px was already right.
    ok(tickOf({ width: 288 }) === tickOf({ width: 1080 }), 'width= changes resolution, never label size');
}

// --- the title holds its own default -----------------------------------------
{
    ok(titleOf({ width: 540 }) === 16, 'the default title is 16px');
    ok(titleOf({ width: 1080 }) === 16, 'and does not move with the canvas either');
}

// --- fontSize= is the knob ----------------------------------------------------
{
    ok(tickOf({ fontSize: 18 }) === 18, 'fontSize=18 gives 18px');
    ok(tickOf({ width: 1080, fontSize: 18 }) === 18, 'and means the same thing at any width');
    ok(titleOf({ fontSize: 18 }) === 24, 'the title follows it proportionally (1.34x)');
    ok(tickOf({ fontSize: '14' }) === 14, 'a string, as the tag map delivers it, is accepted');
    ok(tickOf({ fontSize: 0 }) === 12, 'zero falls back rather than rendering nothing');
    ok(tickOf({ fontSize: -5 }) === 12, 'and so does a negative');
    ok(tickOf({ fontSize: 'abc' }) === 12, 'and so does nonsense');
    ok(tickOf({ fontSize: 13.7 }) === 14, 'a fraction rounds to a whole pixel');
}

console.log(fail ? `\n${fail} FAILED` : '\nchart fonts OK');
process.exit(fail ? 1 : 0);
