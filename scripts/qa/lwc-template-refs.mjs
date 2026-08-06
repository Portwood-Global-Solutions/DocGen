// LWC template-reference audit — every {name} a template binds must exist in its JS.
//
// Pure Node, no org needed:  node scripts/qa/lwc-template-refs.mjs
//
// WHY THIS EXISTS
// ---------------
// A template that binds a getter or handler the class does not define fails SILENTLY.
// LWC renders the component, the expression resolves to undefined, and the control is
// simply inert — a dropdown with no options, a button that does nothing. It deploys
// clean, it lints clean, and the only way to find out is to click it.
//
// This has bitten this component twice, both times the same way: an edit replaced a
// RANGE of the JS file and the range quietly contained handlers belonging to a
// different feature. The Data button went dead that way once; the QR/barcode panel went
// dead that way a second time, shipping a Type dropdown with no options and a field
// input wired to nothing. Deployment cannot catch it, so this does.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

const LWC_DIR = new URL('../../force-app/main/default/lwc/', import.meta.url).pathname;

// Iteration aliases (for:item / for:index / iterator) are declared by the template
// itself, so they are legitimately absent from the JS.
function localNames(html) {
    const names = new Set();
    for (const m of html.matchAll(/for:item="([^"]+)"/g)) names.add(m[1]);
    for (const m of html.matchAll(/for:index="([^"]+)"/g)) names.add(m[1]);
    for (const m of html.matchAll(/iterator:([A-Za-z0-9_]+)=/g)) names.add(m[1]);
    for (const m of html.matchAll(/lwc:ref="([^"]+)"/g)) names.add(m[1]);
    return names;
}

function definedNames(js) {
    const names = new Set();
    // Getters, methods, class fields, @api/@track properties.
    for (const m of js.matchAll(/^\s*(?:get|set)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm)) names.add(m[1]);
    for (const m of js.matchAll(/^\s*(?:async\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*\{/gm)) names.add(m[1]);
    for (const m of js.matchAll(/^\s*(?:@api\s+|@track\s+|@wire\([^)]*\)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*[=;]/gm)) {
        names.add(m[1]);
    }
    return names;
}

let bad = 0;
let checked = 0;
for (const bundle of readdirSync(LWC_DIR)) {
    const dir = join(LWC_DIR, bundle);
    if (!statSync(dir).isDirectory()) continue;
    const htmlPath = join(dir, bundle + '.html');
    const jsPath = join(dir, bundle + '.js');
    if (!existsSync(htmlPath) || !existsSync(jsPath)) continue;

    const html = readFileSync(htmlPath, 'utf8');
    const js = readFileSync(jsPath, 'utf8');
    const known = definedNames(js);
    const locals = localNames(html);
    checked += 1;

    // {name} and {name.path} in text/attributes, plus attr={name} bindings.
    const refs = new Set();
    for (const m of html.matchAll(/\{\s*([A-Za-z_][A-Za-z0-9_]*)(?:\.[A-Za-z0-9_.]+)?\s*\}/g)) refs.add(m[1]);

    const missing = [...refs].filter((r) => !known.has(r) && !locals.has(r)).sort();
    if (missing.length) {
        bad += missing.length;
        process.stdout.write(`  FAIL  ${bundle}: template binds undefined ${missing.join(', ')}\n`);
    }
}

process.stdout.write(bad ? `\n${bad} undefined template reference(s)\n` : `\ntemplate refs OK (${checked} bundles)\n`);
process.exit(bad ? 1 : 0);
