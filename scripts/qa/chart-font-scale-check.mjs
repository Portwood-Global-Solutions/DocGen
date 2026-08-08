/**
 * Chart label sizing.
 *
 *   node scripts/qa/chart-font-scale-check.mjs
 *
 * Chart.js sizes text in CANVAS pixels, and the PNG is then scaled to whatever the
 * placeholder is — a PowerPoint shape, a PDF box. Absolute pixel sizes therefore do not
 * survive the trip, and the failure is counter-intuitive: raising `width=` makes the
 * text SMALLER in the finished document, because more pixels are squeezed into the same
 * physical space. An author trying to sharpen a chart shrinks its labels.
 *
 * So the sizes have to be a fixed FRACTION of the canvas. Then `width=` controls
 * resolution only, and apparent size is decided by the placeholder — the one thing the
 * author can actually see.
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

// --- text is a fixed fraction of the canvas ----------------------------------
{
    const base = tickOf({ width: 540 });
    const wide = tickOf({ width: 1080 });
    // 405 not 270: 270 is half the baseline, which trips the 0.6 floor and would be
    // testing the clamp rather than the scaling. That floor is checked on its own below.
    const narrow = tickOf({ width: 405 });
    ok(base === 12, `540px canvas keeps the 12px baseline (got ${base})`);
    ok(wide === 24, `doubling the width doubles the label (got ${wide})`);
    ok(narrow === 9, `three-quarter width gives three-quarter text (got ${narrow})`);
    // The point of all this: label-to-chart ratio is constant, so the placeholder
    // decides apparent size and `width=` does not fight it.
    ok(wide / 1080 === base / 540, 'the label-to-width ratio is identical at both sizes');
}

// --- the title moves with the ticks ------------------------------------------
{
    ok(titleOf({ width: 540 }) === 16, 'title keeps its 16px baseline');
    ok(titleOf({ width: 1080 }) === 32, 'and doubles with the canvas');
}

// --- fontSize= is the author's override --------------------------------------
{
    ok(tickOf({ width: 540, fontSize: 18 }) === 18, 'fontSize=18 at the baseline width gives 18');
    ok(tickOf({ width: 1080, fontSize: 18 }) === 36, 'and scales with the canvas, so it means the same thing');
    ok(titleOf({ width: 540, fontSize: 18 }) === 24, 'the title follows the override too');
    ok(tickOf({ width: 540, fontSize: '14' }) === 14, 'a string from the tag map is accepted');
    ok(tickOf({ width: 540, fontSize: 0 }) === 12, 'fontSize=0 falls back rather than rendering nothing');
    ok(tickOf({ width: 540, fontSize: -5 }) === 12, 'and so does a negative');
    ok(tickOf({ width: 540, fontSize: 'abc' }) === 12, 'and so does nonsense');
}

// --- the scale is clamped -----------------------------------------------------
{
    // Below the floor the labels stop being legible however they are placed; above the
    // ceiling a very wide chart turns into headlines.
    ok(tickOf({ width: 60 }) === 7, `a tiny canvas floors at 0.6x -> 7px (got ${tickOf({ width: 60 })})`);
    ok(tickOf({ width: 270 }) === 7, `and so does half the baseline (got ${tickOf({ width: 270 })})`);
    ok(tickOf({ width: 9000 }) === 36, `a huge one caps at 3x (got ${tickOf({ width: 9000 })})`);
}

// --- defaults hold when the tag says nothing ---------------------------------
{
    ok(tickOf({}) === 12, 'no width given falls back to the baseline');
    ok(tickOf({ width: 'not a number' }) === 12, 'and so does an unparseable width');
}

console.log(fail ? `\n${fail} FAILED` : '\nchart fonts OK');
process.exit(fail ? 1 : 0);
