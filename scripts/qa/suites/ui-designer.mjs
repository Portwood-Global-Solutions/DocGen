/**
 * The existing designer smoke test, folded into the harness.
 *
 * scripts/ui-smoke.mjs is 90+ behavioural browser assertions built up over the
 * designer work, and it is the most battle-tested thing here — it has caught a
 * dozen real regressions including several I introduced. It is deliberately NOT
 * rewritten into this harness's style: it is shelled out to and its output
 * parsed. Rewriting working assertions to satisfy a report format would risk the
 * assertions to gain nothing.
 */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { check, suiteResult, SEVERITY } from '../lib/report.mjs';

const exec = promisify(execFile);

export async function run({ org, headed }) {
    const args = ['scripts/ui-smoke.mjs', '--org', org];
    if (headed) args.push('--headed');
    let out = '';
    try {
        const r = await exec('node', args, { maxBuffer: 32 * 1024 * 1024, timeout: 1800000 });
        out = r.stdout;
    } catch (e) {
        // Non-zero exit means assertions failed — that is a RESULT, and its stdout
        // holds the per-check lines we want.
        out = (e.stdout || '') + (e.stderr || '');
    }

    const checks = [];
    for (const line of out.split('\n')) {
        const m = /^\s*(PASS|FAIL|SKIP)\s+(.+?)(?:\s+—\s+(.*))?$/.exec(line);
        if (!m) continue;
        const [, verdict, name, detail] = m;
        if (verdict === 'SKIP') {
            checks.push({ name, ok: false, detail: detail || 'skipped', severity: SEVERITY.MINOR, skipped: true });
        } else {
            checks.push(check(name, verdict === 'PASS', detail || '', SEVERITY.MAJOR));
        }
    }
    if (!checks.length) {
        checks.push(
            check(
                'designer smoke ran',
                false,
                'ui-smoke.mjs produced no PASS/FAIL lines — it probably could not open the designer at all',
                SEVERITY.BLOCKER
            )
        );
    }
    return suiteResult('ui-designer', 'Designer UI', checks);
}
