/**
 * The scripts/e2e-*.apex suite, run in order and PARSED rather than eyeballed.
 *
 * These scripts print `PASS: n  FAIL: n  ALL TESTS PASSED`. Two failure modes
 * matter and only one is obvious:
 *
 *  1. A non-zero FAIL count — the script ran and something was wrong.
 *  2. NO SUMMARY LINE AT ALL — the script hit a governor limit and died. A
 *     thrown LimitException prints nothing, so a run that emits no `PASS:` is
 *     not a pass; it is the worst kind of failure, the silent one. This is why
 *     e2e-03b exists as a separate file from e2e-03.
 *
 * Order matters: 02 creates the data 03..06b depend on, 08 tears it down.
 */
import { runAnonymousFile } from '../lib/sf.mjs';
import { check, suiteResult, SEVERITY } from '../lib/report.mjs';
import { existsSync } from 'node:fs';

/** The release-checklist sequence, in the order the checklist runs them. */
export const E2E_SEQUENCE = [
    ['e2e-01-permissions.apex', 'Permissions', SEVERITY.BLOCKER],
    ['e2e-02-template-crud.apex', 'Template CRUD', SEVERITY.BLOCKER],
    ['e2e-03-generate-pdf.apex', 'PDF generation', SEVERITY.BLOCKER],
    ['e2e-03b-page-setup.apex', 'Page setup', SEVERITY.MAJOR],
    ['e2e-04-generate-docx.apex', 'DOCX generation', SEVERITY.BLOCKER],
    ['e2e-05-generate-bulk.apex', 'Bulk generation', SEVERITY.MAJOR],
    ['e2e-06-signatures.apex', 'Signatures', SEVERITY.BLOCKER],
    ['e2e-06b-signature-lifecycle.apex', 'Signature lifecycle', SEVERITY.MAJOR],
    ['e2e-07-syntax1.apex', 'Merge-tag syntax', SEVERITY.BLOCKER],
    ['e2e-07-syntax2.apex', 'Merge-tag syntax', SEVERITY.BLOCKER],
    ['e2e-07-syntax3.apex', 'Merge-tag syntax', SEVERITY.BLOCKER],
    ['e2e-07-syntax4.apex', 'Merge-tag syntax', SEVERITY.BLOCKER],
    ['e2e-09-images.apex', 'Images', SEVERITY.MAJOR],
    ['e2e-08-cleanup.apex', 'Cleanup', SEVERITY.MINOR]
];

export function parseE2E(log) {
    const m = /PASS:\s*(\d+)\s+FAIL:\s*(\d+)/i.exec(log || '');
    if (!m) {
        // Pull whatever the org said went wrong — a governor limit or a compile
        // error, both of which print instead of the summary.
        const err =
            /(System\.LimitException[^\n]*)/.exec(log || '') ||
            /(Compile error[^\n]*)/i.exec(log || '') ||
            /(FATAL_ERROR[^\n]*)/.exec(log || '');
        return {
            ran: false,
            pass: 0,
            fail: 0,
            why: err ? err[1].slice(0, 220) : 'no PASS/FAIL summary line was printed'
        };
    }
    return { ran: true, pass: Number(m[1]), fail: Number(m[2]), why: '' };
}

export async function run({ org, only }) {
    const checks = [];
    for (const [file, area, severity] of E2E_SEQUENCE) {
        if (only && !file.includes(only)) continue;
        const path = `scripts/${file}`;
        if (!existsSync(path)) {
            checks.push(check(`${file} exists`, false, 'script missing from scripts/', SEVERITY.MAJOR));
            continue;
        }
        let log = '';
        try {
            log = await runAnonymousFile(org, path, { timeout: 900000 });
        } catch (e) {
            checks.push(check(`${area}: ${file}`, false, `CLI failed: ${String(e.message).slice(0, 200)}`, severity));
            continue;
        }
        const r = parseE2E(log);
        if (!r.ran) {
            checks.push(
                check(
                    `${area}: ${file}`,
                    false,
                    // Spelled out because a missing summary reads like nothing happened.
                    `NO SUMMARY PRINTED — the script did not finish. ${r.why}`,
                    severity
                )
            );
            continue;
        }
        checks.push(
            check(
                `${area}: ${file}`,
                r.fail === 0,
                r.fail === 0 ? `${r.pass} assertions` : `${r.fail} of ${r.pass + r.fail} assertions failed`,
                severity
            )
        );
    }
    return suiteResult('apex-e2e', 'Apex end-to-end', checks);
}
