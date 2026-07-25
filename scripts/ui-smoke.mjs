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
      // Full reset per control. Reusing whatever block survived the previous command
      // makes results order-dependent — the bullet-list test replaces the <p> with a
      // <ul>, so the ordered-list test that follows was operating on a different
      // element entirely. Each control now starts from an identical document.
      //
      // The baseline is deliberately CONTRARY (red, bold, Times, highlighted) so
      // commands whose result is already the current state still have something to
      // change. Alignment is the exception: it is seeded opposite to whichever
      // alignment is under test, since "centre" on centred text is a legitimate no-op.
      const seed = (label) => {
        pv.focus();
        const style = pv.querySelector('style');
        while (pv.firstChild) pv.removeChild(pv.firstChild);
        if (style) pv.appendChild(style);
        const p = document.createElement('p');
        p.style.textAlign = /center|centre/i.test(label) ? 'left'
                          : /right/i.test(label) ? 'left'
                          : /left/i.test(label) ? 'center'
                          : 'center';
        p.innerHTML = '<span style="color:#e01e1e;font-family:Times,serif;font-weight:bold;background-color:#fff3a3">smoke probe text</span>';
        pv.appendChild(p);
        const r = document.createRange();
        r.selectNodeContents(p);
        const s = window.getSelection();
        s.removeAllRanges(); s.addRange(r);
        return p;
      };
      const label0 = (b) => (b.textContent || b.title || b.dataset.cmd || b.dataset.taction || '?').trim();
      const clickable = [...bar.querySelectorAll('button')].filter(b => {
        const t = (b.textContent || '').trim();
        // undo/redo have no stable effect on a fresh doc; zoom is a view control.
        void t;
        // Undo/redo cannot be asserted after a programmatic DOM reset — the browser's
        // undo stack does not track our manual DOM writes. Zoom is a view control.
        // Menu triggers open chrome rather than mutating the document; they have
        // their own popover assertions. Leaving them in this loop also left their
        // menus OPEN, which then toggled shut under the later tests.
        if (b.getAttribute('aria-haspopup') === 'true' || b.dataset.menu) return false;
        // View controls (zoom, focus mode) change what you SEE, never the document.
        if (b.dataset.viewctl) return false;
        return b.dataset.cmd !== 'undo' && b.dataset.cmd !== 'redo' && !b.dataset.zstep && !b.dataset.szstep;
      });
      for (const b of clickable) {
        seed(label0(b));
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

        // --- 4b. Contextual table row: hidden outside a table, functional inside --
        // Density comes from hiding ~45 controls until they are relevant. That is only
        // an improvement if they reliably COME BACK, so assert both halves.
        const tableCtx = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const bar = () => __dgFind('.dg-format-bar');
      const countTableBtns = () => bar().querySelectorAll('[data-taction]').length;
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);

      // Caret in a plain paragraph -> table tools should be absent.
      const p = document.createElement('p');
      p.textContent = 'outside any table';
      pv.appendChild(p);
      pv.focus();
      let r = document.createRange(); r.selectNodeContents(p);
      let s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
      document.dispatchEvent(new Event('selectionchange'));
      return new Promise((resolve) => setTimeout(() => {
        const hiddenOutside = countTableBtns() === 0;

        // Caret inside a table cell -> table tools should appear and work.
        const tbl = document.createElement('table');
        tbl.innerHTML = '<tr><td>cell one</td><td>cell two</td></tr>';
        pv.appendChild(tbl);
        const td = tbl.querySelector('td');
        const r2 = document.createRange(); r2.selectNodeContents(td);
        const s2 = window.getSelection(); s2.removeAllRanges(); s2.addRange(r2);
        document.dispatchEvent(new Event('selectionchange'));
        setTimeout(() => {
          const shownInside = countTableBtns() > 0;
          let rowAdded = false;
          const addRow = bar().querySelector('[data-taction="rowAfter"]');
          if (addRow) {
            const before = tbl.rows.length;
            addRow.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
            addRow.click();
            rowAdded = tbl.rows.length === before + 1;
          }
          resolve({ hiddenOutside, shownInside, rowAdded, btnCount: countTableBtns() });
        }, 400);
      }, 400));`)
        );
        record(
            'table tools hidden outside a table',
            tableCtx.hiddenOutside,
            `${tableCtx.btnCount} table buttons visible`
        );
        record('table tools appear inside a table', tableCtx.shownInside, '');
        record('table tools work when shown (+ Row)', tableCtx.rowAdded, '');

        // Confluence-style seam inserts: a + on the boundary where the new column/row
        // lands. Assert they exist, are not ghost click targets, and actually insert.
        const seams = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const wrap = __dgFind('.dg-canvas-wrap');
      const tbl = pv.querySelector('table');
      if (!tbl) return { ok:false, why:'no table in canvas' };
      // Dispatch on a CELL, not the canvas: _updateTableOverlay resolves the table
      // from event.target, and a synthetic event on pv has target === pv, which is
      // not inside any table.
      const cell0 = tbl.querySelector('td, th') || tbl;
      const r = cell0.getBoundingClientRect();
      cell0.dispatchEvent(new MouseEvent('mousemove', {bubbles:true, composed:true,
        clientX: Math.round(r.left + 5), clientY: Math.round(r.top + 5)}));
      return new Promise((resolve) => setTimeout(() => {
        const all = __dgFind('.dg-tbl-seam', true) || [];
        if (!all.length) return resolve({ ok:false, why:'no seams rendered' });
        // Ghost-target contract.
        let ghost = null;
        for (const el of all) {
          const cs = getComputedStyle(el);
          if (parseFloat(cs.opacity) < 0.02 && cs.pointerEvents !== 'none') { ghost = 'seam at opacity 0 still clickable'; break; }
        }
        if (ghost) return resolve({ ok:false, why:ghost });
        // Functional: a column seam must add a column.
        const colSeam = all.find(e => e.dataset.axis === 'col');
        if (!colSeam) return resolve({ ok:false, why:'no column seam' });
        const before = tbl.rows[0].children.length;
        colSeam.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        colSeam.click();
        setTimeout(() => {
          const after = tbl.rows[0].children.length;
          resolve({ ok: after === before + 1, why: after === before + 1 ? '' : ('columns ' + before + ' -> ' + after), count: all.length });
        }, 250);
      }, 500));`)
        );
        record('table seams: render, no ghost targets, insert a column', seams.ok, seams.why);

        // Block gutter handle: appears for the hovered block, inserts, and reorders.
        const blocks = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);
      const a = document.createElement('p'); a.textContent = 'AAA'; pv.appendChild(a);
      const b = document.createElement('p'); b.textContent = 'BBB'; pv.appendChild(b);
      const r = a.getBoundingClientRect();
      a.dispatchEvent(new MouseEvent('mousemove', {bubbles:true, composed:true,
        clientX: Math.round(r.left + 10), clientY: Math.round(r.top + 5)}));
      return new Promise((resolve) => setTimeout(() => {
        const h = __dgFind('.dg-blk-handle');
        if (!h) return resolve({ ok:false, why:'handle did not appear' });
        const cs = getComputedStyle(h);
        if (parseFloat(cs.opacity) < 0.02 && cs.pointerEvents !== 'none') {
          return resolve({ ok:false, why:'ghost click target' });
        }
        const btns = [...h.querySelectorAll('button')];
        const down = btns.find(x => x.dataset.dir === 'down');
        if (!down) return resolve({ ok:false, why:'no move control' });
        const orderBefore = [...pv.querySelectorAll('p')].map(p => p.textContent).join(',');
        down.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        down.click();
        setTimeout(() => {
          const orderAfter = [...pv.querySelectorAll('p')].map(p => p.textContent).join(',');
          resolve({ ok: orderBefore === 'AAA,BBB' && orderAfter === 'BBB,AAA',
                    why: orderBefore + ' -> ' + orderAfter });
        }, 250);
      }, 500));`)
        );
        record('block handle: appears and reorders blocks', blocks.ok, blocks.why);

        // Word-style grid picker: 4x3 must produce a 4-column, 4-row table (3 body
        // rows + header) that does NOT overhang the sheet.
        const grid = await page.evaluate(
            inPage(`
      const bar = __dgFind('.dg-format-bar');
      const pv = __dgFind('.dg-pv');
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);
      const p = document.createElement('p'); p.textContent = 'anchor'; pv.appendChild(p);
      pv.focus();
      const rr = document.createRange(); rr.selectNodeContents(p); rr.collapse(false);
      const ss = window.getSelection(); ss.removeAllRanges(); ss.addRange(rr);

      const trigger = [...bar.querySelectorAll('button')].find(b => /Table/.test(b.textContent||''));
      if (!trigger) return { ok:false, why:'grid trigger missing' };
      // LWC re-renders ASYNCHRONOUSLY, so a synchronous re-check after click always
      // sees the old DOM. Click, WAIT, then decide whether a second click is needed
      // (a previous test may have left the menu open, making the first click a close).
      const clickTrigger = () => {
        trigger.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        trigger.click();
      };
      clickTrigger();
      return new Promise((resolve) => setTimeout(() => {
        if (!__dgFind('.dg-grid-menu')) {
          clickTrigger();
        }
        setTimeout(() => {
        const menu = __dgFind('.dg-grid-menu');
        if (!menu) return resolve({ ok:false, why:'grid did not open' });
        const cs = getComputedStyle(menu);
        if (cs.position !== 'fixed') return resolve({ ok:false, why:'grid not fixed: ' + cs.position });
        const cell = menu.querySelector('[data-r="3"][data-c="4"]');
        if (!cell) return resolve({ ok:false, why:'no 4x3 cell' });
        cell.dispatchEvent(new MouseEvent('mouseenter', {bubbles:true, composed:true}));
        cell.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        cell.click();
        setTimeout(() => {
          const t = pv.querySelector('table');
          if (!t) return resolve({ ok:false, why:'no table inserted' });
          const cols = t.rows[0] ? t.rows[0].children.length : 0;
          const rows = t.rows.length;
          // Must not overhang the sheet.
          const pcs = getComputedStyle(pv);
          const contentW = pv.getBoundingClientRect().width
            - (parseFloat(pcs.paddingLeft)||0) - (parseFloat(pcs.paddingRight)||0);
          const overhang = t.getBoundingClientRect().width > contentW + 1;
          resolve({ ok: cols === 4 && rows === 4 && !overhang,
                    why: 'cols=' + cols + ' rows=' + rows + ' overhang=' + overhang });
        }, 300);
        }, 450);
      }, 450));`)
        );
        record('insert-table grid: 4x3 picker inserts and fits the page', grid.ok, grid.why);

        // Tables must never extend past the canvas, including after edits that grow
        // them (adding columns is the common way this happens).
        const overflow = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const t = pv.querySelector('table');
      if (!t) return { ok:false, why:'no table to test' };
      const bar = __dgFind('.dg-format-bar');
      // Put the caret in the table so the contextual tools appear.
      const td = t.querySelector('td, th');
      const r = document.createRange(); r.selectNodeContents(td);
      const s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
      document.dispatchEvent(new Event('selectionchange'));
      return new Promise((resolve) => setTimeout(() => {
        const addCol = bar.querySelector('[data-taction="colAfter"]');
        if (!addCol) return resolve({ ok:false, why:'no add-column control' });
        // Add several columns — enough to overhang without a clamp.
        for (let i = 0; i < 6; i++) {
          addCol.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
          addCol.click();
        }
        setTimeout(() => {
          const pcs = getComputedStyle(pv);
          const contentW = pv.getBoundingClientRect().width
            - (parseFloat(pcs.paddingLeft)||0) - (parseFloat(pcs.paddingRight)||0);
          const w = t.getBoundingClientRect().width;
          resolve({ ok: w <= contentW + 1, why: 'table ' + Math.round(w) + 'px vs content ' + Math.round(contentW) + 'px' });
        }, 350);
      }, 400));`)
        );
        record('table never extends past the canvas after adding columns', overflow.ok, overflow.why);

        // Cell-selection highlight must not linger.
        const stale = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const t = pv.querySelector('table');
      if (!t) return { ok:false, why:'no table' };
      const cells = [...t.querySelectorAll('td, th')];
      // Mark cells the way a drag-select does, then click elsewhere to clear.
      cells.slice(0, 3).forEach(c => { c.setAttribute('data-dg-selcell','1'); c.style.boxShadow = 'inset 0 0 0 2px #7c3aed'; });
      const p = document.createElement('p'); p.textContent = 'outside'; pv.appendChild(p);
      p.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
      p.dispatchEvent(new MouseEvent('click', {bubbles:true, composed:true, cancelable:true}));
      return new Promise((resolve) => setTimeout(() => {
        const left = pv.querySelectorAll('[data-dg-selcell]').length;
        resolve({ ok: left === 0, why: left + ' cells still marked selected' });
      }, 350));`)
        );
        record('cell selection highlight does not hang', stale.ok, stale.why);

        // --- 4c. Selection bubble: appears, is unclipped, and actually formats ----
        // The bubble is position: fixed precisely so no ancestor can clip it. Assert
        // that property directly rather than trusting the CSS — this is the same
        // class of check that would have caught the overflow regression.
        const bubble = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);
      const p = document.createElement('p');
      p.textContent = 'select me for the bubble';
      pv.appendChild(p);
      pv.focus();
      const r = document.createRange(); r.selectNodeContents(p);
      const s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
      document.dispatchEvent(new Event('selectionchange'));
      return new Promise((resolve) => setTimeout(() => {
        const el = __dgFind('.dg-sel-bubble');
        if (!el) return resolve({ appeared:false });
        const br = el.getBoundingClientRect();
        const cs = getComputedStyle(el);
        // No clipping ancestor may be smaller than the bubble.
        let clipper = null, node = el.parentElement;
        while (node && !clipper) {
          const ncs = getComputedStyle(node);
          if ((ncs.overflowX !== 'visible' || ncs.overflowY !== 'visible')) {
            const nr = node.getBoundingClientRect();
            if (nr.height < br.height - 1 || nr.width < br.width - 1) {
              clipper = (typeof node.className === 'string' && node.className ? node.className.split(' ')[0] : node.tagName)
                        + ' overflow:' + ncs.overflowX + '/' + ncs.overflowY;
            }
          }
          node = node.parentElement;
        }
        // Centre must be hit-testable.
        const cx = Math.round(br.left + br.width/2), cy = Math.round(br.top + br.height/2);
        let top = document.elementFromPoint(cx, cy), guard = 0;
        while (top && top.shadowRoot && guard++ < 10) {
          const inner = top.shadowRoot.elementFromPoint(cx, cy);
          if (!inner || inner === top) break;
          top = inner;
        }
        // Does it actually format?
        const bold = [...el.querySelectorAll('button')].find(b => (b.textContent||'').trim() === 'B');
        let formatted = false;
        if (bold) {
          const before = pv.innerHTML;
          bold.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
          bold.click();
          formatted = pv.innerHTML !== before;
        }
        // Must sit above the selection, not on top of it.
        const selRect = r.getBoundingClientRect();
        resolve({
          appeared: true,
          fixed: cs.position === 'fixed',
          onScreen: br.top >= 0 && br.left >= 0 && br.width > 20 && br.height > 10,
          hitTestable: !!(top && el.contains(top)),
          clipper,
          coversSelection: br.bottom > selRect.top + 2 && br.top < selRect.bottom - 2,
          formatted
        });
      }, 500));`)
        );
        record('bubble: appears on text selection', !!bubble.appeared, '');
        if (bubble.appeared) {
            record('bubble: position fixed (uncippable)', !!bubble.fixed, 'must be fixed, got ' + bubble.fixed);
            record('bubble: on screen with real size', !!bubble.onScreen, '');
            record('bubble: no clipping ancestor', !bubble.clipper, bubble.clipper || '');
            record('bubble: centre is hit-testable', !!bubble.hitTestable, '');
            record('bubble: does not cover the selection', !bubble.coversSelection, '');
            record('bubble: bold actually formats', !!bubble.formatted, '');
        }

        // --- 4c-2. Toolbar popovers: open, unclipped, hit-testable, functional ----
        // The exact thing that broke the editor before. Every trigger is opened and
        // its popover checked for the properties CSS review cannot see.
        for (const menuKey of ['textColor', 'highlight', 'font']) {
            const r = await page.evaluate(
                inPage(`
        const key = '${menuKey}';
        const bar = __dgFind('.dg-format-bar');
        const pv = __dgFind('.dg-pv');
        const trigger = bar.querySelector('[data-menu="' + key + '"]');
        if (!trigger) return { ok:false, why:'trigger missing' };

        // Seed a selection so the command has something to act on.
        const style = pv.querySelector('style');
        while (pv.firstChild) pv.removeChild(pv.firstChild);
        if (style) pv.appendChild(style);
        const p = document.createElement('p');
        // Background included so a "no highlight" choice is a real change rather
        // than a legitimate no-op on unhighlighted text.
        p.innerHTML = '<span style="color:#111;font-family:Times,serif;background-color:#ffe9a8">popover probe</span>';
        pv.appendChild(p);
        pv.focus();
        const sr = document.createRange(); sr.selectNodeContents(p);
        const s = window.getSelection(); s.removeAllRanges(); s.addRange(sr);

        trigger.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
        trigger.click();
        return new Promise((resolve) => setTimeout(() => {
          const menu = __dgFind('.dg-fmt-menu');
          if (!menu) return resolve({ ok:false, why:'menu did not open' });
          const mr = menu.getBoundingClientRect();
          const cs = getComputedStyle(menu);
          if (mr.width < 8 || mr.height < 8) return resolve({ ok:false, why:'menu has no size' });
          if (cs.position !== 'fixed') return resolve({ ok:false, why:'not position:fixed, got ' + cs.position });

          // Clipping ancestor check.
          let clipper = null, node = menu.parentElement;
          while (node && !clipper) {
            const ncs = getComputedStyle(node);
            if (ncs.overflowX !== 'visible' || ncs.overflowY !== 'visible') {
              const nr = node.getBoundingClientRect();
              if (nr.height < mr.height - 1 || nr.width < mr.width - 1) {
                clipper = (typeof node.className === 'string' && node.className ? node.className.split(' ')[0] : node.tagName)
                          + ' overflow:' + ncs.overflowX + '/' + ncs.overflowY;
              }
            }
            node = node.parentElement;
          }
          if (clipper) return resolve({ ok:false, why:'clipped by ' + clipper });

          // Centre hit-test.
          const cx = Math.round(mr.left + mr.width/2), cy = Math.round(mr.top + mr.height/2);
          let top = document.elementFromPoint(cx, cy), guard = 0;
          while (top && top.shadowRoot && guard++ < 10) {
            const inner = top.shadowRoot.elementFromPoint(cx, cy);
            if (!inner || inner === top) break;
            top = inner;
          }
          if (!(top && menu.contains(top))) return resolve({ ok:false, why:'centre not hit-testable' });

          // On screen.
          if (mr.left < 0 || mr.top < 0 || mr.right > innerWidth + 1 || mr.bottom > innerHeight + 1) {
            return resolve({ ok:false, why:'off screen' });
          }

          // A choice inside it must actually format.
          const choice = menu.querySelector('.dg-fmt-swatch, .dg-fmt-menu-item');
          if (!choice) return resolve({ ok:false, why:'no choices inside' });
          const before = pv.innerHTML;
          choice.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
          choice.click();
          setTimeout(() => {
            resolve({ ok: pv.innerHTML !== before, why: pv.innerHTML !== before ? '' : 'choice did not format' });
          }, 200);
        }, 350));`)
            );
            record(`popover ${menuKey}: opens, unclipped, hit-testable, formats`, r.ok, r.why);
        }

        // --- 4c-3. Header/footer must BE the sheet, not panels above and below ----
        // "Part of the canvas" is measurable: same width as the page, horizontally
        // aligned with it, and no visible gap between band and page.
        const sheet = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const hdr = __dgFind('.dg-chrome-band_header');
      const ftr = __dgFind('.dg-chrome-band_footer');
      const sheetEl = __dgFind('.dg-sheet');
      if (!hdr || !ftr) return { ok:false, why:'bands missing' };
      if (!sheetEl) return { ok:false, why:'no .dg-sheet wrapper' };
      if (!(sheetEl.contains(pv) && sheetEl.contains(hdr) && sheetEl.contains(ftr))) {
        return { ok:false, why:'bands and page are not in the same sheet' };
      }
      const p = pv.getBoundingClientRect();
      const h = hdr.getBoundingClientRect();
      const f = ftr.getBoundingClientRect();
      const widthMatch = Math.abs(h.width - p.width) <= 2 && Math.abs(f.width - p.width) <= 2;
      const leftMatch = Math.abs(h.left - p.left) <= 2 && Math.abs(f.left - p.left) <= 2;
      // Flush: the header's bottom edge should meet the page's top edge.
      const gapTop = p.top - h.bottom;
      const gapBottom = f.top - p.bottom;
      const flush = Math.abs(gapTop) <= 3 && Math.abs(gapBottom) <= 3;
      return {
        ok: widthMatch && leftMatch && flush,
        why: 'w ' + Math.round(h.width) + '/' + Math.round(p.width) +
             ' left ' + Math.round(h.left) + '/' + Math.round(p.left) +
             ' gaps ' + Math.round(gapTop) + ',' + Math.round(gapBottom)
      };`)
        );
        record('header/footer are part of the sheet (width, alignment, flush)', sheet.ok, sheet.why);

        // --- 4c-4. Ghost preview, fit-width, focus mode --------------------------
        const extras = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const bar = __dgFind('.dg-format-bar');
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);
      const t = document.createElement('table');
      t.innerHTML = '<tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr>';
      pv.appendChild(t);
      const cell0 = t.querySelector('td');
      const cr = cell0.getBoundingClientRect();
      cell0.dispatchEvent(new MouseEvent('mousemove', {bubbles:true, composed:true,
        clientX: Math.round(cr.left+5), clientY: Math.round(cr.top+5)}));
      return new Promise((resolve) => setTimeout(() => {
        const out = {};
        // Ghost on seam hover.
        const seam = (__dgFind('.dg-tbl-seam', true) || [])[0];
        if (!seam) { out.ghost = 'no seam'; }
        else {
          seam.dispatchEvent(new MouseEvent('mouseenter', {bubbles:true, composed:true}));
        }
        setTimeout(() => {
          const g = __dgFind('.dg-tbl-ghost');
          if (g) {
            const gr = g.getBoundingClientRect();
            const gcs = getComputedStyle(g);
            out.ghost = (gr.width > 4 && gr.height > 4 && gcs.pointerEvents === 'none') ? 'ok'
                        : ('bad size/pointer-events: ' + Math.round(gr.width) + 'x' + Math.round(gr.height) + ' pe=' + gcs.pointerEvents);
          } else if (!out.ghost) { out.ghost = 'ghost did not appear'; }

          // Fit width should widen the page toward the column.
          const sel = [...bar.querySelectorAll('select')].find(s2 => [...s2.options].some(o => o.value === 'fit'));
          if (!sel) { out.fit = 'no fit option'; }
          else {
            const before = pv.getBoundingClientRect().width;
            sel.value = 'fit';
            sel.dispatchEvent(new Event('change', {bubbles:true, composed:true}));
            setTimeout(() => {
              const after = pv.getBoundingClientRect().width;
              const col = __dgFind('.dg-designer-canvas-col');
              const colW = col ? col.getBoundingClientRect().width : 0;
              out.fit = (after >= before && after <= colW + 2) ? 'ok'
                        : ('page ' + Math.round(before) + '->' + Math.round(after) + ' col ' + Math.round(colW));

              // Focus mode should hide the setup rows.
              const focusBtn = bar.querySelector('[data-viewctl="focus"]');
              if (!focusBtn) { out.focus = 'no focus button'; resolve(out); return; }
              const chromeRow = __dgFind('.dg-designer-toolbar');
              const visBefore = chromeRow ? chromeRow.getBoundingClientRect().height > 0 : false;
              focusBtn.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true}));
              focusBtn.click();
              setTimeout(() => {
                const row2 = __dgFind('.dg-designer-toolbar');
                const visAfter = row2 ? row2.getBoundingClientRect().height > 0 : false;
                out.focus = (visBefore && !visAfter) ? 'ok' : ('visible before=' + visBefore + ' after=' + visAfter);
                // restore
                const fb = __dgFind('[data-viewctl="focus"]');
                if (fb) { fb.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, composed:true, cancelable:true})); fb.click(); }
                resolve(out);
              }, 400);
            }, 400);
          }
        }, 300);
      }, 500));`)
        );
        record('table +/- shows a ghost of what it will add/remove', extras.ghost === 'ok', extras.ghost || '');
        record('zoom: Fit width fills the column', extras.fit === 'ok', extras.fit || '');
        record('focus mode hides the setup chrome', extras.focus === 'ok', extras.focus || '');

        // --- 4c-5. Highlight residue, backspace floor, backtick menu -------------
        const hygiene = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const style = pv.querySelector('style');
      while (pv.firstChild) pv.removeChild(pv.firstChild);
      if (style) pv.appendChild(style);
      const a = document.createElement('p'); a.textContent = 'block one'; pv.appendChild(a);
      const b = document.createElement('p'); b.textContent = 'block two'; pv.appendChild(b);
      const t = document.createElement('table');
      t.innerHTML = '<tr><td>c1</td><td>c2</td></tr>';
      pv.appendChild(t);
      pv.focus();
      const put = (el) => {
        const r = document.createRange(); r.selectNodeContents(el); r.collapse(true);
        const s2 = window.getSelection(); s2.removeAllRanges(); s2.addRange(r);
        document.dispatchEvent(new Event('selectionchange'));
      };
      // Walk block -> block -> cell -> cell; only ONE region may stay highlighted.
      put(a);
      return new Promise((resolve) => setTimeout(() => {
        put(b);
        setTimeout(() => {
          const cells = t.querySelectorAll('td');
          put(cells[0]);
          setTimeout(() => {
            put(cells[1]);
            setTimeout(() => {
              const painted = pv.querySelectorAll('[data-dg-paint]').length;
              const out = { painted };

              // Backtick must open the insert menu.
              const p3 = document.createElement('p'); pv.appendChild(p3);
              const tn = document.createTextNode('\u0060');
              p3.appendChild(tn);
              const r3 = document.createRange();
              r3.setStart(tn, 1); r3.collapse(true);
              const s3 = window.getSelection(); s3.removeAllRanges(); s3.addRange(r3);
              pv.dispatchEvent(new Event('input', {bubbles:true}));
              setTimeout(() => {
                out.slash = !!__dgFind('.dg-slash-menu') || !!__dgFind('[class*="slash"]');
                resolve(out);
              }, 400);
            }, 300);
          }, 300);
        }, 300);
      }, 300));`)
        );
        record(
            'only one region highlighted after moving block->block->cell->cell',
            hygiene.painted <= 1,
            hygiene.painted + ' regions painted'
        );
        record('backtick opens the insert menu', !!hygiene.slash, '');

        // --- 4d. Invisible chrome must never intercept clicks --------------------
        // opacity: 0 does NOT remove an element from hit-testing. Any overlay left at
        // pointer-events: auto while invisible becomes a dead zone over the document.
        const ghosts = await page.evaluate(
            inPage(`
      const offenders = [];
      const check = (sel) => {
        for (const el of (__dgFind(sel, true) || [])) {
          const cs = getComputedStyle(el);
          const invisible = parseFloat(cs.opacity) < 0.02 || cs.visibility === 'hidden';
          if (invisible && cs.pointerEvents !== 'none') {
            const r = el.getBoundingClientRect();
            if (r.width > 2 && r.height > 2) {
              offenders.push(sel + ' @' + Math.round(r.left) + ',' + Math.round(r.top));
            }
          }
        }
      };
      check('.dg-tbl-handle');
      check('.dg-drop-marker');
      check('.dg-sel-bubble');
      return { offenders };`)
        );
        record(
            'no invisible chrome intercepts clicks',
            ghosts.offenders.length === 0,
            ghosts.offenders.slice(0, 3).join(', ')
        );

        // Clicking the page must always land on the page, never on hidden chrome.
        const canvasClickable = await page.evaluate(
            inPage(`
      const pv = __dgFind('.dg-pv');
      const r = pv.getBoundingClientRect();
      // The toolbar is sticky and CORRECTLY covers the top of the canvas once the
      // page scrolls under it, so probe strictly below its bottom edge — otherwise
      // this asserts a bug that isn't one.
      const bar = __dgFind('.dg-format-bar');
      const barBottom = bar ? bar.getBoundingClientRect().bottom : 0;
      const top0 = Math.max(r.top, barBottom) + 24;
      const pts = [[r.left + r.width/2, top0], [r.left + 40, top0 + 80], [r.right - 40, top0 + 160]];
      const bad = [];
      for (const [x, y] of pts) {
        let top = document.elementFromPoint(Math.round(x), Math.round(y)), guard = 0;
        while (top && top.shadowRoot && guard++ < 10) {
          const inner = top.shadowRoot.elementFromPoint(Math.round(x), Math.round(y));
          if (!inner || inner === top) break;
          top = inner;
        }
        if (!(top && (top === pv || pv.contains(top)))) {
          bad.push(Math.round(x)+','+Math.round(y)+' -> ' + (top ? (top.className || top.tagName) : 'null'));
        }
      }
      return { bad };`)
        );
        record('canvas click points reach the page', canvasClickable.bad.length === 0, canvasClickable.bad.join(' | '));

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
