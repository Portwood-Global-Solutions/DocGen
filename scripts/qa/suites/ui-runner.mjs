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
 * HOW THE RECORD-PAGE COMPONENTS ARE REACHED
 * ------------------------------------------
 * docGenRunner and docGenSignatureSender are lightning__RecordPage components and
 * the package deliberately ships no FlexiPage — customers place them themselves.
 * There is no supported URL that renders an LWC on a record without a page
 * assignment, so for a long time both were recorded here as SKIPPED. They are now
 * hosted by a QA-ONLY FlexiPage, `QA_DocGen_Account_Record`, which lives in
 * scripts/qa/fixtures/ (OUTSIDE force-app, so a package build cannot pick it up)
 * and is deployed to the verify org by scripts/qa/fixtures/deploy.sh. It is
 * assigned as the org-default Account record page, so openRecord(page, base,
 * <accountId>) renders both components. If those checks start reporting the host
 * as missing, re-run that deploy script — do NOT re-skip them.
 *
 * docGenButton is still unreachable: it is lightning__RecordAction ONLY, and no
 * quick action hosts it. That remains a skip, with that reason.
 *
 * WHAT IT COULD NOT REACH
 * -----------------------
 * See the skip checks at the bottom and the report's "Not covered by this run"
 * section. A skipped check is never counted as a pass.
 *
 * HOUSE RULES OBSERVED (from scripts/ui-smoke.mjs)
 *   1. login() busts Lightning's IndexedDB cache. It is never skipped — and any
 *      navigation in this file that must NOT see a cached @AuraEnabled(cacheable)
 *      payload goes through clearLightningCache() first (the empty-state check
 *      would otherwise assert against a template list captured seconds earlier).
 *   2. HIT_TEST every control before believing it is usable — "it is in the DOM"
 *      has hidden at least one blocker in this very component (see the spinner
 *      overlay check below, which is a real defect this suite found).
 *   3. CSS :hover ignores synthetic events — drive with page.mouse.
 *   4. Synthetic keydown is not typing — drive with page.keyboard. The one
 *      exception is the runner's NATIVE <select> controls, which are driven with
 *      Playwright's own selectOption(): a native dropdown popup is an OS-level
 *      window that page.mouse cannot reach, and selectOption is a real Playwright
 *      action (it fires the browser's own input/change), not a dispatched event.
 *   5. inPage() bodies are TEMPLATE LITERALS: a backslash-s becomes a literal
 *      "s". No regex escapes are used in any evaluated body below.
 *   6. host.textContent on an LWC is the EMPTY STRING — content lives in the
 *      shadow root. Everything that reads component text goes through the
 *      shadow-walking helpers, never textContent on a host.
 */
import { check, skip, suiteResult, suiteSkipped, SEVERITY } from '../lib/report.mjs';
import { launch, login, openTab, openRecord, inPage, HIT_TEST } from '../lib/browser.mjs';
import { runAnonymous, debugMap, soql, sf, orgFrontDoorUrl } from '../lib/sf.mjs';

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
 *
 * `runTag` is stamped into Good PDF's Document_Title_Format__c (on BOTH the
 * template and its active version — the render path prefers the version's
 * snapshot) so the file the record-page runner produces can be identified by
 * name in a shared org. Without it, "a PDF appeared on the Account" proves
 * nothing: this suite's own bulk phase and every previous run leave PDFs there.
 *
 * Two ready-made PDFs are also attached to Alpha so the Combine PDFs tab has
 * something to list. Its dual listbox is populated from getRecordPdfs at wire
 * time, so they must exist BEFORE the page loads.
 */
const seedApex = (runTag) => `
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
    Type__c = 'HTML', Output_Format__c = 'PDF', Query_Config__c = qc, Is_Active__c = true, Category__c = '${PREFIX}',
    Document_Title_Format__c = '${runTag} {Name}');
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
        Content_Version_Id__c = cvs[i].Id,
        Document_Title_Format__c = t.Id == good.Id ? '${runTag} {Name}' : null));
    i++;
}
insert vers;

// Two PDFs on Alpha so the Combine PDFs tab has a populated source list.
Blob sample = Blob.toPdf('<html><body><p>${PREFIX} merge source</p></body></html>');
insert new List<ContentVersion>{
    new ContentVersion(Title = '${PREFIX} merge source A', PathOnClient = 'uiqa-merge-a.pdf',
        VersionData = sample, FirstPublishLocationId = accts[0].Id),
    new ContentVersion(Title = '${PREFIX} merge source B', PathOnClient = 'uiqa-merge-b.pdf',
        VersionData = sample, FirstPublishLocationId = accts[0].Id)
};

// A job parked in a non-terminal status. Recent Jobs renders a spinner for it,
// which is the precondition for the overlay check in the browser phase — seeded
// rather than hoped for, so that check is deterministic instead of depending on
// whatever jobs happen to be lying around the org.
insert new DocGen_Job__c(Template__c = good.Id, Status__c = 'Queued', Label__c = '${PREFIX} parked job');

System.debug('NS=' + DocGen_Template__c.sObjectType.getDescribe().getName());
System.debug('ACCT=' + accts[0].Id);
System.debug('GOOD=' + good.Id);
System.debug('LOCKED=' + locked.Id);
System.debug('SEEDED=' + [SELECT COUNT() FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%'] + ',' +
    [SELECT COUNT() FROM Account WHERE Name LIKE '${PREFIX}%']);
`;

/**
 * The runner's server contract.
 *
 * These call the SAME Apex the docGenRunner component's wire and Generate button
 * call — getTemplatesForObjectAndRecord for the picker, processDocument for the
 * output. The component IS driven in the browser further down; these exist
 * because a few of its contracts have no UI surface at all. The clearest is the
 * output-format lock: the runner removed its format picker in v1.74, so "the
 * format cannot be overridden at run time" can only be proved by asking the
 * server to override it and watching it refuse.
 *
 * Only DocGenException-throwing entry points are used: an @AuraEnabled method
 * that throws AuraHandledException cannot be caught in anonymous Apex, and an
 * uncatchable throw would roll the whole probe back with no output.
 */
const probeApex = (runTag) => `
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

/**
 * Hides every Account template so the runner's "no templates for this record"
 * empty state can actually be observed.
 *
 * There is no other way to reach it: the picker keys on
 * `Base_Object_API__c = :objectApiName AND Is_Active__c != FALSE`, and the QA
 * FlexiPage is Account-only, so a record with no matching template does not
 * exist while any active Account template does. The previous Is_Active__c value
 * of every row is returned as JSON and re-applied immediately afterwards (and
 * again from the suite's finally block), so the flip is restored even if the
 * assertion throws. It is deliberately the FIRST browser check, to keep the
 * window in which the org is modified as short as possible.
 */
const HIDE_ACCOUNT_TEMPLATES_APEX = `
List<DocGen_Template__c> all = [SELECT Id, Is_Active__c FROM DocGen_Template__c WHERE Base_Object_API__c = 'Account'];
List<Map<String, Object>> snap = new List<Map<String, Object>>();
for (DocGen_Template__c t : all) {
    snap.add(new Map<String, Object>{ 'i' => String.valueOf(t.Id), 'a' => t.Is_Active__c });
    t.Is_Active__c = false;
}
update all;
System.debug('SNAP=' + JSON.serialize(snap));
`;

/** Re-applies the exact Is_Active__c value each template had before the hide. */
const restoreAccountTemplatesApex = (snapJson) => `
List<Object> rows = (List<Object>) JSON.deserializeUntyped('${String(snapJson).replace(/'/g, "\\'")}');
List<DocGen_Template__c> ups = new List<DocGen_Template__c>();
for (Object o : rows) {
    Map<String, Object> m = (Map<String, Object>) o;
    ups.add(new DocGen_Template__c(Id = (Id) m.get('i'), Is_Active__c = (Boolean) m.get('a')));
}
update ups;
System.debug('RESTORED=' + ups.size());
`;

/**
 * Cleanup. Note DocGen_Error_Log__c.Template_Id__c is a TEXT field, not a
 * lookup — binding a Set<Id> to it does not compile, and a compile failure here
 * would silently leave every seeded row (including the parked Queued job, which
 * would then break the Bulk Generation screen for anyone else using the org).
 *
 * The signature rows are removed BEFORE the templates they point at, and the two
 * ContentVersions a signature request creates are removed by Id: the viewing
 * document is titled after the template (so the '${PREFIX}%' sweep would catch
 * it) but the frozen snapshot is titled `docgen_sig_frozen`, which that sweep
 * would miss and which would then accumulate on every run.
 */
const CLEANUP_APEX = `
List<DocGen_Template__c> mine = [SELECT Id FROM DocGen_Template__c WHERE Name LIKE '${PREFIX}%'];
Set<Id> ids = new Set<Id>();
Set<String> idStrings = new Set<String>();
for (DocGen_Template__c t : mine) { ids.add(t.Id); idStrings.add(String.valueOf(t.Id)); }
if (!ids.isEmpty()) {
    List<DocGen_Signature_Request__c> reqs = [
        SELECT Id, Source_Document_Id__c, Frozen_Document_CV_Id__c
        FROM DocGen_Signature_Request__c WHERE Template__c IN :ids];
    Set<Id> cvIds = new Set<Id>();
    for (DocGen_Signature_Request__c r : reqs) {
        if (String.isNotBlank(r.Source_Document_Id__c)) cvIds.add((Id) r.Source_Document_Id__c);
        if (String.isNotBlank(r.Frozen_Document_CV_Id__c)) cvIds.add((Id) r.Frozen_Document_CV_Id__c);
    }
    if (!reqs.isEmpty()) {
        Set<Id> reqIds = new Map<Id, DocGen_Signature_Request__c>(reqs).keySet();
        delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c IN :reqIds];
        delete reqs;
    }
    if (!cvIds.isEmpty()) {
        delete [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId IN :cvIds];
    }
    delete [SELECT Id FROM DocGen_Error_Log__c WHERE Template_Id__c IN :idStrings];
    delete [SELECT Id FROM DocGen_Job__c WHERE Template__c IN :ids];
    delete [SELECT Id FROM DocGen_Saved_Query__c WHERE DocGen_Template__c IN :ids];
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
async function locate(page, sel, nth = 0) {
    const pick = `const el = __dgFind(${JSON.stringify(sel)}, true)[${nth}] || null;`;
    const r = await ev(
        page,
        `
    ${pick}
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
    ${pick}
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

/**
 * Descends THROUGH the shadow roots of one element to the first `sel` inside it.
 *
 * __dgFind searches the whole document; this is scoped to a single host, which is
 * the only way to tell three identically-rendered `<input class="slds-input">`
 * elements apart. A lightning-input's real input is two shadow roots down
 * (lightning-input → lightning-primitive-input-simple → input) and the host has
 * NO light children, so `host.querySelector('input')` returns null — the walk has
 * to start at the host's OWN shadow root, not at the host.
 */
const DEEP = `
  const __dgDeep = (root, sel) => {
    const walk = (n) => {
      if (!n || !n.querySelectorAll) return null;
      const hit = n.querySelector(sel);
      if (hit) return hit;
      for (const el of n.querySelectorAll('*')) {
        if (el.shadowRoot) { const r = walk(el.shadowRoot); if (r) return r; }
      }
      return null;
    };
    return (root && root.shadowRoot ? walk(root.shadowRoot) : null) || walk(root);
  };`;

/**
 * The real `<input>` of a lightning-input, identified by the host's `label`
 * property (and `data-index` for the repeated signer rows).
 *
 * Matching on a CSS selector is not possible here: the signer row's Name and
 * Email inputs carry no name, no placeholder and only a generated id.
 */
async function locateLightningInput(page, label, index) {
    // The data-index clause is composed HERE, in node — an `index === undefined`
    // test written inside the evaluated body would reference a variable that
    // does not exist in the page and throw ReferenceError.
    const byIndex = index === undefined ? '' : ` && (x.dataset || {}).index === ${JSON.stringify(index)}`;
    const finder = `
    ${DEEP}
    const host = __dgFind('lightning-input', true).find(
      x => x.label === ${JSON.stringify(label)}${byIndex});
    const el = host ? __dgDeep(host, 'input') : null;`;
    const found = await ev(
        page,
        `${finder}\n if (!el) return false; el.scrollIntoView({ block: 'center' }); return true;`
    );
    if (!found) return { found: false, hit: 'missing' };
    await page.waitForTimeout(300);
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
 * Type into a control the way a person does: real mouse to focus, real keys.
 * A dispatched keydown does not make the browser insert a character, and an
 * assignment to .value does not fire the change LWC listens for.
 */
async function typeInto(page, pos, text) {
    await clickAt(page, pos, 250);
    await page.keyboard.type(text);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(600);
}

/**
 * Re-runs login()'s cache bust WITHOUT re-authenticating.
 *
 * The template picker is `@AuraEnabled(cacheable=true)`, so Lightning persists
 * its payload to IndexedDB and will serve it to the next page load. The
 * empty-state check would otherwise assert against the template list captured
 * moments earlier and pass — or fail — for the wrong reason.
 */
async function clearLightningCache(page) {
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
}

/**
 * Every interactive control the runner is showing, as data.
 *
 * Used to prove a NEGATIVE — that no control exists which could change the
 * output FILE FORMAT. Asserting on the presence of a named widget would not do
 * it; the claim is about the whole surface, so the whole surface is enumerated.
 * Select options are reported by VALUE as well as label because the template
 * names themselves contain the word "PDF".
 */
const runnerControls = (page) =>
    ev(
        page,
        `
    ${TEXT_OF}
    const h = __dgFind(${JSON.stringify(host('doc-gen-runner'))});
    if (!h) return { present: false };
    const sel = __dgFind('select.custom-select', true).map(s => ({
      values: [...s.options].map(o => o.value),
      labels: [...s.options].map(o => (o.textContent || '').trim())
    }));
    return {
      present: true,
      selects: sel,
      segs: __dgFind('.seg-btn', true).map(b => ({ v: b.dataset.value, label: __dgText(b), active: /active/.test(b.className) })),
      pills: __dgFind('.pill-btn', true).map(b => ({ v: b.dataset.value, label: __dgText(b), active: /active/.test(b.className) })),
      primary: __dgFind('.cool-brand-btn', true).map(b => ({ label: __dgText(b), disabled: !!b.disabled })),
      dualListboxes: __dgFind('lightning-dual-listbox', true).map(d => (d.options || []).map(o => o.label))
    };
  `
    );

/** Which of the runner's two native selects is which, by the values they carry. */
function classifySelects(controls) {
    const selects = (controls && controls.selects) || [];
    return {
        category: selects.findIndex((s) => s.values.indexOf('__ALL__') !== -1),
        template: selects.findIndex((s) => s.values.some((v) => /^[a-zA-Z0-9]{15,18}$/.test(v)))
    };
}

/** found + disabled for a button carrying `text`, read through shadow roots. */
const buttonState = (page, text) =>
    ev(
        page,
        `
    ${TEXT_OF}
    const b = __dgFind('button', true).find(e => __dgText(e).indexOf(${JSON.stringify(text)}) !== -1);
    return b ? { found: true, disabled: !!b.disabled } : { found: false, disabled: null };
  `
    );

/**
 * Waits for a file whose title contains `needle` to be LINKED TO THE RECORD.
 *
 * Save-to-Record for PDF goes through DocGenPdfSaveQueueable, so the Aura call
 * returns before anything is written — polling the server is the only honest
 * evidence. A spinner finishing is not evidence.
 */
async function waitForRecordFile(org, recordId, needle, timeoutMs) {
    const deadline = Date.now() + timeoutMs;
    let seen = [];
    while (Date.now() < deadline) {
        const rows = await soql(
            org,
            `SELECT ContentDocument.Title, ContentDocument.FileExtension FROM ContentDocumentLink ` +
                `WHERE LinkedEntityId = '${recordId}'`
        );
        seen = rows.map((r) => (r.ContentDocument || {}).Title).filter(Boolean);
        const hit = rows.filter((r) => r.ContentDocument && String(r.ContentDocument.Title).indexOf(needle) !== -1);
        if (hit.length) return { file: hit[0].ContentDocument, all: seen, needle };
        await new Promise((r) => setTimeout(r, 5000));
    }
    // `needle` is echoed back so a failure message can name what was searched
    // for rather than what the caller thinks it searched for.
    return { file: null, all: seen, needle };
}

/** How many files are linked to a record right now. */
async function recordFileCount(org, recordId) {
    const rows = await soql(org, `SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = '${recordId}'`);
    return rows.length;
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

    // Stamped into the seeded template's Document_Title_Format__c, the bulk job
    // labels and the signer name, so every row and file this run creates can be
    // told apart from a previous run's leftovers in a shared org.
    const runTag = `${PREFIX}-${Date.now().toString(36)}`;

    let seedLog;
    try {
        seedLog = debugMap(await runAnonymous(org, seedApex(runTag)));
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
    // The title the seeded template renders under: "<runTag> <record name>".
    const expectedTitle = `${runTag} ${PREFIX} Alpha`;
    let browser;
    // Set when the Output Mode was successfully switched to Individual Files —
    // the per-record attachment assertion is only meaningful in that mode.
    let individualMode = false;
    // Is_Active__c snapshot taken while the empty state is being observed. Held
    // here so the suite's finally block can restore it even if a check throws.
    let hiddenTemplateSnapshot = null;
    // Only clears the snapshot AFTER the restore lands, so a failed restore is
    // retried by the suite's finally block instead of being forgotten.
    const restoreHiddenTemplates = async () => {
        if (!hiddenTemplateSnapshot) return;
        await runAnonymous(org, restoreAccountTemplatesApex(hiddenTemplateSnapshot));
        hiddenTemplateSnapshot = null;
    };

    try {
        /* ============================================================ *
         * 1. The runner's server contract — the parts of it that have no
         *    UI surface, plus the audience rules the picker must apply.
         *    The component itself is driven in section 2.
         * ============================================================ */
        const area = 'Runner (server contract)';
        try {
            const p = debugMap(await runAnonymous(org, probeApex(runTag)));
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
                    "the generated document's title resolves merge tokens against the record",
                    (p.GEN_TITLE || '') === expectedTitle,
                    `Document_Title_Format__c = "${runTag} {Name}" → title was "${p.GEN_TITLE}", ` +
                        `expected "${expectedTitle}"`,
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

            // The two pickers run different queries, so they are checked apart —
            // one assertion covering both hid which half was actually broken.

            // ACTIVE: a deactivated template must never be selectable, and on the
            // bulk screen least of all — the blast radius is a job across
            // thousands of records rather than one document.
            add({
                ...check(
                    'bulk template picker excludes deactivated templates',
                    bulkPicker.indexOf(`${PREFIX} Inactive`) === -1,
                    bulkPicker.indexOf(`${PREFIX} Inactive`) === -1
                        ? 'matches the single-record runner'
                        : `"${PREFIX} Inactive" is selectable for a bulk run. ` +
                              `DocGenBulkController.getBulkTemplates must filter Is_Active__c != FALSE, ` +
                              `the same predicate getTemplatesForObjectInternal uses. Picker: ${bulkPicker.join(', ')}`,
                    SEVERITY.MAJOR
                ),
                area
            });

            // RECORD FILTER: a genuinely different question, and the answer is not
            // simply "the picker is wrong".
            //
            // Record_Filter__c is a per-RECORD rule, and the bulk screen has no
            // single record — getBulkTemplates passes null to filterTemplatesForSender
            // precisely because of that, so only sharing and audience apply. Offering
            // the template is therefore defensible.
            //
            // What is NOT defensible is that nothing downstream applies it either:
            // Record_Filter__c is evaluated only in DocGenController's per-record
            // path (see canUseTemplateForRecord), and the batch does not call it. So
            // a bulk run over a WHERE clause can generate documents for records the
            // template's own filter excludes — silently, and at scale.
            //
            // Reported rather than fixed: making the batch honour the filter changes
            // what existing bulk jobs produce, which is a product decision.
            add({
                ...check(
                    'a record-filtered template is not silently applied to excluded records in bulk',
                    bulkPicker.indexOf(`${PREFIX} Filtered Out`) === -1,
                    `"${PREFIX} Filtered Out" carries a Record_Filter__c and is offered for bulk, where the filter ` +
                        `is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the ` +
                        `batch never calls the per-record check. Documents can be generated for records the ` +
                        `template excludes. Either the batch must apply the filter, or the picker must exclude it.`,
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
         * 2. docGenRunner ON A RECORD PAGE — the screen the customer
         *    actually uses. Reached through the QA-only FlexiPage
         *    described in the file header.
         *
         *    login() is what makes any of this trustworthy: Lightning
         *    serves component bundles AND cacheable Apex payloads out of
         *    IndexedDB, and has passed checks against code that was no
         *    longer deployed. It is never skipped, and clearLightningCache
         *    repeats the bust before any navigation whose result must not
         *    come from the previous one.
         * ============================================================ */
        const runnerArea = 'Runner (record page)';
        const launched = await launch({ headed });
        browser = launched.browser;
        const page = launched.page;
        const consoleErrors = launched.consoleErrors;
        const base = await login(page, org);

        const goodId = seedLog.GOOD || '';
        const lockedId = seedLog.LOCKED || '';

        /* --- 2a. The empty state ------------------------------------- *
         * Done FIRST and restored immediately: it is the only check that
         * has to modify rows this suite did not create.                  */
        try {
            const hide = debugMap(await runAnonymous(org, HIDE_ACCOUNT_TEMPLATES_APEX));
            hiddenTemplateSnapshot = hide.SNAP || null;
            if (!hiddenTemplateSnapshot) {
                add(
                    skip(
                        'the runner shows an actionable empty state when no template matches the record',
                        'the Is_Active__c snapshot came back empty, so the Account templates were never hidden and ' +
                            'the empty state could not be produced without guessing',
                        SEVERITY.MAJOR
                    )
                );
            } else {
                await clearLightningCache(page);
                await openRecord(page, base, acctId, 15000);
                const emptyText = await componentText(page, 'doc-gen-runner');
                const emptyControls = await runnerControls(page);
                const emptyPrimary = (emptyControls.primary || [])[0];
                add({
                    ...check(
                        'the runner shows an actionable empty state when no template matches the record',
                        emptyText.indexOf('No templates available for this record') !== -1 &&
                            emptyText.indexOf('Ask an admin') !== -1 &&
                            !!emptyPrimary &&
                            emptyPrimary.disabled === true,
                        emptyControls.present
                            ? `with every Account template inactive the runner rendered ` +
                                  `${emptyText.length} chars; Create Document disabled=${
                                      emptyPrimary ? emptyPrimary.disabled : 'no button'
                                  }. The user must be told WHY there is nothing to pick, and must not be able to ` +
                                  `press a button that cannot work.`
                            : 'the runner did not render at all',
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
            }
        } catch (e) {
            add(
                skip(
                    'the runner shows an actionable empty state when no template matches the record',
                    `threw: ${String(e.message).slice(0, 160)}`,
                    SEVERITY.MAJOR
                )
            );
        } finally {
            try {
                await restoreHiddenTemplates();
            } catch (e) {
                /* the suite's finally block retries */
            }
        }

        /* --- 2b. It renders, cleanly -------------------------------- */
        await clearLightningCache(page);
        const runnerErrMark = consoleErrors.length;
        await openRecord(page, base, acctId, 15000);
        const runnerText = await componentText(page, 'doc-gen-runner');
        const controls = await runnerControls(page);
        const idx = classifySelects(controls);
        const runnerErrors = consoleErrors.slice(runnerErrMark);

        add({
            ...check(
                'docGenRunner renders on a record page',
                controls.present && runnerText.indexOf('Select Template') !== -1 && idx.template !== -1,
                controls.present
                    ? `rendered ${runnerText.length} chars, ${controls.selects.length} picker(s), ` +
                          `${(controls.primary || []).length} primary button(s)`
                    : `no ${host('doc-gen-runner')} in the DOM. If this org lost the QA host page, re-run ` +
                          `scripts/qa/fixtures/deploy.sh — do not re-skip this check.`,
                SEVERITY.BLOCKER
            ),
            area: runnerArea
        });
        add({
            ...check(
                'the runner shows neither an error nor an empty state on a record that has templates',
                controls.present &&
                    runnerText.indexOf('Error:') === -1 &&
                    runnerText.indexOf('No templates available') === -1,
                `component text starts: ${runnerText.slice(0, 200)}`,
                SEVERITY.BLOCKER
            ),
            area: runnerArea
        });
        add({
            ...check(
                'docGenRunner boots without a console error',
                runnerErrors.length === 0,
                runnerErrors.slice(0, 3).join(' | '),
                SEVERITY.MAJOR
            ),
            area: runnerArea
        });

        if (!controls.present || idx.template === -1) {
            add(
                skip(
                    'record-page runner interaction checks',
                    'the runner did not render its template picker, so nothing downstream could be driven',
                    SEVERITY.BLOCKER
                )
            );
        } else {
            const tplLabels = controls.selects[idx.template].labels;
            const offered = (name) => tplLabels.some((l) => l.indexOf(name) !== -1);

            /* --- 2c. The picker ------------------------------------- */
            add({
                ...check(
                    'the record-page template picker lists a template the user can actually run',
                    offered(`${PREFIX} Good PDF`),
                    `picker showed: ${tplLabels.join(' / ')}`,
                    SEVERITY.BLOCKER
                ),
                area: runnerArea
            });
            const leaked = [`${PREFIX} Inactive`, `${PREFIX} Filtered Out`, `${PREFIX} Needs PermSet`].filter(offered);
            add({
                ...check(
                    'the record-page picker applies the active and audience rules',
                    leaked.length === 0,
                    leaked.length
                        ? `the picker offered ${leaked.join(', ')} — Is_Active__c / Record_Filter__c / ` +
                              `Required_Permission_Sets__c should have excluded them for this record and user`
                        : `Inactive, Record_Filter__c-excluded and permission-gated templates were all withheld`,
                    SEVERITY.MAJOR
                ),
                area: runnerArea
            });
            const tplSelPos = await locate(page, 'select.custom-select', idx.template);
            add({
                ...check(
                    'the template picker is reachable by a mouse',
                    tplSelPos.found && tplSelPos.hit === 'ok',
                    `found=${tplSelPos.found} hit=${tplSelPos.hit}`,
                    SEVERITY.BLOCKER
                ),
                area: runnerArea
            });

            // Category filter. Driven with Playwright's own selectOption because
            // a native <select> popup is an OS window page.mouse cannot open.
            if (idx.category === -1) {
                add(
                    skip(
                        'choosing a category narrows the template list',
                        'the category filter is hidden — it only renders when the loaded templates span more than ' +
                            'one Category__c value, which is a legitimate state for this org',
                        SEVERITY.MINOR
                    )
                );
            } else {
                try {
                    await page.locator('select.custom-select').nth(idx.category).selectOption(PREFIX);
                    await page.waitForTimeout(1500);
                    const filtered = await runnerControls(page);
                    const fIdx = classifySelects(filtered);
                    const fLabels = (filtered.selects[fIdx.template] || { labels: [] }).labels.filter(
                        (l) => l.indexOf('Choose a template') === -1
                    );
                    add({
                        ...check(
                            'choosing a category narrows the template list to that category',
                            fLabels.length > 0 && fLabels.every((l) => l.indexOf(`[${PREFIX}]`) !== -1),
                            `after picking category "${PREFIX}" the picker showed: ${fLabels.join(' / ') || '(nothing)'}`,
                            SEVERITY.MAJOR
                        ),
                        area: runnerArea
                    });
                    await page.locator('select.custom-select').nth(fIdx.category).selectOption('__ALL__');
                    await page.waitForTimeout(1200);
                } catch (e) {
                    add(
                        skip(
                            'choosing a category narrows the template list to that category',
                            `the category select could not be driven: ${String(e.message).slice(0, 140)}`,
                            SEVERITY.MAJOR
                        )
                    );
                }
            }

            /* --- 2d. Save to Record actually saves ------------------ */
            if (!goodId) {
                add(
                    skip(
                        'pressing Create Document in Save to Record mode puts the document on the record',
                        'the seed did not report the template Id, so the picker could not be driven to a known template',
                        SEVERITY.BLOCKER
                    )
                );
            } else {
                await page.locator('select.custom-select').nth(idx.template).selectOption(goodId);
                await page.waitForTimeout(1500);

                const savePill = await locate(page, '.pill-btn[data-value="save"]');
                add({
                    ...check(
                        'the Save to Record output choice is reachable',
                        savePill.found && savePill.hit === 'ok',
                        `found=${savePill.found} hit=${savePill.hit}`,
                        SEVERITY.BLOCKER
                    ),
                    area: runnerArea
                });

                if (savePill.found && savePill.hit === 'ok') {
                    await clickAt(page, savePill, 1000);
                    const afterSave = await runnerControls(page);
                    const savePillNow = (afterSave.pills || []).find((p) => p.v === 'save');
                    add({
                        ...check(
                            'choosing Save to Record is honoured by the UI',
                            !!savePillNow && savePillNow.active === true,
                            `output pills after the click: ${(afterSave.pills || [])
                                .map((p) => `${p.v}${p.active ? '(active)' : ''}`)
                                .join(', ')}`,
                            SEVERITY.MAJOR
                        ),
                        area: runnerArea
                    });

                    const genPos = await locate(page, '.cool-brand-btn');
                    add({
                        ...check(
                            'the Create Document button is reachable',
                            genPos.found && genPos.hit === 'ok',
                            `found=${genPos.found} hit=${genPos.hit}`,
                            SEVERITY.BLOCKER
                        ),
                        area: runnerArea
                    });

                    if (genPos.found && genPos.hit === 'ok') {
                        await clickAt(page, genPos, 2000);
                        // SERVER STATE. Save-to-Record for PDF runs in
                        // DocGenPdfSaveQueueable, so the Aura call returns long
                        // before anything is written — a finished spinner proves
                        // nothing at all here.
                        const saved = await waitForRecordFile(org, acctId, expectedTitle, 210000);
                        add({
                            ...check(
                                'pressing Create Document in Save to Record mode puts the document ON the record',
                                !!saved.file,
                                saved.file
                                    ? `ContentDocument "${saved.file.Title}" linked to ${acctId}`
                                    : `no file whose title contains "${saved.needle}" appeared on the record ` +
                                          `within 210s. Files linked to it: ${saved.all.join(', ') || '(none)'}`,
                                SEVERITY.BLOCKER
                            ),
                            area: runnerArea
                        });
                        if (!saved.file) {
                            // Not a failure of its own — it could not be
                            // evaluated, and a second red line for one cause
                            // would just inflate the count.
                            add(
                                skip(
                                    "the saved file is in the template's own output format",
                                    'no file reached the record, so there was no format to inspect',
                                    SEVERITY.MAJOR
                                )
                            );
                        } else {
                            add({
                                ...check(
                                    "the saved file is in the template's own output format",
                                    saved.file.FileExtension === 'pdf',
                                    `Output_Format__c = PDF, file extension = .${saved.file.FileExtension}`,
                                    SEVERITY.MAJOR
                                ),
                                area: runnerArea
                            });
                        }
                    }
                }

                /* --- 2e. Download must NOT also save ---------------- */
                const dlPill = await locate(page, '.pill-btn[data-value="download"]');
                if (!dlPill.found || dlPill.hit !== 'ok') {
                    add(
                        skip(
                            'pressing Create Document in Download mode downloads the document',
                            `the Download output choice was not reachable (${dlPill.hit})`,
                            SEVERITY.BLOCKER
                        )
                    );
                } else {
                    await clickAt(page, dlPill, 1000);
                    const afterDl = await runnerControls(page);
                    const dlPillNow = (afterDl.pills || []).find((p) => p.v === 'download');
                    add({
                        ...check(
                            'choosing Download is honoured by the UI',
                            !!dlPillNow && dlPillNow.active === true,
                            `output pills after the click: ${(afterDl.pills || [])
                                .map((p) => `${p.v}${p.active ? '(active)' : ''}`)
                                .join(', ')}`,
                            SEVERITY.MAJOR
                        ),
                        area: runnerArea
                    });

                    const filesBefore = await recordFileCount(org, acctId);
                    // Armed BEFORE the click: the anchor-click download fires as
                    // soon as the bytes come back.
                    const downloadName = page
                        .waitForEvent('download', { timeout: 210000 })
                        .then((d) => d.suggestedFilename())
                        .catch(() => null);
                    const genPos2 = await locate(page, '.cool-brand-btn');
                    if (genPos2.found && genPos2.hit === 'ok') {
                        await clickAt(page, genPos2, 1500);
                    }
                    const dlName = await downloadName;
                    add({
                        ...check(
                            'pressing Create Document in Download mode downloads the document to the browser',
                            !!dlName && dlName.indexOf(runTag) !== -1,
                            dlName
                                ? `the browser received "${dlName}"`
                                : `no download event fired within 210s — the user pressed the button and got no file`,
                            SEVERITY.BLOCKER
                        ),
                        area: runnerArea
                    });
                    await page.waitForTimeout(8000);
                    const filesAfter = await recordFileCount(org, acctId);
                    add({
                        ...check(
                            'Download does NOT also attach the document to the record',
                            filesAfter === filesBefore,
                            `files linked to the record: ${filesBefore} before the run, ${filesAfter} after. ` +
                                `Download and Save to Record are the two halves of one choice; honouring it means ` +
                                `Download leaves the record untouched.`,
                            SEVERITY.MAJOR
                        ),
                        area: runnerArea
                    });
                }
            }

            /* --- 2f. A locked output format has no runtime control -- */
            if (!lockedId) {
                add(
                    skip(
                        'a template with Lock_Output_Format__c exposes no runtime file-format control',
                        'the seed did not report the locked template Id',
                        SEVERITY.MAJOR
                    )
                );
            } else {
                try {
                    await page.locator('select.custom-select').nth(idx.template).selectOption(lockedId);
                    await page.waitForTimeout(1500);
                    const lockedControls = await runnerControls(page);
                    const lIdx = classifySelects(lockedControls);
                    const strayPickers = (lockedControls.selects || []).filter(
                        (s, i) => i !== lIdx.category && i !== lIdx.template
                    );
                    const pillValues = (lockedControls.pills || []).map((p) => p.v).sort();
                    const onlyDestination = pillValues.every((v) => v === 'download' || v === 'save');
                    add({
                        ...check(
                            'a template with Lock_Output_Format__c exposes no runtime file-format control',
                            strayPickers.length === 0 && onlyDestination,
                            `with the locked template selected the runner offered ${lockedControls.selects.length} ` +
                                `picker(s) (category + template) and the choice widgets [${pillValues.join(', ')}], ` +
                                `which are output DESTINATIONS, not formats. The server half of this contract — an ` +
                                `explicit override being refused — is asserted in the server-contract area.`,
                            SEVERITY.MAJOR
                        ),
                        area: runnerArea
                    });
                } catch (e) {
                    add(
                        skip(
                            'a template with Lock_Output_Format__c exposes no runtime file-format control',
                            `the locked template could not be selected: ${String(e.message).slice(0, 140)}`,
                            SEVERITY.MAJOR
                        )
                    );
                }
            }

            /* --- 2g. Document Packet tab ---------------------------- */
            const packetSeg = await locate(page, '.seg-btn[data-value="packet"]');
            if (!packetSeg.found || packetSeg.hit !== 'ok') {
                add(
                    skip(
                        'the Document Packet tab renders and its controls are reachable',
                        `the Document Packet tab was not reachable (${packetSeg.hit})`,
                        SEVERITY.MAJOR
                    )
                );
            } else {
                await clickAt(page, packetSeg, 4000);
                const packet = await runnerControls(page);
                // The dual-listbox HOST always reads as "covered by" its own
                // inner list — HIT_TEST's containment test cannot cross a shadow
                // boundary — so the inner list is what gets hit-tested.
                const packetList = await locate(page, '.slds-dueling-list__options');
                const packetBtn = await locate(page, '.cool-brand-btn');
                const packetOpts = (packet.dualListboxes || [])[0] || [];
                add({
                    ...check(
                        'the Document Packet tab renders its template chooser and it is reachable',
                        (packet.segs || []).some((s) => s.v === 'packet' && s.active) &&
                            (packet.dualListboxes || []).length === 1 &&
                            packetList.hit === 'ok',
                        `packet tab active=${(packet.segs || []).some((s) => s.v === 'packet' && s.active)}, ` +
                            `dual listboxes=${(packet.dualListboxes || []).length}, source list hit=${packetList.hit}`,
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
                add({
                    ...check(
                        "the packet chooser offers the record's PDF templates",
                        packetOpts.some((l) => l.indexOf(`${PREFIX} Good PDF`) !== -1),
                        `chooser offered ${packetOpts.length} template(s): ${packetOpts.slice(0, 6).join(' / ')}`,
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
                add({
                    ...check(
                        'the Create Packet button is reachable and refuses to run with nothing chosen',
                        packetBtn.hit === 'ok' && ((packet.primary || [])[0] || {}).disabled === true,
                        `button hit=${packetBtn.hit}, disabled=${((packet.primary || [])[0] || {}).disabled}`,
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
            }

            /* --- 2h. Combine PDFs tab ------------------------------- */
            const mergeSeg = await locate(page, '.seg-btn[data-value="mergeOnly"]');
            if (!mergeSeg.found || mergeSeg.hit !== 'ok') {
                add(
                    skip(
                        'the Combine PDFs tab renders and its controls are reachable',
                        `the Combine PDFs tab was not reachable (${mergeSeg.hit})`,
                        SEVERITY.MAJOR
                    )
                );
            } else {
                await clickAt(page, mergeSeg, 4000);
                const merge = await runnerControls(page);
                const mergeList = await locate(page, '.slds-dueling-list__options');
                const mergeBtn = await locate(page, '.cool-brand-btn');
                const mergeOpts = (merge.dualListboxes || [])[0] || [];
                const seededSources = mergeOpts.filter((l) => l.indexOf(`${PREFIX} merge source`) !== -1);
                add({
                    ...check(
                        "the Combine PDFs tab lists the record's existing PDFs and they are reachable",
                        (merge.segs || []).some((s) => s.v === 'mergeOnly' && s.active) &&
                            seededSources.length === 2 &&
                            mergeList.hit === 'ok',
                        `tab active=${(merge.segs || []).some((s) => s.v === 'mergeOnly' && s.active)}, ` +
                            `source list hit=${mergeList.hit}, it offered ${mergeOpts.length} file(s) ` +
                            `of which ${seededSources.length} are the two PDFs this suite attached to the record`,
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
                add({
                    ...check(
                        'the Combine PDFs button is reachable and refuses to run with fewer than two files chosen',
                        mergeBtn.hit === 'ok' && ((merge.primary || [])[0] || {}).disabled === true,
                        `button hit=${mergeBtn.hit}, disabled=${((merge.primary || [])[0] || {}).disabled} ` +
                            `with nothing moved into the Combine list`,
                        SEVERITY.MAJOR
                    ),
                    area: runnerArea
                });
            }
        }

        /* ============================================================ *
         * 3. docGenSignatureSender ON A RECORD PAGE.
         *    Same host page. Ends in SOQL against the two objects a
         *    signature request is supposed to write.
         * ============================================================ */
        const signArea = 'Signature sender (record page)';
        try {
            const senderErrMark = consoleErrors.length;
            await clearLightningCache(page);
            await openRecord(page, base, acctId, 15000);
            const senderText = await componentText(page, 'doc-gen-signature-sender');
            const senderErrors = consoleErrors.slice(senderErrMark);
            const senderUp =
                senderText.indexOf('Select Template') !== -1 &&
                senderText.indexOf('Signers') !== -1 &&
                senderText.indexOf('Generate Signature Links') !== -1;
            add({
                ...check(
                    'docGenSignatureSender renders on a record page',
                    senderUp,
                    senderUp
                        ? `rendered ${senderText.length} chars with its template picker, signer table and send button`
                        : `component text: ${senderText.slice(0, 220) || '(nothing — is the QA host page still deployed?)'}`,
                    SEVERITY.BLOCKER
                ),
                area: signArea
            });
            add({
                ...check(
                    'docGenSignatureSender boots without a console error',
                    senderErrors.length === 0,
                    senderErrors.slice(0, 3).join(' | '),
                    SEVERITY.MAJOR
                ),
                area: signArea
            });

            if (!senderUp) {
                add(
                    skip(
                        'docGenSignatureSender validates its fields and writes the signature rows',
                        'the component did not render, so nothing could be driven',
                        SEVERITY.BLOCKER
                    )
                );
            } else {
                const signerName = `${runTag} Signer`;
                const signerEmail = `${runTag.toLowerCase()}@example.com`;

                // --- validation gate, before anything is filled in -----
                const emptyGate = await buttonState(page, 'Generate Signature Links');
                add({
                    ...check(
                        'the send button refuses to send with no document and no signer details',
                        emptyGate.found && emptyGate.disabled === true,
                        `found=${emptyGate.found} disabled=${emptyGate.disabled}`,
                        SEVERITY.MAJOR
                    ),
                    area: signArea
                });

                // --- pick a document -----------------------------------
                const cbPos = await locateComboboxShowing(page, ['Choose a DocGen template...']);
                add({
                    ...check(
                        'the signature document picker is reachable',
                        cbPos.found && cbPos.hit === 'ok',
                        `found=${cbPos.found} hit=${cbPos.hit}`,
                        SEVERITY.BLOCKER
                    ),
                    area: signArea
                });
                let picked = false;
                if (cbPos.found && cbPos.hit === 'ok') {
                    await clickAt(page, cbPos, 1500);
                    const opt = await locateByText(page, '.slds-media__body', `${PREFIX} Good PDF`);
                    add({
                        ...check(
                            'the signature document picker offers the record’s templates and they can be clicked',
                            opt.found && opt.hit === 'ok',
                            `found=${opt.found} hit=${opt.hit}`,
                            SEVERITY.BLOCKER
                        ),
                        area: signArea
                    });
                    if (opt.found && opt.hit === 'ok') {
                        await clickAt(page, opt, 6000);
                        picked = true;
                    }
                }

                if (!picked) {
                    add(
                        skip(
                            'docGenSignatureSender validates its fields and writes the signature rows',
                            'no template could be selected, so no request could be sent',
                            SEVERITY.BLOCKER
                        )
                    );
                } else {
                    const afterDoc = await buttonState(page, 'Generate Signature Links');
                    add({
                        ...check(
                            'a document alone is not enough to send — the signer is still required',
                            afterDoc.disabled === true,
                            `with a template chosen and the signer row blank, the send button is ` +
                                `disabled=${afterDoc.disabled}`,
                            SEVERITY.MAJOR
                        ),
                        area: signArea
                    });

                    // Real mouse + real keys. A dispatched keydown inserts nothing.
                    const rolePos = await locateLightningInput(page, 'Role', '0');
                    const namePos = await locateLightningInput(page, 'Name', '0');
                    const emailPos = await locateLightningInput(page, 'Email', '0');
                    const reachable = rolePos.hit === 'ok' && namePos.hit === 'ok' && emailPos.hit === 'ok';
                    add({
                        ...check(
                            'every signer field is reachable by a mouse',
                            reachable,
                            `role=${rolePos.hit} name=${namePos.hit} email=${emailPos.hit}`,
                            SEVERITY.BLOCKER
                        ),
                        area: signArea
                    });

                    if (!reachable) {
                        add(
                            skip(
                                'docGenSignatureSender writes correct signature request and signer rows',
                                'the signer fields could not be reached, so no request could be sent',
                                SEVERITY.BLOCKER
                            )
                        );
                    } else {
                        await typeInto(page, rolePos, 'Signer');
                        await typeInto(page, await locateLightningInput(page, 'Name', '0'), signerName);
                        const partial = await buttonState(page, 'Generate Signature Links');
                        add({
                            ...check(
                                'a signer with no email address cannot be sent to',
                                partial.disabled === true,
                                `role and name filled, email blank → send button disabled=${partial.disabled}`,
                                SEVERITY.MAJOR
                            ),
                            area: signArea
                        });

                        await typeInto(page, await locateLightningInput(page, 'Email', '0'), signerEmail);
                        const ready = await buttonState(page, 'Generate Signature Links');
                        add({
                            ...check(
                                'a complete document + signer enables the send button',
                                ready.disabled === false,
                                `role, name and email all filled → send button disabled=${ready.disabled}`,
                                SEVERITY.BLOCKER
                            ),
                            area: signArea
                        });

                        if (ready.disabled !== false) {
                            add(
                                skip(
                                    'docGenSignatureSender writes correct signature request and signer rows',
                                    'the send button never enabled, so no request could be sent',
                                    SEVERITY.BLOCKER
                                )
                            );
                        } else {
                            const sendPos = await locateByText(page, 'button', 'Generate Signature Links');
                            add({
                                ...check(
                                    'the send button is reachable by a mouse',
                                    sendPos.found && sendPos.hit === 'ok',
                                    `found=${sendPos.found} hit=${sendPos.hit}`,
                                    SEVERITY.BLOCKER
                                ),
                                area: signArea
                            });
                            if (sendPos.found && sendPos.hit === 'ok') {
                                await clickAt(page, sendPos, 5000);

                                // SERVER STATE — polled, because the request
                                // renders a PDF before it inserts anything.
                                const req = await waitForSignatureRequest(org, ns, goodId, 210000);
                                const signers = req
                                    ? await soql(
                                          org,
                                          `SELECT Id, ${ns}Signer_Name__c, ${ns}Signer_Email__c, ` +
                                              `${ns}Role_Name__c, ${ns}Status__c, ${ns}Sort_Order__c, ` +
                                              `${ns}Signature_Request__c FROM ${ns}DocGen_Signer__c ` +
                                              `WHERE ${ns}Signature_Request__c = '${req.Id}'`
                                      )
                                    : [];
                                const doneText = await componentText(page, 'doc-gen-signature-sender');

                                add({
                                    ...check(
                                        'sending a signature request tells the user it worked',
                                        doneText.indexOf('Signature Links Generated!') !== -1,
                                        doneText.indexOf('Error generating links') !== -1
                                            ? `the component showed: ${doneText.slice(0, 220)}`
                                            : `component text: ${doneText.slice(0, 220)}`,
                                        SEVERITY.MAJOR
                                    ),
                                    area: signArea
                                });
                                add({
                                    ...check(
                                        'sending writes a DocGen_Signature_Request__c tied to this record and template',
                                        !!req &&
                                            F(req, 'Related_Record_Id__c') === acctId &&
                                            F(req, 'Status__c') === 'Sent' &&
                                            F(req, 'Signing_Order__c') === 'Parallel' &&
                                            !!F(req, 'Source_Document_Id__c'),
                                        req
                                            ? `request ${req.Id}: record=${F(req, 'Related_Record_Id__c')} ` +
                                                  `(expected ${acctId}), status=${F(req, 'Status__c')}, ` +
                                                  `order=${F(req, 'Signing_Order__c')}, ` +
                                                  `sourceDoc=${
                                                      F(req, 'Source_Document_Id__c') ||
                                                      '(none — the signer ' + 'would have nothing to open)'
                                                  }`
                                            : `no DocGen_Signature_Request__c for template ${goodId} appeared within 210s`,
                                        SEVERITY.BLOCKER
                                    ),
                                    area: signArea
                                });
                                const s = signers[0];
                                add({
                                    ...check(
                                        'sending writes exactly one DocGen_Signer__c carrying what was typed',
                                        signers.length === 1 &&
                                            F(s, 'Signer_Name__c') === signerName &&
                                            F(s, 'Signer_Email__c') === signerEmail &&
                                            F(s, 'Role_Name__c') === 'Signer' &&
                                            F(s, 'Status__c') === 'Pending' &&
                                            Number(F(s, 'Sort_Order__c')) === 1,
                                        signers.length
                                            ? `${signers.length} signer row(s) (expected 1); first = ` +
                                                  `name "${F(s, 'Signer_Name__c')}" (typed "${signerName}"), ` +
                                                  `email "${F(s, 'Signer_Email__c')}" (typed "${signerEmail}"), ` +
                                                  `role "${F(s, 'Role_Name__c')}" (typed "Signer"), ` +
                                                  `status "${F(s, 'Status__c')}" (expected "Pending"), ` +
                                                  `sort order ${F(s, 'Sort_Order__c')} (expected 1)`
                                            : 'no DocGen_Signer__c rows were written for the request',
                                        SEVERITY.BLOCKER
                                    ),
                                    area: signArea
                                });
                            }
                        }
                    }
                }
            }
        } catch (e) {
            add(
                skip(
                    'docGenSignatureSender record-page checks',
                    `threw: ${String(e.message).slice(0, 180)}`,
                    SEVERITY.BLOCKER
                )
            );
        }

        /* ============================================================ *
         * 4. Bulk runner — the generation UI that ships with a tab.
         * ============================================================ */
        const bulkArea = 'Bulk runner';
        const bulkErrMark = consoleErrors.length;
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
        // Sliced from a mark taken just before this tab opened — the record-page
        // sections ran first in the same browser, and their console output must
        // not be attributed to this component.
        const bootErrors = consoleErrors.slice(bulkErrMark);
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
         * 6. Command Hub — the front door for everything else the
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
         * 7. What this run could NOT reach, said out loud.
         *    A skipped check is not a passing one.
         *
         *    The docGenRunner / docGenSignatureSender skips that used to
         *    live here are GONE: those components are now driven for real
         *    in sections 2 and 3 via the QA host FlexiPage. What is left
         *    is genuinely out of reach.
         * ============================================================ */
        /* ---- docGenButton: one-click generation from a record action ---- *
         * Reached through the QA_DocGen_Button quick action. A
         * lightning__RecordAction cannot sit in a FlexiPage region, so unlike
         * docGenRunner it needs a QuickActionDefinition AND a page-layout entry
         * (scripts/qa/fixtures/, applied by setup-org.sh). If these checks start
         * reporting the action as missing, re-run that — do NOT re-skip them.
         *
         * The component is entirely data-driven: three DocGen_Button__mdt
         * fixtures make an Account resolve to exactly ONE visible config, which
         * is what sends it down the run-immediately branch rather than the
         * picker. The other two exist to be filtered out, by two DIFFERENT
         * rules, so a failure can name which filter broke.
         */
        try {
            await openRecord(page, base, acctId);
            const filesBefore = await recordFileCount(org, acctId);

            // The action may be on the visible bar or under the overflow menu,
            // depending on viewport width and how many actions the layout has.
            const actionLabel = 'DocGen Button (QA)';
            let act = await locateByText(page, 'a, button', actionLabel);
            if (!act.found) {
                const more = await locateByText(page, 'button, a', 'Show more actions');
                if (more.found && more.hit === 'ok') {
                    await clickAt(page, more, 1200);
                    act = await locateByText(page, 'a, button', actionLabel);
                }
            }

            if (!act.found) {
                add(
                    check(
                        'the DocGen quick action is present on the record',
                        false,
                        `no action labelled "${actionLabel}" on the Account highlights panel — the QuickAction or ` +
                            'its layout entry did not deploy. Re-run scripts/qa/setup-org.sh.',
                        SEVERITY.MAJOR
                    )
                );
            } else {
                add(
                    check(
                        'the DocGen quick action is reachable by a mouse',
                        act.hit === 'ok',
                        act.hit === 'ok' ? 'clickable on the highlights panel' : `unreachable: ${act.hit}`,
                        SEVERITY.MAJOR
                    )
                );

                // Armed BEFORE the click: deliver() creates an anchor and clicks
                // it synchronously on the generate() response, so the download can
                // fire before an await placed after the click is even reached.
                const downloadName = page
                    .waitForEvent('download', { timeout: 180000 })
                    .then((d) => d.suggestedFilename())
                    .catch(() => null);

                await clickAt(page, act, 3000);

                // Sampled FAST and only briefly. On the happy path the component
                // generates and then closes its own action screen
                // (CloseActionScreenEvent), so it is gone in about a second — a
                // 20s poll for "the host is still present" asserts the OPPOSITE
                // of correct behaviour, and duly failed on a run where the
                // document downloaded perfectly. Its absence is therefore not
                // evidence of anything; only its ERROR state is, and that is what
                // the next check looks for.
                let shown = '';
                for (let i = 0; i < 25 && !shown.trim(); i++) {
                    shown = (await componentText(page, 'doc-gen-button')) || '';
                    if (!shown.trim()) await page.waitForTimeout(200);
                }

                // The filter rules are asserted against the SERVER, not against
                // whatever the modal happened to be showing when it was sampled.
                // Reading them off `shown` looked fine and was vacuous: the
                // component closes on success, `shown` is then empty, and "the
                // empty string does not contain 'QA Inactive'" passes without
                // testing anything at all.
                //
                // Two fixtures exist purely to be excluded, by two DIFFERENT
                // rules, so a failure names which one broke.
                const btnLog = await runAnonymous(
                    org,
                    `Id a = [SELECT Id FROM Account WHERE Id = '${acctId}' LIMIT 1].Id;
             List<DocGenButtonController.ButtonOption> opts = DocGenButtonController.getButtons(a);
             String names = '';
             for (DocGenButtonController.ButtonOption o : opts) { names += o.developerName + ';'; }
             System.debug('BTNCOUNT=' + opts.size());
             System.debug('BTNNAMES=' + names);`
                );
                const btn = debugMap(btnLog);
                const names = btn.BTNNAMES || '';
                const onlyActiveAccount = btn.BTNCOUNT === '1' && names.indexOf('QA_Account_Doc') !== -1;
                add(
                    check(
                        'a retired or wrong-object button configuration never appears',
                        onlyActiveAccount,
                        onlyActiveAccount
                            ? 'getButtons returned only QA_Account_Doc — the inactive fixture and the Contact ' +
                                  'fixture were both withheld, so the component takes its run-immediately branch'
                            : `getButtons returned ${btn.BTNCOUNT} option(s) [${names}] — expected exactly ` +
                                  'QA_Account_Doc. QA_Account_Inactive leaking means the Active__c filter broke; ' +
                                  'QA_Contact_Doc leaking means the Object_API_Name__c filter broke.',
                        // A retired configuration coming back to life still
                        // GENERATES a document, and it looks legitimate — worse
                        // than a button that is simply missing.
                        SEVERITY.BLOCKER
                    )
                );

                // STRUCTURAL, not a keyword match. A keyword list passed a
                // component that was displaying "No DocGen Template found with
                // API Name 'QA_Verify_Designer'" — plainly an error, but it
                // contains none of the words error/failed/not configured. The
                // component's own error branch is the only reliable signal: it
                // is the one that renders .slds-text-color_error.
                const errored = await ev(
                    page,
                    `
                const h = __dgFind(${JSON.stringify(host('doc-gen-button'))});
                if (!h) return null;
                const find = (root) => {
                  if (root.querySelector && root.querySelector('.slds-text-color_error')) return true;
                  for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : []))
                    if (el.shadowRoot && find(el.shadowRoot)) return true;
                  return false;
                };
                return find(h.shadowRoot || h);
              `
                );
                // errored === null means the host had already closed itself, which
                // on this component only happens AFTER a successful generate — so
                // it is a pass, and the download check below is what proves it.
                add(
                    check(
                        'pressing the record action does not error',
                        !errored,
                        errored
                            ? `component is in its error state: ${shown.trim().slice(0, 200)}`
                            : errored === null
                              ? 'the action screen had already closed itself, which it only does after a ' +
                                    'successful generate'
                              : 'no error state',
                        SEVERITY.MAJOR
                    )
                );

                const dlName = await downloadName;
                add(
                    check(
                        'the record action delivers a document to the browser',
                        !!dlName,
                        dlName
                            ? `downloaded "${dlName}"`
                            : 'no download event fired within 180s — a person pressed the button and got no file',
                        SEVERITY.BLOCKER
                    )
                );

                // Save_To_Record__c = false on the fixture, so the record's file
                // count must be UNCHANGED. Asserting the download alone would
                // pass even if the setting were being ignored.
                const filesAfter = await recordFileCount(org, acctId);
                add(
                    check(
                        'Save To Record = false leaves the record untouched',
                        filesAfter === filesBefore,
                        filesAfter === filesBefore
                            ? `${filesAfter} files before and after`
                            : `file count went ${filesBefore} -> ${filesAfter}; the configuration says download only`,
                        SEVERITY.MAJOR
                    )
                );
            }
        } catch (e) {
            add(skip('docGenButton record-action checks', `threw: ${String(e.message).slice(0, 160)}`, SEVERITY.MAJOR));
        }
        /* ---- the user who was never granted DocGen ---- *
         * Every check so far ran as a System Administrator with DocGen_Admin.
         * That is the one user whose experience is guaranteed to be fine, and it
         * hides the most common real-world first impression of the product: an
         * ordinary user who lands on a record page before anyone assigned them
         * the permission set.
         *
         * A second identity is the only way to see it — System.runAs does not
         * exist in anonymous Apex, and the component's behaviour lives in the
         * browser. So: create a Standard User with NO DocGen permission set,
         * set a password, and sign in as them in a separate browser context.
         * The original session is untouched.
         */
        let restrictedCtx = null;
        try {
            // `sf org create user` rather than Apex + the login form. Creating the
            // User in Apex and calling System.setPassword works, but the login
            // form then refuses the brand-new identity and the run lands back on
            // the login page with no session — the route simply cannot get in.
            // The CLI registers the identity as an auth alias, so a front-door
            // URL carries the session and no password is typed at all.
            //
            // The alias is per-org: two verify orgs would otherwise fight over
            // one alias and the second would silently drive the first org's user.
            const alias = `uiqa-restricted-${org}`;
            let restrictedUser = null;
            try {
                // Reuse before create — every run creating a user would exhaust a
                // scratch org's handful of Salesforce licences.
                const shown = await sf(['org', 'display', '--target-org', alias, '--json'], { retries: 0 });
                restrictedUser = JSON.parse(shown).result.username;
            } catch (e) {
                const made = await sf(
                    [
                        'org',
                        'create',
                        'user',
                        '--target-org',
                        org,
                        '--definition-file',
                        'scripts/qa/fixtures/restricted-user.json',
                        '--set-alias',
                        alias,
                        '--json'
                    ],
                    { retries: 0 }
                ).catch((err) => String(err.stdout || err.message || ''));
                try {
                    restrictedUser = JSON.parse(made).result.username;
                } catch (e2) {
                    restrictedUser = null;
                }
            }

            // Assert the premise rather than assuming it: if anything ever
            // assigns this user a DocGen permission set, the check below stops
            // measuring an unentitled user and starts passing for the wrong
            // reason.
            const rs = restrictedUser
                ? debugMap(
                      await runAnonymous(
                          org,
                          `Integer psa = [SELECT COUNT() FROM PermissionSetAssignment
                 WHERE Assignee.Username = '${restrictedUser}' AND PermissionSet.Name LIKE 'DocGen%'];
               System.debug('RDOCGENPS=' + psa);`
                      )
                  )
                : {};
            rs.RUSER = restrictedUser;

            if (!rs.RUSER) {
                add(
                    skip(
                        'a user without the DocGen permission set gets a clear message, not a broken UI',
                        'could not create or resolve the restricted user via `sf org create user` — the org may be ' +
                            'out of Salesforce licences.',
                        SEVERITY.MAJOR
                    )
                );
            } else if (rs.RDOCGENPS !== '0') {
                add(
                    skip(
                        'a user without the DocGen permission set gets a clear message, not a broken UI',
                        `the QA user already carries ${rs.RDOCGENPS} DocGen permission set(s), so this would not be ` +
                            'testing an unentitled user. Remove them and re-run.',
                        SEVERITY.MAJOR
                    )
                );
            } else {
                const r = await launch({ headed });
                restrictedCtx = r;
                // Front-door URL for the RESTRICTED alias — this is the whole
                // point of going through the CLI. It carries a session, so the
                // login form is never involved.
                const frontDoor = await orgFrontDoorUrl(alias);
                await r.page.goto(frontDoor, { waitUntil: 'domcontentloaded' });
                await r.page.waitForTimeout(6000);

                // DID THE SESSION ACTUALLY TAKE? This gate is not optional.
                // Without it a run that lands back on the Salesforce login page —
                // whose own text contains "access" and "log in" — matches the
                // leniency below and reports a cheerful PASS for a session that
                // never existed. It did exactly that on the first attempt.
                const authed = await r.page
                    .evaluate(() => !!(document.cookie && document.cookie.indexOf('sid=') !== -1))
                    .catch(() => false);
                const url = r.page.url();
                const onLoginPage = /\/login|secur\/login/i.test(url) || !authed;
                const challenged = /verify|challenge|_ui\/identity/i.test(url) || (await r.page.title()).match(/Verify/i);
                if (onLoginPage || challenged) {
                    add(
                        skip(
                            'a user without the DocGen permission set gets a clear message, not a broken UI',
                            challenged
                                ? 'the org challenged the restricted identity for verification, so the record ' +
                                      `page was never reached (landed on ${url.slice(0, 120)}).`
                                : `the restricted user's front-door URL did not establish a session — still on ` +
                                      `${url.slice(0, 120)}. Re-authorise the alias: sf org create user --target-org ` +
                                      `${org} --definition-file scripts/qa/fixtures/restricted-user.json`,
                            SEVERITY.MAJOR
                        )
                    );
                } else {
                    await r.page.goto(`${base}/lightning/r/${acctId}/view?qa=${Date.now()}`, {
                        waitUntil: 'domcontentloaded'
                    });
                    await r.page.waitForTimeout(12000);
                    const runnerText = (await componentText(r.page, 'doc-gen-runner')) || '';
                    const body = await r.page.evaluate(() => document.body.innerText || '');

                    // The bar is not "it works" — an unentitled user SHOULD be
                    // refused. The bar is that the refusal is legible: no raw
                    // exception, no bare "undefined", no blank panel where a
                    // component should be.
                    const raw =
                        /System\.|Apex|SObject|INSUFFICIENT_ACCESS|FIELD_INTEGRITY|null pointer|undefined/i.test(
                            runnerText
                        );
                    const blank = runnerText.trim().length === 0;
                    const gotSomething = /permission|access|contact your administrator|not available|no templates/i.test(
                        runnerText + ' ' + body
                    );
                    add(
                        check(
                            'a user without the DocGen permission set gets a clear message, not a broken UI',
                            !raw && (!blank || gotSomething),
                            raw
                                ? `the component showed raw platform detail to an end user: ${runnerText.trim().slice(0, 200)}`
                                : blank && !gotSomething
                                  ? 'the component rendered nothing at all — an unentitled user sees an empty ' +
                                    'panel with no explanation of why'
                                  : `handled: ${(runnerText.trim() || body.trim()).slice(0, 200)}`,
                            SEVERITY.MAJOR
                        )
                    );
                }
            }
        } catch (e) {
            add(
                skip(
                    'a user without the DocGen permission set gets a clear message, not a broken UI',
                    `threw: ${String(e.message).slice(0, 200)}`,
                    SEVERITY.MAJOR
                )
            );
        } finally {
            if (restrictedCtx) {
                await restrictedCtx.browser.close().catch(() => {});
            }
        }
        /* ---- Document Packet: actually run it, and read the result ---- *
         * The packet merge happens IN THE BROWSER — there is no packet Apex for
         * a server-side check to call (the runner's whole Apex surface is
         * generate/fetch; the combining is client-side). So the only way to
         * learn whether a packet is correct is to build one, download it, and
         * read the text off the pages.
         *
         * "It downloaded" is not the claim being made here. The claim is that
         * BOTH source documents are inside it — a merge that silently keeps only
         * the first, or writes a valid PDF containing neither, downloads exactly
         * as happily as a correct one.
         */
        try {
            await openRecord(page, base, acctId, 15000);
            const packetTab = await locateByText(page, 'a, button, span', 'Document Packet');
            if (!packetTab.found) {
                add(skip('a Document Packet contains every document it was built from', 'packet tab not found', SEVERITY.MAJOR));
            } else {
                await clickAt(page, packetTab, 2500);
                // Move the first two available templates into the packet by
                // driving the listbox the way a person does: click the option,
                // then press the move button. Re-querying the source list each
                // time matters — moving an option removes it, so the "first"
                // option is a different template on the second pass.
                const moved = await ev(
                    page,
                    `
          const lb = __dgFind('lightning-dual-listbox');
          if (!lb) return { ok: false, why: 'no dual listbox' };
          const root = lb.shadowRoot || lb;
          const names = [];
          for (let pass = 0; pass < 2; pass++) {
            const cols = root.querySelectorAll('ul[role="listbox"], ul.slds-dueling-list__options');
            if (!cols.length) return { ok: false, why: 'no listbox columns' };
            const opt = cols[0].querySelector('li[role="option"], li');
            if (!opt) return { ok: false, why: 'source column empty on pass ' + pass };
            names.push((opt.textContent || '').trim());
            opt.click();
            const btns = root.querySelectorAll('lightning-button-icon, button');
            let movedThis = false;
            for (const b of btns) {
              const t = ((b.title || '') + ' ' + (b.getAttribute('alternative-text') || '') +
                         ' ' + (b.getAttribute('icon-name') || '')).toLowerCase();
              if (t.indexOf('right') !== -1 || t.indexOf('to selected') !== -1 || t.indexOf('in packet') !== -1) {
                b.click(); movedThis = true; break;
              }
            }
            if (!movedThis) return { ok: false, why: 'no move-right control' };
          }
          return { ok: true, names };
        `
                );

                if (!moved || !moved.ok) {
                    add(
                        skip(
                            'a Document Packet contains every document it was built from',
                            `could not move templates into the packet: ${(moved && moved.why) || 'unknown'}`,
                            SEVERITY.MAJOR
                        )
                    );
                } else {
                    const dl = page
                        .waitForEvent('download', { timeout: 300000 })
                        .then((d) => d.path().then((p) => ({ name: d.suggestedFilename(), path: p })))
                        .catch(() => null);
                    const genBtn = await locateByText(page, 'button', 'Packet');
                    if (genBtn.found && genBtn.hit === 'ok') await clickAt(page, genBtn, 3000);
                    const file = await dl;

                    if (!file || !file.path) {
                        add(
                            check(
                                'building a Document Packet produces a file',
                                false,
                                `two templates were moved into the packet (${moved.names.join(', ')}) and the ` +
                                    'generate button pressed, but no download arrived within 300s',
                                SEVERITY.MAJOR
                            )
                        );
                    } else {
                        add(check('building a Document Packet produces a file', true, `downloaded "${file.name}"`, SEVERITY.MAJOR));
                        const { available: pdfOk, pdfText } = await import('../lib/pdf.mjs');
                        if (!(await pdfOk())) {
                            add(
                                skip(
                                    'a Document Packet contains every document it was built from',
                                    'pdftotext is not installed, so the merged file cannot be read',
                                    SEVERITY.MAJOR
                                )
                            );
                        } else {
                            const { readFileSync } = await import('node:fs');
                            const { pages, text, pageCount } = await pdfText(readFileSync(file.path));
                            // Each source template's title text should survive
                            // into the packet. Matching on the template NAMES
                            // taken off the listbox keeps this honest: it
                            // compares against what was actually selected, not
                            // against a hardcoded guess.
                            const found = moved.names.filter((n) => n && text.toLowerCase().includes(n.toLowerCase().slice(0, 12)));
                            add(
                                check(
                                    'a Document Packet contains every document it was built from',
                                    pageCount > 1 && found.length === moved.names.length,
                                    found.length === moved.names.length
                                        ? `${pageCount} pages, and content from all ${moved.names.length} selected documents`
                                        : `${pageCount} pages but only ${found.length} of ${moved.names.length} selected ` +
                                              `documents are present (selected: ${moved.names.join(', ')}). A merge that ` +
                                              'drops a document downloads exactly like one that does not.',
                                    SEVERITY.MAJOR
                                )
                            );
                        }
                    }
                }
            }
        } catch (e) {
            add(
                skip(
                    'a Document Packet contains every document it was built from',
                    `threw: ${String(e.message).slice(0, 200)}`,
                    SEVERITY.MAJOR
                )
            );
        }

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
        // Belt and braces. The empty-state check restores this itself; if it
        // threw between the hide and the restore, every Account template in the
        // org would still be inactive and the next suite would report a
        // catastrophe that this suite caused.
        try {
            await restoreHiddenTemplates();
        } catch (e) {
            /* nothing further can be done from here */
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
 * Waits for the signature request row the sender is supposed to write.
 *
 * Polled rather than slept on: the guided path renders a viewing PDF with
 * Blob.toPdf before it inserts anything, so how long it takes depends on the
 * template. Scoped to the seeded template so a request left behind by another
 * suite can never be mistaken for this one's.
 */
async function waitForSignatureRequest(org, ns, templateId, timeoutMs) {
    if (!templateId) return null;
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
        const rows = await soql(
            org,
            `SELECT Id, ${ns}Status__c, ${ns}Signing_Order__c, ${ns}Related_Record_Id__c, ` +
                `${ns}Template__c, ${ns}Source_Document_Id__c FROM ${ns}DocGen_Signature_Request__c ` +
                `WHERE ${ns}Template__c = '${templateId}' ORDER BY CreatedDate DESC LIMIT 1`
        );
        if (rows.length) return rows[0];
        await new Promise((r) => setTimeout(r, 5000));
    }
    return null;
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
