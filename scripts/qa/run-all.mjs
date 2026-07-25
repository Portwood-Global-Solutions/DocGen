#!/usr/bin/env node
/**
 * DocGen QA — one command, every suite, one report.
 *
 * WHY THIS EXISTS
 * ---------------
 * The evidence that this package works was spread across three places that
 * nobody ran together: an Apex unit run, a hand-run sequence of anonymous Apex
 * scripts, and a browser smoke test for one component. Everything else —
 * page layouts, permission sets, Flow actions, the runner UI, the merge-tag
 * matrix, every output format — was verified by a person clicking, or not at
 * all. This runs the lot and tells you, in one number and one ordered fix list,
 * what works and what does not.
 *
 * USAGE
 *   npm run qa                          # everything, against docgen-verify
 *   npm run qa -- --org myorg
 *   npm run qa -- --suite metadata-audit,merge-tags
 *   npm run qa -- --offline             # only suites that need no org
 *   npm run qa -- --headed              # watch the browser suites
 *   npm run qa -- --list                # what suites exist
 *
 * EXIT CODE
 *   0 = every evaluated check passed
 *   1 = at least one failed
 *   2 = the harness itself could not run
 *
 * OUTPUT
 *   scripts/qa/report/qa-report.md      # the readable report
 *   scripts/qa/report/qa-report.json    # the same data, for trend tracking
 *
 * ADDING A SUITE
 *   Drop a file in suites/ that exports `run({ org, headed, base })` and returns
 *   suiteResult(...) from lib/report.mjs. Register it in SUITES below. Suites
 *   must never throw — a suite that cannot run returns suiteSkipped() so the
 *   report says so out loud instead of quietly reporting 100%.
 */
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { printConsole, toMarkdown, tally, suiteSkipped } from './lib/report.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));

/**
 * needsOrg  — false for suites that read the repo only (they run in CI with no org)
 * heavy     — true for suites that take minutes; skipped by --fast
 */
const SUITES = [
    { id: 'metadata-audit', file: './suites/metadata-audit.mjs', needsOrg: false, heavy: false },
    // apex-e2e FIRST among the org suites. Its scripts share ordered state — 02
    // creates the data 03..06b assert against — and every other suite creates and
    // deletes templates in the same org. Running it late let a sibling suite's
    // cleanup pull the ground out from under e2e-06b, which then aborted with
    // "run e2e-02 first". The chain passes cleanly in isolation; the failure was
    // cross-suite interference, not a product defect.
    { id: 'apex-e2e', file: './suites/apex-e2e.mjs', needsOrg: true, heavy: true },
    { id: 'apex-unit', file: './suites/apex-unit.mjs', needsOrg: true, heavy: true },
    { id: 'merge-tags', file: './suites/merge-tags.mjs', needsOrg: true, heavy: false },
    { id: 'flow-actions', file: './suites/flow-actions.mjs', needsOrg: true, heavy: false },
    { id: 'output-formats', file: './suites/output-formats.mjs', needsOrg: true, heavy: true },
    { id: 'ui-designer', file: './suites/ui-designer.mjs', needsOrg: true, heavy: true },
    { id: 'ui-admin', file: './suites/ui-admin.mjs', needsOrg: true, heavy: true },
    { id: 'ui-runner', file: './suites/ui-runner.mjs', needsOrg: true, heavy: true },
    { id: 'record-pages', file: './suites/record-pages.mjs', needsOrg: true, heavy: false },
    // Reads the generated PDF's TEXT. The only suite that can see the
    // v2.5.0 missing-chrome class of regression, which produced a valid
    // PDF of a plausible size with its title and headers silently gone.
    { id: 'pdf-content', file: './suites/pdf-content.mjs', needsOrg: true, heavy: true }
];

const args = process.argv.slice(2);
const argVal = (name, fallback = null) => {
    const i = args.indexOf(name);
    return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
};
const has = (f) => args.includes(f);

const ORG = argVal('--org', 'docgen-verify');
const HEADED = has('--headed');
const OFFLINE = has('--offline');
const FAST = has('--fast');
const ONLY = (argVal('--suite', '') || '').split(',').filter(Boolean);

if (has('--list')) {
    process.stdout.write('\nSuites:\n');
    for (const s of SUITES) {
        process.stdout.write(`  ${s.id.padEnd(18)} ${s.needsOrg ? 'org' : 'offline'}${s.heavy ? ', heavy' : ''}\n`);
    }
    process.stdout.write('\n');
    process.exit(0);
}

async function main() {
    const startedAt = new Date().toISOString();
    const t0 = Date.now();
    const results = [];

    for (const s of SUITES) {
        if (ONLY.length && !ONLY.includes(s.id)) continue;
        if (OFFLINE && s.needsOrg) continue;
        if (FAST && s.heavy) continue;

        let mod;
        try {
            mod = await import(s.file);
        } catch (e) {
            // A suite that does not exist yet is a KNOWN GAP, reported as such.
            // The alternative — omitting it — makes the report look complete.
            results.push(
                suiteSkipped(
                    s.id,
                    'Not implemented',
                    `suite file missing or broken: ${String(e.message).slice(0, 140)}`
                )
            );
            continue;
        }
        process.stderr.write(`  … ${s.id}\n`);
        try {
            const r = await mod.run({ org: ORG, headed: HEADED });
            results.push(r);
        } catch (e) {
            results.push(suiteSkipped(s.id, 'Crashed', `threw: ${String(e.message).slice(0, 200)}`));
        }
    }

    const durationMs = Date.now() - t0;
    const meta = { org: ORG, startedAt, durationMs, args: args.join(' ') };
    const t = printConsole(results, meta);

    const outDir = join(HERE, 'report');
    if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
    writeFileSync(join(outDir, 'qa-report.md'), toMarkdown(results, meta), 'utf8');
    writeFileSync(join(outDir, 'qa-report.json'), JSON.stringify({ meta, tally: t, suites: results }, null, 2), 'utf8');
    process.stdout.write(`Report: scripts/qa/report/qa-report.md\n\n`);

    process.exit(t.failed ? 1 : 0);
}

main().catch((e) => {
    process.stderr.write(`\nQA harness failed to run: ${e.stack || e.message}\n`);
    process.exit(2);
});
