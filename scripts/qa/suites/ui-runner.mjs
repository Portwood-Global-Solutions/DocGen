/**
 * END-USER UI SUITE — the surfaces a customer actually touches.
 *
 * WHY THIS EXISTS
 * ---------------
 * Every browser check in this repo pointed at the Designer and the admin console —
 * i.e. at the screens *we* use. The screens the customer uses to do the one job the
 * product exists for (pick a template, press the button, get a document) had no
 * browser coverage at all. Apex tests prove the engine merges XML; they cannot
 * prove a person can reach the button, that the button is not sitting under an
 * invisible overlay, or that pressing it puts a file on the record.
 *
 * WHAT IT ASSERTS
 * ---------------
 * Behaviour and SERVER STATE, never layout. "A spinner ran" is not evidence a
 * document was produced — every generation check ends in a SOQL query for the
 * DocGen_Job__c row and the ContentVersion rows that should now exist.
 *
 * WHAT IT COULD NOT REACH (see the skip checks at the bottom, and the report's
 * "Not covered by this run" section)
 * ---------------------------------------------------------------------------
 * docGenRunner, docGenSignatureSender and docGenButton are lightning__RecordPage /
 * lightning__RecordAction components. The package ships tabs for the admin
 * surfaces but NO Lightning record page and NO quick action, and the verify org
 * has none either (`SELECT DeveloperName, Type FROM FlexiPage` returns only
 * UtilityBar rows). There is no supported URL that renders an LWC on a record
 * without a page assignment, so reaching them means hand-building a Lightning
 * record page — which this suite is not allowed to deploy. Those components are
 * therefore recorded as SKIPPED checks with that reason, and their server
 * contract (what the runner's wires and buttons actually call) is exercised
 * through the same Apex the component calls, clearly labelled as such.
 *
 * HOUSE RULES OBSERVED (from scripts/ui-smoke.mjs)
 *   1. Assert behaviour + server state, not layout.
 *   2. HIT_TEST every control before believing it is usable — "it is in the DOM"
 *      has hidden at least one blocker in this very component (see the spinner
 *      overlay check below, which is a real defect this suite found).
 *   3. CSS :hover ignores synthetic events — drive with page.mouse.
 *   4. Synthetic keydown is not typing — drive with page.keyboard.
 *   5. inPage() bodies are TEMPLATE LITERALS: a backslash-s becomes a literal
 *      "s". No regex escapes are used in any evaluated body below.
 */
import { check, skip, suiteResult, suiteSkipped, SEVERITY } from '../lib/report.mjs';
import { launch, login, openTab, inPage, HIT_TEST } from '../lib/browser.mjs';
import { runAnonymous, debugMap, soql } from '../lib/sf.mjs';

/** Everything this suite creates is prefixed so a repeat run can clean up first. */
const PREFIX = 'UIQA';

/** The bulk screen's Output Mode values — packaging modes, not file formats. */
const OUT_MODES = ['Individual Files', 'Print-Ready Packet', 'Combined + Individual'];

/* ------------------------------------------------------------------ *
 * Apex payloads
 * ------------------------------------------------------------------ */

/**
 * Seed. Deliberately covers the edge cases the brief calls out:
 *   Good PDF      — the happy path
 *   No Version    — an active template with no active version (nothing to merge)
 *   Locked Format — Lock_Output_Format__c, so a runtime override must be refused
 *   Filtered Out  — Record_Filter__c that excludes the test records
 *   Needs PermSet — Required_Permission_Sets__c the running user does not hold
 *   Inactive      — Is_Active__c = false
 */
const SEED_APEX = `
List<DocGen_Template__c> old = [SELECT Id FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%'];
if (!old.isEmpty()) {
    Set<Id> ids = new Set<Id>();
    for (DocGen_Template__c t : old) ids.add(t.Id);
    delete [SELECT Id FROM DocGen_Job__c WHERE Template__c IN :ids];
    delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :ids];
    delete old;
}
delete [SELECT Id FROM Account WHERE Name LIKE '${PREFIX}%'];
delete [SELECT Id FROM ContentDocument WHERE Title LIKE '${PREFIX}%'];

List<Account> accts = new List<Account>{
    new Account(Name = '${PREFIX} Alpha', Industry = 'Technology'),
    new Account(Name = '${PREFIX} Beta', Industry = 'Banking')
};
insert accts;

String body = '<html><body><h1>{Name}</h1><p>{Industry}</p></body></html>';
String qc = 'Name, Industry';

DocGen_Template__c good = new DocGen_Template__c(Name = '${PREFIX} Good PDF', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true, Category__c = '${PREFIX}');
DocGen_Template__c noVer = new DocGen_Template__c(Name = '${PREFIX} No Version', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true, Category__c = '${PREFIX}');
DocGen_Template__c locked = new DocGen_Template__c(Name = '${PREFIX} Locked Format', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true,
    Lock_Output_Format__c = true, Category__c = '${PREFIX}');
DocGen_Template__c filtered = new DocGen_Template__c(Name = '${PREFIX} Filtered Out', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true,
    Record_Filter__c = 'Industry = \\'Agriculture\\'', Category__c = '${PREFIX}');
DocGen_Template__c needsPs = new DocGen_Template__c(Name = '${PREFIX} Needs PermSet', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true,
    Required_Permission_Sets__c = '${PREFIX}_No_Such_PermSet', Category__c = '${PREFIX}');
DocGen_Template__c inactive = new DocGen_Template__c(Name = '${PREFIX} Inactive', Base_Object_API__c = 'Account',
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = false, Category__c = '${PREFIX}');
insert new List<DocGen_Template__c>{ good, noVer, locked, filtered, needsPs, inactive };

List<DocGen_Template__c> withBody = new List<DocGen_Template__c>{ good, locked, filtered, needsPs };
List<ContentVersion> cvs = new List<ContentVersion>();
for (DocGen_Template__c t : withBody) {
    cvs.add(new ContentVersion(Title = '${PREFIX} body ' + t.Name, PathOnClient = 'uiqa.html',
        VersionData = Blob.valueOf(body), FirstPublishLocationId = t.Id));
}
insert cvs;

List<DocGen_Template_Version__c> vers = new List<DocGen_Template_Version__c>();
Integer i = 0;
for (DocGen_Template__c t : withBody) {
    vers.add(new DocGen_Template_Version__c(Template__c = t.Id, Is_Active__c = true, Type__c = 'HTML',
        Output_Format__c = 'PDF', Base_Object_API__c = 'Account', Query_Config__c = qc,
        Content_Version_Id__c = cvs[i].Id));
    i++;
}
insert vers;

// A job parked in a non-terminal status. Recent Jobs renders a spinner for it,
// which is the precondition for the overlay check in the browser phase — seeded
// rather than hoped for, so that check is deterministic instead of depending on
// whatever jobs happen to be lying around the org.
insert new DocGen_Job__c(Template__c = good.Id, Status__c = 'Queued', Label__c = '${PREFIX} parked job');

System.debug('NS=' + DocGen_Template__c.sObjectType.getDescribe().getName());
System.debug('ACCT=' + accts[0].Id);
System.debug('SEEDED=' + [SELECT COUNT() FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%'] + ',' +
    [SELECT COUNT() FROM Account WHERE Name LIKE '${PREFIX}%']);
`;

/**
 * The runner's server contract.
 *
 * These call the SAME Apex the docGenRunner component's wire and Generate button
 * call — getTemplatesForObjectAndRecord for the picker, processDocument for the
 * output. They are NOT a substitute for driving the component; they are here
 * because the component itself cannot be reached (see the header), and a picker
 * that offers an unusable template is a user-visible defect either way.
 *
 * Only DocGenException-throwing entry points are used: an @AuraEnabled method
 * that throws AuraHandledException cannot be caught in anonymous Apex, and an
 * uncatchable throw would roll the whole probe back with no output.
 */
const PROBE_APEX = `
Id acctId = [SELECT Id FROM Account WHERE Name = '${PREFIX} Alpha' LIMIT 1].Id;
Map<String, Id> byName = new Map<String, Id>();
for (DocGen_Template__c t : [SELECT Id, Name FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%']) {
    byName.put(t.Name, t.Id);
}

String picker = '';
for (DocGen_Template__c t : DocGenController.getTemplatesForObjectAndRecord('Account', acctId)) {
    if (t.Name.startsWith('${PREFIX}')) picker += t.Name + '~';
}
System.debug('PICKER=' + picker);

String bulkPicker = '';
for (DocGen_Template__c t : DocGenBulkController.getBulkTemplates()) {
    if (t.Name.startsWith('${PREFIX}')) bulkPicker += t.Name + '~';
}
System.debug('BULKPICKER=' + bulkPicker);

try {
    Map<String, Object> r = DocGenService.processDocument(byName.get('${PREFIX} Good PDF'), acctId, null, null);
    Blob b = (Blob) r.get('blob');
    System.debug('GEN_BYTES=' + (b == null ? 0 : b.size()));
    System.debug('GEN_TITLE=' + r.get('title'));
} catch (Exception e) {
    System.debug('GEN_ERR=' + e.getMessage());
}

try {
    DocGenService.processDocument(byName.get('${PREFIX} Locked Format'), acctId, null, 'Word');
    System.debug('LOCK=allowed');
} catch (Exception e) {
    System.debug('LOCK=' + e.getMessage());
}

try {
    Map<String, Object> r2 = DocGenService.processDocument(byName.get('${PREFIX} No Version'), acctId, null, null);
    System.debug('NOVER=produced ' + ((Blob) r2.get('blob')).size() + ' bytes with no active version');
} catch (Exception e) {
    System.debug('NOVER=' + e.getMessage());
}
`;

const CLEANUP_APEX = `
List<DocGen_Template__c> mine = [SELECT Id FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%'];
Set<Id> ids = new Set<Id>();
for (DocGen_Template__c t : mine) ids.add(t.Id);
if (!ids.isEmpty()) {
    delete [SELECT Id FROM DocGen_Error_Log__c WHERE Template_Id__c IN :ids];
    delete [SELECT Id FROM DocGen_Job__c WHERE Template__c IN :ids];
    delete [SELECT Id FROM DocGen_Saved_Query__c WHERE Template__c IN :ids];
    delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :ids];
    delete mine;
}
delete [SELECT Id FROM Account WHERE Name LIKE '${PREFIX}%'];
delete [SELECT Id FROM ContentDocument WHERE Title LIKE '${PREFIX}%'];
System.debug('CLEANED=ok');
`;

/* ------------------------------------------------------------------ *
 * Browser helpers
 * ------------------------------------------------------------------ */

const ev = (page, body) => page.evaluate(inPage(body));

/**
 * Shadow-aware text of an element.
 *
 * `el.textContent` on an LWC host (or on a lightning-base-combobox-item) is the
 * EMPTY STRING — the content lives in the shadow root. Matching on textContent
 * silently matched three empty strings here before this existed, and the check
 * that used it passed while proving nothing.
 */
const TEXT_OF = `
  const __dgText = (el) => {
    const out = [];
    const walk = (n) => {
      if (n.nodeType === 3) { out.push(n.nodeValue); return; }
      if (n.shadowRoot) for (const k of n.shadowRoot.childNodes) walk(k);
      for (const k of n.childNodes) walk(k);
    };
    walk(el);
    return out.join(' ').replace(/[ ]+/g, ' ').trim();
  };`;

/** Selector matching the component host in both a namespaced and a plain org. */
const host = (kebab) => `portwoodglobal-${kebab}, c-${kebab}`;

/**
 * Centre-point of the first element matching `sel`, plus its HIT_TEST verdict.
 * Everything that "clicks" in this suite goes through here so no check can pass
 * against a control that is present but unreachable.
 *
 * The element is scrolled into view first: HIT_TEST reports "off screen" for a
 * control that is merely below the fold, which is not a defect — a person would
 * scroll to it. What it must still catch is something ON TOP of the control.
 */
async function locate(page, sel) {
    const r = await ev(
        page,
        `
    const el = __dgFind(${JSON.stringify(sel)});
    if (!el) return false;
    el.scrollIntoView({ block: 'center', inline: 'center' });
    return true;
  `
    );
    if (!r) return { found: false, hit: 'missing' };
    await page.waitForTimeout(350);
    return ev(
        page,
        `
    ${HIT_TEST}
    const el = __dgFind(${JSON.stringify(sel)});
    if (!el) return { found: false, hit: 'missing' };
    const b = el.getBoundingClientRect();
    return { found: true, hit: __dgHittable(el),
             x: Math.round(b.left + b.width / 2), y: Math.round(b.top + b.height / 2) };
  `
    );
}

/**
 * Locates a combobox by the value it is currently displaying.
 *
 * `lightning-combobox input` never matches as a CSS selector (the control lives
 * in a nested shadow root, and CSS does not cross that boundary), and matching
 * on the shared .slds-combobox__input class alone would find the record picker
 * instead. A readonly SLDS combobox is also not an <input> at all — it is a
 * span with slds-input_faux — so the current value has to be read from either
 * the value property or the text.
 */
async function locateComboboxShowing(page, values) {
    const vals = JSON.stringify(values);
    const finder = `
    const cur = (e) => ((e.value || e.textContent || '') + '').trim();
    const el = __dgFind('.slds-combobox__input, .slds-combobox__input-value', true)
      .find(e => ${vals}.indexOf(cur(e)) !== -1);`;
    const found = await ev(
        page,
        `${finder}\n if (!el) return false; el.scrollIntoView({ block: 'center' }); return true;`
    );
    if (!found) return { found: false, hit: 'missing' };
    await page.waitForTimeout(350);
    return ev(
        page,
        `
    ${HIT_TEST}
    ${finder}
    if (!el) return { found: false, hit: 'missing' };
    const b = el.getBoundingClientRect();
    return { found: true, hit: __dgHittable(el), value: cur(el),
             x: Math.round(b.left + b.width / 2), y: Math.round(b.top + b.height / 2) };
  `
    );
}

/** Same, but picks the element whose text contains `text`. */
async function locateByText(page, sel, text) {
    const finder = `
    ${TEXT_OF}
    const all = __dgFind(${JSON.stringify(sel)}, true);
    const el = all.find(e => __dgText(e).indexOf(${JSON.stringify(text)}) !== -1);`;
    const found = await ev(
        page,
        `${finder}\n if (!el) return false; el.scrollIntoView({ block: 'center' }); return true;`
    );
    if (!found) return { found: false, hit: 'missing' };
    await page.waitForTimeout(350);
    return ev(
        page,
        `
    ${HIT_TEST}
    ${finder}
    if (!el) return { found: false, hit: 'missing' };
    const b = el.getBoundingClientRect();
    return { found: true, hit: __dgHittable(el),
             x: Math.round(b.left + b.width / 2), y: Math.round(b.top + b.height / 2) };
  `
    );
}

/** Real mouse click — synthetic events do not reproduce what a person does. */
async function clickAt(page, pos, settleMs = 1200) {
    await page.mouse.click(pos.x, pos.y);
    await page.waitForTimeout(settleMs);
}

/**
 * All text the component is showing the user.
 *
 * NOT `host.textContent` — an LWC's content lives in its shadow root, so
 * textContent on the host returns the empty string and every assertion written
 * against it would silently pass or silently fail. This walks shadow roots.
 */
const componentText = (page, kebab) =>
    ev(
        page,
        `
    const h = __dgFind(${JSON.stringify(host(kebab))});
    if (!h) return '';
    const out = [];
    const walk = (node) => {
      if (node.nodeType === 3) { out.push(node.nodeValue); return; }
      if (node.shadowRoot) for (const k of node.shadowRoot.childNodes) walk(k);
      for (const k of node.childNodes) walk(k);
    };
    walk(h);
    return out.join(' ');
  `
    );

/**
 * WORKAROUND for the defect asserted by the "no overlay covers the primary
 * control" check below: a non-terminal job in Recent Jobs renders an inline
 * lightning-spinner inside a .history-row that has no positioning context, so
 * the spinner's slds-spinner_container escapes and covers the whole app. The
 * bug is asserted ONCE and then neutralised here, otherwise every later check
 * would fail for the same single reason and the report would say nothing new.
 */
async function neutraliseRowSpinners(page) {
    return ev(
        page,
        `
    let n = 0;
    for (const row of __dgFind('.history-row', true)) {
      for (const s of row.querySelectorAll('lightning-spinner')) { s.style.display = 'none'; n++; }
    }
    return n;
  `
    );
}

/* ------------------------------------------------------------------ *
 * The suite
 * ------------------------------------------------------------------ */

export async function run({ org, headed }) {
    const checks = [];
    const add = (c) => checks.push(c);

    // Namespace of the org under test. `sf data query` needs the prefix; anonymous
    // Apex does not. Resolved from the seed probe rather than assumed.
    let ns = '';
    const F = (rec, field) => (rec ? rec[ns + field] : undefined);

    let seedLog;
    try {
        seedLog = debugMap(await runAnonymous(org, SEED_APEX));
    } catch (e) {
        return suiteSkipped('ui-runner', 'End-user UI', `could not seed test data: ${String(e.message).slice(0, 160)}`);
    }
    const nsName = seedLog.NS || '';
    ns = nsName.indexOf('__') !== -1 ? nsName.slice(0, nsName.indexOf('__') + 2) : '';
    const acctId = seedLog.ACCT || '';
    const seeded = (seedLog.SEEDED || '').split(',');
    if (!acctId || seeded[0] !== '6' || seeded[1] !== '2') {
        return suiteSkipped(
            'ui-runner',
            'End-user UI',
            `seed did not land (templates=${seeded[0]}, accounts=${seeded[1]}) — every later check would be meaningless`
        );
    }

    const tabApi = (name) => (ns ? ns + name : name);
    const runTag = `${PREFIX}-${Date.now().toString(36)}`;
    let browser;
    // Set when the Output Mode was successfully switched to Individual Files —
    // the per-record attachment assertion is only meaningful in that mode.
    let individualMode = false;

    try {
        /* ============================================================ *
         * 1. The runner's server contract.
         *    The component cannot be reached (see header); what it calls can.
         * ============================================================ */
        const area = 'Runner (server contract)';
        try {
            const p = debugMap(await runAnonymous(org, PROBE_APEX));
            const picker = (p.PICKER || '').split('~').filter(Boolean);
            const bulkPicker = (p.BULKPICKER || '').split('~').filter(Boolean);

            // The one thing the picker must do.
            add({
                ...check(
                    'runner template picker offers an active, usable template for the record',
                    picker.indexOf(`${PREFIX} Good PDF`) !== -1,
                    `picker returned: ${picker.join(', ') || '(nothing)'} — DocGenController.getTemplatesForObjectAndRecord`,
                    SEVERITY.BLOCKER
                ),
                area
            });

            // Audience rules. A template the admin scoped away must not be offered.
            add({
                ...check(
                    'picker hides a template whose Record_Filter__c excludes this record',
                    picker.indexOf(`${PREFIX} Filtered Out`) === -1,
                    `Record_Filter__c = Industry = 'Agriculture'; the record is Technology. Picker: ${picker.join(', ')}`,
                    SEVERITY.MAJOR
                ),
                area
            });
            add({
                ...check(
                    'picker hides a template requiring a permission set the user lacks',
                    picker.indexOf(`${PREFIX} Needs PermSet`) === -1,
                    `Required_Permission_Sets__c = ${PREFIX}_No_Such_PermSet. Picker: ${picker.join(', ')}`,
                    SEVERITY.MAJOR
                ),
                area
            });
            add({
                ...check(
                    'picker hides an inactive template',
                    picker.indexOf(`${PREFIX} Inactive`) === -1,
                    `Picker: ${picker.join(', ')}`,
                    SEVERITY.MAJOR
                ),
                area
            });

            // A template with no active version has nothing to merge. Offering it
            // means the user only discovers that after pressing Generate.
            add({
                ...check(
                    'picker hides a template that has no active version',
                    picker.indexOf(`${PREFIX} No Version`) === -1,
                    `"${PREFIX} No Version" is offered in the runner picker but cannot generate — the user gets ` +
                        `"No template file found (active or attached)" only after pressing Generate. ` +
                        `DocGenController.getTemplatesForObjectInternal filters on Is_Active__c/audience but never ` +
                        `checks for an active DocGen_Template_Version__c.`,
                    SEVERITY.MAJOR
                ),
                area
            });

            // Generation, proved by bytes rather than by a spinner.
            const bytes = parseInt(p.GEN_BYTES || '0', 10);
            add({
                ...check(
                    'generating from the picked template produces a real document',
                    bytes > 1000,
                    p.GEN_ERR ? `threw: ${p.GEN_ERR}` : `DocGenService.processDocument returned ${bytes} bytes`,
                    SEVERITY.BLOCKER
                ),
                area
            });
            add({
                ...check(
                    'the generated document is titled from the record',
                    (p.GEN_TITLE || '') === `${PREFIX} Alpha`,
                    `title was "${p.GEN_TITLE}", expected "${PREFIX} Alpha"`,
                    SEVERITY.MINOR
                ),
                area
            });

            // Output format is the template's and cannot be overridden at runtime
            // when the admin locked it. (The runner removed its format picker in
            // v1.74; this is the server-side half of that contract.)
            add({
                ...check(
                    'a locked output format cannot be overridden at run time',
                    (p.LOCK || '').indexOf('locks its output format') !== -1,
                    `Lock_Output_Format__c = true, override 'Word' → "${p.LOCK}"`,
                    SEVERITY.MAJOR
                ),
                area
            });

            // Failure must be loud. A blank document would be silent corruption.
            add({
                ...check(
                    'a template with no active version fails with a message, not a blank document',
                    (p.NOVER || '').indexOf('No template file found') !== -1,
                    `got: ${p.NOVER}`,
                    SEVERITY.BLOCKER
                ),
                area
            });

            // Consistency between the two pickers: bulk uses a different query.
            add({
                ...check(
                    'bulk template picker applies the same active/audience rules as the runner',
                    bulkPicker.indexOf(`${PREFIX} Inactive`) === -1 &&
                        bulkPicker.indexOf(`${PREFIX} Filtered Out`) === -1,
                    `DocGenBulkController.getBulkTemplates has no Is_Active__c filter, so deactivated templates stay ` +
                        `selectable for bulk runs. Bulk picker: ${bulkPicker.join(', ')}`,
                    SEVERITY.MAJOR
                ),
                area
            });
        } catch (e) {
            add(
                skip(
                    'runner server-contract probes',
                    `probe Apex failed: ${String(e.message).slice(0, 180)}`,
                    SEVERITY.BLOCKER
                )
            );
        }

        /* ============================================================ *
         * 2. Bulk runner — the one end-user generation UI that ships
         *    with a tab and is therefore reachable.
         * ============================================================ */
        const bulkArea = 'Bulk runner';
        const launched = await launch({ headed });
        browser = launched.browser;
        const page = launched.page;
        const consoleErrors = launched.consoleErrors;

        const base = await login(page, org);
        await openTab(page, base, tabApi('DocGen_Bulk_Gen'), 12000);

        // Asserted on the words the user must see, not on a character count —
        // the amount of text varies with how many recent jobs exist.
        const bulkText = await componentText(page, 'doc-gen-bulk-runner');
        const rendered = {
            chars: bulkText.length,
            hasHeading: bulkText.indexOf('Bulk Document Generation') !== -1,
            hasStep1: bulkText.indexOf('Step 1') !== -1
        };
        add({
            ...check(
                'bulk generation UI renders on its tab',
                rendered.hasHeading && rendered.hasStep1,
                JSON.stringify(rendered),
                SEVERITY.BLOCKER
            ),
            area: bulkArea
        });
        const bootErrors = consoleErrors.slice();
        add({
            ...check(
                'bulk generation UI boots without a console error',
                bootErrors.length === 0,
                bootErrors.slice(0, 3).join(' | '),
                SEVERITY.MAJOR
            ),
            area: bulkArea
        });

        if (!rendered.hasStep1) {
            add(
                skip(
                    'bulk runner interaction checks',
                    'the component did not render, so nothing downstream could be driven',
                    SEVERITY.BLOCKER
                )
            );
        } else {
            const searchSel = 'input[placeholder="Start typing to find a template..."]';

            // THE control. If this is not clickable the whole feature is dead,
            // and "it is in the DOM" would not have caught it.
            let searchPos = await locate(page, searchSel);
            const liveJobs = await soql(
                org,
                `SELECT Id, ${ns}Status__c FROM ${ns}DocGen_Job__c ` +
                    `WHERE ${ns}Status__c NOT IN ('Completed','Failed','Completed with Errors')`
            );
            add({
                ...check(
                    'the screen stays usable while a job is still running',
                    searchPos.hit === 'ok',
                    searchPos.hit === 'ok'
                        ? `template search box is hittable with ${liveJobs.length} non-terminal job(s) present`
                        : `HIT_TEST on the template search box says "${searchPos.hit}", with ${liveJobs.length} ` +
                              `DocGen_Job__c row(s) in a non-terminal status (this suite parks one deliberately). ` +
                              `A DocGen_Job__c in a non-terminal status ` +
                              `(Draft/Queued/Processing) makes the Recent Jobs row render an inline lightning-spinner; ` +
                              `.history-row has no position:relative, so the spinner's slds-spinner_container escapes ` +
                              `and covers the entire page. Every control in Bulk Generation is unusable until that job ` +
                              `reaches a terminal status. See docGenBulkRunner.html (Recent Jobs row) + ` +
                              `docGenBulkRunner.css .history-row.`,
                    SEVERITY.BLOCKER
                ),
                area: bulkArea
            });

            // Neutralise the overlay so the remaining checks measure their own subject.
            const killed = await neutraliseRowSpinners(page);
            if (killed) searchPos = await locate(page, searchSel);

            if (searchPos.hit !== 'ok') {
                add(
                    skip(
                        'bulk runner interaction checks',
                        `the template search box is still unreachable (${searchPos.hit}) after hiding row spinners`,
                        SEVERITY.BLOCKER
                    )
                );
            } else {
                // --- template picker ------------------------------------------------
                await clickAt(page, searchPos, 1500);
                const onFocus = await ev(
                    page,
                    `return __dgFind('.slds-listbox__option', true).map(o => (o.textContent || '').trim());`
                );
                add({
                    ...check(
                        'focusing the template box lists the available templates',
                        onFocus.length > 0,
                        `${onFocus.length} options offered`,
                        SEVERITY.MAJOR
                    ),
                    area: bulkArea
                });

                await page.keyboard.type(`${PREFIX} Good`);
                await page.waitForTimeout(1500);
                const filteredOpts = await ev(
                    page,
                    `return __dgFind('.slds-listbox__option', true).map(o => (o.textContent || '').trim());`
                );
                add({
                    ...check(
                        'typing narrows the template list to the match',
                        filteredOpts.length > 0 && filteredOpts.every((o) => o.indexOf(`${PREFIX} Good`) !== -1),
                        `after typing "${PREFIX} Good": ${filteredOpts.join(' / ') || '(nothing)'}`,
                        SEVERITY.MAJOR
                    ),
                    area: bulkArea
                });

                // A search with no match must say so rather than show a blank box.
                await page.keyboard.type('ZZZNOSUCHTEMPLATE');
                await page.waitForTimeout(1200);
                const emptyText = await componentText(page, 'doc-gen-bulk-runner');
                add({
                    ...check(
                        'a search with no matches says so instead of showing an empty box',
                        emptyText.indexOf('No templates found') !== -1,
                        'expected the "No templates found" empty state in the dropdown',
                        SEVERITY.MINOR
                    ),
                    area: bulkArea
                });

                // Re-narrow and select the good template.
                for (let i = 0; i < 'ZZZNOSUCHTEMPLATE'.length; i++) await page.keyboard.press('Backspace');
                await page.waitForTimeout(1500);
                const opt = await locateByText(page, '.slds-listbox__option', `${PREFIX} Good PDF`);
                add({
                    ...check(
                        'a template option can be clicked',
                        opt.found && opt.hit === 'ok',
                        `found=${opt.found} hit=${opt.hit}`,
                        SEVERITY.BLOCKER
                    ),
                    area: bulkArea
                });

                if (opt.found && opt.hit === 'ok') {
                    await clickAt(page, opt, 3000);
                    const afterSelect = await componentText(page, 'doc-gen-bulk-runner');
                    add({
                        ...check(
                            'selecting a template opens the filter and run steps',
                            afterSelect.indexOf('Step 2') !== -1 && afterSelect.indexOf('Step 3') !== -1,
                            'Step 2 (Record Filter) and Step 3 (Run Generation) must appear once a template is chosen',
                            SEVERITY.BLOCKER
                        ),
                        area: bulkArea
                    });

                    // The only output choice on this screen is a PACKAGING choice
                    // (individual files / packet / both). The file format is the
                    // template's Output_Format__c and the UI must not appear to
                    // offer a way to change it — otherwise a user would expect a
                    // DOCX out of a PDF template.
                    //
                    // The default is "Print-Ready Packet", which merges everything
                    // into one file on the job. Switching to "Individual Files" is
                    // what makes the per-record attachment assertion below mean
                    // something, so the choice is both asserted AND used.
                    const cbPos = await locateComboboxShowing(page, OUT_MODES);
                    if (cbPos.found && cbPos.hit === 'ok') {
                        await clickAt(page, cbPos, 1200);
                        const opts = await ev(
                            page,
                            `${TEXT_OF}\n return __dgFind('[role="option"]', true).map(o => __dgText(o)).filter(Boolean);`
                        );
                        const formatWords = ['docx', 'Word', 'PowerPoint', 'Excel', 'HTML'];
                        add({
                            ...check(
                                'the bulk screen offers no file-format override — format stays the template’s',
                                opts.length > 0 && !opts.some((o) => formatWords.some((w) => o.indexOf(w) !== -1)),
                                `Output Mode options: ${opts.join(' / ') || '(none opened)'}`,
                                SEVERITY.MINOR
                            ),
                            area: bulkArea
                        });

                        // Target the item's inner body, not the [role="option"]
                        // host: HIT_TEST's containment test cannot cross a shadow
                        // boundary, so the host always reads as "covered by" its
                        // own child.
                        const indiv = await locateByText(page, '.slds-media__body', 'Individual Files');
                        if (indiv.found && indiv.hit === 'ok') {
                            await clickAt(page, indiv, 1500);
                            const nowValue = await locateComboboxShowing(page, OUT_MODES);
                            individualMode = nowValue.value === 'Individual Files';
                            add({
                                ...check(
                                    'choosing an output mode is honoured by the UI',
                                    individualMode,
                                    `after picking "Individual Files" the control reads "${nowValue.value}"`,
                                    SEVERITY.MAJOR
                                ),
                                area: bulkArea
                            });
                        } else {
                            add(
                                skip(
                                    'choosing an output mode is honoured by the UI',
                                    `the "Individual Files" option was not clickable (${indiv.hit})`,
                                    SEVERITY.MAJOR
                                )
                            );
                        }
                    } else {
                        add(
                            skip(
                                'the bulk screen offers no file-format override',
                                `the Output Mode combobox was not reachable (${cbPos.hit})`,
                                SEVERITY.MINOR
                            )
                        );
                    }

                    // --- filter validation ------------------------------------------
                    const condPos = await locate(page, 'textarea');
                    if (condPos.found && condPos.hit === 'ok') {
                        await clickAt(page, condPos, 400);
                        await page.keyboard.type(`Name LIKE '${PREFIX}%'`);
                        await page.keyboard.press('Tab'); // lightning-textarea fires change on blur
                        await page.waitForTimeout(1200);

                        const validate = await locateByText(page, 'button', 'Validate Filter');
                        add({
                            ...check(
                                'the Validate Filter button is clickable',
                                validate.found && validate.hit === 'ok',
                                `found=${validate.found} hit=${validate.hit}`,
                                SEVERITY.MAJOR
                            ),
                            area: bulkArea
                        });
                        if (validate.found && validate.hit === 'ok') {
                            await clickAt(page, validate, 6000);
                            const counted = await componentText(page, 'doc-gen-bulk-runner');
                            add({
                                ...check(
                                    'Validate reports the true number of matching records',
                                    counted.indexOf('2 Records Found') !== -1,
                                    `expected "2 Records Found" for Name LIKE '${PREFIX}%' (2 accounts seeded); ` +
                                        `component text did not contain it`,
                                    SEVERITY.MAJOR
                                ),
                                area: bulkArea
                            });
                        }

                        // --- run it -----------------------------------------------------
                        const jobLabel = `${runTag}-ok`;
                        const namePos = await locate(page, 'input[placeholder="e.g. March Receipts"]');
                        if (namePos.found && namePos.hit === 'ok') {
                            await clickAt(page, namePos, 300);
                            await page.keyboard.type(jobLabel);
                            await page.keyboard.press('Tab');
                            await page.waitForTimeout(800);
                        }

                        const runBtn = await locateByText(page, 'button', 'Run Bulk Generation');
                        add({
                            ...check(
                                'the Run button is clickable once the filter is validated',
                                runBtn.found && runBtn.hit === 'ok',
                                `found=${runBtn.found} hit=${runBtn.hit}`,
                                SEVERITY.BLOCKER
                            ),
                            area: bulkArea
                        });

                        if (runBtn.found && runBtn.hit === 'ok') {
                            await clickAt(page, runBtn, 4000);

                            // SERVER STATE, not the spinner: the job row must exist.
                            const job = await waitForJob(org, ns, jobLabel, 210000);
                            add({
                                ...check(
                                    'pressing Run creates a bulk job on the server',
                                    !!job,
                                    job
                                        ? `DocGen_Job__c ${job.Id} status ${F(job, 'Status__c')}`
                                        : `no DocGen_Job__c with Label__c = ${jobLabel} appeared within 210s`,
                                    SEVERITY.BLOCKER
                                ),
                                area: bulkArea
                            });

                            if (job) {
                                const total = Number(F(job, 'Total_Records__c') || 0);
                                const ok = Number(F(job, 'Success_Count__c') || 0);
                                const err = Number(F(job, 'Error_Count__c') || 0);
                                add({
                                    ...check(
                                        'the job generates one document per matching record',
                                        total === 2 && ok === 2 && err === 0,
                                        `status=${F(job, 'Status__c')} total=${total} success=${ok} errors=${err}; ` +
                                            `error log: ${String(F(job, 'Error_Log__c') || '').slice(0, 160)}`,
                                        SEVERITY.BLOCKER
                                    ),
                                    area: bulkArea
                                });

                                // The document has to actually land on the record.
                                // ContentDocumentLink does not support a semi-join,
                                // so the record ids are resolved first.
                                const seededAccts = await soql(
                                    org,
                                    `SELECT Id FROM Account WHERE Name LIKE '${PREFIX}%'`
                                );
                                const idList = seededAccts.map((a) => `'${a.Id}'`).join(',');
                                const files = idList
                                    ? await soql(
                                          org,
                                          `SELECT ContentDocument.Title, ContentDocument.FileExtension, ` +
                                              `LinkedEntityId FROM ContentDocumentLink ` +
                                              `WHERE LinkedEntityId IN (${idList})`
                                      )
                                    : [];
                                const pdfs = files.filter(
                                    (f) => f.ContentDocument && f.ContentDocument.FileExtension === 'pdf'
                                );
                                const recordsWithFile = new Set(pdfs.map((p) => p.LinkedEntityId)).size;
                                if (individualMode) {
                                    add({
                                        ...check(
                                            'each generated document is attached to its own record',
                                            pdfs.length >= 2 && recordsWithFile >= 2,
                                            `${pdfs.length} pdf files across ${recordsWithFile} records ` +
                                                `(expected 1 each on 2 records) — Output Mode was Individual Files`,
                                            SEVERITY.BLOCKER
                                        ),
                                        area: bulkArea
                                    });
                                } else {
                                    add(
                                        skip(
                                            'each generated document is attached to its own record',
                                            'the run could not be switched to Individual Files output mode, so ' +
                                                'per-record attachment was not exercised',
                                            SEVERITY.BLOCKER
                                        )
                                    );
                                }
                                add({
                                    ...check(
                                        "the output honours the template's Output Format (PDF)",
                                        files.length > 0 &&
                                            files.every(
                                                (f) => !f.ContentDocument || f.ContentDocument.FileExtension === 'pdf'
                                            ),
                                        `extensions produced: ${
                                            [
                                                ...new Set(
                                                    files.map((f) => (f.ContentDocument || {}).FileExtension || '?')
                                                )
                                            ].join(', ') || '(no files attached to the records at all)'
                                        }`,
                                        SEVERITY.MAJOR
                                    ),
                                    area: bulkArea
                                });
                            }
                        }
                    } else {
                        add(
                            skip(
                                'bulk filter + run checks',
                                `the SOQL filter textarea was not reachable (${condPos.hit})`,
                                SEVERITY.BLOCKER
                            )
                        );
                    }
                }
            }
        }

        /* ============================================================ *
         * 3. Failure surfacing — a run that cannot succeed must SAY so.
         *    Uses the template with no active version: every record fails.
         * ============================================================ */
        try {
            await openTab(page, base, tabApi('DocGen_Bulk_Gen'), 12000);
            await neutraliseRowSpinners(page);
            const failLabel = `${runTag}-err`;
            const drove = await driveBulkRun(page, `${PREFIX} No Version`, `Name LIKE '${PREFIX}%'`, failLabel);
            if (!drove.ok) {
                add(
                    skip(
                        'bulk run surfaces per-record failures',
                        `could not drive the second run: ${drove.why}`,
                        SEVERITY.MAJOR
                    )
                );
            } else {
                const failJob = await waitForJob(org, ns, failLabel, 210000);
                add({
                    ...check(
                        'a run where every record fails is reported as failed, not as success',
                        failJob &&
                            Number(F(failJob, 'Error_Count__c') || 0) === 2 &&
                            Number(F(failJob, 'Success_Count__c') || 0) === 0,
                        failJob
                            ? `status=${F(failJob, 'Status__c')} success=${F(failJob, 'Success_Count__c')} ` +
                                  `errors=${F(failJob, 'Error_Count__c')}`
                            : 'no job row appeared',
                        SEVERITY.BLOCKER
                    ),
                    area: bulkArea
                });
                add({
                    ...check(
                        'the failing job records WHY each record failed',
                        failJob && String(F(failJob, 'Error_Log__c') || '').indexOf('template file') !== -1,
                        `Error_Log__c = ${String((failJob && F(failJob, 'Error_Log__c')) || '(empty)').slice(0, 200)}`,
                        SEVERITY.MAJOR
                    ),
                    area: bulkArea
                });

                // and the UI must show it, not just the database
                await openTab(page, base, tabApi('DocGen_Bulk_Gen'), 12000);
                await neutraliseRowSpinners(page);
                const hist = await componentText(page, 'doc-gen-bulk-runner');
                add({
                    ...check(
                        'the Recent Jobs list shows the error count to the user',
                        hist.indexOf(failLabel) !== -1 && hist.indexOf('2 errors') !== -1,
                        `Recent Jobs did not show "${failLabel}" with "2 errors" — a user would see the run as ` +
                            `finished with no indication anything went wrong`,
                        SEVERITY.MAJOR
                    ),
                    area: bulkArea
                });
            }
        } catch (e) {
            add(
                skip(
                    'bulk run surfaces per-record failures',
                    `second run threw: ${String(e.message).slice(0, 160)}`,
                    SEVERITY.MAJOR
                )
            );
        }

        /* ============================================================ *
         * 4. A filter that matches nothing must not be runnable.
         * ============================================================ */
        try {
            await openTab(page, base, tabApi('DocGen_Bulk_Gen'), 12000);
            await neutraliseRowSpinners(page);
            const zero = await driveBulkRun(page, `${PREFIX} Good PDF`, `Name = 'ZZZ-no-such-account'`, '', {
                stopBeforeRun: true
            });
            if (!zero.ok) {
                add(
                    skip(
                        'a filter matching no records blocks the run',
                        `could not set up the zero-match filter: ${zero.why}`,
                        SEVERITY.MINOR
                    )
                );
            } else {
                add({
                    ...check(
                        'a filter that matches no records leaves Run disabled',
                        zero.runDisabled === true,
                        `Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit ` +
                            `a job that will produce nothing. isRunDisabled only requires filterValidated, and ` +
                            `runAnalysis() early-returns on a 0 count so no analysis blocks it ` +
                            `(docGenBulkRunner.js isRunDisabled / runAnalysis).`,
                        SEVERITY.MINOR
                    ),
                    area: bulkArea
                });
            }
        } catch (e) {
            add(
                skip(
                    'a filter matching no records blocks the run',
                    `threw: ${String(e.message).slice(0, 160)}`,
                    SEVERITY.MINOR
                )
            );
        }

        /* ============================================================ *
         * 5. Command Hub — the front door for everything else the
         *    end user can reach without an admin building a page.
         * ============================================================ */
        const hubArea = 'Command Hub';
        try {
            await openTab(page, base, tabApi('DocGen_Command_Hub'), 12000);
            const hubUp = await ev(
                page,
                `
        const h = __dgFind(${JSON.stringify(host('doc-gen-command-hub'))});
        if (!h) return { present: false };
        const navs = [];
        const walk = (root) => {
          for (const el of (root.querySelectorAll ? root.querySelectorAll('button') : [])) {
            const t = (el.textContent || '').trim();
            if (t) navs.push(t);
          }
          for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
            if (el.shadowRoot) walk(el.shadowRoot);
          }
        };
        walk(h.shadowRoot || h);
        return { present: true, navs: navs.slice(0, 12) };
      `
            );
            add({
                ...check(
                    'the DocGen Command Hub renders with its navigation',
                    hubUp.present && (hubUp.navs || []).some((n) => n.indexOf('My Templates') !== -1),
                    JSON.stringify(hubUp).slice(0, 220),
                    SEVERITY.BLOCKER
                ),
                area: hubArea
            });

            if (hubUp.present) {
                // Each sidebar section must actually mount its component. A nav
                // item that highlights but renders nothing is the classic failure
                // here, and only mounting proves the child bundle loaded.
                const sections = [
                    ['Bulk Generation', 'doc-gen-bulk-runner'],
                    ['Signatures', 'doc-gen-signature-settings'],
                    ['Assets', 'doc-gen-assets'],
                    ['Email Templates', 'doc-gen-email-templates']
                ];
                for (const [label, kebab] of sections) {
                    // The Bulk Generation panel brings the escaping row spinner
                    // with it (asserted above), which would then cover the very
                    // nav buttons this loop needs. Neutralise between sections.
                    await neutraliseRowSpinners(page);
                    const nav = await locateByText(page, 'button', label);
                    if (!nav.found || nav.hit !== 'ok') {
                        add({
                            ...check(
                                `Command Hub "${label}" is clickable`,
                                false,
                                `found=${nav.found} hit=${nav.hit}`,
                                SEVERITY.MAJOR
                            ),
                            area: hubArea
                        });
                        continue;
                    }
                    const before = consoleErrors.length;
                    await clickAt(page, nav, 5000);
                    const panelText = await componentText(page, kebab);
                    const newErrors = consoleErrors.slice(before);
                    add({
                        ...check(
                            `Command Hub "${label}" mounts its component`,
                            panelText.length > 40 && newErrors.length === 0,
                            `rendered ${panelText.length} chars of text; ` +
                                `consoleErrors=${newErrors.slice(0, 2).join(' | ') || 'none'}`,
                            SEVERITY.MAJOR
                        ),
                        area: hubArea
                    });
                }

                // The Buttons tab is permission-gated (canManageButtons). Its
                // absence is a legitimate state, so it is reported rather than failed.
                await neutraliseRowSpinners(page);
                const buttonsNav = await locateByText(page, 'button', 'Buttons');
                if (buttonsNav.found && buttonsNav.hit === 'ok') {
                    await clickAt(page, buttonsNav, 5000);
                    const builderText = await componentText(page, 'doc-gen-button-builder');
                    add({
                        ...check(
                            'the document Button builder mounts from the Command Hub',
                            builderText.length > 40,
                            `rendered ${builderText.length} chars of text`,
                            SEVERITY.MAJOR
                        ),
                        area: hubArea
                    });
                } else {
                    add(
                        skip(
                            'the document Button builder mounts from the Command Hub',
                            'the Buttons tab is hidden — DocGenButtonAdminController.canManageButtons returned false ' +
                                'for this user (needs the DocGen_Button_Manager permission set plus metadata-write)',
                            SEVERITY.MINOR
                        )
                    );
                }
            }
        } catch (e) {
            add(skip('Command Hub checks', `threw: ${String(e.message).slice(0, 160)}`, SEVERITY.MAJOR));
        }

        /* ============================================================ *
         * 6. What this run could NOT reach, said out loud.
         *    A skipped check is not a passing one.
         * ============================================================ */
        const unreachable =
            'no Lightning record page or quick action exists in this org that hosts the component ' +
            '(SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no ' +
            'LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but ' +
            'nothing that places this component, and there is no supported URL that renders an LWC on a record ' +
            'without a page assignment. Reaching it requires hand-building a Lightning record page, which this ' +
            'suite is not permitted to deploy.';

        add(skip('docGenRunner renders on a record page', unreachable, SEVERITY.BLOCKER));
        add(skip('docGenRunner Generate button produces a document from a record page', unreachable, SEVERITY.BLOCKER));
        add(skip('docGenRunner honours the Save to Record / Download output choice', unreachable, SEVERITY.MAJOR));
        add(
            skip('docGenRunner shows the empty state when no template matches the record', unreachable, SEVERITY.MAJOR)
        );
        add(skip('docGenSignatureSender validates its fields and creates a request', unreachable, SEVERITY.BLOCKER));
        add(
            skip(
                'docGenSignatureSender writes correct DocGen_Signature_Request__c / DocGen_Signer__c rows',
                unreachable,
                SEVERITY.BLOCKER
            )
        );
        add(skip('docGenButton one-click generation from a record action', unreachable, SEVERITY.MAJOR));
        add(
            skip(
                'a user without the DocGen permission set gets a clear message, not a broken UI',
                'needs a second user and a Login-As session; creating a licensed user and switching identity is ' +
                    'outside what this suite may do to the org, and System.runAs is not available in anonymous Apex. ' +
                    'The template-audience half of this (Required_Permission_Sets__c) IS covered above.',
                SEVERITY.MAJOR
            )
        );

        return suiteResult('ui-runner', 'End-user UI', checks);
    } catch (e) {
        // Never throw out of a suite: a crash must still report what it managed.
        add(skip('ui-runner suite completed', `suite threw: ${String(e.message).slice(0, 200)}`, SEVERITY.BLOCKER));
        return suiteResult('ui-runner', 'End-user UI', checks);
    } finally {
        if (browser) {
            try {
                await browser.close();
            } catch (e) {
                /* nothing useful to do */
            }
        }
        try {
            await runAnonymous(org, CLEANUP_APEX);
        } catch (e) {
            /* leftovers are cleaned by the next run's seed */
        }
    }
}

/* ------------------------------------------------------------------ *
 * Shared drivers
 * ------------------------------------------------------------------ */

/**
 * Drives Step 1 → Step 3 of the bulk runner: pick a template, set a filter,
 * validate, optionally name and run. Returns why it stopped when it could not
 * complete, so the caller can raise a skip rather than a misleading failure.
 */
async function driveBulkRun(page, templateName, condition, jobLabel, { stopBeforeRun = false } = {}) {
    const searchSel = 'input[placeholder="Start typing to find a template..."]';
    const searchPos = await locate(page, searchSel);
    if (!searchPos.found || searchPos.hit !== 'ok') return { ok: false, why: `template search ${searchPos.hit}` };
    await clickAt(page, searchPos, 800);
    await page.keyboard.type(templateName);
    await page.waitForTimeout(1500);

    const opt = await locateByText(page, '.slds-listbox__option', templateName);
    if (!opt.found || opt.hit !== 'ok') return { ok: false, why: `template option ${opt.hit}` };
    await clickAt(page, opt, 3000);

    const condPos = await locate(page, 'textarea');
    if (!condPos.found || condPos.hit !== 'ok') return { ok: false, why: `filter textarea ${condPos.hit}` };
    await clickAt(page, condPos, 400);
    // Clear anything a template auto-filter may have put there.
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+A' : 'Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(condition);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(1000);

    const validate = await locateByText(page, 'button', 'Validate Filter');
    if (!validate.found || validate.hit !== 'ok') return { ok: false, why: `validate button ${validate.hit}` };
    await clickAt(page, validate, 7000);

    if (stopBeforeRun) {
        const state = await page.evaluate(
            inPage(`
      const btns = __dgFind('button', true).filter(b => (b.textContent || '').indexOf('Run Bulk Generation') !== -1);
      if (!btns.length) return { runDisabled: null };
      return { runDisabled: btns.some(b => b.disabled) };
    `)
        );
        return { ok: true, runDisabled: state.runDisabled };
    }

    if (jobLabel) {
        const namePos = await locate(page, 'input[placeholder="e.g. March Receipts"]');
        if (namePos.found && namePos.hit === 'ok') {
            await clickAt(page, namePos, 300);
            await page.keyboard.type(jobLabel);
            await page.keyboard.press('Tab');
            await page.waitForTimeout(600);
        }
    }

    const runBtn = await locateByText(page, 'button', 'Run Bulk Generation');
    if (!runBtn.found || runBtn.hit !== 'ok') return { ok: false, why: `run button ${runBtn.hit}` };
    await clickAt(page, runBtn, 4000);
    return { ok: true };
}

/**
 * Waits for the batch to finish server-side. The UI polls too, but believing the
 * UI's own poll would be circular — this reads the row directly.
 */
async function waitForJob(org, ns, label, timeoutMs) {
    const terminal = ['Completed', 'Failed', 'Completed with Errors'];
    const deadline = Date.now() + timeoutMs;
    let last = null;
    while (Date.now() < deadline) {
        const rows = await soql(
            org,
            `SELECT Id, ${ns}Status__c, ${ns}Total_Records__c, ${ns}Success_Count__c, ${ns}Error_Count__c, ` +
                `${ns}Error_Log__c FROM ${ns}DocGen_Job__c WHERE ${ns}Label__c = '${label}' ` +
                `ORDER BY CreatedDate DESC LIMIT 1`
        );
        if (rows.length) {
            last = rows[0];
            if (terminal.indexOf(last[ns + 'Status__c']) !== -1) return last;
        }
        await new Promise((r) => setTimeout(r, 6000));
    }
    return last;
}
