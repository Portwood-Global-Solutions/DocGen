/**
 * FLOW ACTIONS & CRITICAL ENDPOINTS — does the automation surface actually work?
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * Everything in here is reached by an admin, not by our own UI: a Flow author
 * drags an action onto a canvas, or an LWC calls an @AuraEnabled method. Both
 * paths sit OUTSIDE every Apex unit test, because a unit test calls the method
 * directly in the packaging org's own namespace, where visibility is not
 * enforced and where a thrown exception is just a test assertion. Neither is
 * true for a subscriber.
 *
 * Three failure modes have actually shipped in this package before, and each of
 * them is invisible to `RunLocalTests`:
 *
 *  1. NOT VISIBLE. In a managed package only `global` Apex is visible to a
 *     subscriber. A `public` @InvocableMethod compiles, passes every test, and
 *     simply never appears in the subscriber's Flow Builder. v2.6.0 and v2.7.0
 *     were both released to fix exactly this class of defect. So the static
 *     section below reads the source and asserts `global` on the class, the
 *     method, the request/response wrappers, and every @InvocableVariable.
 *
 *  2. NOT BUILDABLE. A type used as a Flow *variable* (a `List<X>` input) needs
 *     ALL FOUR of: top-level class, `global`, @AuraEnabled members, and an
 *     explicit `global` no-arg constructor. Missing any one and the action
 *     appears but its collection input cannot be populated. It took three
 *     releases to learn all four (see CLAUDE.md). DocGenSigner is the reference.
 *
 *  3. NOT SURVIVABLE. An invocable that throws instead of returning
 *     Success=false faults the whole Flow. Worse, several of these actions
 *     delegate to @AuraEnabled controller methods that raise
 *     AuraHandledException — which CANNOT be constructed outside an Aura/VF
 *     request. In a Flow that surfaces as an uncatchable
 *     `System.LimitException: Can only throw this exception type from
 *     VisualForce or Aura context`, and the action's own catch(Exception) is
 *     powerless to intercept it. The runtime section drives every action the
 *     way Flow does — List<Request> in, List<Response> out — with 2+ requests
 *     per call (Flow batches interviews) and with deliberately bad input.
 *
 * HOW THE RUNTIME PROBES WORK
 * ---------------------------
 * Anonymous Apex has no return channel, so each probe prints `KEY=value` and we
 * read it with debugMap(). One hard constraint shaped the layout of this file:
 * when anonymous Apex dies on an uncatchable exception, `sf apex run` emits NO
 * debug log at all — every line printed before the fatal is lost. So any probe
 * that might fatal gets its OWN runAnonymous() call, and its absence of output
 * (plus the error text on stderr) IS the finding. Values use `~` as a separator
 * because the debug log HTML-escapes `|` to `&#124;`.
 *
 * DATA HYGIENE
 * ------------
 * Everything created is named with the QAFLOW prefix and deleted at both the
 * start and the end of the run, so a crashed run does not poison the next one.
 */
import { runAnonymous, debugMap } from '../lib/sf.mjs';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const CLASSES = new URL('../../../force-app/main/default/classes/', import.meta.url).pathname;

/** Prefix on every record this suite creates. Cleanup keys off it. */
const P = 'QAFLOW';

/**
 * The invocable surface as it stands today. Discovery below is dynamic (so a
 * NEW action is checked automatically), but this list is asserted present so a
 * renamed or accidentally-deleted action is caught rather than silently
 * dropping out of the report.
 */
const EXPECTED_INVOCABLES = [
    'DocGenFlowAction',
    'DocGenBulkFlowAction',
    'DocGenGiantQueryFlowAction',
    'DocGenSignaturePdfFlowAction',
    'DocGenSignatureFlowAction',
    'DocGenSignatureValidator',
    'DocGenSignatureSubmitter',
    'DocGenSignatureFinalizer',
    'DocGenFieldWritebackService'
];

/** Apex primitives and collections that are NOT Apex-Defined Flow types. */
const PRIMITIVES = new Set([
    'string',
    'id',
    'integer',
    'long',
    'decimal',
    'double',
    'boolean',
    'date',
    'datetime',
    'time',
    'blob',
    'object',
    'sobject',
    'account',
    'contact'
]);

// ────────────────────────────────────────────────────────────────────────────
// Apex source scanning
//
// Regexes alone are not enough here: @InvocableMethod descriptions in this
// package contain both parentheses ("(PDF, DOCX, PPTX, XLSX)") and braces
// ("{!$Record.Id}", "{DocumentTitle}"), so a naive `\)` or brace counter walks
// off the end. These two scanners skip quoted strings and comments.
// ────────────────────────────────────────────────────────────────────────────

/**
 * Blanks every comment to spaces, preserving length and line breaks so all
 * offsets stay valid.
 *
 * This is not optional. Half the classes in this package carry a header comment
 * that says the words "@InvocableMethod" while EXPLAINING why the class is
 * global, and DocGenFlsGuard — which has no invocable at all — mentions it too.
 * Scanning raw source finds those comments, invents phantom methods, and
 * reports blocker-severity failures against text.
 */
function blankComments(src) {
    const out = src.split('');
    for (let i = 0; i < src.length; i++) {
        const ch = src[i];
        if (ch === "'") {
            i++;
            while (i < src.length && src[i] !== "'") {
                if (src[i] === '\\') i++;
                i++;
            }
            continue;
        }
        if (ch === '/' && src[i + 1] === '/') {
            while (i < src.length && src[i] !== '\n') out[i++] = ' ';
            continue;
        }
        if (ch === '/' && src[i + 1] === '*') {
            const end = src.indexOf('*/', i + 2);
            const stop = end === -1 ? src.length : end + 2;
            for (; i < stop; i++) if (src[i] !== '\n') out[i] = ' ';
            i--;
            continue;
        }
    }
    return out.join('');
}

/**
 * Returns the index just past the balanced closer that matches the opener at
 * `from`, ignoring anything inside '…' strings or // and /* comments.
 */
function matchDelimiter(src, from, open, close) {
    let depth = 0;
    for (let i = from; i < src.length; i++) {
        const ch = src[i];
        if (ch === "'") {
            i++;
            while (i < src.length && src[i] !== "'") {
                if (src[i] === '\\') i++;
                i++;
            }
            continue;
        }
        if (ch === '/' && src[i + 1] === '/') {
            while (i < src.length && src[i] !== '\n') i++;
            continue;
        }
        if (ch === '/' && src[i + 1] === '*') {
            i = src.indexOf('*/', i + 2);
            if (i === -1) return src.length;
            i++;
            continue;
        }
        if (ch === open) depth++;
        else if (ch === close) {
            depth--;
            if (depth === 0) return i + 1;
        }
    }
    return src.length;
}

/** The `{ … }` body of a named class declaration, or '' if not found. */
function classBody(src, name) {
    const re = new RegExp(`\\bclass\\s+${name}\\b`);
    const m = re.exec(src);
    if (!m) return '';
    const brace = src.indexOf('{', m.index);
    if (brace === -1) return '';
    return src.slice(brace, matchDelimiter(src, brace, '{', '}'));
}

/** The access modifier on a class declaration: global | public | private | ''. */
function classModifier(src, name) {
    const m = new RegExp(
        `\\b(global|public|private)\\s+(?:abstract\\s+|virtual\\s+)?(?:with sharing\\s+|without sharing\\s+|inherited sharing\\s+)?class\\s+${name}\\b`
    ).exec(src);
    return m ? m[1] : '';
}

/**
 * Every @InvocableMethod in a source file, with its annotation arguments and
 * the signature that follows it (comments between the two are skipped —
 * DocGenSignatureSubmitter has a CxSAST comment sitting there).
 */
function invocableMethods(src) {
    const out = [];
    let idx = 0;
    for (;;) {
        idx = src.indexOf('@InvocableMethod', idx);
        if (idx === -1) break;
        const paren = src.indexOf('(', idx);
        const nextBrace = src.indexOf('{', idx);
        let args = '';
        let after = idx + '@InvocableMethod'.length;
        // The annotation may carry no arguments at all — guard against grabbing
        // the method body's own '(' when that happens.
        if (paren !== -1 && (nextBrace === -1 || paren < nextBrace)) {
            const end = matchDelimiter(src, paren, '(', ')');
            args = src.slice(paren + 1, end - 1);
            after = end;
        }
        const bodyStart = src.indexOf('{', after);
        const sig = src
            .slice(after, bodyStart === -1 ? src.length : bodyStart)
            .replace(/\/\/[^\n]*/g, '')
            .replace(/\/\*[\s\S]*?\*\//g, '')
            .replace(/\s+/g, ' ')
            .trim();
        out.push({ args, sig, bodyStart });
        idx = after;
    }
    return out;
}

/** Reads `label='…'` / `description='…'` out of an annotation argument blob. */
function annotationValue(args, key) {
    const m = new RegExp(`${key}\\s*=\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(args || '');
    return m ? m[1] : '';
}

/** Strips single-quoted strings so brace/paren-bearing descriptions don't confuse a scan. */
function withoutStrings(src) {
    return src.replace(/'(?:[^'\\]|\\.)*'/g, "''");
}

/** Every @InvocableVariable declaration in a class body: {type, name, modifier, args}. */
function invocableVariables(body) {
    const out = [];
    let idx = 0;
    for (;;) {
        idx = body.indexOf('@InvocableVariable', idx);
        if (idx === -1) break;
        const paren = body.indexOf('(', idx);
        let after = idx + '@InvocableVariable'.length;
        let args = '';
        const semi = body.indexOf(';', idx);
        if (paren !== -1 && paren < semi) {
            const end = matchDelimiter(body, paren, '(', ')');
            args = body.slice(paren + 1, end - 1);
            after = end;
        }
        const decl = body.slice(after, body.indexOf(';', after) + 1);
        // Skip any stacked annotations (@AuraEnabled) before the declaration.
        const m = /(?:^|\s)(global|public|private)\s+([\w.<>, ]+?)\s+(\w+)\s*;/.exec(decl);
        if (m)
            out.push({
                modifier: m[1],
                type: m[2].replace(/\s+/g, ''),
                name: m[3],
                args,
                hasAura: /@AuraEnabled/.test(decl)
            });
        idx = after;
    }
    return out;
}

// ────────────────────────────────────────────────────────────────────────────
// Static checks — cheap, org-free, and the only way to catch the visibility
// defects that shipped in v2.6.0 and v2.7.0.
// ────────────────────────────────────────────────────────────────────────────

function staticChecks() {
    const checks = [];
    let files = [];
    try {
        files = readdirSync(CLASSES).filter((f) => f.endsWith('.cls'));
    } catch (e) {
        return [skip('Apex classes are readable', `cannot read ${CLASSES}: ${e.message}`, SEVERITY.BLOCKER)];
    }

    // --- discover, so a newly-added action is audited without editing this file ---
    const discovered = [];
    const sources = {};
    for (const f of files) {
        // Comment-blanked from the moment it is read — every scan below relies
        // on it, and a raw read produces phantom findings (see blankComments).
        const src = blankComments(readFileSync(join(CLASSES, f), 'utf8'));
        sources[f.replace('.cls', '')] = src;
        if (/@InvocableMethod/.test(src)) discovered.push(f.replace('.cls', ''));
    }
    for (const name of EXPECTED_INVOCABLES) {
        checks.push(
            check(
                `${name} still declares an @InvocableMethod`,
                discovered.includes(name),
                discovered.includes(name)
                    ? ''
                    : 'the action this suite expects to audit is gone — either it was renamed (update EXPECTED_INVOCABLES) or a subscriber Flow just lost its action',
                SEVERITY.BLOCKER
            )
        );
    }

    for (const name of discovered) {
        const src = sources[name];
        const mods = classModifier(src, name);

        // 1. THE v2.6.0 BUG. `public` compiles and tests green, then is invisible
        //    in every subscriber org's Flow Builder.
        checks.push(
            check(
                `${name} class is global (subscriber-visible)`,
                mods === 'global',
                mods === 'global'
                    ? ''
                    : `declared '${mods || 'no modifier'}' — only global Apex is visible to a managed-package subscriber, so this action will not appear in their Flow Builder`,
                SEVERITY.BLOCKER
            )
        );

        for (const im of invocableMethods(src)) {
            const label = annotationValue(im.args, 'label');
            const desc = annotationValue(im.args, 'description');
            const methodName = (/\b(\w+)\s*\(/.exec(im.sig) || [])[1] || '(unnamed)';
            const isGlobalStatic = /\bglobal\s+static\b/.test(im.sig);

            checks.push(
                check(
                    `${name}.${methodName} is global static`,
                    isGlobalStatic,
                    isGlobalStatic
                        ? ''
                        : `signature is '${im.sig.slice(0, 120)}' — an @InvocableMethod must be global static to be callable by a subscriber Flow`,
                    SEVERITY.BLOCKER
                )
            );

            // Flow Builder shows the label in the action picker and the
            // description in the action's help text. No label means the admin
            // sees a raw method name.
            checks.push(
                check(
                    `${name}.${methodName} has a Flow label`,
                    !!label,
                    label ? label : 'no label= on @InvocableMethod — Flow Builder falls back to the method name',
                    SEVERITY.MINOR
                )
            );
            checks.push(
                check(
                    `${name}.${methodName} has a Flow description`,
                    !!desc,
                    desc
                        ? ''
                        : 'no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs',
                    SEVERITY.MINOR
                )
            );

            // --- the request/response wrapper types must be global too ---
            const paramType = (/\(\s*List\s*<\s*([\w.]+)\s*>/.exec(im.sig) || [])[1];
            const returnType = (/\bstatic\s+(?:List\s*<\s*([\w.]+)\s*>|void)\s+\w+\s*\(/.exec(im.sig) || [])[1];
            for (const [role, t] of [
                ['request', paramType],
                ['response', returnType]
            ]) {
                if (!t) continue;
                const short = t.split('.').pop();
                const m = classModifier(src, short) || classModifier(sources[short] || '', short);
                checks.push(
                    check(
                        `${name}.${short} (${role} type) is global`,
                        m === 'global',
                        m === 'global'
                            ? ''
                            : `declared '${m || 'not found'}' — Flow cannot bind the action's ${role} fields when the wrapper class is not global`,
                        SEVERITY.BLOCKER
                    )
                );

                // --- every field the Flow author sets must itself be global ---
                const body = classBody(src, short) || classBody(sources[short] || '', short);
                const vars = invocableVariables(body);
                const notGlobal = vars.filter((v) => v.modifier !== 'global').map((v) => v.name);
                if (vars.length) {
                    checks.push(
                        check(
                            `${name}.${short}: all ${vars.length} @InvocableVariable fields are global`,
                            notGlobal.length === 0,
                            notGlobal.length
                                ? `not global: ${notGlobal.join(', ')} — invisible to a subscriber Flow`
                                : '',
                            SEVERITY.BLOCKER
                        )
                    );

                    // Only inputs need labels; outputs show up in the Flow's
                    // "Outputs" list by label too, so check both.
                    const unlabelled = vars.filter((v) => !annotationValue(v.args, 'label')).map((v) => v.name);
                    checks.push(
                        check(
                            `${name}.${short}: every input/output carries a label`,
                            unlabelled.length === 0,
                            unlabelled.length
                                ? `no label= on: ${unlabelled.join(', ')} — Flow Builder shows the raw Apex field name to the admin`
                                : '',
                            SEVERITY.MINOR
                        )
                    );

                    // --- APEX-DEFINED FLOW VARIABLE TYPES: all four rules ---
                    // A List<X> input forces the admin to create an Apex-Defined
                    // variable of type X. CLAUDE.md documents all four
                    // requirements and the three releases it took to find them.
                    for (const v of vars) {
                        const el = (/^List<([\w.]+)>$/.exec(v.type) || [])[1];
                        if (!el) continue;
                        if (PRIMITIVES.has(el.toLowerCase())) continue;
                        const short2 = el.split('.').pop();
                        const deprecated = /legacy|deprecat/i.test(
                            annotationValue(v.args, 'label') + annotationValue(v.args, 'description')
                        );
                        // A managed package can never delete a published global
                        // member, so a KNOWN-BAD input that is clearly labelled
                        // deprecated is a documentation problem, not a blocker.
                        const sev = deprecated ? SEVERITY.MINOR : SEVERITY.BLOCKER;
                        const tag = deprecated ? ' (deprecated input)' : '';

                        const standalone = !!sources[short2];
                        const typeSrc = sources[short2] || src;
                        const mod = classModifier(typeSrc, short2);
                        const b = classBody(typeSrc, short2);
                        const hasAura = /@AuraEnabled/.test(b);
                        const hasGlobalCtor = new RegExp(`global\\s+${short2}\\s*\\(\\s*\\)`).test(b);
                        const failures = [];
                        if (!standalone) failures.push('not a top-level class (Flow never lists inner classes)');
                        if (mod !== 'global') failures.push(`class is '${mod || 'unknown'}', not global`);
                        if (!hasAura) failures.push('no @AuraEnabled members');
                        if (!hasGlobalCtor)
                            failures.push(
                                'no explicit global no-arg constructor (the implicit one is public = invisible)'
                            );

                        checks.push(
                            check(
                                `${name}.${short}.${v.name}: ${short2} is a usable Apex-Defined Flow type${tag}`,
                                failures.length === 0,
                                failures.length
                                    ? `${failures.join('; ')}. All four are required — see DocGenSigner.cls for the reference implementation.`
                                    : '',
                                sev
                            )
                        );
                    }
                }
            }

            // --- SOQL/DML sitting directly inside the per-request loop ---
            // Flow hands an invocable up to 200 requests at once. A literal query
            // or DML inside `for (Request …)` multiplies straight into the
            // governor limit. Reported at MINOR because for the document
            // generators the work is genuinely per-record; the runtime probes
            // below measure the real cost.
            if (im.bodyStart !== -1) {
                const body = withoutStrings(src.slice(im.bodyStart, matchDelimiter(src, im.bodyStart, '{', '}')));
                const hits = new Set();
                // EVERY loop, not just the first: a naive `for\s*\([^)]*\)` never
                // matches `for (Integer i = 0; i < requests.size(); i++)` because
                // of the parens in the condition — which is exactly the loop
                // these actions use. Scan them all with a balanced matcher.
                for (let i = 0; (i = body.indexOf('for', i)) !== -1; i++) {
                    if (/\w/.test(body[i - 1] || '')) continue; // 'for' inside an identifier
                    const open = body.indexOf('(', i);
                    if (open === -1) break;
                    const headEnd = matchDelimiter(body, open, '(', ')');
                    const brace = body.indexOf('{', headEnd - 1);
                    if (brace === -1) continue;
                    // The loop's own iterator query (`for (X x : [SELECT …])`)
                    // lives in the header and is correctly bulkified — only the
                    // BODY counts as a query-in-a-loop.
                    const inLoop = body.slice(brace, matchDelimiter(body, brace, '{', '}'));
                    if (/\[\s*SELECT\b/i.test(inLoop)) hits.add('SOQL');
                    if (/\b(insert|update|upsert|delete)\s+[\w(]/i.test(inLoop)) hits.add('DML');
                }
                checks.push(
                    check(
                        `${name}.${methodName} has no literal SOQL/DML inside the per-request loop`,
                        hits.size === 0,
                        hits.size
                            ? `${[...hits].join(' + ')} inside a loop body — Flow can hand this action up to 200 requests in one transaction`
                            : '',
                        SEVERITY.MINOR
                    )
                );
            }
        }
    }
    return checks;
}

// ────────────────────────────────────────────────────────────────────────────
// Runtime probes
// ────────────────────────────────────────────────────────────────────────────

/** The debug log HTML-escapes a handful of characters. Put them back. */
function unesc(s) {
    return String(s == null ? '' : s)
        .replace(/&#124;/g, '|')
        .replace(/&quot;/g, '"')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&');
}

/** The org's account of why a block did not finish. */
function fatalOf(log) {
    const s = String(log || '');
    const m =
        /(System\.[A-Za-z]*Exception:[^\n]*)/.exec(s) ||
        /(Compile error[^\n]*)/i.exec(s) ||
        /(executeCompileFailure[^\n]*)/i.exec(s) ||
        /(Execution failed at this code[^\n]*)/i.exec(s);
    return m ? m[1].trim().slice(0, 240) : '';
}

/**
 * Runs one anonymous-Apex block and returns whatever it managed to print.
 *
 * `retries: 0` matters: a probe we EXPECT to fatal would otherwise be run twice
 * with a 3s sleep between, tripling the suite's wall time.
 */
async function probe(org, apex) {
    try {
        const log = await runAnonymous(org, apex, { retries: 0, timeout: 600000 });
        return { map: debugMap(log), fatal: fatalOf(log) };
    } catch (e) {
        const log = `${e.stdout || ''}\n${e.stderr || ''}\n${e.message || ''}`;
        return {
            map: debugMap(log),
            fatal: fatalOf(log) || 'the anonymous Apex block did not complete and printed no log'
        };
    }
}

/**
 * Turns a probe result into a check. A key that never arrived means the block
 * died before printing it — which is itself the evidence, not a reason to skip.
 */
function fromKey(name, res, key, predicate, detail, severity) {
    if (res.map[key] === undefined) {
        return check(
            name,
            false,
            `the action did not return — anonymous Apex died before it could report. ${res.fatal || 'no error text was captured'}`,
            severity
        );
    }
    const v = unesc(res.map[key]);
    let ok = false;
    try {
        ok = !!predicate(v.split('~'), v);
    } catch (e) {
        ok = false;
    }
    return check(name, ok, ok ? (typeof detail === 'function' ? detail(v) : '') : `got: ${v.slice(0, 220)}`, severity);
}

const SETUP = `
// QAFLOW fixtures. Idempotent: a crashed previous run is cleaned first.
try {
    Set<Id> oldT = new Map<Id, DocGen_Template__c>([SELECT Id FROM DocGen_Template__c WHERE Name LIKE '${P}%']).keySet();
    if (!oldT.isEmpty()) {
        delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :oldT];
        delete [SELECT Id FROM DocGen_Template__c WHERE Id IN :oldT];
    }
    delete [SELECT Id FROM Contact WHERE LastName LIKE '${P}%'];
    delete [SELECT Id FROM Account WHERE Name LIKE '${P}%'];
} catch (Exception e) {
    System.debug('PRECLEAN=' + e.getMessage());
}

Account a = new Account(Name = '${P} Corp', Industry = 'Technology', BillingCity = 'Indianapolis', BillingState = 'IN');
insert a;
System.debug('ACCT_ID=' + a.Id);
insert new Contact(FirstName = 'Quinn', LastName = '${P}', Email = 'quinn@qaflow.example.com', AccountId = a.Id);

ContentVersion cv = new ContentVersion(Title = '${P} body', PathOnClient = 'qaflow.html',
    VersionData = Blob.valueOf('<html><body><h1>${P}</h1><p>Hello {Name} of {BillingCity}, {BillingState}.</p></body></html>'));
insert cv;
Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

ContentVersion cv2 = new ContentVersion(Title = '${P} sig body', PathOnClient = 'qaflowsig.html',
    VersionData = Blob.valueOf('<html><body><h1>${P} Waiver</h1><p>I, {Name}, agree.</p>' +
        '<table><tr><td>{@Signature_Signer:1:Full}</td><td>{@Signature_Signer:2:Date}</td></tr></table></body></html>'));
insert cv2;
Id cv2Id = [SELECT Id FROM ContentVersion WHERE Id = :cv2.Id].Id;

DocGen_Template__c t = new DocGen_Template__c(Name = '${P} Template', API_Name__c = '${P}_TPL', Type__c = 'HTML',
    Base_Object_API__c = 'Account', Query_Config__c = 'Name, Industry, BillingCity, BillingState', Output_Format__c = 'PDF');
insert t;
insert new DocGen_Template_Version__c(Template__c = t.Id, Is_Active__c = true, Content_Version_Id__c = cvId);
System.debug('TPL_ID=' + t.Id);

// A template whose only version is INACTIVE — the "template exists but has
// nothing to render" case an admin hits after unpublishing a draft.
DocGen_Template__c t2 = new DocGen_Template__c(Name = '${P} NoActiveVersion', Type__c = 'HTML',
    Base_Object_API__c = 'Account', Query_Config__c = 'Name', Output_Format__c = 'PDF');
insert t2;
insert new DocGen_Template_Version__c(Template__c = t2.Id, Is_Active__c = false, Content_Version_Id__c = cvId);
System.debug('TPL_NOACTIVE_ID=' + t2.Id);

DocGen_Template__c t3 = new DocGen_Template__c(Name = '${P} Signature Template', Type__c = 'HTML',
    Base_Object_API__c = 'Account', Query_Config__c = 'Name', Output_Format__c = 'PDF');
insert t3;
insert new DocGen_Template_Version__c(Template__c = t3.Id, Is_Active__c = true, Content_Version_Id__c = cv2Id);
System.debug('SIGTPL_ID=' + t3.Id);
System.debug('SETUP_OK=1');
`;

const CLEANUP = `
Integer removed = 0;
try {
    Set<Id> tplIds = new Map<Id, DocGen_Template__c>([SELECT Id FROM DocGen_Template__c WHERE Name LIKE '${P}%']).keySet();
    Set<Id> acctIds = new Map<Id, Account>([SELECT Id FROM Account WHERE Name LIKE '${P}%']).keySet();
    List<String> acctStrs = new List<String>();
    for (Id x : acctIds) { acctStrs.add(String.valueOf(x)); }

    Set<Id> reqIds = new Set<Id>();
    for (DocGen_Signature_Request__c r : [SELECT Id FROM DocGen_Signature_Request__c
            WHERE Template__c IN :tplIds OR Related_Record_Id__c IN :acctStrs]) { reqIds.add(r.Id); }
    if (!reqIds.isEmpty()) {
        delete [SELECT Id FROM DocGen_Signature_Audit__c WHERE Signature_Request__c IN :reqIds];
        delete [SELECT Id FROM DocGen_Signature_Placement__c WHERE Signature_Request__c IN :reqIds];
        delete [SELECT Id FROM DocGen_Signer__c WHERE Signature_Request__c IN :reqIds];
        List<DocGen_Signature_Request__c> rq = [SELECT Id FROM DocGen_Signature_Request__c WHERE Id IN :reqIds];
        removed += rq.size(); delete rq;
    }
    List<DocGen_Job__c> jobs = [SELECT Id FROM DocGen_Job__c WHERE Label__c LIKE '${P}%' OR Template__c IN :tplIds];
    removed += jobs.size(); delete jobs;

    // Files this run generated: by title, plus anything linked to the fixture account.
    Set<Id> docIds = new Set<Id>();
    for (ContentDocument d : [SELECT Id FROM ContentDocument WHERE Title LIKE '${P}%']) { docIds.add(d.Id); }
    for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :acctIds]) {
        docIds.add(l.ContentDocumentId);
    }
    if (!docIds.isEmpty()) {
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        removed += docs.size(); delete docs;
    }
    if (!tplIds.isEmpty()) {
        delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :tplIds];
        List<DocGen_Template__c> t = [SELECT Id FROM DocGen_Template__c WHERE Id IN :tplIds];
        removed += t.size(); delete t;
    }
    delete [SELECT Id FROM Contact WHERE LastName LIKE '${P}%'];
    List<Account> ac = [SELECT Id FROM Account WHERE Id IN :acctIds];
    removed += ac.size(); delete ac;
    System.debug('CLEAN_OK=' + removed);
} catch (Exception e) {
    System.debug('CLEAN_ERR=' + e.getMessage());
}
`;

/**
 * The bulk action queues real batch jobs. We stop them so the org is not left
 * churning — but a blanket "abort every queued BatchApex job" would kill work
 * belonging to another suite running against the same org (this harness is
 * routinely pointed at a shared verify org). Snapshot first, abort only the
 * delta.
 */
const ABORT_SNAPSHOT = `
Set<Id> preExisting = new Set<Id>();
for (AsyncApexJob j : [SELECT Id FROM AsyncApexJob
        WHERE JobType = 'BatchApex' AND Status IN ('Holding','Queued','Preparing') LIMIT 200]) {
    preExisting.add(j.Id);
}`;

const ABORT_NEW = `
Integer aborted = 0;
for (AsyncApexJob j : [SELECT Id FROM AsyncApexJob
        WHERE JobType = 'BatchApex' AND Status IN ('Holding','Queued','Preparing') LIMIT 200]) {
    if (preExisting.contains(j.Id)) { continue; }
    try { System.abortJob(j.Id); aborted++; } catch (Exception e) {}
}
System.debug('ABORTED=' + aborted);`;

export async function run({ org }) {
    const checks = [];

    // The static half needs no org and must always run — it is the only cover
    // for the managed-package visibility rules.
    try {
        checks.push(...staticChecks());
    } catch (e) {
        checks.push(
            skip('Apex source audit', `static scan failed: ${String(e.message).slice(0, 200)}`, SEVERITY.BLOCKER)
        );
    }

    if (!org) {
        checks.push(skip('Flow actions run against an org', 'no --org supplied', SEVERITY.BLOCKER));
        return suiteResult('flow-actions', 'Flow actions & endpoints', checks);
    }

    let ids = {};
    try {
        const setup = await probe(org, SETUP);
        if (setup.map.SETUP_OK !== '1') {
            checks.push(
                skip(
                    'Flow-action fixtures could be created',
                    `setup did not finish — every runtime check below is unevaluated. ${setup.fatal || 'no error captured'}`,
                    SEVERITY.BLOCKER
                )
            );
            return suiteResult('flow-actions', 'Flow actions & endpoints', checks);
        }
        ids = setup.map;

        for (const fn of [
            probeGenerateDocument,
            probeGiantQuery,
            probeBulk,
            probeSignatureRequest,
            probeSignaturePdfAction,
            probeTokenActions,
            probeWriteback,
            probeAuraEndpoints
        ]) {
            try {
                checks.push(...(await fn(org, ids)));
            } catch (e) {
                checks.push(
                    skip(`${fn.name} probes`, `probe crashed: ${String(e.message).slice(0, 200)}`, SEVERITY.MAJOR)
                );
            }
        }
    } catch (e) {
        checks.push(
            skip(
                'Flow-action runtime probes',
                `unexpected harness error: ${String(e.message).slice(0, 200)}`,
                SEVERITY.BLOCKER
            )
        );
    } finally {
        // Always tidy up, even after a crash, so the next run starts green.
        try {
            const c = await probe(org, CLEANUP);
            checks.push(
                check(
                    'Test fixtures were cleaned up',
                    c.map.CLEAN_OK !== undefined,
                    c.map.CLEAN_OK !== undefined
                        ? `${c.map.CLEAN_OK} records removed`
                        : `cleanup did not complete — QAFLOW records may be left in ${org}. ${c.map.CLEAN_ERR || c.fatal}`,
                    SEVERITY.MINOR
                )
            );
        } catch (e) {
            checks.push(skip('Test fixtures were cleaned up', String(e.message).slice(0, 200), SEVERITY.MINOR));
        }
    }

    return suiteResult('flow-actions', 'Flow actions & endpoints', checks);
}

// ── DocGenFlowAction ────────────────────────────────────────────────────────
// The single most-used action in the package. Two requests go in one call
// because a record-triggered Flow on 2 records hands the action both at once —
// if the second is poisoned by the first, every bulk Flow silently misfires.
async function probeGenerateDocument(org, ids) {
    const out = [];
    const A = 'Generate Document';

    const happy = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id tplId = '${ids.TPL_ID}';
DocGenFlowAction.Request r1 = new DocGenFlowAction.Request();
r1.templateId = tplId; r1.recordId = acctId; r1.documentTitle = '${P} Doc A';
// Addressed by API Name, the sandbox-to-production-safe key a Flow should use.
DocGenFlowAction.Request r2 = new DocGenFlowAction.Request();
r2.templateApiName = '${P}_TPL'; r2.recordId = acctId; r2.documentTitle = '${P} Doc B';
Integer q0 = Limits.getQueries();
List<DocGenFlowAction.Response> res = DocGenFlowAction.generateDocument(new List<DocGenFlowAction.Request>{ r1, r2 });
System.debug('COUNT=' + res.size());
System.debug('A=' + res[0].success + '~' + res[0].contentDocumentId + '~' + res[0].contentVersionId + '~' + res[0].errorMessage);
System.debug('B=' + res[1].success + '~' + res[1].contentDocumentId + '~' + res[1].contentVersionId + '~' + res[1].errorMessage);
System.debug('DISTINCT=' + (res[0].contentDocumentId != res[1].contentDocumentId));
System.debug('QPERREQ=' + ((Limits.getQueries() - q0) / 2));
Integer linked = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :acctId AND ContentDocumentId = :res[0].contentDocumentId];
System.debug('NOATTACH=' + linked);
`
    );

    out.push(
        fromKey(
            `${A}: returns one response per request (Flow batches)`,
            happy,
            'COUNT',
            ([v]) => v === '2',
            '',
            SEVERITY.BLOCKER
        )
    );
    // A response that says success but hands back no file is the worst outcome:
    // the Flow continues and the downstream Send Email attaches nothing.
    out.push(
        fromKey(
            `${A}: request 1 (by Template Id) returns a file`,
            happy,
            'A',
            ([ok, doc, ver]) => ok === 'true' && /^069/.test(doc) && /^068/.test(ver),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: request 2 (by Template API Name) returns a file`,
            happy,
            'B',
            ([ok, doc, ver]) => ok === 'true' && /^069/.test(doc) && /^068/.test(ver),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: the two requests produce two different documents`,
            happy,
            'DISTINCT',
            ([v]) => v === 'true',
            '',
            SEVERITY.BLOCKER
        )
    );
    // Issue #90: leaving Save to Record off must not put the file on the record.
    out.push(
        fromKey(
            `${A}: Save to Record = false leaves the record's Files untouched (#90)`,
            happy,
            'NOATTACH',
            ([v]) => v === '0',
            '',
            SEVERITY.MAJOR
        )
    );
    out.push(bulkCostCheck(A, happy, 10, SEVERITY.MINOR));

    // --- edge cases, all in ONE call: Flow does not sort the good from the bad ---
    const edges = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id tplId = '${ids.TPL_ID}';
DocGenFlowAction.Request e1 = new DocGenFlowAction.Request(); e1.recordId = acctId;
DocGenFlowAction.Request e2 = new DocGenFlowAction.Request(); e2.templateId = tplId;
DocGenFlowAction.Request e3 = new DocGenFlowAction.Request(); e3.templateId = tplId; e3.recordId = '001000000000000AAA';
DocGenFlowAction.Request e4 = new DocGenFlowAction.Request(); e4.templateId = 'a0B000000000000AAA'; e4.recordId = acctId;
DocGenFlowAction.Request e5 = new DocGenFlowAction.Request(); e5.templateId = '${ids.TPL_NOACTIVE_ID}'; e5.recordId = acctId;
DocGenFlowAction.Request e6 = new DocGenFlowAction.Request(); e6.templateId = tplId; e6.recordId = acctId; e6.jsonData = '[1,2]';
DocGenFlowAction.Request e7 = new DocGenFlowAction.Request(); e7.templateApiName = 'NO_SUCH_TEMPLATE_API_NAME'; e7.recordId = acctId;
List<DocGenFlowAction.Response> er = DocGenFlowAction.generateDocument(
    new List<DocGenFlowAction.Request>{ e1, e2, e3, e4, e5, e6, e7 });
System.debug('EDGE1=' + er[0].success + '~' + er[0].errorMessage);
System.debug('EDGE2=' + er[1].success + '~' + er[1].errorMessage);
System.debug('EDGE3=' + er[2].success + '~' + er[2].errorMessage);
System.debug('EDGE4=' + er[3].success + '~' + er[3].errorMessage);
System.debug('EDGE5=' + er[4].success + '~' + er[4].errorMessage);
System.debug('EDGE6=' + er[5].success + '~' + er[5].errorMessage);
System.debug('EDGE7=' + er[6].success + '~' + er[6].errorMessage);
`
    );
    const cases = [
        ['no Template Id and no Template API Name', 'EDGE1', /template/i],
        ['a template but no Record Id and no JSON Data', 'EDGE2', /record id|json/i],
        ['a Record Id that does not exist', 'EDGE3', /record|not found/i],
        ['a Template Id that does not exist', 'EDGE4', /template|access/i],
        ['a template whose only version is inactive', 'EDGE5', /template file|active/i],
        ['JSON Data that is an array, not an object', 'EDGE6', /json/i],
        ['a Template API Name that matches nothing', 'EDGE7', /api name/i]
    ];
    for (const [label, key, wants] of cases) {
        out.push(
            fromKey(
                `${A}: ${label} → graceful failure with a useful message`,
                edges,
                key,
                (parts, raw) => parts[0] === 'false' && wants.test(raw),
                '',
                SEVERITY.BLOCKER
            )
        );
    }
    return out;
}

// ── DocGenGiantQueryFlowAction ──────────────────────────────────────────────
async function probeGiantQuery(org, ids) {
    const out = [];
    const A = 'Generate Document (Auto Giant Query)';
    const r = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id tplId = '${ids.TPL_ID}';
DocGenGiantQueryFlowAction.Request g1 = new DocGenGiantQueryFlowAction.Request();
g1.templateId = tplId; g1.recordId = acctId;
DocGenGiantQueryFlowAction.Request g2 = new DocGenGiantQueryFlowAction.Request();
g2.templateId = tplId; g2.recordId = acctId; g2.saveToRecord = true;
Integer q0 = Limits.getQueries();
List<DocGenGiantQueryFlowAction.Response> gr = DocGenGiantQueryFlowAction.generateDocument(
    new List<DocGenGiantQueryFlowAction.Request>{ g1, g2 });
System.debug('COUNT=' + gr.size());
System.debug('A=' + gr[0].success + '~' + gr[0].isGiantQuery + '~' + gr[0].contentDocumentId + '~' + gr[0].contentVersionId + '~' + gr[0].errorMessage);
System.debug('QPERREQ=' + ((Limits.getQueries() - q0) / 2));
Integer linked = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :acctId AND ContentDocumentId = :gr[1].contentDocumentId];
System.debug('ATTACHED=' + linked);
DocGenGiantQueryFlowAction.Request x1 = new DocGenGiantQueryFlowAction.Request(); x1.recordId = acctId;
DocGenGiantQueryFlowAction.Request x2 = new DocGenGiantQueryFlowAction.Request(); x2.templateId = tplId;
DocGenGiantQueryFlowAction.Request x3 = new DocGenGiantQueryFlowAction.Request(); x3.templateId = 'a0B000000000000AAA'; x3.recordId = acctId;
List<DocGenGiantQueryFlowAction.Response> xr = DocGenGiantQueryFlowAction.generateDocument(
    new List<DocGenGiantQueryFlowAction.Request>{ x1, x2, x3 });
System.debug('EDGE1=' + xr[0].success + '~' + xr[0].errorMessage);
System.debug('EDGE2=' + xr[1].success + '~' + xr[1].errorMessage);
System.debug('EDGE3=' + xr[2].success + '~' + xr[2].errorMessage);
`
    );
    out.push(fromKey(`${A}: returns one response per request`, r, 'COUNT', ([v]) => v === '2', '', SEVERITY.BLOCKER));
    // Under the 2,000-row threshold this MUST take the synchronous path and
    // hand back a real file; an isGiantQuery=true here would mean the Flow gets
    // a Job Id and no document for a dataset that needed neither.
    out.push(
        fromKey(
            `${A}: a small dataset renders synchronously and returns a file`,
            r,
            'A',
            ([ok, giant, doc, ver]) => ok === 'true' && giant === 'false' && /^069/.test(doc) && /^068/.test(ver),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: Save to Record = true does attach the file`,
            r,
            'ATTACHED',
            ([v]) => v === '1',
            '',
            SEVERITY.MAJOR
        )
    );
    out.push(bulkCostCheck(A, r, 10, SEVERITY.MINOR));
    for (const [label, key, wants] of [
        ['a null Template Id', 'EDGE1', /template|access/i],
        ['a null Record Id', 'EDGE2', /record|parameters|retriev/i],
        ['a Template Id that does not exist', 'EDGE3', /template|access/i]
    ]) {
        out.push(
            fromKey(
                `${A}: ${label} → graceful failure with a useful message`,
                r,
                key,
                (parts, raw) => parts[0] === 'false' && wants.test(raw),
                '',
                SEVERITY.BLOCKER
            )
        );
    }
    return out;
}

// ── DocGenBulkFlowAction ────────────────────────────────────────────────────
// Split into three blocks on purpose: the null-Template-Id case raises an
// UNCATCHABLE exception, which kills its whole anonymous-Apex block and takes
// every line printed before it down with it.
async function probeBulk(org, ids) {
    const out = [];
    const A = 'Generate Bulk Documents';

    const happy = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id tplId = '${ids.TPL_ID}';
${ABORT_SNAPSHOT}
DocGenBulkFlowAction.Request b1 = new DocGenBulkFlowAction.Request();
b1.templateId = tplId; b1.jobLabel = '${P} Job A'; b1.recordIds = new List<String>{ String.valueOf(acctId) };
DocGenBulkFlowAction.Request b2 = new DocGenBulkFlowAction.Request();
b2.templateId = tplId; b2.jobLabel = '${P} Job B'; b2.queryCondition = 'Name = \\'${P} Corp\\'';
List<DocGenBulkFlowAction.Response> br = DocGenBulkFlowAction.generateBulkDocuments(
    new List<DocGenBulkFlowAction.Request>{ b1, b2 });
System.debug('COUNT=' + br.size());
System.debug('A=' + br[0].success + '~' + br[0].jobId + '~' + br[0].errorMessage);
System.debug('B=' + br[1].success + '~' + br[1].jobId + '~' + br[1].errorMessage);
System.debug('DISTINCT=' + (br[0].jobId != br[1].jobId));
${ABORT_NEW}
`
    );
    out.push(
        fromKey(`${A}: returns one response per request`, happy, 'COUNT', ([v]) => v === '2', '', SEVERITY.BLOCKER)
    );
    out.push(
        fromKey(
            `${A}: request 1 (explicit Record Ids) queues a job`,
            happy,
            'A',
            ([ok, job]) => ok === 'true' && /^a0/.test(job),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: request 2 (WHERE condition) queues a job`,
            happy,
            'B',
            ([ok, job]) => ok === 'true' && /^a0/.test(job),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: the two requests queue two different jobs`,
            happy,
            'DISTINCT',
            ([v]) => v === 'true',
            '',
            SEVERITY.BLOCKER
        )
    );

    // Injection guard: a Flow variable holding user text must not reach SOQL.
    const guard = await probe(
        org,
        `
${ABORT_SNAPSHOT}
DocGenBulkFlowAction.Request y = new DocGenBulkFlowAction.Request();
y.templateId = '${ids.TPL_ID}'; y.jobLabel = '${P} Job Inj';
y.recordIds = new List<String>{ 'not-a-salesforce-id' };
DocGenBulkFlowAction.Request z = new DocGenBulkFlowAction.Request();
z.templateId = '${ids.TPL_ID}'; z.jobLabel = '${P} Job Bad'; z.queryCondition = 'Bogus__c = 1';
List<DocGenBulkFlowAction.Response> r = DocGenBulkFlowAction.generateBulkDocuments(
    new List<DocGenBulkFlowAction.Request>{ y, z });
System.debug('INJ=' + r[0].success + '~' + r[0].errorMessage);
System.debug('BADWHERE=' + r[1].success + '~' + r[1].errorMessage);
${ABORT_NEW}
`
    );
    out.push(
        fromKey(
            `${A}: a malformed Record Id is rejected, not concatenated into SOQL`,
            guard,
            'INJ',
            (parts, raw) => parts[0] === 'false' && /invalid record id/i.test(raw),
            '',
            SEVERITY.BLOCKER
        )
    );
    // Not fatal — the batch reports the failure in Job History — but the Flow
    // author is told the job started when it cannot possibly run.
    out.push(
        fromKey(
            `${A}: a WHERE condition that cannot compile is reported to the Flow`,
            guard,
            'BADWHERE',
            ([ok]) => ok === 'false',
            '',
            SEVERITY.MINOR
        )
    );

    // OWN BLOCK: this is the one that dies.
    const nullTpl = await probe(
        org,
        `
DocGenBulkFlowAction.Request y = new DocGenBulkFlowAction.Request();
y.jobLabel = '${P} Job NullTemplate';
List<DocGenBulkFlowAction.Response> r = DocGenBulkFlowAction.generateBulkDocuments(
    new List<DocGenBulkFlowAction.Request>{ y });
System.debug('NULLTPL=' + r[0].success + '~' + r[0].errorMessage);
`
    );
    out.push(
        auraLeakCheck(
            `${A}: a null Template Id → graceful failure, not an unhandled Flow fault`,
            nullTpl,
            'NULLTPL',
            (parts) => parts[0] === 'false',
            "DocGenBulkController.submitJob wraps every failure in DocGenService.ahe() (an AuraHandledException). Outside an Aura/VF request that constructor itself throws, so the action's own catch(Exception) cannot intercept it and the Flow faults with a message that never mentions the missing Template Id."
        )
    );
    return out;
}

// ── DocGenSignatureFlowAction ("DocGen: Create Signature Request") ──────────
async function probeSignatureRequest(org, ids) {
    const out = [];
    const A = 'Create Signature Request';

    const happy = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id sigTpl = '${ids.SIGTPL_ID}';
DocGenSigner s1 = new DocGenSigner(); s1.name = '${P} Signer One'; s1.email = 'qaflow.one@example.com'; s1.role = 'Signer';
DocGenSigner s2 = new DocGenSigner(); s2.name = '${P} Signer Two'; s2.email = 'qaflow.two@example.com';
DocGenSignatureFlowAction.Request a = new DocGenSignatureFlowAction.Request();
a.templateId = sigTpl; a.relatedRecordId = acctId; a.signerRecords = new List<DocGenSigner>{ s1 };
a.sendEmails = false; a.signingOrder = 'Single';
DocGenSignatureFlowAction.Request b = new DocGenSignatureFlowAction.Request();
b.templateId = sigTpl; b.relatedRecordId = acctId; b.signerRecords = new List<DocGenSigner>{ s2 };
b.sendEmails = false; b.signingOrder = 'Single';
List<DocGenSignatureFlowAction.Result> rr = DocGenSignatureFlowAction.generate(
    new List<DocGenSignatureFlowAction.Request>{ a, b });
System.debug('COUNT=' + rr.size());
System.debug('A=' + rr[0].success + '~' + rr[0].signatureRequestId + '~' + (rr[0].signerUrls == null ? 0 : rr[0].signerUrls.size()) + '~' + rr[0].errorMessage);
System.debug('B=' + rr[1].success + '~' + rr[1].signatureRequestId + '~' + rr[1].errorMessage);
System.debug('DISTINCT=' + (rr[0].signatureRequestId != rr[1].signatureRequestId));
System.debug('URL=' + (rr[0].signerUrls != null && !rr[0].signerUrls.isEmpty() ? rr[0].signerUrls[0] : 'NONE'));
System.debug('ECHO=' + rr[0].signerNames[0] + '~' + rr[0].signerEmails[0] + '~' + rr[0].signerRoles[0]);
List<DocGen_Signer__c> made = [SELECT Secure_Token__c FROM DocGen_Signer__c WHERE Signature_Request__c = :rr[0].signatureRequestId];
System.debug('SIGNERS=' + made.size());
if (!made.isEmpty()) { System.debug('TOKEN=' + made[0].Secure_Token__c); }
`
    );
    out.push(fromKey(`${A}: returns one result per request`, happy, 'COUNT', ([v]) => v === '2', '', SEVERITY.BLOCKER));
    out.push(
        fromKey(
            `${A}: request 1 creates a request and one signing URL`,
            happy,
            'A',
            ([ok, reqId, urls]) => ok === 'true' && /^a0/.test(reqId) && urls === '1',
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: request 2 also succeeds (not poisoned by request 1)`,
            happy,
            'B',
            ([ok, reqId]) => ok === 'true' && /^a0/.test(reqId),
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: the two requests are distinct records`,
            happy,
            'DISTINCT',
            ([v]) => v === 'true',
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: a DocGen_Signer__c row is actually written`,
            happy,
            'SIGNERS',
            ([v]) => v === '1',
            '',
            SEVERITY.BLOCKER
        )
    );
    // The URL is what the Flow hands to a Send Email element; a URL missing its
    // token is a link that cannot sign anything.
    out.push(
        fromKey(
            `${A}: the signing URL carries a 64-char token and targets the guided page`,
            happy,
            'URL',
            (parts, raw) => /token=[a-f0-9]{64}/i.test(raw) && /DocGenSignaturePdf/.test(raw),
            '',
            SEVERITY.BLOCKER
        )
    );
    // Outputs feed downstream Flow elements — an empty or shuffled echo means
    // the admin's email merge fields are wrong.
    out.push(
        fromKey(
            `${A}: Signer Names/Emails/Roles outputs echo the input (role defaults to "Signer")`,
            happy,
            'ECHO',
            ([n, e, role]) => n === `${P} Signer One` && e === 'qaflow.one@example.com' && role === 'Signer',
            '',
            SEVERITY.MAJOR
        )
    );
    // A placeholder domain is org configuration, not a code defect — report it
    // as a skip so it reads as "not proven here", not as a pass.
    if (happy.map.URL && /CONFIGURE_SITE_URL_IN_SETUP/.test(unesc(happy.map.URL))) {
        out.push(
            skip(
                `${A}: the signing URL points at a real, reachable site`,
                'this org has no Experience Site URL in DocGen Settings, so the action returns the <CONFIGURE_SITE_URL_IN_SETUP> placeholder. The link shape is correct but end-to-end reachability is unproven here.',
                SEVERITY.MAJOR
            )
        );
    }

    // --- validation edges: each in its own block (several throw) ---
    const edgeSrc = (bodyLines) => `
Id acctId = '${ids.ACCT_ID}';
Id sigTpl = '${ids.SIGTPL_ID}';
DocGenSigner ok = new DocGenSigner(); ok.name = '${P} Signer One'; ok.email = 'qaflow.one@example.com';
try {
${bodyLines}
    List<DocGenSignatureFlowAction.Result> x = DocGenSignatureFlowAction.generate(new List<DocGenSignatureFlowAction.Request>{ r });
    System.debug('OUT=RETURNED~' + x[0].success + '~' + x[0].errorMessage);
} catch (Exception e) {
    System.debug('OUT=THREW~' + e.getTypeName() + '~' + e.getMessage());
}
`;
    const edges = [
        [
            'a null Template Id',
            `    DocGenSignatureFlowAction.Request r = new DocGenSignatureFlowAction.Request();
    r.relatedRecordId = acctId; r.signerRecords = new List<DocGenSigner>{ ok }; r.sendEmails = false;`,
            /template id is required/i
        ],
        [
            'a null Related Record Id',
            `    DocGenSignatureFlowAction.Request r = new DocGenSignatureFlowAction.Request();
    r.templateId = sigTpl; r.signerRecords = new List<DocGenSigner>{ ok }; r.sendEmails = false;`,
            /related record id is required/i
        ],
        [
            'an empty Signers collection',
            `    DocGenSignatureFlowAction.Request r = new DocGenSignatureFlowAction.Request();
    r.templateId = sigTpl; r.relatedRecordId = acctId; r.sendEmails = false;`,
            /at least one signer/i
        ],
        [
            'a signer with no email',
            `    DocGenSigner bad = new DocGenSigner(); bad.name = '${P} No Email';
    DocGenSignatureFlowAction.Request r = new DocGenSignatureFlowAction.Request();
    r.templateId = sigTpl; r.relatedRecordId = acctId; r.signerRecords = new List<DocGenSigner>{ bad }; r.sendEmails = false;`,
            /must have an email/i
        ]
    ];
    const threw = [];
    for (const [label, body, wants] of edges) {
        const res = await probe(org, edgeSrc(body));
        // Each of these is a distinct mistake an admin makes, so each gets its
        // own check that the MESSAGE is actionable.
        out.push(
            fromKey(
                `${A}: ${label} → the Flow author gets an actionable message`,
                res,
                'OUT',
                (parts, raw) => wants.test(raw),
                '',
                SEVERITY.MAJOR
            )
        );
        if (res.map.OUT && unesc(res.map.OUT).startsWith('THREW')) threw.push(label);
    }
    // …but they all share ONE design decision, so the fix list gets ONE row.
    // The class documents the throw as deliberate ("preserves existing Flow
    // behavior where bad input stops the Flow"), which is defensible — except
    // that Result advertises Success and Error Message outputs that this path
    // never reaches, so a Flow author who wired up a fault path never sees them.
    out.push(
        check(
            `${A}: input validation reports through Success/Error Message rather than faulting the Flow`,
            threw.length === 0,
            threw.length
                ? `throws DocGenException instead of returning Result.success=false for: ${threw.join('; ')}. The Result class advertises "Success" and "Error Message" outputs that are unreachable on these paths — the Flow interview faults instead. Deliberate per the class comment, but it makes those two outputs a lie for the most common author mistakes.`
                : '',
            SEVERITY.MAJOR
        )
    );

    // OWN BLOCK: a template Id that does not exist reaches the @AuraEnabled
    // controller layer and leaks an AuraHandledException.
    const noTpl = await probe(
        org,
        `
DocGenSigner ok = new DocGenSigner(); ok.name = '${P} Signer One'; ok.email = 'qaflow.one@example.com';
DocGenSignatureFlowAction.Request r = new DocGenSignatureFlowAction.Request();
r.templateId = 'a0B000000000000AAA'; r.relatedRecordId = '${ids.ACCT_ID}';
r.signerRecords = new List<DocGenSigner>{ ok }; r.sendEmails = false;
try {
    List<DocGenSignatureFlowAction.Result> x = DocGenSignatureFlowAction.generate(new List<DocGenSignatureFlowAction.Request>{ r });
    System.debug('OUT=RETURNED~' + x[0].success + '~' + x[0].errorMessage);
} catch (Exception e) {
    System.debug('OUT=THREW~' + e.getTypeName() + '~' + e.getMessage());
}
`
    );
    // What was ACTUALLY broken here: the failure arrived as
    // `System.LimitException: Can only throw this exception type from
    // VisualForce or Aura context`, because the controller raises an
    // AuraHandledException and that type cannot be thrown outside an Aura/VF
    // request. A LimitException is UNCATCHABLE, so no amount of care in the
    // action could report it and the Flow author saw a cryptic platform error.
    // The action now validates the template up front and raises a catchable,
    // readable DocGenException.
    //
    // Whether validation should instead RETURN Success=false is a separate,
    // deliberate design decision (the class comment says bad input is meant to
    // stop the Flow) and changing it would alter behaviour for every Flow
    // already in production — those interviews stop today and would start
    // continuing down the happy path. That trade-off is a product call, so it
    // is raised as its own finding rather than silently changed here.
    out.push(
        auraLeakCheck(
            `${A}: a Template Id that does not exist fails with a catchable, readable error`,
            noTpl,
            'OUT',
            (parts) =>
                (parts[0] === 'RETURNED' && parts[1] === 'false') ||
                (parts[0] === 'THREW' &&
                    /DocGenException/.test(parts[1] || '') &&
                    /Template not found/i.test(parts[2] || '')),
            'The failure must be a catchable exception with a message naming the bad Id — not an uncatchable LimitException from an AuraHandledException raised outside an Aura request.'
        )
    );
    return out;
}

// ── DocGenSignaturePdfFlowAction (deprecated, still installed and callable) ─
async function probeSignaturePdfAction(org, ids) {
    const out = [];
    const A = 'Send Existing Document for Signature (deprecated)';
    const r = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id sigTpl = '${ids.SIGTPL_ID}';
DocGenSigner s1 = new DocGenSigner(); s1.name = '${P} Pdf One'; s1.email = 'qaflow.p1@example.com';
DocGenSigner s2 = new DocGenSigner(); s2.name = '${P} Pdf Two'; s2.email = 'qaflow.p2@example.com';
DocGenSignaturePdfFlowAction.Request a = new DocGenSignaturePdfFlowAction.Request();
a.templateId = sigTpl; a.relatedRecordId = acctId; a.signerRecords = new List<DocGenSigner>{ s1 }; a.signingOrder = 'Single';
DocGenSignaturePdfFlowAction.Request b = new DocGenSignaturePdfFlowAction.Request();
b.templateId = sigTpl; b.relatedRecordId = acctId; b.signerRecords = new List<DocGenSigner>{ s2 }; b.signingOrder = 'Single';
List<DocGenSignaturePdfFlowAction.Result> rr = DocGenSignaturePdfFlowAction.send(
    new List<DocGenSignaturePdfFlowAction.Request>{ a, b });
System.debug('COUNT=' + rr.size());
System.debug('A=' + rr[0].success + '~' + rr[0].signatureRequestId + '~' + (rr[0].signerUrls == null ? 0 : rr[0].signerUrls.size()) + '~' + rr[0].errorMessage);
System.debug('B=' + rr[1].success + '~' + rr[1].signatureRequestId + '~' + rr[1].errorMessage);
System.debug('DISTINCT=' + (rr[0].signatureRequestId != rr[1].signatureRequestId));
// A Flow can hand an action an empty/unset collection.
System.debug('NULLIN=' + DocGenSignaturePdfFlowAction.send(null).size());
`
    );
    out.push(fromKey(`${A}: returns one result per request`, r, 'COUNT', ([v]) => v === '2', '', SEVERITY.MAJOR));
    out.push(
        fromKey(
            `${A}: still creates a working request (existing Flows must not break)`,
            r,
            'A',
            ([ok, reqId, urls]) => ok === 'true' && /^a0/.test(reqId) && urls === '1',
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(fromKey(`${A}: second request also succeeds`, r, 'B', ([ok]) => ok === 'true', '', SEVERITY.MAJOR));
    out.push(
        fromKey(`${A}: the two requests are distinct records`, r, 'DISTINCT', ([v]) => v === 'true', '', SEVERITY.MAJOR)
    );
    out.push(
        fromKey(
            `${A}: a null request list returns empty, not an exception`,
            r,
            'NULLIN',
            ([v]) => v === '0',
            '',
            SEVERITY.MAJOR
        )
    );

    // The DEPRECATED Content Version Id input must give an admin who is still
    // using it a message that tells them what to change.
    const dep = await probe(
        org,
        `
DocGenSigner ok = new DocGenSigner(); ok.name = '${P} Pdf One'; ok.email = 'qaflow.p1@example.com';
DocGenSignaturePdfFlowAction.Request r = new DocGenSignaturePdfFlowAction.Request();
r.contentVersionId = '068000000000000AAA'; r.relatedRecordId = '${ids.ACCT_ID}';
r.signerRecords = new List<DocGenSigner>{ ok };
try {
    List<DocGenSignaturePdfFlowAction.Result> x = DocGenSignaturePdfFlowAction.send(new List<DocGenSignaturePdfFlowAction.Request>{ r });
    System.debug('OUT=RETURNED~' + x[0].success + '~' + x[0].errorMessage);
} catch (Exception e) {
    System.debug('OUT=THREW~' + e.getTypeName() + '~' + e.getMessage());
}
`
    );
    out.push(
        fromKey(
            `${A}: the removed Content Version Id path explains what to use instead`,
            dep,
            'OUT',
            (parts, raw) => /template id/i.test(raw),
            '',
            SEVERITY.MAJOR
        )
    );
    return out;
}

// ── Token-driven actions: Validator / Submitter / Finalizer ─────────────────
// These are the custom-signing helpers documented in UserGuide §11.8. They are
// what a subscriber wires into their own signing screen flow.
async function probeTokenActions(org, ids) {
    const out = [];

    const v = await probe(
        org,
        `
List<DocGen_Signer__c> s = [SELECT Secure_Token__c FROM DocGen_Signer__c
    WHERE Signer_Email__c = 'qaflow.one@example.com' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('HAVETOKEN=' + s.size());
List<DocGenSignatureValidator.FlowInput> ins = new List<DocGenSignatureValidator.FlowInput>();
DocGenSignatureValidator.FlowInput i1 = new DocGenSignatureValidator.FlowInput();
i1.token = s.isEmpty() ? 'x' : s[0].Secure_Token__c;
DocGenSignatureValidator.FlowInput i2 = new DocGenSignatureValidator.FlowInput(); i2.token = 'deadbeef';
DocGenSignatureValidator.FlowInput i3 = new DocGenSignatureValidator.FlowInput(); i3.token = null;
ins.add(i1); ins.add(i2); ins.add(i3);
List<DocGenSignatureValidator.FlowOutput> o = DocGenSignatureValidator.validateToken(ins);
System.debug('COUNT=' + o.size());
System.debug('GOOD=' + o[0].isValid + '~' + o[0].signerName + '~' + o[0].documentTitle + '~' + o[0].errorMessage);
System.debug('BAD=' + o[1].isValid + '~' + o[1].errorMessage);
System.debug('NULLTOK=' + o[2].isValid + '~' + o[2].errorMessage);
`
    );
    const V = 'Validate Signature Token';
    out.push(fromKey(`${V}: returns one output per input`, v, 'COUNT', ([n]) => n === '3', '', SEVERITY.BLOCKER));
    out.push(
        fromKey(
            `${V}: a live token validates and returns the signer + document title`,
            v,
            'GOOD',
            ([ok, signer, title]) => ok === 'true' && signer === `${P} Signer One` && !!title && title !== 'null',
            '',
            SEVERITY.BLOCKER
        )
    );
    // A malformed token must be a polite "no", never an exception — the signer
    // is a guest on a public page when this runs.
    out.push(
        fromKey(
            `${V}: a malformed token returns isValid=false with a reason`,
            v,
            'BAD',
            ([ok, msg]) => ok === 'false' && !!msg,
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${V}: a null token returns isValid=false with a reason`,
            v,
            'NULLTOK',
            ([ok, msg]) => ok === 'false' && !!msg,
            '',
            SEVERITY.BLOCKER
        )
    );

    // BULK SAFETY AT FLOW SCALE. Flow batches up to 200 interviews into one
    // invocable call. This block is separate because when it blows the SOQL
    // limit it takes its whole log with it.
    const vb = await probe(
        org,
        `
List<DocGen_Signer__c> s = [SELECT Secure_Token__c FROM DocGen_Signer__c
    WHERE Signer_Email__c = 'qaflow.one@example.com' ORDER BY CreatedDate DESC LIMIT 1];
List<DocGenSignatureValidator.FlowInput> ins = new List<DocGenSignatureValidator.FlowInput>();
for (Integer i = 0; i < 60; i++) {
    DocGenSignatureValidator.FlowInput fi = new DocGenSignatureValidator.FlowInput();
    fi.token = s.isEmpty() ? 'x' : s[0].Secure_Token__c;
    ins.add(fi);
}
List<DocGenSignatureValidator.FlowOutput> o = DocGenSignatureValidator.validateToken(ins);
System.debug('BULK60=' + o.size());
`
    );
    out.push(fromKey(`${V}: survives a 60-request Flow batch`, vb, 'BULK60', ([n]) => n === '60', '', SEVERITY.MAJOR));

    const sub = await probe(
        org,
        `
DocGenSignatureSubmitter.FlowInput a = new DocGenSignatureSubmitter.FlowInput(); a.token = 'deadbeef'; a.signatureData = 'xyz';
DocGenSignatureSubmitter.FlowInput b = new DocGenSignatureSubmitter.FlowInput(); b.token = null; b.signatureData = null;
List<DocGenSignatureSubmitter.FlowOutput> o = DocGenSignatureSubmitter.submitSignature(
    new List<DocGenSignatureSubmitter.FlowInput>{ a, b });
System.debug('COUNT=' + o.size());
System.debug('BAD=' + o[0].isSuccess + '~' + o[0].errorMessage);
System.debug('NULLIN=' + o[1].isSuccess + '~' + o[1].errorMessage);
`
    );
    const S = 'Submit Signed Signature';
    out.push(fromKey(`${S}: returns one output per input`, sub, 'COUNT', ([n]) => n === '2', '', SEVERITY.BLOCKER));
    out.push(
        fromKey(
            `${S}: a bad token returns isSuccess=false with a reason`,
            sub,
            'BAD',
            ([ok, msg]) => ok === 'false' && !!msg,
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${S}: null inputs return isSuccess=false with a reason`,
            sub,
            'NULLIN',
            ([ok, msg]) => ok === 'false' && !!msg,
            '',
            SEVERITY.BLOCKER
        )
    );

    const fin = await probe(
        org,
        `
DocGenSignatureFinalizer.FinalizeRequest a = new DocGenSignatureFinalizer.FinalizeRequest();
a.token = 'deadbeef'; a.base64Image = 'xyz';
try {
    DocGenSignatureFinalizer.finalizeSignature(new List<DocGenSignatureFinalizer.FinalizeRequest>{ a });
    System.debug('OUT=RETURNED');
} catch (Exception e) {
    System.debug('OUT=THREW~' + e.getTypeName() + '~' + e.getMessage());
}
`
    );
    // Finalize is the LAST step of a subscriber's custom signing flow. An
    // expired or reused token there is routine, not exceptional.
    out.push(
        fromKey(
            'Finalize Signature Image: a bad token is handled, not thrown into the Flow',
            fin,
            'OUT',
            ([kind]) => kind === 'RETURNED',
            '',
            SEVERITY.MAJOR
        )
    );
    return out;
}

// ── DocGenFieldWritebackService ─────────────────────────────────────────────
async function probeWriteback(org, ids) {
    const out = [];
    const A = 'Write Back Signer Form Fields';
    // Its own contract is "failures are logged, never thrown" — so the whole
    // point of this probe is that a hostile input list changes nothing.
    const r = await probe(
        org,
        `
// Scoped to THIS run's template — an unscoped "most recent request" would pick
// up another suite's record when both run against the same org.
List<DocGen_Signature_Request__c> rq = [SELECT Id FROM DocGen_Signature_Request__c
    WHERE Template__c = '${ids.SIGTPL_ID}' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('HAVEREQ=' + rq.size());
DocGenFieldWritebackService.WritebackRequest a = new DocGenFieldWritebackService.WritebackRequest();
a.requestId = rq.isEmpty() ? null : String.valueOf(rq[0].Id);
DocGenFieldWritebackService.WritebackRequest b = new DocGenFieldWritebackService.WritebackRequest(); b.requestId = null;
DocGenFieldWritebackService.WritebackRequest c = new DocGenFieldWritebackService.WritebackRequest(); c.requestId = 'not-an-id';
DocGenFieldWritebackService.WritebackRequest d = new DocGenFieldWritebackService.WritebackRequest(); d.requestId = 'a08000000000000AAA';
try {
    DocGenFieldWritebackService.writeBackFields(
        new List<DocGenFieldWritebackService.WritebackRequest>{ a, b, c, d, null });
    System.debug('MIXED=RETURNED');
} catch (Exception e) {
    System.debug('MIXED=THREW~' + e.getTypeName() + '~' + e.getMessage());
}
try { DocGenFieldWritebackService.writeBackFields(null); System.debug('NULLLIST=RETURNED'); }
catch (Exception e) { System.debug('NULLLIST=THREW~' + e.getMessage()); }
List<DocGenFieldWritebackService.WritebackRequest> many = new List<DocGenFieldWritebackService.WritebackRequest>();
for (Integer i = 0; i < 60; i++) {
    DocGenFieldWritebackService.WritebackRequest w = new DocGenFieldWritebackService.WritebackRequest();
    w.requestId = rq.isEmpty() ? null : String.valueOf(rq[0].Id);
    many.add(w);
}
try { DocGenFieldWritebackService.writeBackFields(many); System.debug('BULK60=RETURNED'); }
catch (Exception e) { System.debug('BULK60=THREW~' + e.getMessage()); }
`
    );
    out.push(
        fromKey(
            `${A}: a mixed list (valid, null, malformed, missing) never throws`,
            r,
            'MIXED',
            ([kind]) => kind === 'RETURNED',
            '',
            SEVERITY.BLOCKER
        )
    );
    out.push(
        fromKey(
            `${A}: a null request list is a no-op`,
            r,
            'NULLLIST',
            ([kind]) => kind === 'RETURNED',
            '',
            SEVERITY.MAJOR
        )
    );
    // Caveat recorded on purpose: the fixture request has no form-field config,
    // so this proves the guard clauses hold at scale, not the write path.
    out.push(
        fromKey(
            `${A}: survives a 60-request Flow batch`,
            r,
            'BULK60',
            ([kind]) => kind === 'RETURNED',
            () =>
                'note: the fixture request carries no form-field config, so this exercises the guard path, not a 60-record write',
            SEVERITY.MAJOR
        )
    );
    return out;
}

// ── @AuraEnabled endpoints the LWCs cannot start without ────────────────────
// Called exactly as the components call them. Only happy paths: an @AuraEnabled
// method's error contract IS AuraHandledException, which is correct for an LWC
// but cannot be constructed (or caught) from anonymous Apex — so negative paths
// here belong in unit tests, not in this harness.
async function probeAuraEndpoints(org, ids) {
    const out = [];
    const r = await probe(
        org,
        `
Id acctId = '${ids.ACCT_ID}';
Id tplId = '${ids.TPL_ID}';
System.debug('TEMPLATELIST=' + DocGenController.getTemplateList().size());
System.debug('ALLTEMPLATES=' + DocGenController.getAllTemplates().size());
System.debug('TPLFOROBJ=' + DocGenController.getTemplatesForObject('Account').size());
System.debug('TPLFORRECORD=' + DocGenController.getTemplatesForObjectAndRecord('Account', String.valueOf(acctId)).size());
System.debug('TPLBYID=' + DocGenController.getTemplateById(tplId).Name);
System.debug('OBJECTOPTIONS=' + DocGenController.getObjectOptions().size());
System.debug('OBJECTFIELDS=' + DocGenController.getObjectFields('Account').size());
System.debug('UPDATEABLEFIELDS=' + DocGenController.getUpdateableObjectFields('Account').size());
System.debug('CHILDRELS=' + DocGenController.getChildRelationships('Account').size());
Map<String, Object> pv = DocGenController.previewRecordData(acctId, 'Account', 'Name, Industry');
System.debug('PREVIEW=' + (pv != null) + '~' + (pv != null && pv.containsKey('Name')) + '~' + (pv != null ? String.valueOf(pv.get('Name')) : ''));
Map<String, Object> gd = DocGenController.generateDocumentData(tplId, acctId);
System.debug('GENDATA=' + (gd != null) + '~' + (gd != null && !gd.isEmpty()));
System.debug('BULKTEMPLATES=' + DocGenBulkController.getBulkTemplates().size());
System.debug('VALIDATEFILTER=' + DocGenBulkController.validateFilter('Account', 'Name != null'));
System.debug('RECENTJOBS=' + (DocGenBulkController.getRecentJobs() != null));
System.debug('SAVEDQUERIES=' + (DocGenBulkController.getSavedQueries(tplId) != null));
System.debug('ORGURL=' + String.isNotBlank(DocGenSetupController.getOrgUrl()));
System.debug('SETTINGS=' + (DocGenSetupController.getSettings() != null));
System.debug('SETTINGSFRESH=' + (DocGenSetupController.getSettingsFresh() != null));
System.debug('OWA=' + (DocGenSetupController.getOrgWideEmailAddresses() != null));
System.debug('SIGSETUP=' + DocGenSetupController.validateSignatureSetup().size());
System.debug('BUTTONS=' + (DocGenButtonController.getButtons(acctId) != null));
List<DocGen_Signer__c> s = [SELECT Secure_Token__c FROM DocGen_Signer__c
    WHERE Signer_Email__c = 'qaflow.one@example.com' ORDER BY CreatedDate DESC LIMIT 1];
if (!s.isEmpty()) {
    System.debug('SIGVALIDATE=' + DocGenSignatureController.validateToken(s[0].Secure_Token__c).isValid);
}
`
    );
    const E = (name, key, pred, sev = SEVERITY.BLOCKER) => out.push(fromKey(name, r, key, pred, '', sev));

    // Every one of these is a component's very first call — an empty or failing
    // result is a blank screen for the admin, not a degraded one.
    E('docGenAdmin: getTemplateList returns templates', 'TEMPLATELIST', ([n]) => Number(n) > 0);
    E('docGenAdmin: getAllTemplates returns templates', 'ALLTEMPLATES', ([n]) => Number(n) > 0);
    E('docGenRunner: getTemplatesForObject("Account") finds the fixture template', 'TPLFOROBJ', ([n]) => Number(n) > 0);
    E('docGenRunner: getTemplatesForObjectAndRecord respects record filters', 'TPLFORRECORD', ([n]) => Number(n) > 0);
    E('docGenAdmin: getTemplateById returns the right record', 'TPLBYID', (p, raw) => raw === `${P} Template`);
    E('Query builder: getObjectOptions is populated', 'OBJECTOPTIONS', ([n]) => Number(n) > 0);
    E('Query builder: getObjectFields("Account") is populated', 'OBJECTFIELDS', ([n]) => Number(n) > 0);
    E(
        'Query builder: getUpdateableObjectFields("Account") is populated',
        'UPDATEABLEFIELDS',
        ([n]) => Number(n) > 0,
        SEVERITY.MAJOR
    );
    E('Query builder: getChildRelationships("Account") is populated', 'CHILDRELS', ([n]) => Number(n) > 0);
    E(
        'Preview: previewRecordData returns the requested fields',
        'PREVIEW',
        ([notNull, hasName, name]) => notNull === 'true' && hasName === 'true' && name === `${P} Corp`
    );
    E(
        'Runner: generateDocumentData returns merge data',
        'GENDATA',
        ([notNull, nonEmpty]) => notNull === 'true' && nonEmpty === 'true'
    );
    E('docGenBulkRunner: getBulkTemplates returns templates', 'BULKTEMPLATES', ([n]) => Number(n) > 0);
    E('docGenBulkRunner: validateFilter counts matching records', 'VALIDATEFILTER', ([n]) => Number(n) >= 1);
    E('docGenBulkRunner: getRecentJobs responds', 'RECENTJOBS', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('docGenBulkRunner: getSavedQueries responds', 'SAVEDQUERIES', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('Setup: getOrgUrl returns a URL', 'ORGURL', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('Setup: getSettings responds', 'SETTINGS', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('Setup: getSettingsFresh responds', 'SETTINGSFRESH', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('Setup: getOrgWideEmailAddresses responds', 'OWA', ([v]) => v === 'true', SEVERITY.MAJOR);
    E('Setup: validateSignatureSetup returns its checklist', 'SIGSETUP', ([n]) => Number(n) > 0, SEVERITY.MAJOR);
    E(
        'Record page: getButtons responds for a record with no configured buttons',
        'BUTTONS',
        ([v]) => v === 'true',
        SEVERITY.MAJOR
    );
    E('Signing page: validateToken accepts a live token', 'SIGVALIDATE', ([v]) => v === 'true');

    return out;
}

// ── shared check shapes ─────────────────────────────────────────────────────

/**
 * An action that leaks an AuraHandledException out of a Flow-invocable method.
 * The signature of this defect is unmistakable and worth naming in the report:
 * the block prints nothing and the org says "Can only throw this exception type
 * from VisualForce or Aura context".
 */
function auraLeakCheck(name, res, key, predicate, why) {
    const leaked = /Can only throw this exception type from VisualForce or Aura context/i.test(res.fatal || '');
    if (leaked) {
        return check(
            name,
            false,
            `UNHANDLED: the org raised "Can only throw this exception type from VisualForce or Aura context". ${why}`,
            SEVERITY.BLOCKER
        );
    }
    return fromKey(name, res, key, predicate, '', SEVERITY.BLOCKER);
}

/**
 * How many requests this action can take in one Flow transaction before the
 * 100-SOQL limit ends it. Document generation is genuinely per-record work, so
 * this is not a demand for bulkification — it is the number an admin needs when
 * they point a record-triggered Flow at a list view.
 */
function bulkCostCheck(action, res, minimum, severity) {
    const raw = res.map.QPERREQ;
    if (raw === undefined) {
        return skip(
            `${action}: SOQL cost per request is known`,
            `the probe did not report it. ${res.fatal || ''}`,
            severity
        );
    }
    const per = Number(unesc(raw));
    const max = per > 0 ? Math.floor(100 / per) : 999;
    return check(
        `${action}: a Flow batch of at least ${minimum} requests fits in one transaction`,
        max >= minimum,
        `${per} SOQL per request → about ${max} requests per transaction (Flow can hand an invocable up to 200)`,
        severity
    );
}
