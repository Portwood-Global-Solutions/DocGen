/**
 * PDF text extraction — so a check can assert what is ON the page.
 *
 * WHY THIS EXISTS
 * ---------------
 * Every generation check in this harness could prove a PDF was produced, was
 * several kilobytes and started with %PDF. None could prove what it CONTAINED.
 * That gap is not academic: the v2.5.0 regression (#134/#135) shipped a PDF of
 * exactly the right shape and size whose title, header, column headers and
 * footer had all silently vanished, leaving bare data rows. Every byte-level
 * assertion available at the time passed.
 *
 * Backed by poppler's pdftotext, which is not guaranteed to be installed. When
 * it is missing every caller must SKIP rather than pass — `available()` exists
 * so a suite can say so out loud instead of quietly proving nothing.
 */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const exec = promisify(execFile);

let _available = null;

/** Is pdftotext on this machine? Cached — the answer cannot change mid-run. */
export async function available() {
    if (_available !== null) return _available;
    try {
        await exec('pdftotext', ['-v']);
        _available = true;
    } catch (e) {
        _available = false;
    }
    return _available;
}

/**
 * Extract text from a PDF given as a base64 string or a Buffer.
 *
 * Returns { pages: string[], text: string, pageCount: number }.
 *
 * -layout preserves column structure. Without it a table's cells are emitted in
 * an order that has little to do with what a reader sees, so an assertion about
 * a row's contents becomes a coin toss.
 */
export async function pdfText(input) {
    const buf = Buffer.isBuffer(input) ? input : Buffer.from(String(input), 'base64');
    const dir = mkdtempSync(join(tmpdir(), 'dgqa-pdf-'));
    const file = join(dir, 'doc.pdf');
    try {
        writeFileSync(file, buf);
        const { stdout } = await exec('pdftotext', ['-layout', '-enc', 'UTF-8', file, '-'], {
            maxBuffer: 64 * 1024 * 1024
        });
        // pdftotext separates pages with a form feed. Splitting on it is the
        // only way to ask "does this appear on EVERY page?", which is the whole
        // question for a running header or footer.
        const pages = stdout.split('\f');
        // A trailing form feed leaves an empty final element that is not a page.
        if (pages.length && !pages[pages.length - 1].trim()) pages.pop();
        return { pages, text: stdout, pageCount: pages.length };
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
}

/** How many pages contain `needle`. */
export function pagesContaining(pages, needle) {
    const n = String(needle).toLowerCase();
    return pages.filter((p) => p.toLowerCase().indexOf(n) !== -1).length;
}

/**
 * Whitespace-insensitive containment.
 *
 * -layout pads cells with runs of spaces to hold a column, so a phrase that
 * reads as "Unit Price" on the page can arrive as "Unit    Price". Matching the
 * raw string would fail on text that is plainly present.
 */
export function textHas(haystack, needle) {
    const norm = (s) => String(s).replace(/\s+/g, ' ').toLowerCase();
    return norm(haystack).indexOf(norm(needle)) !== -1;
}
