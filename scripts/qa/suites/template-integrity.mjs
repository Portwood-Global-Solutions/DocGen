/**
 * CAN A PERSON ACTUALLY OPEN AND EDIT THIS TEMPLATE?
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * Four real bugs were found by a human clicking around an org that 1,500+
 * automated checks had just passed. Every one of them lived in the gap between
 * "the server holds the right data" and "a person can use it":
 *
 *   1. Version Type__c defaulted to Word, so HTML templates never appeared in
 *      the Designer picker at all.
 *   2. The Designer reads a ContentVersion titled docgen_html_body_<templateId>,
 *      not the version's Content_Version_Id__c. Templates opened to an empty
 *      canvas while generating perfect 70KB PDFs.
 *   3. Merge-tag pills used white-space:nowrap with no width limit, so a long
 *      tag escaped its table cell, covered the neighbouring one, and swallowed
 *      its clicks — visibly present, impossible to edit.
 *   4. Loop tags sat as bare text nodes directly inside <table>, where the HTML
 *      parser foster-parents them out of the table entirely.
 *
 * Not one existing check looked at any of it, because every one asserted
 * server-side state. These three assert what the UI needs.
 */
import { runAnonymous, debugMap } from '../lib/sf.mjs';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';
import { launch, login, inPage } from '../lib/browser.mjs';

/**
 * Both server checks in one transaction — they are two SOQL queries and a loop,
 * and splitting them would double the round-trip for no benefit.
 */
const PROBE = `
Integer htmlTotal = 0, bodyMissing = 0, typeMismatch = 0;
List<String> missingNames = new List<String>();
List<String> mismatchNames = new List<String>();

Map<Id, String> tplType = new Map<Id, String>();
for (DocGen_Template__c t : [SELECT Id, Name, Type__c FROM DocGen_Template__c]) {
    tplType.put(t.Id, t.Type__c);
}

for (DocGen_Template_Version__c v : [
    SELECT Template__c, Template__r.Name, Type__c
    FROM DocGen_Template_Version__c
    WHERE Is_Active__c = TRUE
]) {
    String tt = tplType.get(v.Template__c);
    // The template's behaviour is DERIVED from the version
    // (DocGenController: template.Type__c = version.Type__c), so a disagreement
    // is not cosmetic — it decides which editor opens and how the body is parsed.
    if (tt != v.Type__c) {
        typeMismatch++;
        if (mismatchNames.size() < 5) {
            mismatchNames.add(v.Template__r.Name + ' (tpl=' + tt + ' ver=' + v.Type__c + ')');
        }
    }
    if (tt == 'HTML') {
        htmlTotal++;
        String body;
        try {
            body = DocGenController.getHtmlTemplateBody(v.Template__c);
        } catch (Exception e) {
            body = null;
        }
        // This is the exact call the visual Designer makes. Null or empty means
        // the canvas opens blank, however healthy the template looks otherwise.
        if (String.isBlank(body)) {
            bodyMissing++;
            if (missingNames.size() < 5) {
                missingNames.add(v.Template__r.Name);
            }
        }
    }
}
System.debug('HTMLTOTAL=' + htmlTotal);
System.debug('BODYMISSING=' + bodyMissing);
System.debug('TYPEMISMATCH=' + typeMismatch);
System.debug('MISSINGNAMES=' + String.join(missingNames, ' | '));
System.debug('MISMATCHNAMES=' + String.join(mismatchNames, ' | '));
`;

/** Open the Designer on one template and measure every pill's geometry. */
async function measurePills(org, headed) {
    const { browser, page } = await launch({ headed });
    try {
        const base = await login(page, org);
        await page.goto(`${base}/lightning/n/DocGen_Template_Manager?qa=${Date.now()}`, {
            waitUntil: 'domcontentloaded'
        });
        await page.waitForTimeout(9000);

        // REAL mouse click. A dispatched click on the tab does not switch it —
        // the same synthetic-event rule that applies everywhere else here.
        const tab = await page.evaluate(
            inPage(`
      const t = __dgFind('a, span, li', true).find(x => (x.textContent || '').trim() === 'Designer (Beta)');
      if (!t) return null;
      t.scrollIntoView({ block: 'center' });
      const r = t.getBoundingClientRect();
      return { x: Math.round(r.left + r.width / 2), y: Math.round(r.top + r.height / 2) };`)
        );
        if (!tab) return { ok: false, why: 'no Designer tab' };
        await page.mouse.click(tab.x, tab.y);
        await page.waitForTimeout(6000);

        // Try SEVERAL templates, not just the first the picker offers.
        // The picker is ordered most-recently-edited first, and the one at the
        // top may legitimately have no table at all — the first run of this
        // check opened "Price List with Barcodes", found zero pills in cells and
        // skipped, reporting nothing about the many templates that do have them.
        const OPEN_ATTEMPTS = 4;
        let geom = null;
        let label = '';
        for (let attempt = 0; attempt < OPEN_ATTEMPTS; attempt++) {
            if (attempt > 0) {
                // Back to the picker for the next candidate.
                await page.goto(`${base}/lightning/n/DocGen_Template_Manager?qa=${Date.now()}`, {
                    waitUntil: 'domcontentloaded'
                });
                await page.waitForTimeout(8000);
                await page.mouse.click(tab.x, tab.y);
                await page.waitForTimeout(5000);
            }
            const card = await page.evaluate(
                inPage(`
        const c = __dgFind('[role="option"], li, div', true)
          .filter(e => /Design\\s*→|Design →/.test(e.textContent || ''));
        const idx = ${attempt};
        if (c.length <= idx) return null;
        const leaf = c[idx];
        leaf.scrollIntoView({ block: 'center' });
        const r = leaf.getBoundingClientRect();
        return { x: Math.round(r.left + r.width / 2), y: Math.round(r.top + r.height / 2),
                 label: (leaf.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 60) };`)
            );
            if (!card) break;
            label = card.label;
            await page.mouse.click(card.x, card.y);
            await page.waitForTimeout(18000);
            geom = await page.evaluate(inPage(PILL_GEOMETRY));
            if (geom && geom.inCells > 0) break;
        }
        if (!geom) return { ok: false, why: 'the Designer picker listed no template to open' };
        return { ...geom, template: label };
    } finally {
        await browser.close().catch(() => {});
    }
}

/** Measured inside the page; kept separate so the retry loop can re-run it. */
const PILL_GEOMETRY = `
      const pills = __dgFind('span[data-dg-tag]', true);
      let inCells = 0, overflowing = 0, covered = 0;
      const samples = [];
      for (const p of pills) {
        const cell = p.closest ? p.closest('td, th') : null;
        if (!cell) continue;
        inCells++;
        const pr = p.getBoundingClientRect(), cr = cell.getBoundingClientRect();
        if (pr.right > cr.right + 1 || pr.left < cr.left - 1) {
          overflowing++;
          if (samples.length < 3) samples.push((p.textContent || '').trim().slice(0, 30));
        }
        // Covered AT ITS OWN CENTRE is what makes a pill unclickable — the
        // symptom that started this. Presence in the DOM proves nothing.
        const cx = Math.round(pr.left + pr.width / 2), cy = Math.round(pr.top + pr.height / 2);
        let top = document.elementFromPoint(cx, cy), guard = 0;
        while (top && top.shadowRoot && guard++ < 10) {
          const inner = top.shadowRoot.elementFromPoint(cx, cy);
          if (!inner || inner === top) break;
          top = inner;
        }
        if (top && top !== p && !p.contains(top) && !top.contains(p)) covered++;
      }
      return { ok: true, total: pills.length, inCells, overflowing, covered, samples };`;

export async function run({ org, headed }) {
    const checks = [];
    const add = (c) => checks.push(c);

    // ---- 1 + 2: server-side, cheap, and would have caught two shipped bugs ----
    let m = {};
    try {
        m = debugMap(await runAnonymous(org, PROBE, { timeout: 600000 }));
    } catch (e) {
        return suiteResult('template-integrity', 'Template integrity', [
            check('the template integrity probe ran', false, String(e.message).slice(0, 200), SEVERITY.BLOCKER)
        ]);
    }

    const htmlTotal = Number(m.HTMLTOTAL || 0);
    const bodyMissing = Number(m.BODYMISSING || 0);
    const typeMismatch = Number(m.TYPEMISMATCH || 0);

    add(
        check(
            'every HTML template returns a body to the visual Designer',
            htmlTotal > 0 && bodyMissing === 0,
            bodyMissing === 0
                ? `all ${htmlTotal} HTML templates return a non-empty body from getHtmlTemplateBody`
                : `${bodyMissing} of ${htmlTotal} return NOTHING — those open to an empty canvas however well they ` +
                      `generate. The Designer reads a ContentVersion titled docgen_html_body_<templateId>, not the ` +
                      `version's Content_Version_Id__c: ${m.MISSINGNAMES || ''}`,
            SEVERITY.BLOCKER
        )
    );

    add(
        check(
            'each template agrees with its active version about its own type',
            typeMismatch === 0,
            typeMismatch === 0
                ? 'no template/version type disagreements'
                : `${typeMismatch} disagree. Type__c on the VERSION has Word as its picklist default, so any ` +
                      `programmatic creation that omits it silently mistypes an HTML template — and the template ` +
                      `derives its behaviour from the version: ${m.MISMATCHNAMES || ''}`,
            SEVERITY.BLOCKER
        )
    );

    // ---- 3: the browser one ----
    let g;
    try {
        g = await measurePills(org, headed);
    } catch (e) {
        add(
            skip(
                'merge-tag pills stay inside their table cells',
                `threw: ${String(e.message).slice(0, 160)}`,
                SEVERITY.MAJOR
            )
        );
        return suiteResult('template-integrity', 'Template integrity', checks);
    }
    if (!g || !g.ok) {
        add(
            skip(
                'merge-tag pills stay inside their table cells',
                `could not open a template in the Designer: ${(g && g.why) || 'unknown'}`,
                SEVERITY.MAJOR
            )
        );
        return suiteResult('template-integrity', 'Template integrity', checks);
    }

    if (!g.inCells) {
        add(
            skip(
                'merge-tag pills stay inside their table cells',
                `"${g.template}" opened with ${g.total} pills but none inside a table, so there was nothing to measure`,
                SEVERITY.MINOR
            )
        );
    } else {
        add(
            check(
                'merge-tag pills stay inside their table cells and none is covered',
                g.overflowing === 0 && g.covered === 0,
                g.overflowing === 0 && g.covered === 0
                    ? `${g.inCells} pills in cells of "${g.template}": none overflowing, none covered`
                    : `${g.overflowing} of ${g.inCells} pills overflow their cell and ${g.covered} are covered at ` +
                          `their own centre — an overflowing pill lands on the neighbouring cell and swallows its ` +
                          `clicks, so both become uneditable. Samples: ${(g.samples || []).join(', ')}`,
                SEVERITY.MAJOR
            )
        );
    }

    return suiteResult('template-integrity', 'Template integrity', checks);
}
