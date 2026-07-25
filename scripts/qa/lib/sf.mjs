/**
 * Salesforce CLI helpers.
 *
 * Every suite that talks to an org goes through here, so retry/timeout/parsing
 * behaviour is decided once. The CLI is chatty and occasionally flaky (the
 * ETIMEDOUT on a Soap endpoint is real and transient), so reads retry.
 */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const exec = promisify(execFile);

const BIG = 64 * 1024 * 1024; // Apex debug logs are large; never truncate them.

async function sf(args, { timeout = 900000, retries = 1 } = {}) {
    let lastErr;
    for (let attempt = 0; attempt <= retries; attempt++) {
        try {
            const { stdout } = await exec('sf', args, { maxBuffer: BIG, timeout });
            return stdout;
        } catch (e) {
            lastErr = e;
            // stdout is still useful on a non-zero exit — apex run returns non-zero
            // when the script itself printed a failure, which is a RESULT not an error.
            if (e.stdout && e.stdout.length) return e.stdout;
            if (attempt < retries) await new Promise((r) => setTimeout(r, 3000));
        }
    }
    throw lastErr;
}

export async function orgFrontDoorUrl(org) {
    const raw = await sf(['org', 'open', '--target-org', org, '--url-only', '--json'], { retries: 2 });
    return JSON.parse(raw).result.url;
}

/** Run a block of anonymous Apex; returns the raw log. */
export async function runAnonymous(org, apexSource, opts = {}) {
    const dir = mkdtempSync(join(tmpdir(), 'dgqa-'));
    const file = join(dir, 'run.apex');
    writeFileSync(file, apexSource, 'utf8');
    return sf(['apex', 'run', '--target-org', org, '-f', file], opts);
}

/** Run an anonymous Apex FILE that already exists (the scripts/e2e-*.apex set). */
export async function runAnonymousFile(org, path, opts = {}) {
    return sf(['apex', 'run', '--target-org', org, '-f', path], opts);
}

/**
 * Pull DEBUG lines a script emitted. Anonymous Apex has no return channel, so
 * every suite that needs data out of an org prints `KEY=value` and reads it here.
 */
export function debugLines(log) {
    const out = [];
    for (const line of String(log || '').split('\n')) {
        const m = /\|USER_DEBUG\|\[\d+\]\|[A-Z]+\|([\s\S]*)$/.exec(line);
        if (m) out.push(m[1]);
    }
    return out;
}

/** Values printed as `KEY=value` by an anonymous Apex probe. */
export function debugMap(log) {
    const map = {};
    for (const line of debugLines(log)) {
        const m = /^([A-Z0-9_]+)=([\s\S]*)$/.exec(line.trim());
        if (m) map[m[1]] = m[2];
    }
    return map;
}

export async function soql(org, query) {
    const raw = await sf(['data', 'query', '--target-org', org, '-q', query, '--json'], { retries: 2 });
    try {
        return JSON.parse(raw).result.records || [];
    } catch (e) {
        return [];
    }
}

/**
 * Run Apex tests. Pass classNames to scope the run, or nothing for RunLocalTests.
 *
 * RunLocalTests is the default because enumerating every test class as a
 * --class-names flag builds a command line the CLI rejects outright — 43 flags
 * was enough — and it is what the release checklist runs anyway.
 */
export async function runApexTests(org, classNames, { timeout = 3600000 } = {}) {
    const args = ['apex', 'run', 'test', '--target-org', org, '--wait', '60', '--result-format', 'json'];
    if (classNames && classNames.length && classNames.length <= 20) {
        for (const c of classNames) args.push('--class-names', c);
    } else {
        args.push('--test-level', 'RunLocalTests');
    }
    const raw = await sf(args, { timeout });
    const jsonStart = raw.indexOf('{');
    if (jsonStart === -1) return { summary: null, tests: [] };
    try {
        const parsed = JSON.parse(raw.slice(jsonStart));
        const r = parsed.result || parsed;
        return { summary: r.summary || null, tests: r.tests || [] };
    } catch (e) {
        return { summary: null, tests: [], raw };
    }
}

export { sf };
