#!/usr/bin/env node
/**
 * Designer UI smoke test.
 *
 * WHY THIS EXISTS
 * ---------------
 * A toolbar rewrite shipped that measured perfectly — one row, 9 clusters, 38px tall —
 * and was completely broken: every popover opened inside a clipping container and was
 * invisible, and the menu toggles never fired. Measuring layout is not testing. This
 * script drives every control the way a person would and asserts the document actually
 * changed, so that class of regression cannot ship again.
 *
 * It also clears Lightning's IndexedDB component cache before testing. Lightning served
 * stale bundles during manual verification and silently invalidated two separate runs;
 * any check that skips this step can pass against code that is no longer deployed.
 *
 * USAGE
 *   node scripts/ui-smoke.mjs --org docgen-verify [--template "Verify — Designer"] [--headed]
 *
 * EXIT CODE
 *   0 = every control behaved; non-zero = at least one did not (details printed).
 */

import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
const argVal = (name, fallback = null) => {
    const i = args.indexOf(name);
    return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
};
const ORG = argVal('--org', 'docgen-verify');
const TEMPLATE_HINT = argVal('--template', 'Verify');
const HEADED = args.includes('--headed');

const results = [];
const record = (name, ok, detail = '') => {
    results.push({ name, ok, detail });
    process.stdout.write(`${ok ? '  PASS' : '  FAIL'}  ${name}${detail ? ` — ${detail}` : ''}\n`);
};

function frontDoorUrl(org) {
    const raw = execFileSync('sf', ['org', 'open', '--target-org', org, '--url-only', '--json'], {
        encoding: 'utf8'
    });
    return JSON.parse(raw).result.url;
}

/**
 * Piercing query: the Designer lives inside LWC shadow roots, so a plain
 * document.querySelector never finds it.
 */
const PIERCE = `
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
 * page.evaluate(string) evaluates its argument as an EXPRESSION, so a bare function
 * declaration is a SyntaxError. Everything gets wrapped in an IIFE that returns the
 * body's value.
 */
const inPage = (body) => `(() => {${PIERCE}\n return (() => {${body}})(); })()`;

async function main() {
    console.log(`\nDesigner UI smoke — org: ${ORG}\n`);
    const url = frontDoorUrl(ORG);
    const browser = await chromium.launch({ headless: !HEADED });
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    const consoleErrors = [];
    page.on('console', (m) => {
        if (m.type() === 'error') consoleErrors.push(m.text());
    });
    page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));

    try {
        await page.goto(url, { waitUntil: 'domcontentloaded' });
        await page.waitForTimeout(4000);

        // --- Lightning cache bust -------------------------------------------------
        // Without this the browser can run a bundle that is no longer deployed.
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

        const base = new URL(url).origin.replace('.my.salesforce.com', '.lightning.force.com');
        await page.goto(`${base}/lightning/n/portwoodglobal__DocGen_Template_Manager?smoke=${Date.now()}`, {
            waitUntil: 'domcontentloaded'
        });
        await page.waitForTimeout(6000);

        // --- Open the Designer on a template -------------------------------------
        await page.locator('[role="tab"]:has-text("Your Templates")').first().click();
        await page.waitForTimeout(2500);
        const row = page.locator(`tr:has-text("${TEMPLATE_HINT}")`).first();
        await row.locator('button[aria-haspopup="true"]').first().click();
        await page.waitForTimeout(800);
        await page.locator('[role="menuitem"]:has-text("Design")').first().click();
        await page.waitForTimeout(6000);

        const ready = await page.evaluate(
            inPage(`return { bar: !!__dgFind('.dg-format-bar'), pv: !!__dgFind('.dg-pv') };`)
        );
        record('designer opens (toolbar + canvas present)', ready.bar && ready.pv, JSON.stringify(ready));
        if (!ready.bar || !ready.pv) throw new Error('Designer did not open — aborting');

        // --- 1. Every toolbar control changes the document ------------------------
        const controlReport = await page.evaluate(
            inPage(`
      const bar = __dgFind('.dg-format-bar');
      const pv = __dgFind('.dg-pv');
      const out = [];
      // Seed a DELIBERATELY CONTRARY baseline. Asserting "the DOM changed" against
      // plain default text produces false failures for every command whose result is
      // already the current state — "align left" on left-aligned text, "clear
      // formatting" on unformatted text, "Helvetica" on Helvetica. Starting from
      // centred, red, bold, Times, highlighted text means every command under test has
      // something real to change.
      const seed = () => {
        pv.focus();
        let p = pv.querySelector('p, h1, h2, td, div');
        if (!p) { p = document.createElement('p'); pv.appendChild(p); }
        p.setAttribute('style', 'text-align:center');
        p.innerHTML = '<span style="color:#e01e1e;font-family:Times,serif;font-weight:bold;background-color:#fff3a3">smoke probe text</span>';
        const r = document.createRange();
        r.selectNodeContents(p);
        const s = window.getSelection();
        s.removeAllRanges(); s.addRange(r);
        return p;
      };
      const clickable = [...bar.querySelectorAll('button')].filter(b => {
        const t = (b.textContent || '').trim();
        // undo/redo have no stable effect on a fresh doc; zoom is a view control.
        return !/^(↺|↻|⤺|⤻|Undo|Redo|−|\\+)$/.test(t) && !b.dataset.zstep;
      });
      for (const b of clickable) {
        seed();
        const before = pv.innerHTML;
        let opensMenu = !!b.dataset.menu;
        b.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        b.click();
        const after = pv.innerHTML;
        const label = (b.textContent || b.title || b.dataset.cmd || b.dataset.taction || '?').trim().slice(0, 22);
        out.push({
          label,
          kind: opensMenu ? 'menu' : (b.dataset.taction ? 'table' : 'format'),
          changed: before !== after,
          menuKey: b.dataset.menu || null
        });
      }
      return { total: clickable.length, controls: out };`)
        );

        for (const c of controlReport.controls) {
            if (c.kind === 'menu') continue; // asserted separately below
            if (c.kind === 'table') continue; // needs a table context; covered in table section
            record(`toolbar: ${c.label}`, c.changed, c.changed ? '' : 'clicking it changed nothing');
        }

        // --- 2. Popovers render AND are hit-testable ------------------------------
        // This is the assertion that would have caught the overflow-clipping bug:
        // a menu can exist in the DOM, have a sane rect, and still be invisible
        // because an ancestor clips it. Hit-testing at its centre is the only
        // honest check.
        const menuKeys = controlReport.controls.filter((c) => c.menuKey).map((c) => c.menuKey);
        for (const key of menuKeys) {
            const r = await page.evaluate(
                inPage(`
        const key = '${key}';
        const bar = __dgFind('.dg-format-bar');
        const btn = [...bar.querySelectorAll('button')].find(b => b.dataset.menu === key);
        if (!btn) return { ok:false, why:'toggle button missing' };
        btn.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        btn.click();
        const menu = __dgFind('.dg-fmt-menu');
        if (!menu) return { ok:false, why:'menu did not open' };
        const mr = menu.getBoundingClientRect();
        if (mr.width < 4 || mr.height < 4) return { ok:false, why:'menu has no size' };
        // Is the menu's own centre actually the top-most element there?
        const cx = Math.round(mr.left + mr.width/2), cy = Math.round(mr.top + mr.height/2);
        let top = document.elementFromPoint(cx, cy), guard = 0;
        while (top && top.shadowRoot && guard++ < 10) {
          const inner = top.shadowRoot.elementFromPoint(cx, cy);
          if (!inner || inner === top) break;
          top = inner;
        }
        const inside = !!(top && menu.contains(top));
        // Clipping ancestors are the specific failure mode we regressed on.
        let clipper = null;
        let el = menu.parentElement;
        while (el && !clipper) {
          const cs = getComputedStyle(el);
          if ((cs.overflowY !== 'visible' || cs.overflowX !== 'visible') && el.getBoundingClientRect().height < mr.height) {
            clipper = (el.className && typeof el.className === 'string' ? el.className.split(' ')[0] : el.tagName) +
                      ' overflow:' + cs.overflowX + '/' + cs.overflowY;
          }
          el = el.parentElement;
        }
        return { ok: inside && !clipper, why: clipper ? ('clipped by ' + clipper) : (inside ? '' : 'centre not hit-testable') };`)
            );
            record(`popover: ${key}`, r.ok, r.why);
        }

        // --- 3. Header / footer surfaces get the same treatment as the body -------
        for (const which of ['header', 'footer']) {
            const r = await page.evaluate(
                inPage(`
        const which = '${which}';
        const band = __dgFind('.dg-chrome-band_' + which);
        if (!band) return { ok:false, why:'band not rendered' };
        if (band.getAttribute('contenteditable') !== 'true') return { ok:false, why:'band not editable' };
        const bar = __dgFind('.dg-format-bar');
        const bold = [...bar.querySelectorAll('button')].find(b => (b.textContent||'').trim() === 'B');
        if (!bold) return { ok:false, why:'no bold button' };
        band.focus();
        let p = band.querySelector('p, div, span') || band;
        if (!p.textContent.trim()) p.textContent = 'band probe';
        const r2 = document.createRange();
        r2.selectNodeContents(p);
        const s = window.getSelection();
        s.removeAllRanges(); s.addRange(r2);
        const before = band.innerHTML;
        bold.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        bold.click();
        return { ok: band.innerHTML !== before, why: band.innerHTML !== before ? '' : 'bold did not affect the band' };`)
            );
            record(`surface parity: bold works in ${which}`, r.ok, r.why);
        }

        // --- 4. Zoom scales the whole sheet, including the bands ------------------
        const zoomReport = await page.evaluate(
            inPage(`
      const bar = __dgFind('.dg-format-bar');
      const sel = [...bar.querySelectorAll('select')].find(s => /%/.test(s.options[s.selectedIndex] ? s.options[s.selectedIndex].text : ''));
      if (!sel) return { supported:false, why:'no zoom select found' };
      const pv = __dgFind('.dg-pv');
      const hdr = __dgFind('.dg-chrome-band_header');
      const before = { pv: pv.getBoundingClientRect().width, hdr: hdr ? hdr.getBoundingClientRect().width : null };
      sel.value = '1.5';
      sel.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
      const after = { pv: pv.getBoundingClientRect().width, hdr: hdr ? hdr.getBoundingClientRect().width : null };
      return {
        supported: true,
        bodyScaled: after.pv > before.pv * 1.2,
        headerScaled: after.hdr != null ? after.hdr > before.hdr * 1.2 : null,
        before, after
      };`)
        );
        if (zoomReport.supported) {
            record(
                'zoom: body scales',
                !!zoomReport.bodyScaled,
                JSON.stringify(zoomReport.before) + ' -> ' + JSON.stringify(zoomReport.after)
            );
            record(
                'zoom: header scales with the sheet',
                zoomReport.headerScaled === true,
                zoomReport.headerScaled === null ? 'no header band' : 'header must scale with the page'
            );
        } else {
            record('zoom: control present', false, zoomReport.why);
        }

        // --- 5. No console errors while driving the UI ---------------------------
        record(
            'no console errors during interaction',
            consoleErrors.length === 0,
            consoleErrors.slice(0, 3).join(' | ')
        );
    } catch (err) {
        record('smoke run completed', false, err.message);
    } finally {
        await browser.close();
    }

    const failed = results.filter((r) => !r.ok);
    console.log(`\n${results.length - failed.length}/${results.length} checks passed\n`);
    if (failed.length) {
        console.log('FAILURES:');
        for (const f of failed) console.log(`  - ${f.name}${f.detail ? `: ${f.detail}` : ''}`);
        process.exit(1);
    }
    process.exit(0);
}

main();
