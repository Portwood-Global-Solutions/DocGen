// HTML → Canvas import fidelity harness.
//
//   node scripts/qa/canvas-import-fidelity.mjs
//
// Converts each shipped starter through htmlToCanvas(), re-serializes it as a Canvas
// document, and reports what survived. It writes both bodies to /tmp so they can be
// rendered and compared as PDFs in an org.
//
// WHY THIS EXISTS
// ---------------
// The claim behind the importer is that a Canvas document IS an HTML document, so
// re-describing an existing template's blocks as boxes should emit near-identical
// markup and leave the PDF essentially unchanged. That claim is testable, and a
// conversion tool nobody measured is exactly the kind of thing that quietly degrades
// every template it touches.
//
// Needs a DOM: htmlToCanvas parses with <template>. Run under jsdom when available;
// otherwise this reports the fact rather than pretending to have measured something.
import { readFileSync, writeFileSync } from 'node:fs';

const KIT = new URL('../../force-app/main/default/lwc/docGenAuthoringKit/docGenAuthoringKit.js', import.meta.url);
const MODEL = new URL('../../force-app/main/default/lwc/docGenCanvas/canvasModel.js', import.meta.url);

let JSDOM;
try {
    ({ JSDOM } = await import('jsdom'));
} catch {
    process.stdout.write(
        'jsdom is not installed, so the importer cannot be exercised headlessly.\n' +
            '  npm i -D jsdom     then re-run\n' +
            'The importer itself is unaffected; this harness just needs a DOM to drive it.\n'
    );
    process.exit(2);
}

const dom = new JSDOM('<!doctype html><html><body></body></html>');
global.document = dom.window.document;
global.window = dom.window;

// The kit imports one helper from another LWC bundle, which Node cannot resolve.
// Inlined here rather than stubbed away: parseSOQLFields shapes what the starters
// build, so replacing it with a fake would measure a document nobody ships.
const UTILS = new URL('../../force-app/main/default/lwc/docGenUtils/docGenUtils.js', import.meta.url);
writeFileSync('/tmp/dg-utils.mjs', readFileSync(UTILS, 'utf8'));
writeFileSync('/tmp/dg-kit.mjs', readFileSync(KIT, 'utf8').replace("from 'c/docGenUtils'", "from '/tmp/dg-utils.mjs'"));
writeFileSync('/tmp/dg-model.mjs', readFileSync(MODEL, 'utf8'));
const kit = await import('/tmp/dg-kit.mjs?v=' + Date.now());
const m = await import('/tmp/dg-model.mjs?v=' + Date.now());

// A representative query shape, so the starters build with real merge tags in them.
const shape = {
    baseObject: 'Account',
    baseFields: ['Name', 'AccountNumber', 'Industry', 'Phone', 'BillingCity'],
    parentFields: [],
    children: [{ relationshipName: 'Opportunities', fields: ['Name', 'Amount', 'StageName', 'CloseDate'] }]
};

// Signals worth preserving: lose any of these and the document is materially changed.
function census(html) {
    // <head> is excluded from BOTH sides. The source carries a <title>, the converted
    // deliberately does not (a title is not page content and printed as a visible line
    // when it leaked through), so counting it made a lossless conversion look lossy.
    const visible = html.replace(/<head[\s\S]*?<\/head>/gi, ' ').replace(/<title[\s\S]*?<\/title>/gi, ' ');
    const text = visible
        .replace(/<(script|style)[\s\S]*?<\/\1>/gi, ' ')
        .replace(/<[^>]*>/g, ' ')
        .replace(/&nbsp;|&#160;/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    return {
        mergeTags: (visible.match(/\{[#/^%@*?]?[A-Za-z_][^}]*\}/g) || []).filter((t) => !t.includes(':') || true)
            .length,
        tables: (visible.match(/<table/gi) || []).length,
        rows: (visible.match(/<tr/gi) || []).length,
        cells: (visible.match(/<t[dh]/gi) || []).length,
        images: (visible.match(/<img/gi) || []).length,
        words: text ? text.split(' ').length : 0
    };
}

let failures = 0;

// --- links -----------------------------------------------------------------
// Blob.toPdf emits a real /Link annotation: an http(s) href becomes a /URI action and
// an in-document #anchor a /GoTo jump — measured against a rendered PDF, which is why
// the link button exists at all after being removed on the opposite assumption.
// The href is filtered by SCHEME because it is the one attribute here that can carry
// executable content, and refusing one must never take its text away with it.
const linkClean = m.sanitizeInline(
    '<p><a href="https://example.com">ok</a> <a href="javascript:alert(1)">bad</a> <a href="#terms">jump</a></p>'
);
const linkChecks = [
    ['an https link keeps its href', linkClean.includes('href="https://example.com"')],
    ['an in-document anchor keeps its href', linkClean.includes('href="#terms"')],
    ['a javascript: href is refused', !/javascript/i.test(linkClean)],
    ['refusing an href never removes its text', linkClean.includes('bad')]
];
process.stdout.write('\nSanitizer — links\n' + '='.repeat(64) + '\n');
for (const [name, ok] of linkChecks) {
    if (!ok) failures++;
    process.stdout.write((ok ? '  PASS  ' : '  FAIL  ') + name + '\n');
}

process.stdout.write('\nHTML → Canvas import fidelity\n' + '='.repeat(64) + '\n');

for (const starter of kit.STARTERS) {
    const source = kit.buildStarterHtml(starter.key, shape);
    const { doc, page, report } = m.htmlToCanvas(source);
    const geo = page ? m.pageGeometry(page.size, page.orientation, page.margins) : m.pageGeometry('Letter', 'Portrait');
    const converted = m.serialize(doc, geo);

    const a = census(source);
    const b = census(converted);
    // Merge tags and table structure MUST survive exactly — those are the document's
    // meaning. Word count is allowed to drift slightly (wrapper markup, whitespace).
    const exact = ['mergeTags', 'tables', 'rows', 'cells', 'images'];
    const bad = exact.filter((k) => a[k] !== b[k]);
    const wordDrift = a.words === 0 ? 0 : Math.abs(a.words - b.words) / a.words;
    const ok = bad.length === 0 && wordDrift < 0.02;
    if (!ok) failures++;

    process.stdout.write(
        `\n${ok ? 'PASS' : 'FAIL'}  ${starter.label}  (${report.boxes} boxes)\n` +
            `      tags ${a.mergeTags}→${b.mergeTags}   tables ${a.tables}→${b.tables}   ` +
            `rows ${a.rows}→${b.rows}   cells ${a.cells}→${b.cells}   ` +
            `images ${a.images}→${b.images}   words ${a.words}→${b.words}\n`
    );
    if (bad.length) process.stdout.write(`      LOST: ${bad.join(', ')}\n`);
    for (const d of report.dropped) process.stdout.write(`      dropped: ${d}\n`);

    writeFileSync(`/tmp/dg-import-${starter.key}-source.html`, source);
    writeFileSync(`/tmp/dg-import-${starter.key}-canvas.html`, converted);
}

process.stdout.write(
    '\n' +
        '='.repeat(64) +
        (failures ? `\n${failures} starter(s) lost content in conversion\n` : '\nall starters converted losslessly\n') +
        'bodies written to /tmp/dg-import-*-{source,canvas}.html for PDF comparison\n'
);
process.exit(failures ? 1 : 0);
