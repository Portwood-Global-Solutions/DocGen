/**
 * Browser helpers for the UI suites.
 *
 * Three hard-won rules are baked in here so no suite has to remember them:
 *
 *  1. BUST LIGHTNING'S CACHE before believing anything. Lightning serves stale
 *     component bundles from IndexedDB and will happily pass a check against code
 *     that is no longer deployed. This invalidated two separate verification runs.
 *  2. PIERCE SHADOW ROOTS. Everything here lives inside LWC shadow DOM; a plain
 *     document.querySelector finds nothing.
 *  3. SYNTHETIC EVENTS ARE NOT REAL ONES. CSS :hover does not respond to a
 *     dispatched mousemove, and a dispatched keydown never triggers the browser's
 *     own editing behaviour. Use page.mouse / page.keyboard when the thing under
 *     test is the browser's reaction, not ours.
 */
import { chromium } from 'playwright';
import { orgFrontDoorUrl } from './sf.mjs';

export const PIERCE = `
  const __dgFind = (sel, all) => {
    const hit = [];
    const walk = (root) => {
      if (root.querySelectorAll) {
        for (const el of root.querySelectorAll(sel)) { hit.push(el); if (!all && hit.length) return true; }
      }
      for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
        if (el.shadowRoot && walk(el.shadowRoot)) return true;
      }
      return false;
    };
    walk(document);
    return all ? hit : (hit[0] || null);
  };`;

/**
 * page.evaluate(string) evaluates its argument as an EXPRESSION, so a bare
 * function declaration is a SyntaxError. Everything is wrapped in an IIFE.
 *
 * NOTE for suite authors: this body is a JS TEMPLATE LITERAL. A `\s` inside one
 * collapses to a literal "s" — write `\\s` for a regex escape, or avoid escapes
 * entirely. This silently rewrote a regex and produced a false failure once.
 */
export const inPage = (body) => `(() => {${PIERCE}\n return (() => {${body}})(); })()`;

export async function launch({ headed = false, width = 1440, height = 900 } = {}) {
    const browser = await chromium.launch({ headless: !headed });
    const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    const consoleErrors = [];
    page.on('console', (m) => {
        if (m.type() === 'error') consoleErrors.push(m.text());
    });
    page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));
    return { browser, ctx, page, consoleErrors };
}

/** Log in, clear Lightning's caches, and return the org's lightning base URL. */
export async function login(page, org) {
    const url = await orgFrontDoorUrl(org);
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(4000);
    await page.evaluate(async () => {
        try {
            localStorage.clear();
            sessionStorage.clear();
        } catch (e) {
            /* storage may be blocked */
        }
        if (indexedDB.databases) {
            const dbs = await indexedDB.databases();
            await Promise.all(
                dbs.map(
                    (d) =>
                        new Promise((res) => {
                            const r = indexedDB.deleteDatabase(d.name);
                            r.onsuccess = r.onerror = r.onblocked = () => res();
                        })
                )
            );
        }
    });
    return new URL(url).origin.replace('.my.salesforce.com', '.lightning.force.com');
}

/** Open a Lightning app page, cache-busted. */
export async function openTab(page, base, apiName, waitMs = 6000) {
    await page.goto(`${base}/lightning/n/${apiName}?qa=${Date.now()}`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(waitMs);
}

/** Open a record page. */
export async function openRecord(page, base, recordId, waitMs = 5000) {
    await page.goto(`${base}/lightning/r/${recordId}/view?qa=${Date.now()}`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(waitMs);
}

/**
 * Is this element genuinely reachable by a mouse? Catches the whole class of
 * "the control is there but something invisible is on top of it" — which has
 * been the cause of several real defects here (clipped popovers, ghost overlays,
 * a grid picker trapped behind the toolbar).
 */
export const HIT_TEST = `
  const __dgHittable = (el) => {
    if (!el) return 'missing';
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return 'zero size';
    const cs = getComputedStyle(el);
    if (parseFloat(cs.opacity) < 0.02) return 'transparent';
    if (cs.visibility === 'hidden' || cs.display === 'none') return 'hidden';
    const x = Math.round(r.left + r.width / 2), y = Math.round(r.top + r.height / 2);
    if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) return 'off screen';
    let top = document.elementFromPoint(x, y), guard = 0;
    while (top && top.shadowRoot && guard++ < 12) {
      const inner = top.shadowRoot.elementFromPoint(x, y);
      if (!inner || inner === top) break;
      top = inner;
    }
    if (!top) return 'nothing at its centre';
    if (top === el || el.contains(top) || top.contains(el)) return 'ok';
    return 'covered by ' + (top.className || top.tagName);
  };`;
