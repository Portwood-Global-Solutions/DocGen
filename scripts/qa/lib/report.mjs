/**
 * THE RESULT CONTRACT
 * ===================
 * Every suite in this harness — Apex, browser, metadata, whatever comes next —
 * returns the same shape. That is the whole reason a report exists at all: six
 * suites written by six people in six styles still aggregate into one number and
 * one fix list.
 *
 * A suite returns:
 *   {
 *     suite:   'merge-tags',            // stable id, used in the report and to filter runs
 *     area:    'Merge tags',            // human grouping in the report
 *     skipped: false,                   // true when the suite could not run at all
 *     reason:  '',                      // why, when skipped
 *     checks:  [ Check, ... ]
 *   }
 *
 * A Check is:
 *   {
 *     name:     'what was asserted',    // reads as a sentence, not a code symbol
 *     ok:       true | false,
 *     detail:   'evidence either way',  // on failure this must say WHERE to look
 *     severity: 'blocker'|'major'|'minor',   // default 'major'
 *     skipped:  false,                  // a check that could not run is NOT a pass
 *     area:     'optional sub-area'
 *   }
 *
 * The severity field is what turns a wall of failures into a work queue:
 *   blocker — a customer cannot complete the job (generation fails, data lost)
 *   major   — a feature is broken but has a workaround
 *   minor   — cosmetic, or an internal-only rough edge
 */

export const SEVERITY = { BLOCKER: 'blocker', MAJOR: 'major', MINOR: 'minor' };

/** Build a check. Keeps every suite from inventing its own field names. */
export function check(name, ok, detail = '', severity = SEVERITY.MAJOR) {
    return { name, ok: !!ok, detail: detail || '', severity, skipped: false };
}

/** A check that could not be evaluated. Counted separately — never as a pass. */
export function skip(name, reason, severity = SEVERITY.MAJOR) {
    return { name, ok: false, detail: reason, severity, skipped: true };
}

export function suiteResult(suite, area, checks, extra = {}) {
    return { suite, area, checks: checks || [], skipped: false, reason: '', ...extra };
}

export function suiteSkipped(suite, area, reason) {
    return { suite, area, checks: [], skipped: true, reason };
}

const GREEN = '[32m';
const RED = '[31m';
const YELLOW = '[33m';
const DIM = '[2m';
const BOLD = '[1m';
const OFF = '[0m';

export function tally(suites) {
    let passed = 0;
    let failed = 0;
    let skipped = 0;
    const bySeverity = { blocker: 0, major: 0, minor: 0 };
    for (const s of suites) {
        for (const c of s.checks) {
            if (c.skipped) {
                skipped++;
                continue;
            }
            if (c.ok) {
                passed++;
            } else {
                failed++;
                bySeverity[c.severity] = (bySeverity[c.severity] || 0) + 1;
            }
        }
    }
    const evaluated = passed + failed;
    return {
        passed,
        failed,
        skipped,
        evaluated,
        total: evaluated + skipped,
        // Skipped checks are excluded from the rate but reported alongside it —
        // a suite that silently skips everything must not read as 100%.
        rate: evaluated ? Math.round((passed / evaluated) * 1000) / 10 : 0,
        bySeverity
    };
}

export function printConsole(suites, meta) {
    const t = tally(suites);
    process.stdout.write(`\n${BOLD}DocGen QA — ${meta.org}${OFF}  ${DIM}${meta.startedAt}${OFF}\n\n`);
    for (const s of suites) {
        if (s.skipped) {
            process.stdout.write(`${YELLOW}  SKIP${OFF}  ${BOLD}${s.suite}${OFF} — ${s.reason}\n`);
            continue;
        }
        const st = tally([s]);
        const colour = st.failed ? RED : GREEN;
        process.stdout.write(
            `${colour}  ${st.failed ? 'FAIL' : ' OK '}${OFF}  ${BOLD}${s.suite}${OFF} ` +
                `${DIM}${st.passed}/${st.evaluated}${st.skipped ? ` (+${st.skipped} skipped)` : ''}${OFF}\n`
        );
        for (const c of s.checks) {
            if (c.ok) continue;
            const tag = c.skipped ? `${YELLOW}skip${OFF}` : `${RED}${c.severity}${OFF}`;
            process.stdout.write(`        [${tag}] ${c.name}${c.detail ? ` ${DIM}— ${c.detail}${OFF}` : ''}\n`);
        }
    }
    process.stdout.write(
        `\n${BOLD}${t.passed}/${t.evaluated} passed${OFF} (${t.rate}%)` +
            `${t.skipped ? `  ${YELLOW}${t.skipped} skipped${OFF}` : ''}` +
            `${t.failed ? `  ${RED}${t.failed} failed${OFF}` : ''}\n`
    );
    if (t.failed) {
        process.stdout.write(
            `${DIM}blockers ${t.bySeverity.blocker || 0} · major ${t.bySeverity.major || 0} · minor ${t.bySeverity.minor || 0}${OFF}\n`
        );
    }
    process.stdout.write('\n');
    return t;
}

export function toMarkdown(suites, meta) {
    const t = tally(suites);
    const L = [];
    L.push(`# DocGen QA report`);
    L.push('');
    L.push(`**Org** \`${meta.org}\` · **Run** ${meta.startedAt} · **Duration** ${Math.round(meta.durationMs / 1000)}s`);
    L.push('');
    L.push(`## Headline`);
    L.push('');
    L.push(`| | |`);
    L.push(`| --- | --- |`);
    L.push(`| Checks evaluated | ${t.evaluated} |`);
    L.push(`| Passed | ${t.passed} (${t.rate}%) |`);
    L.push(`| Failed | ${t.failed} |`);
    L.push(`| Skipped (not counted) | ${t.skipped} |`);
    L.push(`| Blockers | ${t.bySeverity.blocker || 0} |`);
    L.push(`| Major | ${t.bySeverity.major || 0} |`);
    L.push(`| Minor | ${t.bySeverity.minor || 0} |`);
    L.push('');

    L.push(`## Coverage by area`);
    L.push('');
    L.push(`| Suite | Area | Passed | Failed | Skipped | Rate |`);
    L.push(`| --- | --- | ---: | ---: | ---: | ---: |`);
    for (const s of suites) {
        if (s.skipped) {
            L.push(`| \`${s.suite}\` | ${s.area} | — | — | — | _skipped: ${s.reason}_ |`);
            continue;
        }
        const st = tally([s]);
        L.push(
            `| \`${s.suite}\` | ${s.area} | ${st.passed} | ${st.failed} | ${st.skipped} | ${st.rate}% |`
        );
    }
    L.push('');

    const failures = [];
    for (const s of suites) {
        for (const c of s.checks) {
            if (!c.ok && !c.skipped) failures.push({ ...c, suite: s.suite });
        }
    }
    if (failures.length) {
        L.push(`## What to fix`);
        L.push('');
        L.push(`Ordered by severity. The detail column is written to say WHERE to look.`);
        L.push('');
        L.push(`| Severity | Suite | Check | Evidence |`);
        L.push(`| --- | --- | --- | --- |`);
        const order = { blocker: 0, major: 1, minor: 2 };
        failures.sort((a, b) => order[a.severity] - order[b.severity]);
        for (const f of failures) {
            L.push(
                `| **${f.severity}** | \`${f.suite}\` | ${esc(f.name)} | ${esc(f.detail).slice(0, 300)} |`
            );
        }
        L.push('');
    } else {
        L.push(`## What to fix`);
        L.push('');
        L.push(`Nothing — every evaluated check passed.`);
        L.push('');
    }

    const skips = [];
    for (const s of suites) {
        for (const c of s.checks) {
            if (c.skipped) skips.push({ ...c, suite: s.suite });
        }
    }
    if (skips.length) {
        L.push(`## Not covered by this run`);
        L.push('');
        L.push(`A skipped check is not a passing one. Each of these is a gap in the evidence.`);
        L.push('');
        for (const s of skips) L.push(`- \`${s.suite}\` — ${esc(s.name)}: ${esc(s.detail)}`);
        L.push('');
    }

    L.push(`## Every check`);
    L.push('');
    for (const s of suites) {
        if (s.skipped) continue;
        L.push(`### ${s.suite} — ${s.area}`);
        L.push('');
        for (const c of s.checks) {
            const mark = c.skipped ? '⊘' : c.ok ? '✅' : '❌';
            L.push(`- ${mark} ${esc(c.name)}${c.detail ? ` — ${esc(c.detail).slice(0, 200)}` : ''}`);
        }
        L.push('');
    }
    return L.join('\n');
}

function esc(s) {
    return String(s == null ? '' : s)
        .replace(/\|/g, '\\|')
        .replace(/\n/g, ' ');
}
