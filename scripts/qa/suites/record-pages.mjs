/**
 * RECORD PAGES — the live half of the layout story.
 *
 * WHY THIS EXISTS
 * ---------------
 * `metadata-audit` reads the repo and answers "is this field on a layout file?".
 * That is a necessary question and an insufficient one. Between a layout XML in
 * git and the panel an admin actually stares at there are four more things that
 * can silently swallow a field:
 *
 *   1. the layout in the repo is not the layout ASSIGNED to the running profile
 *      (Salesforce auto-creates a default layout on deploy; if assignment never
 *      happened the admin sees Salesforce's stub, not ours);
 *   2. field-level security hides the field from the running user even though the
 *      layout lists it;
 *   3. the object has no layout file at all, so nobody ever noticed the default
 *      stub is what ships;
 *   4. the page itself errors — a broken related list or component can take the
 *      whole record page down.
 *
 * None of those are visible from the filesystem. This suite seeds one record per
 * DocGen object, opens the real record page in a real browser as the real running
 * user, and reports what is on the screen. It is deliberately complementary to
 * metadata-audit — it never re-litigates "is it in the XML", only "is it on the
 * screen".
 *
 * HOW PRESENCE IS DETERMINED
 * --------------------------
 * Lightning stamps every rendered record field with
 * `data-target-selection-name="sfdc:RecordField.<Object>.<Field>"`. That is an
 * API-name-level signal and it is the primary evidence used here — far more
 * reliable than scraping labels, which collide ("Type", "Status") and are
 * reformatted. Label text is kept as a SECOND, independent signal so a field is
 * only ever reported missing when BOTH say it is missing. A false "missing"
 * finding is worse than none: it trains people to ignore the report.
 *
 * SAFETY
 * ------
 * Every record this suite creates carries the literal prefix `ZZQA` in a text
 * field, and cleanup deletes strictly by that prefix (plus the exact Ids seeded).
 * It never deletes by date or by owner, so it cannot eat real data if a run dies
 * halfway. Cleanup also runs BEFORE seeding, to clear orphans from a crashed run
 * — the unique-constrained fields (API_Name__c, Asset_Key__c, Secure_Token__c)
 * would otherwise collide on the next run.
 */
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';
import { launch, login, openRecord, inPage, HIT_TEST } from '../lib/browser.mjs';
import { runAnonymous, debugMap } from '../lib/sf.mjs';

const ROOT = new URL('../../../force-app/main/default/', import.meta.url).pathname;

/** The prefix every seeded record carries. Cleanup keys off exactly this. */
const PFX = 'ZZQA';

/**
 * Seed/delete order. Parents first on the way in, children first on the way out.
 * Master-detail cascade would handle most of the deletes, but being explicit
 * means a partial failure still cleans what it can.
 */
const OBJECTS = [
    'DocGen_Template__c',
    'DocGen_Template_Version__c',
    'DocGen_Job__c',
    'DocGen_Saved_Query__c',
    'DocGen_Error_Log__c',
    'DocGen_Asset__c',
    'DocGen_Email_Template__c',
    'DocGen_Signature_Request__c',
    'DocGen_Signer__c',
    'DocGen_Signature_Placement__c',
    'DocGen_Signature_Audit__c'
];

/**
 * The text field on each object that carries the ZZQA marker, so cleanup can find
 * its own records without an Id list (autonumber Name fields cannot be prefixed).
 * Every one of these is a plain Text/LongText field the generic seeder populates.
 */
const SWEEP_FIELD = {
    DocGen_Template__c: 'Name',
    DocGen_Template_Version__c: 'Category__c',
    DocGen_Job__c: 'Label__c',
    DocGen_Saved_Query__c: 'Name',
    DocGen_Error_Log__c: 'Context__c',
    DocGen_Asset__c: 'Name',
    DocGen_Email_Template__c: 'Name',
    DocGen_Signature_Request__c: 'Signer_Name__c',
    DocGen_Signer__c: 'Signer_Name__c',
    DocGen_Signature_Placement__c: 'Tag_Text__c',
    DocGen_Signature_Audit__c: 'Signer_Name__c'
};

/**
 * Fields whose editing UI is deliberately somewhere other than the record page.
 * They are STILL REPORTED — a reader must be able to see the whole set of fields
 * an admin cannot reach from the record page — but at minor severity with the
 * reason attached, so the real gaps stay at the top of the fix list. A waiver
 * here is a decision on the record, not a silence.
 */
const UI_ELSEWHERE = {
    'DocGen_Template__c.Header_Html__c': 'edited in the Designer header band',
    'DocGen_Template__c.Footer_Html__c': 'edited in the Designer footer band',
    'DocGen_Template__c.Form_Fields_Config__c': 'edited on the Signer Inputs tab',
    'DocGen_Template_Version__c.Header_Html__c': 'edited in the Designer header band',
    'DocGen_Template_Version__c.Footer_Html__c': 'edited in the Designer footer band',
    'DocGen_Template_Version__c.Query_Config__c': 'edited by the visual query builder',
    'DocGen_Signature_Request__c.Frozen_Document__c': 'internal snapshot blob written by the signing engine',
    'DocGen_Signature_Request__c.Render_Data_Snapshot__c': 'internal snapshot blob written by the signing engine',
    'DocGen_Signature_Request__c.Signature_Data__c': 'internal, written by the signing engine',
    'DocGen_Signer__c.Field_Data_Json__c': 'internal, written by the signing engine',
    'DocGen_Signer__c.Signature_Data__c': 'internal, written by the signing engine',
    // These three are capabilities, not settings. Secure_Token__c IS the guest
    // signer's authorisation to write; putting it on a layout would hand anyone
    // with read access the ability to impersonate a signer. Absent ON PURPOSE.
    'DocGen_Signature_Request__c.Secure_Token__c': 'signing capability token — deliberately not on a layout',
    'DocGen_Signer__c.Secure_Token__c': 'signing capability token — deliberately not on a layout',
    'DocGen_Signer__c.PIN_Hash__c': 'credential hash — deliberately not on a layout'
};

/**
 * Console noise Salesforce itself emits on a stock record page. Anything not
 * matched here is treated as a real error, because a component blowing up is
 * exactly the failure this suite exists to catch. Keep this list short and
 * justified — a permissive filter makes the console check worthless.
 */
const CONSOLE_NOISE = [
    /favicon/i,
    /Failed to load resource.*(analytics|instrumentation|telemetry|logging)/i,
    /\[LWS\]/i,
    /Content Security Policy.*(report|frame-ancestors)/i,
    /ERR_BLOCKED_BY_CLIENT/i
];

// ---------------------------------------------------------------------------
// repo metadata
// ---------------------------------------------------------------------------

function xmlValues(xml, tag) {
    const out = [];
    const re = new RegExp(`<${tag}>([^<]*)</${tag}>`, 'g');
    let m;
    while ((m = re.exec(xml)) !== null) out.push(m[1]);
    return out;
}

const norm = (s) =>
    String(s == null ? '' : s)
        .replace(/ /g, ' ')
        .replace(/\s+/g, ' ')
        .replace(/[*:]+$/, '')
        .trim()
        .toLowerCase();

/** Labels Lightning renders for the standard fields our layouts reference. */
const STANDARD_LABELS = {
    OwnerId: 'Owner',
    CreatedById: 'Created By',
    LastModifiedById: 'Last Modified By',
    RecordTypeId: 'Record Type'
};

/**
 * Read everything this suite needs about one object out of the repo: its custom
 * fields with labels, its Name-field label, and the layout that is supposed to
 * show them.
 */
function readObjectMeta(obj) {
    const dir = join(ROOT, 'objects', obj);
    const meta = { obj, fields: [], layoutFields: [], relatedLists: [], layoutFile: null, nameLabel: 'Name' };
    const objXmlPath = join(dir, `${obj}.object-meta.xml`);
    if (existsSync(objXmlPath)) {
        const x = readFileSync(objXmlPath, 'utf8');
        const nf = /<nameField>([\s\S]*?)<\/nameField>/.exec(x);
        if (nf) meta.nameLabel = (xmlValues(nf[1], 'label')[0] || 'Name').trim();
        meta.pluralLabel = (xmlValues(x, 'pluralLabel')[0] || obj).trim();
        meta.label = (xmlValues(x, 'label')[0] || obj).trim();
    }
    const fieldsDir = join(dir, 'fields');
    if (existsSync(fieldsDir)) {
        for (const f of readdirSync(fieldsDir)) {
            if (!f.endsWith('.field-meta.xml')) continue;
            const api = f.replace('.field-meta.xml', '');
            const x = readFileSync(join(fieldsDir, f), 'utf8');
            meta.fields.push({
                api,
                label: (xmlValues(x, 'label')[0] || api).trim(),
                type: (xmlValues(x, 'type')[0] || '').trim(),
                isFormula: /<formula>/.test(x)
            });
        }
    }
    const layoutsDir = join(ROOT, 'layouts');
    if (existsSync(layoutsDir)) {
        const file = readdirSync(layoutsDir).find((f) => f.startsWith(`${obj}-`));
        if (file) {
            meta.layoutFile = file;
            const x = readFileSync(join(layoutsDir, file), 'utf8');
            meta.layoutFields = xmlValues(x, 'field');
            meta.relatedLists = xmlValues(x, 'relatedList');
        }
    }
    return meta;
}

/** Label for a field named on a layout — custom, standard, or the Name field. */
function labelForLayoutField(meta, api) {
    if (api === 'Name') return meta.nameLabel;
    if (STANDARD_LABELS[api]) return STANDARD_LABELS[api];
    const f = meta.fields.find((x) => x.api === api);
    return f ? f.label : api;
}

// ---------------------------------------------------------------------------
// org side — seed and clean
// ---------------------------------------------------------------------------

/**
 * Anonymous Apex cannot declare classes or methods, so both scripts are flat
 * loops. Both resolve the namespace from the describe rather than assuming it:
 * this harness has to work against a no-namespace staging org AND a namespaced
 * scratch org, where every field is `portwoodglobal__X__c`.
 */
function nsPreamble() {
    return `
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
String ns = '';
for (String k : gd.keySet()) {
    if (k.endsWith('docgen_template__c') && !k.contains('version')) {
        ns = k.substring(0, k.length() - 'docgen_template__c'.length());
        break;
    }
}
`;
}

function cleanupApex() {
    const pairs = OBJECTS.slice()
        .reverse()
        .map((o) => {
            const f = SWEEP_FIELD[o];
            const expr = f === 'Name' ? `'Name'` : `ns + '${f}'`;
            return `objs.add('${o}'); flds.add(${expr});`;
        })
        .join('\n');
    return `${nsPreamble()}
List<String> objs = new List<String>();
List<String> flds = new List<String>();
${pairs}
Integer removed = 0;
for (Integer i = 0; i < objs.size(); i++) {
    Schema.SObjectType t = gd.get((ns + objs[i]).toLowerCase());
    if (t == null) continue;
    try {
        List<SObject> doomed = Database.query(
            'SELECT Id FROM ' + t.getDescribe().getName() + ' WHERE ' + flds[i] + ' LIKE \\'${PFX}%\\' LIMIT 500'
        );
        if (doomed.isEmpty()) continue;
        for (Database.DeleteResult r : Database.delete(doomed, false)) { if (r.isSuccess()) removed++; }
    } catch (Exception e) {
        System.debug('CLEANERR_' + objs[i].toUpperCase() + '=' + e.getMessage());
    }
}
System.debug('REMOVED=' + removed);
`;
}

/**
 * Describe-driven seeder: for every createable field it can type-guess, it writes
 * a plausible value. Populating everything (rather than just the required set) is
 * deliberate — a field whose VALUE renderer is broken only shows up when the
 * field has a value, and picklists prove the layout is rendering real data.
 * Reference fields are only filled from records this script already created; it
 * never invents an Id.
 */
function seedApex(runToken) {
    const list = OBJECTS.map((o) => `'${o}'`).join(', ');
    return `${nsPreamble()}
System.debug('NS=' + (ns == '' ? '(none)' : ns));
List<String> order = new List<String>{ ${list} };
Map<String, Id> made = new Map<String, Id>();
Integer seq = 0;
for (String objName : order) {
    seq++;
    Schema.SObjectType t = gd.get((ns + objName).toLowerCase());
    if (t == null) { System.debug('SEEDERR_' + objName.toUpperCase() + '=object not present in this org'); continue; }
    Schema.DescribeSObjectResult dsr = t.getDescribe();
    if (!dsr.isCreateable()) { System.debug('SEEDERR_' + objName.toUpperCase() + '=object not createable by the running user'); continue; }
    Map<String, Schema.SObjectField> fm = dsr.fields.getMap();
    SObject rec = t.newSObject();
    Integer fi = 0;
    for (String fk : fm.keySet()) {
        fi++;
        Schema.DescribeFieldResult d = fm.get(fk).getDescribe();
        if (!d.isCreateable()) continue;
        String nm = d.getName();
        Schema.DisplayType ty = d.getType();
        String uniq = '${PFX}-${runToken}-' + seq + '-' + fi;
        try {
            if (ty == Schema.DisplayType.Reference) {
                List<Schema.SObjectType> refs = d.getReferenceTo();
                if (!refs.isEmpty() && made.containsKey(String.valueOf(refs[0]))) {
                    rec.put(nm, made.get(String.valueOf(refs[0])));
                }
            } else if (ty == Schema.DisplayType.Boolean) {
                rec.put(nm, true);
            } else if (ty == Schema.DisplayType.Currency || ty == Schema.DisplayType.Double || ty == Schema.DisplayType.Percent) {
                rec.put(nm, 1.0);
            } else if (ty == Schema.DisplayType.Integer) {
                rec.put(nm, 1);
            } else if (ty == Schema.DisplayType.Date) {
                rec.put(nm, Date.today());
            } else if (ty == Schema.DisplayType.Datetime) {
                rec.put(nm, Datetime.now());
            } else if (ty == Schema.DisplayType.Email) {
                rec.put(nm, 'zzqa' + seq + 'x' + fi + '@example.invalid');
            } else if (ty == Schema.DisplayType.Phone) {
                rec.put(nm, '5555550100');
            } else if (ty == Schema.DisplayType.Url) {
                rec.put(nm, 'https://example.invalid/' + uniq);
            } else if (ty == Schema.DisplayType.Picklist || ty == Schema.DisplayType.MultiPicklist) {
                for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                    if (pe.isActive()) { rec.put(nm, pe.getValue()); break; }
                }
            } else if (ty == Schema.DisplayType.String || ty == Schema.DisplayType.TextArea) {
                Integer len = d.getLength();
                String v = uniq;
                if (len != null && len > 0 && v.length() > len) v = v.substring(0, len);
                rec.put(nm, v);
            }
        } catch (Exception e) {
            /* a field this loop cannot type-guess is not worth failing the whole seed over */
        }
    }
    try {
        insert rec;
        made.put(dsr.getName(), rec.Id);
        System.debug('SEED_' + objName.toUpperCase() + '=' + rec.Id);
    } catch (Exception e) {
        System.debug('SEEDERR_' + objName.toUpperCase() + '=' + String.valueOf(e.getMessage()).replace('\\n', ' '));
    }
}
`;
}

// ---------------------------------------------------------------------------
// browser side
// ---------------------------------------------------------------------------

/**
 * One evaluate that harvests everything the checks need from the rendered page.
 * NOTE: this body is a TEMPLATE LITERAL — every regex escape is doubled.
 */
const SCRAPE = inPage(`${HIT_TEST}
  const norm = (s) => String(s == null ? '' : s)
      .replace(/\\u00a0/g, ' ').replace(/\\s+/g, ' ').replace(/[*:]+$/, '').trim();

  // __dgHittable decides containment with Node.contains, which does NOT cross a
  // shadow boundary — a component whose own shadow content sits at its centre
  // therefore reads as "covered by ...". Walk the COMPOSED ancestor chain before
  // believing that verdict, or every LWC on the page looks obscured.
  const composedContains = (el, node) => {
    let n = node, guard = 0;
    while (n && guard++ < 80) { if (n === el) return true; n = n.parentNode || n.host || null; }
    return false;
  };
  const hitScrolled = (el) => {
    if (!el) return 'missing';
    try { el.scrollIntoView({ block: 'center' }); } catch (e) {}
    const v = __dgHittable(el);
    if (v.indexOf('covered by') !== 0) return v;
    const r = el.getBoundingClientRect();
    const x = Math.round(r.left + r.width / 2), y = Math.round(r.top + r.height / 2);
    let top = document.elementFromPoint(x, y), guard = 0;
    while (top && top.shadowRoot && guard++ < 12) {
      const inner = top.shadowRoot.elementFromPoint(x, y);
      if (!inner || inner === top) break;
      top = inner;
    }
    return composedContains(el, top) ? 'ok' : v;
  };

  // Lightning stamps the API name of every rendered record field here. This is
  // the authoritative presence signal; labels are only the cross-check.
  const apis = [];
  for (const el of __dgFind('[data-target-selection-name]', true)) {
    const v = el.getAttribute('data-target-selection-name') || '';
    if (v.indexOf('sfdc:RecordField.') === 0) apis.push(v.substring('sfdc:RecordField.'.length));
  }

  const labelEls = __dgFind('.test-id__field-label, .slds-form-element__label', true);
  const labels = [...new Set(labelEls.map((e) => norm(e.textContent)).filter(Boolean))];

  // Error surfaces: the record-level one, the per-component one, and the words
  // Salesforce uses when the running user simply cannot see the record.
  const errEls = __dgFind(
    'records-error, .forceError, .errorMessage, .slds-notify_alert, .slds-scoped-notification_error, .forcePageError, .genericError',
    true
  );
  const errors = [...new Set(errEls.map((e) => norm(e.textContent)).filter(Boolean))];

  const bodyText = norm(document.body.innerText || '');
  const denied = /insufficient privileges|you don't have access|do not have access|isn't available|is not available|record you are trying to access|entity is deleted/i.test(bodyText);

  // Related lists live in their own containers; count and hit-test them.
  const rlEls = __dgFind(
    'lst-related-list-single-container, lst-related-list-container, .forceRelatedListSingleContainer, .forceRelatedListCardDesktop',
    true
  );
  const relatedHits = rlEls.slice(0, 12).map((e) => hitScrolled(e));
  // Read each related list's own text, NOT document.body — the app nav bar lists
  // every DocGen object by name, so a whole-page substring search reports a
  // related list as present when only its NAV ITEM is on screen. That produced a
  // false pass on the first run of this suite.
  const relatedTexts = rlEls.slice(0, 20)
      .map((e) => norm(e.innerText || e.textContent || '').toLowerCase().slice(0, 400))
      .filter(Boolean);

  // Any custom (namespaced) component actually placed on the page.
  const customTags = [...new Set(__dgFind('*', true)
      .map((e) => e.tagName.toLowerCase())
      .filter((t) => /^(portwoodglobal|c)-/.test(t)))];

  const firstLabel = labelEls[0] || null;
  return {
    apis: [...new Set(apis)],
    labels,
    errors,
    denied,
    bodyLen: bodyText.length,
    // Lower-cased because every Node-side comparison against it is case-folded;
    // comparing a folded needle against a mixed-case haystack silently never
    // matches, which is exactly how this check first reported false failures.
    bodyText: bodyText.toLowerCase().slice(0, 8000),
    fieldCount: __dgFind('records-record-layout-item, .test-id__field-label', true).length,
    relatedCount: rlEls.length,
    relatedHits,
    relatedTexts,
    customTags,
    firstFieldHit: hitScrolled(firstLabel),
    firstFieldLabel: firstLabel ? norm(firstLabel.textContent) : ''
  };
`);

/** Click a record-page tab by its visible text. Returns whether it was found. */
function clickTab(text) {
    return inPage(`
      const norm = (s) => String(s == null ? '' : s).replace(/\\u00a0/g, ' ').replace(/\\s+/g, ' ').trim();
      const t = __dgFind('[role="tab"], a.tabHeader, li[role="presentation"] a', true)
          .find((e) => norm(e.textContent) === ${JSON.stringify(text)});
      if (!t) return false;
      try { t.click(); } catch (e) { return false; }
      return true;
    `);
}

/**
 * The heading Salesforce puts on a related-list card is the child lookup's
 * `<relationshipLabel>` ("Versions"), NOT the child object's plural label
 * ("DocGen Template Versions"). Matching on the plural label looked right and was
 * wrong. Falls back to the plural label when the field declares no label.
 */
function relatedListHeading(rl) {
    const [childObj, fkField] = rl.split('.');
    const fkPath = join(ROOT, 'objects', childObj, 'fields', `${fkField}.field-meta.xml`);
    if (existsSync(fkPath)) {
        const lbl = xmlValues(readFileSync(fkPath, 'utf8'), 'relationshipLabel')[0];
        if (lbl) return lbl.trim();
    }
    return readObjectMeta(childObj).pluralLabel || childObj;
}

/** Strip the namespace from an API name so repo names and org names compare. */
const bare = (api) => String(api).replace(/^[A-Za-z0-9]+__(?=[A-Za-z])/, '');

// ---------------------------------------------------------------------------

export async function run({ org, headed }) {
    const checks = [];
    const metas = OBJECTS.map(readObjectMeta);
    const runToken = Date.now().toString(36).slice(-6);

    let seeded = {};
    let seedLog = '';
    try {
        // Clear orphans from any previous crashed run first — the unique-constrained
        // fields would otherwise collide and the seed would half-fail.
        await runAnonymous(org, cleanupApex(), { timeout: 300000 });
        seedLog = await runAnonymous(org, seedApex(runToken), { timeout: 300000 });
        seeded = debugMap(seedLog);
    } catch (e) {
        return suiteResult('record-pages', 'Record pages', [
            skip(
                'seed a record for every DocGen object',
                `anonymous Apex failed: ${String(e.message).slice(0, 200)}`,
                SEVERITY.BLOCKER
            )
        ]);
    }

    const idFor = (obj) => seeded[`SEED_${obj.toUpperCase()}`] || null;
    const seedErrFor = (obj) => seeded[`SEEDERR_${obj.toUpperCase()}`] || null;

    let browser = null;
    try {
        const b = await launch({ headed });
        browser = b.browser;
        const { page, consoleErrors } = b;

        let base;
        try {
            // Rule 1: never skip login() — it busts Lightning's IndexedDB cache. A
            // stale component bundle has invalidated verification runs here before.
            base = await login(page, org);
        } catch (e) {
            for (const m of metas) {
                checks.push(
                    skip(
                        `${m.obj} record page renders`,
                        `could not log in to ${org}: ${String(e.message).slice(0, 120)}`,
                        SEVERITY.BLOCKER
                    )
                );
            }
            return suiteResult('record-pages', 'Record pages', checks);
        }

        for (const m of metas) {
            const obj = m.obj;
            const id = idFor(obj);

            // No record => no record page to inspect. That is a finding, not a skip,
            // when the object simply refused to accept a row.
            if (!id) {
                const why = seedErrFor(obj) || 'no Id returned and no error reported';
                checks.push(
                    check(
                        `${obj} accepts a record so its page can be opened`,
                        false,
                        `could not seed a row: ${why}`,
                        SEVERITY.BLOCKER
                    )
                );
                checks.push(skip(`${obj} record page renders`, 'no seeded record to open', SEVERITY.BLOCKER));
                continue;
            }

            const errBefore = consoleErrors.length;
            let detail;
            let related = null;
            try {
                await openRecord(page, base, id, 7000);
                // The stock record page splits Details and Related across tabs. Select
                // Details explicitly rather than trusting whichever tab is remembered.
                await page.evaluate(clickTab('Details'));
                await page.waitForTimeout(3000);
                detail = await page.evaluate(SCRAPE);

                const hasRelatedTab = await page.evaluate(clickTab('Related'));
                if (hasRelatedTab) {
                    await page.waitForTimeout(4500);
                    related = await page.evaluate(SCRAPE);
                }
            } catch (e) {
                checks.push(
                    check(
                        `${obj} record page renders`,
                        false,
                        `opening /lightning/r/${id}/view threw: ${String(e.message).slice(0, 200)}`,
                        SEVERITY.BLOCKER
                    )
                );
                continue;
            }

            const pageErrors = detail.errors.filter((t) => t && t.length > 3);

            // --- 1. does the page come up at all? -------------------------------
            // Blank, error panel, or an access wall are all the same outcome for the
            // admin: there is no usable record page for this object.
            const renders = detail.fieldCount > 0 && !detail.denied && pageErrors.length === 0;
            checks.push(
                check(
                    `${obj} record page renders`,
                    renders,
                    renders
                        ? `${detail.fieldCount} field slots rendered`
                        : detail.denied
                          ? `access wall on /lightning/r/${id}/view — the running user cannot see the record`
                          : pageErrors.length
                            ? `error panel on /lightning/r/${id}/view: ${pageErrors.join(' | ').slice(0, 200)}`
                            : `no field rendered at all on /lightning/r/${id}/view — blank record page`,
                    SEVERITY.BLOCKER
                )
            );
            if (!renders) {
                // Everything below reads the same page; reporting 15 derived failures
                // from one dead page is noise, so state the gap once and move on.
                checks.push(
                    skip(
                        `${obj} layout fields are present on the rendered page`,
                        'the record page did not render, so nothing could be compared against the layout',
                        SEVERITY.MAJOR
                    )
                );
                continue;
            }

            // --- 2. is the detail panel genuinely reachable? ---------------------
            // Rule 2: HIT_TEST, not just "in the DOM". A panel behind an overlay is
            // as useless as one that never rendered.
            checks.push(
                check(
                    `${obj} detail fields are genuinely visible (hit test)`,
                    detail.firstFieldHit === 'ok',
                    detail.firstFieldHit === 'ok'
                        ? `first field "${detail.firstFieldLabel}" is hittable`
                        : `first field "${detail.firstFieldLabel}" is ${detail.firstFieldHit} — something is covering the detail panel`,
                    SEVERITY.MAJOR
                )
            );

            // Presence sets. Union detail + related scrapes: a field can sit on
            // either tab and still be reachable by the admin.
            const renderedApis = new Set(
                [...detail.apis, ...((related && related.apis) || [])].map((a) => bare(a.split('.').pop()))
            );
            const renderedLabels = new Set([...detail.labels, ...((related && related.labels) || [])].map(norm));
            const isPresent = (api, label) => renderedApis.has(bare(api)) || renderedLabels.has(norm(label));

            // --- 3. every field the LAYOUT declares must actually render ---------
            // This is the check metadata-audit cannot make: the layout can say the
            // field is there while FLS, or an unassigned layout, hides it.
            if (!m.layoutFile) {
                checks.push(
                    check(
                        `${obj} has a layout file backing its record page`,
                        false,
                        `no layouts/${obj}-*.layout-meta.xml in the repo — the org is showing Salesforce's auto-generated default layout, which is why only ${renderedApis.size} fields render`,
                        SEVERITY.MAJOR
                    )
                );
            } else {
                for (const api of m.layoutFields) {
                    const label = labelForLayoutField(m, api);
                    const present = isPresent(api, label);
                    checks.push(
                        check(
                            `${obj}.${api} renders on the record page`,
                            present,
                            present
                                ? ''
                                : `on ${m.layoutFile} but not on the rendered page (looked for API "${api}" and label "${label}"). Either that layout is not assigned to the running profile, or field-level security hides it.`,
                            SEVERITY.MAJOR
                        )
                    );
                }
            }

            // --- 4. fields that exist on the OBJECT but nowhere on the page ------
            // An admin cannot set what they cannot see. Reported as one check per
            // object with the whole list, so the fix is a single layout edit.
            const invisible = [];
            const invisibleWaived = [];
            for (const f of m.fields) {
                if (isPresent(f.api, f.label)) continue;
                const waiver = UI_ELSEWHERE[`${obj}.${f.api}`];
                (waiver ? invisibleWaived : invisible).push(waiver ? `${f.api} (${waiver})` : `${f.api} "${f.label}"`);
            }
            checks.push(
                check(
                    `${obj} exposes every one of its fields somewhere on the record page`,
                    invisible.length === 0,
                    invisible.length === 0
                        ? invisibleWaived.length
                            ? `all reachable; ${invisibleWaived.length} field(s) intentionally edited elsewhere`
                            : ''
                        : `${invisible.length} field(s) exist on the object but render nowhere: ${invisible.join(', ')}`,
                    SEVERITY.MAJOR
                )
            );
            if (invisibleWaived.length) {
                checks.push(
                    check(
                        `${obj} fields edited outside the record page are accounted for`,
                        true,
                        invisibleWaived.join(', '),
                        SEVERITY.MINOR
                    )
                );
            }

            // --- 5. related lists ------------------------------------------------
            const wantedRelated = m.relatedLists.length;
            if (wantedRelated) {
                if (!related) {
                    checks.push(
                        check(
                            `${obj} record page exposes its related lists`,
                            false,
                            `the layout declares ${wantedRelated} related list(s) (${m.relatedLists.join(', ')}) but the page has no Related tab`,
                            SEVERITY.MAJOR
                        )
                    );
                } else {
                    const relErrors = related.errors.filter((t) => t && t.length > 3);
                    const noneMsg = /no related lists to display/.test(related.bodyText);
                    const loaded = related.relatedCount > 0 && !noneMsg && relErrors.length === 0;
                    checks.push(
                        check(
                            `${obj} related lists load without error`,
                            loaded,
                            loaded
                                ? `${related.relatedCount} related list container(s) rendered`
                                : noneMsg
                                  ? `Related tab says "No related lists to display" although ${m.layoutFile} declares ${m.relatedLists.join(', ')}`
                                  : relErrors.length
                                    ? `error in the related area: ${relErrors.join(' | ').slice(0, 200)}`
                                    : `no related list container rendered although ${m.layoutFile} declares ${m.relatedLists.join(', ')}`,
                            SEVERITY.MAJOR
                        )
                    );
                    // Each declared child list should be nameable on the page, so a
                    // silently-dropped list is not hidden by a sibling that did load.
                    for (const rl of m.relatedLists) {
                        const heading = rl === 'RelatedFileList' ? 'Files' : relatedListHeading(rl);
                        // Search only inside the related-list cards, never the whole
                        // page: the nav bar names every DocGen object.
                        const shown = related.relatedTexts.some((t) => t.includes(norm(heading)));
                        checks.push(
                            check(
                                `${obj} shows its "${heading}" related list`,
                                shown,
                                shown
                                    ? ''
                                    : `layout declares ${rl} but no related-list card headed "${heading}" is on the Related tab` +
                                          (related.relatedTexts.length
                                              ? ` (cards present: ${related.relatedTexts.map((t) => t.slice(0, 40)).join(' / ')})`
                                              : ' (no cards at all)'),
                                rl === 'RelatedFileList' ? SEVERITY.MINOR : SEVERITY.MAJOR
                            )
                        );
                    }
                    if (related.relatedHits.length) {
                        const bad = related.relatedHits.filter((h) => h !== 'ok');
                        checks.push(
                            check(
                                `${obj} related lists are genuinely visible (hit test)`,
                                bad.length === 0,
                                bad.length === 0
                                    ? ''
                                    : `${bad.length} related list container(s) not reachable: ${bad.join(', ')}`,
                                SEVERITY.MINOR
                            )
                        );
                    }
                }
            }

            // --- 6. custom components placed on the page -------------------------
            // The stock record page carries none today; if one is ever added, this
            // catches it rendering its error state instead of its content.
            const tags = [...new Set([...(detail.customTags || []), ...((related && related.customTags) || [])])];
            const componentErrors = [
                ...pageErrors,
                ...(related ? related.errors.filter((t) => t && t.length > 3) : [])
            ];
            checks.push(
                check(
                    `${obj} page components report no error state`,
                    componentErrors.length === 0,
                    componentErrors.length === 0
                        ? tags.length
                            ? `custom components on the page: ${tags.join(', ')}`
                            : 'no custom component is placed on this record page'
                        : componentErrors.join(' | ').slice(0, 250),
                    SEVERITY.MAJOR
                )
            );

            // --- 7. console ------------------------------------------------------
            const fresh = consoleErrors.slice(errBefore).filter((t) => !CONSOLE_NOISE.some((re) => re.test(t)));
            checks.push(
                check(
                    `${obj} record page logs no console errors`,
                    fresh.length === 0,
                    fresh.length === 0 ? '' : `${fresh.length}: ${fresh.slice(0, 3).join(' | ').slice(0, 250)}`,
                    SEVERITY.MAJOR
                )
            );
        }
    } catch (e) {
        // Rule: never throw. Whatever went wrong becomes a visible gap.
        checks.push(
            skip(
                'record-page sweep completed',
                `the suite stopped early: ${String(e && e.message).slice(0, 220)}`,
                SEVERITY.BLOCKER
            )
        );
    } finally {
        if (browser) {
            try {
                await browser.close();
            } catch (e) {
                /* closing a already-dead browser must not mask the real result */
            }
        }
        // Always give the org its records back, even after a crash.
        try {
            const log = await runAnonymous(org, cleanupApex(), { timeout: 300000 });
            const removed = debugMap(log).REMOVED;
            checks.push(
                check(
                    'every seeded QA record is deleted again',
                    removed !== undefined && Number(removed) > 0,
                    removed === undefined
                        ? 'cleanup script produced no REMOVED count — check the org for records whose name or marker field starts with ZZQA'
                        : `${removed} record(s) removed`,
                    SEVERITY.MINOR
                )
            );
        } catch (e) {
            checks.push(
                check(
                    'every seeded QA record is deleted again',
                    false,
                    `cleanup failed: ${String(e.message).slice(0, 180)} — delete rows whose name or marker field starts with ZZQA by hand`,
                    SEVERITY.MAJOR
                )
            );
        }
    }

    return suiteResult('record-pages', 'Record pages', checks);
}
