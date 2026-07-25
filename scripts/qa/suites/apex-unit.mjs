/**
 * The Apex unit suite — outcome plus REAL per-class coverage.
 *
 * "1470 tests, 100%" tells you nothing about where the risk is, and org-wide
 * coverage hides the class nobody tests at all. This reports the run outcome,
 * names any failing test, and then reports coverage PER CLASS so an untested
 * surface is visible by name.
 *
 * An earlier version guessed at coverage by asking whether a *Test class NAME
 * contained the production class name. That reported 32 classes as "untested
 * surface" when most are exercised by shared test files such as DocGenMiscTests
 * — a guess dressed up as a measurement, and it would have sent someone chasing
 * 32 phantom gaps. The numbers now come from ApexCodeCoverageAggregate.
 */
import { readdirSync } from 'node:fs';
import { runApexTests, apexCoverage, parseHumanTestRun } from '../lib/sf.mjs';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';

const CLASSES_DIR = new URL('../../../force-app/main/default/classes/', import.meta.url).pathname;

/** The bar a 2GP package build enforces org-wide. */
const PACKAGING_BAR = 75;

export function classInventory() {
    const files = readdirSync(CLASSES_DIR).filter((f) => f.endsWith('.cls'));
    const all = files.map((f) => f.replace('.cls', ''));
    return {
        all,
        tests: all.filter((c) => /test/i.test(c)),
        prod: all.filter((c) => !/test/i.test(c))
    };
}

export async function run({ org, classes }) {
    const checks = [];
    const { tests } = classInventory();
    if (!tests.length) {
        return suiteResult('apex-unit', 'Apex unit', [
            skip('Apex tests ran', 'no test classes found in the repo', SEVERITY.BLOCKER)
        ]);
    }

    // An explicit list is honoured as a deliberate scope; otherwise RunLocalTests.
    const toRun = classes && classes.length ? classes : [];
    let res;
    try {
        res = await runApexTests(org, toRun, { coverage: true });
    } catch (e) {
        return suiteResult('apex-unit', 'Apex unit', [
            check('Apex tests ran', false, String(e.message).slice(0, 240), SEVERITY.BLOCKER)
        ]);
    }

    const outcome = parseHumanTestRun(res.human || '');
    if (!outcome.ran) {
        return suiteResult('apex-unit', 'Apex unit', [
            check(
                'Apex tests ran',
                false,
                'the CLI produced no test summary — the run did not complete',
                SEVERITY.BLOCKER
            )
        ]);
    }

    checks.push(
        check(
            'the Apex test run passes',
            outcome.outcome === 'Passed' && outcome.failures.length === 0,
            outcome.outcome === 'Passed'
                ? `${outcome.ran} tests, ${outcome.passRate}%`
                : `${outcome.failures.length} failing: ` +
                      outcome.failures
                          .map((f) => f.test)
                          .slice(0, 5)
                          .join(', '),
            SEVERITY.BLOCKER
        )
    );
    // One check per failing test, so the report names it rather than burying it.
    for (const f of outcome.failures) {
        checks.push(check(`${f.test} passes`, false, f.message, SEVERITY.BLOCKER));
    }

    // --- per-class coverage ---------------------------------------------------
    let cov = [];
    try {
        cov = await apexCoverage(org);
    } catch (e) {
        checks.push(skip('per-class coverage was reported', String(e.message).slice(0, 160), SEVERITY.MINOR));
    }
    const prodCov = cov.filter((c) => !/test/i.test(c.name) && c.percent !== null);
    if (!prodCov.length) {
        checks.push(
            skip(
                'per-class coverage was reported',
                'ApexCodeCoverageAggregate returned nothing — the run may not have collected coverage',
                SEVERITY.MINOR
            )
        );
    }
    for (const c of prodCov) {
        // ZERO coverage is a different problem from thin coverage: nothing
        // exercises the class at all, so nothing would notice if it broke.
        if (c.percent === 0) {
            checks.push(
                check(
                    `${c.name} is exercised by some test`,
                    false,
                    `0% — ${c.total} lines, none covered. Nothing would notice if this class broke.`,
                    SEVERITY.MAJOR
                )
            );
            continue;
        }
        checks.push(
            check(
                `${c.name} meets the ${PACKAGING_BAR}% packaging bar`,
                c.percent >= PACKAGING_BAR,
                `${c.percent}% (${c.covered}/${c.total} lines)`,
                SEVERITY.MINOR
            )
        );
    }

    // Org-wide: the number the package build actually gates on.
    if (prodCov.length) {
        const covered = prodCov.reduce((a, c) => a + c.covered, 0);
        const total = prodCov.reduce((a, c) => a + c.total, 0);
        const pct = total ? Math.round((covered / total) * 100) : 0;
        checks.push(
            check(
                `org-wide coverage is at or above ${PACKAGING_BAR}%`,
                pct >= PACKAGING_BAR,
                `${pct}% (${covered}/${total} lines) — a 2GP build fails below ${PACKAGING_BAR}%`,
                SEVERITY.BLOCKER
            )
        );
    }

    return suiteResult('apex-unit', 'Apex unit', checks);
}
