/**
 * The Apex unit suite, reported PER CLASS rather than as one number.
 *
 * "1470 tests, 100%" tells you nothing about where the risk is. This reports the
 * per-class outcome so a failure names its class, and — more usefully — flags
 * production classes that have NO test class at all. An untested class is not a
 * passing one, and the org-wide coverage percentage hides exactly that.
 */
import { readdirSync } from 'node:fs';
import { runApexTests } from '../lib/sf.mjs';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';

const CLASSES_DIR = new URL('../../../force-app/main/default/classes/', import.meta.url).pathname;

/** Classes that legitimately have no dedicated test class. */
const NO_TEST_EXPECTED = new Set([
    'DocGenException' // a bare exception type
]);

export function classInventory() {
    const files = readdirSync(CLASSES_DIR).filter((f) => f.endsWith('.cls'));
    const all = files.map((f) => f.replace('.cls', ''));
    const tests = all.filter((c) => /test/i.test(c));
    const prod = all.filter((c) => !/test/i.test(c));
    return { all, tests, prod };
}

export async function run({ org, classes }) {
    const { tests, prod } = classInventory();
    const checks = [];

    // --- which production classes have no test at all? ------------------------
    // Cheap, offline, and it is the metric that actually moves risk.
    const testBlob = tests.join('|').toLowerCase();
    for (const c of prod) {
        if (NO_TEST_EXPECTED.has(c)) continue;
        const has = testBlob.includes(c.toLowerCase());
        checks.push(
            check(
                `${c} has a test class`,
                has,
                has ? '' : 'no *Test class references this class name — untested surface',
                SEVERITY.MAJOR
            )
        );
    }

    // --- run the tests --------------------------------------------------------
    // No explicit list -> RunLocalTests. Naming all 43 classes builds a command
    // line the CLI refuses, which surfaced as a blocker that was really a harness
    // bug rather than a failing test.
    const toRun = classes && classes.length ? classes : [];
    if (!tests.length) {
        checks.push(skip('Apex tests ran', 'no test classes found', SEVERITY.BLOCKER));
        return suiteResult('apex-unit', 'Apex unit', checks);
    }
    let res;
    try {
        res = await runApexTests(org, toRun);
    } catch (e) {
        checks.push(check('Apex tests ran', false, String(e.message).slice(0, 240), SEVERITY.BLOCKER));
        return suiteResult('apex-unit', 'Apex unit', checks);
    }

    if (!res.tests.length) {
        checks.push(
            check(
                'Apex tests ran',
                false,
                'the CLI returned no test results — check the org and the class list',
                SEVERITY.BLOCKER
            )
        );
        return suiteResult('apex-unit', 'Apex unit', checks);
    }

    // One check per CLASS, so a failure names where to look without 1470 rows.
    const byClass = {};
    for (const t of res.tests) {
        const cls = (t.ApexClass && t.ApexClass.Name) || t.FullName?.split('.')[0] || 'unknown';
        byClass[cls] = byClass[cls] || { pass: 0, fail: 0, failures: [] };
        if (t.Outcome === 'Pass') byClass[cls].pass++;
        else {
            byClass[cls].fail++;
            byClass[cls].failures.push(`${t.MethodName}: ${String(t.Message || '').slice(0, 120)}`);
        }
    }
    for (const [cls, r] of Object.entries(byClass)) {
        checks.push(
            check(
                `${cls} passes`,
                r.fail === 0,
                r.fail === 0 ? `${r.pass} methods` : r.failures.slice(0, 3).join(' | '),
                SEVERITY.BLOCKER
            )
        );
    }
    return suiteResult('apex-unit', 'Apex unit', checks, { summary: res.summary });
}
