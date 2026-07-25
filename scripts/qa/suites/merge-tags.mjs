/**
 * MERGE TAGS — the product's core contract.
 * =========================================
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * Merge tags ARE the product. Everything else (page setup, signatures, bulk,
 * the designer) is packaging around "this tag became that value". The existing
 * evidence for tag correctness is `scripts/e2e-07-syntax1..4.apex` — four hand-
 * written anonymous-Apex scripts that print a PASS/FAIL tally. They are good,
 * but they were written incrementally alongside bug fixes, so they prove the
 * bugs stayed fixed rather than proving the syntax surface works. Nothing in
 * them covers: a value containing `<`, an orphan `{/Close}`, a 4,000-character
 * field, a tag inside an href, a loop that crosses the heap-check boundary, or
 * what a tag does when it simply cannot resolve.
 *
 * This suite enumerates the syntax surface from the parser itself
 * (`DocGenService.processXml`, the dispatch chain around line 3700-4420) and
 * asserts each form, then spends most of its weight on the edge cases — because
 * a merge tag that renders the WRONG value silently is the failure mode that
 * reaches a customer's signed contract.
 *
 * HOW IT RUNS
 * -----------
 * `DocGenService.processXmlForTest(xml, data)` is the public test seam. Every
 * check is a row in a table:
 *
 *     { id, name, ctx, xml, mode, exp, sev }
 *
 * A generic Apex runner (RUNNER, below) walks that table inside ONE anonymous
 * transaction and prints one `T_<ID>=<0|1>|<expected>|<actual>` line per row,
 * which `debugMap()` reads back. Table-driven rather than one-call-per-tag
 * because anonymous Apex caps at 20,000 characters and every `sf apex run` is a
 * ~4s round trip — 200 separate calls would take 15 minutes and prove nothing
 * extra.
 *
 * WHAT THE SEAM CANNOT REACH (honest gaps, reported as skips)
 * ----------------------------------------------------------
 *  - `currentTemplateType` is a PRIVATE static and the 3-arg
 *    `processXmlForTest(xml, data, type)` overload is `@TestVisible private`,
 *    which anonymous Apex cannot call. So every check here runs in the default
 *    'Word' branch. HTML-specific escaping (`\n` → `<br/>`), Excel's literal-
 *    newline branch and the PowerPoint strip-tags branch are NOT covered.
 *  - `{PageNumber}`/`{TotalPages}` are deliberately preserved by processXml and
 *    resolved later by `wrapHtmlForPdf`'s @page counters. We assert the
 *    preservation contract only; the rendered page number is a PDF-level
 *    concern belonging to the output-formats suite.
 *
 * SEVERITY RULE USED THROUGHOUT
 * -----------------------------
 *  blocker — silently WRONG output (bad value, unescaped XML, dropped data).
 *            This is the one that ships a broken document to a customer.
 *  major   — a supported tag errors, or template syntax leaks into the document.
 *  minor   — cosmetic, or a documented limitation we simply want pinned down.
 */
import { runAnonymous, debugMap } from '../lib/sf.mjs';
import { check, skip, suiteResult, suiteSkipped, SEVERITY } from '../lib/report.mjs';
import { writeFileSync } from 'node:fs';

const { BLOCKER, MAJOR, MINOR } = SEVERITY;

/* ------------------------------------------------------------------ *
 * Apex source helpers
 * ------------------------------------------------------------------ */

/** Render a JS string as an Apex string literal. */
function aq(s) {
    return (
        "'" +
        String(s === undefined || s === null ? '' : s)
            .replace(/\\/g, '\\\\')
            .replace(/'/g, "\\'")
            .replace(/\n/g, '\\n')
            .replace(/\r/g, '\\r') +
        "'"
    );
}

/**
 * The generic case runner.
 *
 * Modes:
 *   EQ    exact match            NOT   must NOT contain
 *   HAS   must contain           BLANK output is empty
 *   RE    java regex find        LEN   output length equals exp
 *   THROW must throw; exp (if set) must appear in the message
 *   EQD / HASD  same as EQ / HAS but exp is a KEY into the DYN map (Apex identifiers are case-insensitive, so it cannot be called EXP alongside a local named exp), for
 *               values only the org knows (today's date, running user).
 *
 * Flags (6th column) toggle the two public statics that change tag lifecycle,
 * and opt a row into the pre-merge run-defragmenter:
 *   SIG    preserveSignatureTags = true
 *   FF     resolveFormFields     = true
 *   MERGE  run mergeRunsInTagsForTest() first (simulates Word splitting a tag
 *          across <w:r> runs because of character formatting)
 */
const RUNNER = `
for (Integer qi = 0; qi < CS.size(); qi++) {
    List<String> c = CS[qi];
    String flags = c.size() > 5 ? c[5] : '';
    DocGenService.preserveSignatureTags = flags.contains('SIG');
    DocGenService.resolveFormFields = flags.contains('FF');
    String src = c[2];
    String got = null;
    String err = null;
    try {
        if (flags.contains('MERGE')) { src = DocGenService.mergeRunsInTagsForTest(src); }
        got = DocGenService.processXmlForTest(src, CTX.get(c[1]));
    } catch (Exception qe) {
        err = qe.getTypeName() + ': ' + qe.getMessage();
    }
    DocGenService.preserveSignatureTags = false;
    DocGenService.resolveFormFields = false;
    String mode = c[3];
    String exp = c[4];
    if (mode == 'EQD') { mode = 'EQ'; exp = DYN.get(exp); }
    if (mode == 'HASD') { mode = 'HAS'; exp = DYN.get(exp); }
    if (exp == null) { exp = ''; }
    Boolean ok = false;
    if (err != null) {
        ok = (mode == 'THROW') && (String.isBlank(exp) || err.contains(exp));
    } else if (mode == 'THROW') {
        ok = false;
    } else if (mode == 'EQ') {
        ok = (got == exp);
    } else if (mode == 'HAS') {
        ok = got.contains(exp);
    } else if (mode == 'NOT') {
        ok = !got.contains(exp);
    } else if (mode == 'BLANK') {
        ok = String.isEmpty(got);
    } else if (mode == 'LEN') {
        ok = (String.valueOf(got.length()) == exp);
    } else if (mode == 'RE') {
        ok = Pattern.compile(exp).matcher(got).find();
    }
    String ev = (err != null) ? ('THREW ' + err) : got;
    if (ev == null) { ev = '<null>'; }
    if (ev == '') { ev = '<empty>'; }
    if (ev.length() > 190) { ev = ev.substring(0, 190) + '<TRUNCATED>'; }
    // Field separator is '~~', NOT '|': the Salesforce debug log uses '|' as its
    // own column delimiter and HTML-escapes any pipe inside a USER_DEBUG value to
    // '&#124;', which makes a pipe-delimited payload unparseable on the way back.
    System.debug(
        'T_' + c[0] + '=' + (ok ? '1' : '0') +
        '~~' + c[3] + ' ' + exp.replace('\\n', ' ').replace('~~', '~-~') +
        '~~' + ev.replace('\\n', '\\\\n').replace('\\r', '').replace('~~', '~-~')
    );
}
`;

/* ------------------------------------------------------------------ *
 * Data contexts. Each batch pulls in only what it needs so no single
 * anonymous block gets close to the 20,000-character ceiling.
 * ------------------------------------------------------------------ */
const CTX_SRC = {
    // The everything-scalar record. Deliberately contains the values that
    // historically break document generation: markup characters, an apostrophe,
    // non-ASCII + astral-plane text, an embedded merge tag, a query-string URL.
    base: `
CTX.put('base', new Map<String,Object>{
    'Name' => 'Acme Corp',
    'NullF' => null,
    'Blank' => '',
    'RichBlank' => '<p><br></p>',
    'Xml' => 'R&D <Widgets> "Q1" it\\'s',
    'Uni' => 'Zürich 東京 😀',
    'Multi' => 'Line1\\nLine2',
    'Inject' => '{Secret}',
    'Secret' => 'LEAKED',
    'Url' => 'https://ex.test/a?b=1&c=2',
    'Amt' => 75000.50,
    'Rate' => 15.5,
    'Qty' => 1234567,
    'Amount' => 75000,
    'Stage' => 'Won',
    'Active' => true,
    'Inactive' => false,
    'Text' => 'not-a-number',
    'Code' => 'ABC-123&X',
    'D' => DateTime.newInstance(2026, 4, 8, 13, 45, 0),
    'DateStr' => '2026-04-08',
    'IsoStr' => '2026-04-08T13:45:00.000Z',
    'Account' => new Map<String,Object>{
        'Name' => 'Parent Co',
        'Owner' => new Map<String,Object>{ 'Name' => 'Deep Owner' }
    }
});
String LONGV = '';
for (Integer li = 0; li < 400; li++) { LONGV += '0123456789'; }
CTX.get('base').put('Long', LONGV);
`,
    items: `
CTX.put('items', new Map<String,Object>{
    'Items' => new List<Object>{
        new Map<String,Object>{ 'Name' => 'Item A', 'Amount' => 100 },
        new Map<String,Object>{ 'Name' => 'Item B', 'Amount' => 200 },
        new Map<String,Object>{ 'Name' => 'Item C', 'Amount' => 50 }
    },
    'Empty' => new List<Object>(),
    'Parent' => 'ParentValue',
    'Active' => true,
    'Inactive' => false,
    'Blank' => '',
    'RichBlank' => '<p><br></p>',
    'Name' => 'Acme Corp',
    'Amount' => 75000,
    'Stage' => 'Won',
    'Strings' => new List<Object>{ 'raw1', 'raw2' },
    'Wrapped' => new Map<String,Object>{
        'totalSize' => 2,
        'records' => new List<Object>{
            new Map<String,Object>{ 'Name' => 'W1' },
            new Map<String,Object>{ 'Name' => 'W2' }
        }
    }
});
`,
    // 60 rows crosses HEAP_CHECK_EVERY_N_ITERS (50) so the heap-pressure probe
    // actually fires mid-loop — the one code path that can abort a loop early.
    many: `
List<Object> MANYR = new List<Object>();
for (Integer mi = 1; mi <= 60; mi++) { MANYR.add(new Map<String,Object>{ 'N' => String.valueOf(mi) }); }
CTX.put('many', new Map<String,Object>{ 'Rows' => MANYR });
`,
    nested: `
CTX.put('nested', new Map<String,Object>{
    'Orders' => new List<Object>{
        new Map<String,Object>{ 'O' => 'O1', 'Lines' => new List<Object>{
            new Map<String,Object>{ 'L' => 'L1a' }, new Map<String,Object>{ 'L' => 'L1b' } } },
        new Map<String,Object>{ 'O' => 'O2', 'Lines' => new List<Object>{
            new Map<String,Object>{ 'L' => 'L2a' } } }
    }
});
`,
    // Signer form fields arrive under the reserved '__formFields' key.
    ff: `
CTX.put('ff', new Map<String,Object>{
    '__formFields' => new Map<String,Object>{ 'title' => 'CTO', 'xml' => '<b>&' }
});
`,
    // In-memory ChartBucket source. Counts: Bus 3, Car 2, Ash 1, Bike 1, null 1
    // (total 8) — chosen so the desc-by-count / alpha-on-tie ordering is
    // observable AND a null bucket exists.
    chart: `
CTX.put('chart', new Map<String,Object>{
    'Answers' => new List<Object>{
        new Map<String,Object>{ 'Choice__c' => 'Bus' },
        new Map<String,Object>{ 'Choice__c' => 'Bus' },
        new Map<String,Object>{ 'Choice__c' => 'Bus' },
        new Map<String,Object>{ 'Choice__c' => 'Car' },
        new Map<String,Object>{ 'Choice__c' => 'Car' },
        new Map<String,Object>{ 'Choice__c' => 'Bike' },
        new Map<String,Object>{ 'Choice__c' => 'Ash' },
        new Map<String,Object>{ 'Choice__c' => null }
    },
    'Multi' => new List<Object>{
        new Map<String,Object>{ 'Modes__c' => 'Bus;Car' },
        new Map<String,Object>{ 'Modes__c' => 'Bus' },
        new Map<String,Object>{ 'Modes__c' => 'Car;Bike' }
    },
    'NoRows' => new List<Object>(),
    'Wrap' => new List<Object>{ new Map<String,Object>{ 'Answers' => new List<Object>{
        new Map<String,Object>{ 'Choice__c' => 'Inner' } } } }
});
`
};

/** Values only the org can supply, referenced by EQD / HASD rows. */
const DYN_SRC = `
DYN.put('user_name', UserInfo.getName());
DYN.put('user_email', UserInfo.getUserEmail());
DYN.put('user_id', String.valueOf(UserInfo.getUserId()));
DYN.put('today_iso', String.valueOf(Date.today()));
DYN.put('this_year', String.valueOf(Date.today().year()));
`;

function preamble(ctxKeys) {
    return [
        'Map<String, Map<String,Object>> CTX = new Map<String, Map<String,Object>>();',
        'Map<String,String> DYN = new Map<String,String>();',
        ...ctxKeys.map((k) => CTX_SRC[k]),
        DYN_SRC
    ].join('\n');
}

function casesApex(cases) {
    const rows = cases.map((c) => {
        const cols = [aq(c.id), aq(c.ctx), aq(c.xml), aq(c.mode), aq(c.exp)];
        if (c.flags) cols.push(aq(c.flags));
        return `new List<String>{${cols.join(',')}}`;
    });
    return `List<List<String>> CS = new List<List<String>>{\n${rows.join(',\n')}\n};`;
}

/* ------------------------------------------------------------------ *
 * THE CASES
 * ------------------------------------------------------------------ */

/* --- Batch 1: field resolution + built-in tags ------------------------ */
const B1 = [
    {
        id: 'PLAIN',
        name: '{Name} resolves a plain field',
        ctx: 'base',
        xml: '{Name}',
        mode: 'EQ',
        exp: 'Acme Corp',
        sev: BLOCKER
    },
    {
        id: 'PARENT_DOT',
        name: '{Account.Name} resolves a parent relationship field',
        ctx: 'base',
        xml: '{Account.Name}',
        mode: 'EQ',
        exp: 'Parent Co',
        sev: BLOCKER
    },
    {
        id: 'GRANDPARENT',
        name: '{Account.Owner.Name} resolves two hops up',
        ctx: 'base',
        xml: '{Account.Owner.Name}',
        mode: 'EQ',
        exp: 'Deep Owner',
        sev: MAJOR
    },
    {
        id: 'CASE_INSENS',
        name: '{name} resolves case-insensitively',
        ctx: 'base',
        xml: '{name}',
        mode: 'EQ',
        exp: 'Acme Corp',
        sev: MAJOR
    },
    {
        id: 'BANG_PREFIX',
        name: '{!Name} (Salesforce-style prefix) resolves like {Name}',
        ctx: 'base',
        xml: '{!Name}',
        mode: 'EQ',
        exp: 'Acme Corp',
        sev: MAJOR
    },
    // Authors paste tags out of a doc and leave spaces. The parser trims — if it
    // ever stops, every such template silently blanks out.
    {
        id: 'PADDED',
        name: '{ Name } tolerates whitespace inside the braces',
        ctx: 'base',
        xml: '{ Name }',
        mode: 'EQ',
        exp: 'Acme Corp',
        sev: MAJOR
    },
    // ---- unresolvable tags. The contract is "render nothing", never "render
    // the tag" — a leaked `{Field}` in a signed PDF is a customer-visible defect.
    {
        id: 'MISSING',
        name: '{Missing} (no such key) renders empty, not the raw tag',
        ctx: 'base',
        xml: '{Missing}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'NULL_VAL',
        name: '{NullF} (key present, value null) renders empty',
        ctx: 'base',
        xml: '{NullF}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'BLANK_VAL',
        name: '{Blank} (empty-string value) renders empty',
        ctx: 'base',
        xml: '{Blank}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'MISSING_SUB',
        name: '{Account.Missing} (missing subfield) renders empty',
        ctx: 'base',
        xml: '{Account.Missing}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'MISSING_REL',
        name: '{Nope.Sub} (missing relationship) renders empty, no throw',
        ctx: 'base',
        xml: '{Nope.Sub}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'MISSING_DEEP',
        name: '{Nope.A.B.C} (deep missing path) renders empty, no throw',
        ctx: 'base',
        xml: '{Nope.A.B.C}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'SURROUND',
        name: 'Text around an unresolved tag survives intact',
        ctx: 'base',
        xml: 'before {Missing} after',
        mode: 'EQ',
        exp: 'before  after',
        sev: MAJOR
    },
    {
        id: 'MULTI_TAG',
        name: 'Two tags in one text node both resolve',
        ctx: 'base',
        xml: '{Name}/{Stage}',
        mode: 'EQ',
        exp: 'Acme Corp/Won',
        sev: MAJOR
    },
    // ---- built-ins
    {
        id: 'TODAY_ISO',
        name: '{Today:yyyy-MM-dd} equals the org calendar date',
        ctx: 'base',
        xml: '{Today:yyyy-MM-dd}',
        mode: 'EQD',
        exp: 'today_iso',
        sev: BLOCKER
    },
    {
        id: 'TODAY_LONG',
        name: '{Today:MMMM d, yyyy} formats the date',
        ctx: 'base',
        xml: '{Today:MMMM d, yyyy}',
        mode: 'RE',
        exp: '^[A-Z][a-z]+ \\d{1,2}, \\d{4}$',
        sev: MAJOR
    },
    {
        id: 'TODAY_BARE',
        name: '{Today} renders a date containing the current year',
        ctx: 'base',
        xml: '{Today}',
        mode: 'HASD',
        exp: 'this_year',
        sev: MAJOR
    },
    {
        id: 'NOW_FMT',
        name: '{Now:yyyy-MM-dd HH:mm} formats a timestamp',
        ctx: 'base',
        xml: '{Now:yyyy-MM-dd HH:mm}',
        mode: 'RE',
        exp: '^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$',
        sev: MAJOR
    },
    {
        id: 'RU_NAME',
        name: '{RunningUser.Name} resolves the executing user',
        ctx: 'base',
        xml: '{RunningUser.Name}',
        mode: 'EQD',
        exp: 'user_name',
        sev: MAJOR
    },
    {
        id: 'RU_EMAIL',
        name: '{RunningUser.Email} resolves the executing user email',
        ctx: 'base',
        xml: '{RunningUser.Email}',
        mode: 'EQD',
        exp: 'user_email',
        sev: MAJOR
    },
    {
        id: 'RU_LOWER',
        name: '{runninguser.name} resolves case-insensitively',
        ctx: 'base',
        xml: '{runninguser.name}',
        mode: 'EQD',
        exp: 'user_name',
        sev: MINOR
    },
    // ProfileId is deliberately NOT in RUNNING_USER_FIELDS. Leaking it would be a
    // data-exposure bug, so "renders empty" is the assertion, not "renders an Id".
    {
        id: 'RU_DENY',
        name: '{RunningUser.ProfileId} (outside the allowlist) renders empty',
        ctx: 'base',
        xml: '{RunningUser.ProfileId}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'PAGENUM',
        name: '{PageNumber} survives processXml verbatim for the PDF counter layer',
        ctx: 'base',
        xml: '{PageNumber}',
        mode: 'EQ',
        exp: '{PageNumber}',
        sev: MAJOR
    },
    {
        id: 'TOTALPAGES',
        name: '{TotalPages} survives processXml verbatim',
        ctx: 'base',
        xml: '{TotalPages}',
        mode: 'EQ',
        exp: '{TotalPages}',
        sev: MAJOR
    },
    {
        id: 'PAGENUM_CASE',
        name: '{pagenumber} is preserved case-insensitively',
        ctx: 'base',
        xml: '{pagenumber}',
        mode: 'EQ',
        exp: '{pagenumber}',
        sev: MINOR
    },
    {
        id: 'PAGE_SENTENCE',
        name: '"Page {PageNumber} of {TotalPages}" passes through untouched',
        ctx: 'base',
        xml: 'Page {PageNumber} of {TotalPages}',
        mode: 'EQ',
        exp: 'Page {PageNumber} of {TotalPages}',
        sev: MAJOR
    }
];

/* --- Batch 2: format suffixes ---------------------------------------- */
const B2 = [
    {
        id: 'CUR_BARE',
        name: '{Amt:currency} formats US dollars with separators',
        ctx: 'base',
        xml: '{Amt:currency}',
        mode: 'EQ',
        exp: '$75,000.50',
        sev: BLOCKER
    },
    {
        id: 'CUR_EUR',
        name: '{Amt:currency:EUR} uses the euro symbol',
        ctx: 'base',
        xml: '{Amt:currency:EUR}',
        mode: 'HAS',
        exp: '€',
        sev: MAJOR
    },
    {
        id: 'CUR_EUR_DE',
        name: '{Amt:currency:EUR:de_DE} uses German separators',
        ctx: 'base',
        xml: '{Amt:currency:EUR:de_DE}',
        mode: 'HAS',
        exp: '75.000,50',
        sev: MAJOR
    },
    // JPY is a zero-decimal currency — rounding must happen, not truncation.
    {
        id: 'CUR_JPY',
        name: '{Amt:currency:JPY} rounds to zero decimals',
        ctx: 'base',
        xml: '{Amt:currency:JPY}',
        mode: 'HAS',
        exp: '75,001',
        sev: MAJOR
    },
    {
        id: 'CUR_AUTO',
        name: '{Amt:currency:auto} falls back to $ when no ISO is on the record',
        ctx: 'base',
        xml: '{Amt:currency:auto}',
        mode: 'HAS',
        exp: '$',
        sev: MAJOR
    },
    {
        id: 'PCT',
        name: '{Rate:percent} renders a percent sign',
        ctx: 'base',
        xml: '{Rate:percent}',
        mode: 'HAS',
        exp: '%',
        sev: MAJOR
    },
    {
        id: 'NUM',
        name: '{Qty:number} groups thousands',
        ctx: 'base',
        xml: '{Qty:number}',
        mode: 'EQ',
        exp: '1,234,567',
        sev: MAJOR
    },
    {
        id: 'NUM_PATTERN',
        name: '{Qty:#,##0} honours a custom numeric pattern',
        ctx: 'base',
        xml: '{Qty:#,##0}',
        mode: 'EQ',
        exp: '1,234,567',
        sev: MAJOR
    },
    {
        id: 'NUM_DEC',
        name: '{Amt:0.00} honours a two-decimal pattern',
        ctx: 'base',
        xml: '{Amt:0.00}',
        mode: 'EQ',
        exp: '75,000.50',
        sev: MAJOR
    },
    // A numeric format on non-numeric text must degrade to the raw value rather
    // than throwing mid-merge and killing the whole document.
    {
        id: 'NUM_ON_TEXT',
        name: '{Text:currency} on non-numeric text degrades to the raw value',
        ctx: 'base',
        xml: '{Text:currency}',
        mode: 'EQ',
        exp: 'not-a-number',
        sev: MAJOR
    },
    {
        id: 'CHK_TRUE',
        name: '{Active:checkbox} renders [X] when true',
        ctx: 'base',
        xml: '{Active:checkbox}',
        mode: 'EQ',
        exp: '[X]',
        sev: MAJOR
    },
    {
        id: 'CHK_FALSE',
        name: '{Inactive:checkbox} renders [ ] when false',
        ctx: 'base',
        xml: '{Inactive:checkbox}',
        mode: 'EQ',
        exp: '[ ]',
        sev: MAJOR
    },
    {
        id: 'DT_SLASH',
        name: '{D:MM/dd/yyyy} formats a DateTime',
        ctx: 'base',
        xml: '{D:MM/dd/yyyy}',
        mode: 'EQ',
        exp: '04/08/2026',
        sev: BLOCKER
    },
    {
        id: 'DT_LONG',
        name: '{D:MMMM d, yyyy} formats a DateTime long-form',
        ctx: 'base',
        xml: '{D:MMMM d, yyyy}',
        mode: 'EQ',
        exp: 'April 8, 2026',
        sev: MAJOR
    },
    {
        id: 'DT_TIME',
        name: '{D:HH:mm} formats the time component',
        ctx: 'base',
        xml: '{D:HH:mm}',
        mode: 'EQ',
        exp: '13:45',
        sev: MAJOR
    },
    {
        id: 'DT_LOCALE_DE',
        name: '{D:date:de_DE} uses the German date pattern',
        ctx: 'base',
        xml: '{D:date:de_DE}',
        mode: 'EQ',
        exp: '08.04.2026',
        sev: MAJOR
    },
    {
        id: 'DT_LOCALE_DEF',
        name: '{D:date} renders a locale date, not an ISO timestamp',
        ctx: 'base',
        xml: '{D:date}',
        mode: 'NOT',
        exp: 'T13:45',
        sev: MAJOR
    },
    // Snapshot/cache JSON round-trips turn Date fields into "yyyy-MM-dd" strings.
    // The parser re-types them; if it regresses the raw string prints and, worse,
    // a timezone shift can move the day. Both are asserted.
    {
        id: 'DATESTR_FMT',
        name: '{DateStr:MM/dd/yyyy} re-types a "yyyy-MM-dd" string and formats it',
        ctx: 'base',
        xml: '{DateStr:MM/dd/yyyy}',
        mode: 'EQ',
        exp: '04/08/2026',
        sev: BLOCKER
    },
    {
        id: 'DATESTR_BARE',
        name: '{DateStr} on a date-string shows no 00:00:00 time tail',
        ctx: 'base',
        xml: '{DateStr}',
        mode: 'NOT',
        exp: ':',
        sev: MAJOR
    },
    {
        id: 'DATESTR_DAY',
        name: '{DateStr} keeps the calendar day (no timezone shift)',
        ctx: 'base',
        xml: '{DateStr}',
        mode: 'HAS',
        exp: '8',
        sev: BLOCKER
    },
    {
        id: 'ISOSTR_FMT',
        name: '{IsoStr:yyyy} re-types an ISO datetime string',
        ctx: 'base',
        xml: '{IsoStr:yyyy}',
        mode: 'EQ',
        exp: '2026',
        sev: MAJOR
    },
    {
        id: 'LABEL_FALLBACK',
        name: '{Stage:label} falls back to the raw value with no label map',
        ctx: 'base',
        xml: '{Stage:label}',
        mode: 'EQ',
        exp: 'Won',
        sev: MAJOR
    },
    // ':upper' is NOT a supported suffix. Pinning the behaviour so we notice if
    // it ever starts printing ":upper" into the document instead of ignoring it.
    {
        id: 'UNKNOWN_SUFFIX',
        name: '{Name:upper} (unsupported suffix) is ignored, not printed',
        ctx: 'base',
        xml: '{Name:upper}',
        mode: 'EQ',
        exp: 'Acme Corp',
        sev: MINOR
    }
];

/* --- Batch 3: sections, loops, conditionals --------------------------- */
const B3 = [
    {
        id: 'LOOP',
        name: '{#Items}...{/Items} repeats the body once per row',
        ctx: 'items',
        xml: '{#Items}[{Name}]{/Items}',
        mode: 'EQ',
        exp: '[Item A][Item B][Item C]',
        sev: BLOCKER
    },
    {
        id: 'LOOP_EMPTY',
        name: '{#Items} over an empty list renders nothing and leaks no tag',
        ctx: 'items',
        xml: '{#Empty}[{Name}]{/Empty}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'LOOP_EMPTY_ELSE',
        name: '{#Empty}...{:else}... renders the else branch for 0 rows',
        ctx: 'items',
        xml: '{#Empty}x{:else}none{/Empty}',
        mode: 'EQ',
        exp: 'none',
        sev: MAJOR
    },
    {
        id: 'LOOP_WRAPPED',
        name: '{#Rel} iterates a {totalSize, records} relationship wrapper',
        ctx: 'items',
        xml: '{#Wrapped}[{Name}]{/Wrapped}',
        mode: 'EQ',
        exp: '[W1][W2]',
        sev: MAJOR
    },
    // A list of non-map entries (strings) must be skipped silently, not throw.
    {
        id: 'LOOP_SCALARS',
        name: '{#Rel} over non-record entries renders nothing rather than throwing',
        ctx: 'items',
        xml: '{#Strings}[x]{/Strings}',
        mode: 'BLANK',
        exp: '',
        sev: MINOR
    },
    // 60 rows crosses the every-50-iterations heap probe. No row may be dropped.
    {
        id: 'LOOP_MANY',
        name: '{#Rows} over 60 rows emits every row (crosses the heap-check boundary)',
        ctx: 'many',
        xml: '{#Rows}{N},{/Rows}',
        mode: 'LEN',
        exp: '171',
        sev: BLOCKER
    },
    {
        id: 'LOOP_MANY_LAST',
        name: '{#Rows} over 60 rows includes the last row',
        ctx: 'many',
        xml: '{#Rows}{N},{/Rows}',
        mode: 'HAS',
        exp: '60,',
        sev: BLOCKER
    },
    {
        id: 'LOOP_NESTED',
        name: 'Nested {#Orders}{#Lines} loops expand inner rows per outer row',
        ctx: 'nested',
        xml: '{#Orders}[{O}{#Lines}({L}){/Lines}]{/Orders}',
        mode: 'EQ',
        exp: '[O1(L1a)(L1b)][O2(L2a)]',
        sev: BLOCKER
    },
    // Documented limitation, pinned so a change is noticed: the loop body is
    // processed against the CHILD map only, so parent fields are not in scope.
    {
        id: 'LOOP_PARENT_SCOPE',
        name: 'A parent field inside {#Items} is out of scope (renders empty)',
        ctx: 'items',
        xml: '{#Items}[{Parent}]{/Items}',
        mode: 'EQ',
        exp: '[][][]',
        sev: MINOR
    },
    // {index}/{count} are ChartBucket-only variables; a plain child loop has no
    // row counter. Assert only that the literal tag does not leak.
    {
        id: 'LOOP_INDEX',
        name: '{index} inside a plain {#Items} loop leaks no literal tag',
        ctx: 'items',
        xml: '{#Items}[{index}]{/Items}',
        mode: 'NOT',
        exp: '{index}',
        sev: MINOR
    },
    {
        id: 'LOOP_COUNT',
        name: '{count} inside a plain {#Items} loop leaks no literal tag',
        ctx: 'items',
        xml: '{#Items}[{count}]{/Items}',
        mode: 'NOT',
        exp: '{count}',
        sev: MINOR
    },
    // ---- boolean / truthiness sections
    {
        id: 'SEC_TRUE',
        name: '{#Flag} shows the body when the field is true',
        ctx: 'items',
        xml: '{#Active}Yes{/Active}',
        mode: 'EQ',
        exp: 'Yes',
        sev: BLOCKER
    },
    {
        id: 'SEC_FALSE',
        name: '{#Flag} hides the body when the field is false',
        ctx: 'items',
        xml: '{#Inactive}Yes{/Inactive}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'SEC_STRING',
        name: '{#Field} treats a non-blank string as truthy',
        ctx: 'items',
        xml: '{#Name}Y{/Name}',
        mode: 'EQ',
        exp: 'Y',
        sev: MAJOR
    },
    {
        id: 'SEC_BLANK',
        name: '{#Field} treats an empty string as falsy',
        ctx: 'items',
        xml: '{#Blank}Y{/Blank}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    // Rich-text fields that "look empty" in the UI are <p><br></p> under the
    // hood — issue #48. Section and inverse must agree on that.
    {
        id: 'SEC_RICHBLANK',
        name: '{#Field} treats visually-blank rich text (<p><br></p>) as falsy',
        ctx: 'items',
        xml: '{#RichBlank}Y{/RichBlank}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'INV_RICHBLANK',
        name: '{^Field} shows for visually-blank rich text (symmetric with {#})',
        ctx: 'items',
        xml: '{^RichBlank}N{/RichBlank}',
        mode: 'EQ',
        exp: 'N',
        sev: MAJOR
    },
    {
        id: 'INV_FALSE',
        name: '{^Flag} shows the body when the field is false',
        ctx: 'items',
        xml: '{^Inactive}No{/Inactive}',
        mode: 'EQ',
        exp: 'No',
        sev: BLOCKER
    },
    {
        id: 'INV_TRUE',
        name: '{^Flag} hides the body when the field is true',
        ctx: 'items',
        xml: '{^Active}No{/Active}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'SEC_ELSE_T',
        name: '{#Flag}Y{:else}N{/Flag} takes the true branch',
        ctx: 'items',
        xml: '{#Active}Y{:else}N{/Active}',
        mode: 'EQ',
        exp: 'Y',
        sev: MAJOR
    },
    {
        id: 'SEC_ELSE_F',
        name: '{#Flag}Y{:else}N{/Flag} takes the else branch',
        ctx: 'items',
        xml: '{#Inactive}Y{:else}N{/Inactive}',
        mode: 'EQ',
        exp: 'N',
        sev: MAJOR
    },
    {
        id: 'INV_ELSE',
        name: '{^Flag}Y{:else}N{/Flag} takes the else branch when truthy',
        ctx: 'items',
        xml: '{^Active}Y{:else}N{/Active}',
        mode: 'EQ',
        exp: 'N',
        sev: MAJOR
    },
    {
        id: 'SEC_MAP',
        name: '{#Parent}{Field}{/Parent} scopes into a related map',
        ctx: 'base',
        xml: '{#Account}{Name}{/Account}',
        mode: 'EQ',
        exp: 'Parent Co',
        sev: MAJOR
    },
    // ---- {#IF ...} comparisons
    {
        id: 'IF_GT',
        name: '{#IF Amount > 10000} evaluates a numeric comparison',
        ctx: 'items',
        xml: '{#IF Amount > 10000}Big{/IF}',
        mode: 'EQ',
        exp: 'Big',
        sev: BLOCKER
    },
    {
        id: 'IF_GT_ENC',
        name: '{#IF Amount &gt; 10000} works with the OOXML-escaped operator',
        ctx: 'items',
        xml: '{#IF Amount &gt; 10000}Big{/IF}',
        mode: 'EQ',
        exp: 'Big',
        sev: BLOCKER
    },
    {
        id: 'IF_LT_FALSE',
        name: '{#IF Amount < 100} is false for a large value',
        ctx: 'items',
        xml: '{#IF Amount < 100}T{/IF}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'IF_EQ_SQ',
        name: "{#IF Stage = 'Won'} matches a single-quoted literal",
        ctx: 'items',
        xml: "{#IF Stage = 'Won'}C{/IF}",
        mode: 'EQ',
        exp: 'C',
        sev: MAJOR
    },
    {
        id: 'IF_EQ_DQ',
        name: '{#IF Stage = "Won"} matches a double-quoted literal',
        ctx: 'items',
        xml: '{#IF Stage = "Won"}C{/IF}',
        mode: 'EQ',
        exp: 'C',
        sev: MAJOR
    },
    {
        id: 'IF_NEQ',
        name: "{#IF Stage != 'Lost'} evaluates inequality",
        ctx: 'items',
        xml: "{#IF Stage != 'Lost'}A{/IF}",
        mode: 'EQ',
        exp: 'A',
        sev: MAJOR
    },
    {
        id: 'IF_AND',
        name: '{#IF a AND b} evaluates a conjunction',
        ctx: 'items',
        xml: "{#IF Amount > 10000 AND Stage = 'Won'}B{/IF}",
        mode: 'EQ',
        exp: 'B',
        sev: MAJOR
    },
    {
        id: 'IF_OR',
        name: '{#IF a OR b} evaluates a disjunction',
        ctx: 'items',
        xml: "{#IF Amount < 1 OR Stage = 'Won'}B{/IF}",
        mode: 'EQ',
        exp: 'B',
        sev: MAJOR
    },
    {
        id: 'IF_NOT',
        name: '{#IF NOT(...)} negates a comparison',
        ctx: 'items',
        xml: "{#IF NOT(Stage = 'Lost')}B{/IF}",
        mode: 'EQ',
        exp: 'B',
        sev: MAJOR
    },
    {
        id: 'IF_ELSE',
        name: '{#IF ...}{:else}... falls to the else branch on a missing field',
        ctx: 'items',
        xml: '{#IF Nope > 1}X{:else}Y{/IF}',
        mode: 'EQ',
        exp: 'Y',
        sev: MAJOR
    },
    {
        id: 'IF_NESTED',
        name: 'Nested {#IF} blocks pair with the right {/IF}',
        ctx: 'items',
        xml: "{#IF Amount > 10000}{#IF Stage = 'Won'}D{/IF}{/IF}",
        mode: 'EQ',
        exp: 'D',
        sev: MAJOR
    },
    {
        id: 'IF_IN_LOOP',
        name: 'A conditional inside a loop evaluates per row',
        ctx: 'items',
        xml: '{#Items}{#IF Amount > 99}[{Name}]{/IF}{/Items}',
        mode: 'EQ',
        exp: '[Item A][Item B]',
        sev: BLOCKER
    },
    // Word table rows: the loop must clone the whole <w:tr>, not just the cell.
    {
        id: 'ROW_EXPAND',
        name: 'A loop inside <w:tr> clones the whole table row per record',
        ctx: 'items',
        xml: '<w:tbl><w:tr><w:tc><w:t>{#Items}{Name}{/Items}</w:t></w:tc></w:tr></w:tbl>',
        mode: 'RE',
        exp: '(?s)<w:tr>.*<w:tr>.*<w:tr>',
        sev: BLOCKER
    },
    {
        id: 'ROW_EXPAND_DATA',
        name: 'A loop inside <w:tr> keeps every row value',
        ctx: 'items',
        xml: '<w:tbl><w:tr><w:tc><w:t>{#Items}{Name}{/Items}</w:t></w:tc></w:tr></w:tbl>',
        mode: 'HAS',
        exp: 'Item C',
        sev: BLOCKER
    }
];

/* --- Batch 4: aggregates, barcodes, images, assets -------------------- */
const B4 = [
    {
        id: 'AGG_SUM',
        name: '{SUM:Items.Amount} totals a child collection',
        ctx: 'items',
        xml: '{SUM:Items.Amount}',
        mode: 'EQ',
        exp: '350',
        sev: BLOCKER
    },
    {
        id: 'AGG_COUNT',
        name: '{COUNT:Items} counts a child collection',
        ctx: 'items',
        xml: '{COUNT:Items}',
        mode: 'EQ',
        exp: '3',
        sev: BLOCKER
    },
    {
        id: 'AGG_AVG',
        name: '{AVG:Items.Amount} averages a child collection',
        ctx: 'items',
        xml: '{AVG:Items.Amount}',
        mode: 'HAS',
        exp: '116',
        sev: MAJOR
    },
    {
        id: 'AGG_MIN',
        name: '{MIN:Items.Amount} returns the smallest value',
        ctx: 'items',
        xml: '{MIN:Items.Amount}',
        mode: 'EQ',
        exp: '50',
        sev: MAJOR
    },
    {
        id: 'AGG_MAX',
        name: '{MAX:Items.Amount} returns the largest value',
        ctx: 'items',
        xml: '{MAX:Items.Amount}',
        mode: 'EQ',
        exp: '200',
        sev: MAJOR
    },
    {
        id: 'AGG_LOWER',
        name: '{sum:Items.Amount} accepts a lower-case function name',
        ctx: 'items',
        xml: '{sum:Items.Amount}',
        mode: 'EQ',
        exp: '350',
        sev: MINOR
    },
    {
        id: 'AGG_FMT',
        name: '{SUM:Items.Amount:currency} applies a format suffix to the total',
        ctx: 'items',
        xml: '{SUM:Items.Amount:currency}',
        mode: 'EQ',
        exp: '$350.00',
        sev: MAJOR
    },
    // An aggregate over nothing must be 0, not blank — a blank cell in a totals
    // row reads as "we forgot", a 0 reads as "there is none".
    {
        id: 'AGG_EMPTY',
        name: '{COUNT:Empty} over an empty collection renders 0',
        ctx: 'items',
        xml: '{COUNT:Empty}',
        mode: 'EQ',
        exp: '0',
        sev: MAJOR
    },
    {
        id: 'AGG_SUM_EMPTY',
        name: '{SUM:Empty.Amount} over an empty collection renders 0',
        ctx: 'items',
        xml: '{SUM:Empty.Amount}',
        mode: 'EQ',
        exp: '0',
        sev: MAJOR
    },
    {
        id: 'AGG_MISSING_REL',
        name: '{COUNT:Nope} on a missing relationship renders 0, no throw',
        ctx: 'items',
        xml: '{COUNT:Nope}',
        mode: 'EQ',
        exp: '0',
        sev: MAJOR
    },
    {
        id: 'AGG_MISSING_FLD',
        name: '{SUM:Items.Nope} on a missing field renders 0, no throw',
        ctx: 'items',
        xml: '{SUM:Items.Nope}',
        mode: 'EQ',
        exp: '0',
        sev: MAJOR
    },
    // A colon tag whose head is not an aggregate function must be read as
    // {Field:format}, not silently swallowed.
    {
        id: 'AGG_NOT_FN',
        name: '{Nope:bar} (colon tag, unknown function) renders empty, not an error',
        ctx: 'items',
        xml: '{Nope:bar}',
        mode: 'BLANK',
        exp: '',
        sev: MINOR
    },
    // ---- barcodes: processXml emits the ##BARCODE:type:size:value## marker
    // that DocGenHtmlRenderer later rasterises.
    {
        id: 'BC_DEFAULT',
        name: '{*Field} defaults to a code128 barcode marker',
        ctx: 'base',
        xml: '{*Code}',
        mode: 'EQ',
        exp: '##BARCODE:code128::ABC-123&amp;X##',
        sev: MAJOR
    },
    {
        id: 'BC_QR',
        name: '{*Field:qr} emits a QR marker',
        ctx: 'base',
        xml: '{*Code:qr}',
        mode: 'EQ',
        exp: '##BARCODE:qr::ABC-123&amp;X##',
        sev: MAJOR
    },
    {
        id: 'BC_QR_SIZE',
        name: '{*Field:qr:200} carries the size through',
        ctx: 'base',
        xml: '{*Code:qr:200}',
        mode: 'EQ',
        exp: '##BARCODE:qr:200:ABC-123&amp;X##',
        sev: MAJOR
    },
    {
        id: 'BC_128_WH',
        name: '{*Field:code128:300x80} carries a WxH size through',
        ctx: 'base',
        xml: '{*Code:code128:300x80}',
        mode: 'EQ',
        exp: '##BARCODE:code128:300x80:ABC-123&amp;X##',
        sev: MAJOR
    },
    {
        id: 'BC_39',
        name: '{*Field:code39} emits a code39 marker',
        ctx: 'base',
        xml: '{*Code:code39}',
        mode: 'HAS',
        exp: '##BARCODE:code39::',
        sev: MAJOR
    },
    // The marker is XML — an unescaped & in the value would corrupt the part.
    {
        id: 'BC_ESCAPE',
        name: '{*Field} XML-escapes the barcode value',
        ctx: 'base',
        xml: '{*Code:qr}',
        mode: 'NOT',
        exp: '123&X',
        sev: BLOCKER
    },
    {
        id: 'BC_NULL',
        name: '{*NullF:qr} on a null value emits nothing',
        ctx: 'base',
        xml: '{*NullF:qr}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    // ---- images and shared assets
    {
        id: 'IMG_NULL',
        name: '{%Field} on a null image field emits nothing (no broken markup)',
        ctx: 'base',
        xml: '{%NullF}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'IMG_NULL_SIZED',
        name: '{%Field:200x100} on a null image field emits nothing',
        ctx: 'base',
        xml: '{%NullF:200x100}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'IMG_INDEX_NONE',
        name: '{%Image:1} with no attached image emits nothing',
        ctx: 'base',
        xml: '{%Image:1}',
        mode: 'BLANK',
        exp: '',
        sev: MAJOR
    },
    {
        id: 'ASSET_MISSING',
        name: '{%asset:key} for an unknown asset renders a visible placeholder',
        ctx: 'base',
        xml: '{%asset:dgqa_no_such_asset}',
        mode: 'HAS',
        exp: '[missing asset:',
        sev: MAJOR
    },
    // Authors write <img src="{%asset:logo}">. In attribute context the tag must
    // resolve to a URL, never expand into a whole nested <img> element.
    {
        id: 'ASSET_IN_SRC',
        name: '{%asset:key} inside src="" emits a URL, not a nested <img>',
        ctx: 'base',
        xml: '<img src="{%asset:dgqa_no_such_asset}">',
        mode: 'EQ',
        exp: '<img src="">',
        sev: MAJOR
    }
];

/* --- Batch 5: edge cases, escaping, lifecycle tags -------------------- */
const B5 = [
    // ---- XML escaping. An unescaped '<' in a field value produces a DOCX Word
    // refuses to open. This is the highest-consequence check in the suite.
    {
        id: 'ESC_LT',
        name: 'A value containing "<" is XML-escaped',
        ctx: 'base',
        xml: '{Xml}',
        mode: 'HAS',
        exp: '&lt;Widgets&gt;',
        sev: BLOCKER
    },
    {
        id: 'ESC_RAW',
        name: 'A value containing "<" leaves no raw markup in the output',
        ctx: 'base',
        xml: '{Xml}',
        mode: 'NOT',
        exp: '<Widgets>',
        sev: BLOCKER
    },
    {
        id: 'ESC_AMP',
        name: 'A value containing "&" is XML-escaped',
        ctx: 'base',
        xml: '{Xml}',
        mode: 'HAS',
        exp: '&amp;',
        sev: BLOCKER
    },
    {
        id: 'ESC_QUOTE',
        name: 'A value containing quotes is XML-escaped',
        ctx: 'base',
        xml: '{Xml}',
        mode: 'NOT',
        exp: '"Q1"',
        sev: MAJOR
    },
    {
        id: 'ESC_HREF',
        name: 'A tag inside href="" escapes the query-string ampersand',
        ctx: 'base',
        xml: '<a href="{Url}">x</a>',
        mode: 'HAS',
        exp: 'b=1&amp;c=2',
        sev: BLOCKER
    },
    {
        id: 'ESC_HREF_INTACT',
        name: 'A tag inside href="" keeps the attribute well-formed',
        ctx: 'base',
        xml: '<a href="{Url}">x</a>',
        mode: 'RE',
        exp: '^<a href="https://ex\\.test/a\\?b=1&amp;c=2">x</a>$',
        sev: MAJOR
    },
    // ---- payload shapes
    {
        id: 'UNICODE',
        name: 'A unicode + emoji value round-trips unchanged',
        ctx: 'base',
        xml: '{Uni}',
        mode: 'EQ',
        exp: 'Zürich 東京 😀',
        sev: MAJOR
    },
    {
        id: 'LONG_VALUE',
        name: 'A 4,000-character value is not truncated',
        ctx: 'base',
        xml: '{Long}',
        mode: 'LEN',
        exp: '4000',
        sev: BLOCKER
    },
    {
        id: 'MULTILINE',
        name: 'A multi-line value becomes Word line breaks, not literal newlines',
        ctx: 'base',
        xml: '<w:r><w:t>{Multi}</w:t></w:r>',
        mode: 'HAS',
        exp: '<w:br/>',
        sev: MAJOR
    },
    {
        id: 'MULTILINE_TEXT',
        name: 'A multi-line value keeps both lines',
        ctx: 'base',
        xml: '<w:r><w:t>{Multi}</w:t></w:r>',
        mode: 'HAS',
        exp: 'Line2',
        sev: MAJOR
    },
    // Template injection: a DATA value that looks like a tag must never be
    // re-parsed, or a record field could pull other records' data into the doc.
    {
        id: 'NO_REPARSE',
        name: 'A field value that looks like a merge tag is not re-parsed',
        ctx: 'base',
        xml: '{Inject}',
        mode: 'NOT',
        exp: 'LEAKED',
        sev: BLOCKER
    },
    {
        id: 'NO_REPARSE_LIT',
        name: 'A field value that looks like a merge tag renders literally',
        ctx: 'base',
        xml: '{Inject}',
        mode: 'EQ',
        exp: '{Secret}',
        sev: MAJOR
    },
    // ---- malformed templates: must fail LOUDLY with a message naming the tag,
    // never produce half a document.
    {
        id: 'ERR_UNCLOSED_BRACE',
        name: '{unclosed (no closing brace) throws a named error',
        ctx: 'base',
        xml: 'a {unclosed b',
        mode: 'THROW',
        exp: 'Malformed merge tag',
        sev: MAJOR
    },
    {
        id: 'ERR_UNCLOSED_LOOP',
        name: '{#Items} with no {/Items} throws a named error',
        ctx: 'items',
        xml: '{#Items}{Name}',
        mode: 'THROW',
        exp: 'missing closing',
        sev: MAJOR
    },
    {
        id: 'ERR_UNCLOSED_INV',
        name: '{^Flag} with no {/Flag} throws a named error',
        ctx: 'items',
        xml: '{^Active}x',
        mode: 'THROW',
        exp: 'Malformed inverse',
        sev: MAJOR
    },
    {
        id: 'ERR_NAMES_TAG',
        name: 'A malformed-loop error names the offending tag',
        ctx: 'items',
        xml: '{#Items}{Name}',
        mode: 'THROW',
        exp: 'Items',
        sev: MINOR
    },
    {
        id: 'EMPTY_TAG',
        name: '{} (empty tag) renders nothing and does not throw',
        ctx: 'base',
        xml: 'a{}b',
        mode: 'EQ',
        exp: 'ab',
        sev: MINOR
    },
    // A stray closer is template-author error, and the engine's answer is
    // DELIBERATE: emit it literally so the author sees their typo in the output.
    // The sibling case proves it is a policy and not an accident — an unmatched
    // OPENER ({#NoClose}) is emitted literally too, and DocGenMiscTests has a
    // named test for each. Silently swallowing a malformed section tag would
    // lose content with no signal at all, which is the worse failure.
    //
    // Pinned here so that if anyone ever changes it, it is a decision rather
    // than a regression. If the call is revisited, the fix is at
    // DocGenService.cls `} else if (tagContent.startsWith('/'))`.
    {
        id: 'ORPHAN_CLOSE',
        name: '{/Orphan} with no opener is emitted literally so the author sees the typo',
        ctx: 'base',
        xml: 'a{/Orphan}b',
        mode: 'EQ',
        exp: 'a{/Orphan}b',
        sev: MAJOR
    },
    // Follows from the same policy plus normal literal passthrough: the scanner
    // consumes `{{nested}` as one (unresolvable, therefore empty) tag and the
    // trailing brace is ordinary text. Pinned rather than "fixed" for the same
    // reason as ORPHAN_CLOSE.
    {
        id: 'DOUBLE_BRACE',
        name: '{{nested}} resolves the inner tag to empty and passes the trailing brace through',
        ctx: 'base',
        xml: '{{nested}}',
        mode: 'EQ',
        exp: '}',
        sev: MINOR
    },
    {
        id: 'DOUBLE_BRACE_NAME',
        name: '{{nested}} does not print the inner tag name',
        ctx: 'base',
        xml: '{{nested}}',
        mode: 'NOT',
        exp: 'nested',
        sev: MINOR
    },
    // ---- Word splits a tag across runs whenever the author changes formatting
    // mid-tag. mergeRunsInTags is the pre-merge defragmenter every path calls.
    {
        id: 'SPLIT_MERGED',
        name: 'A tag split across <w:r> runs resolves after run de-fragmentation',
        ctx: 'base',
        xml: '<w:r><w:t>{Na</w:t></w:r><w:r><w:t>me}</w:t></w:r>',
        mode: 'HAS',
        exp: 'Acme Corp',
        sev: BLOCKER,
        flags: 'MERGE'
    },
    {
        id: 'SPLIT_FMT_MERGED',
        name: 'A tag with a format suffix split across runs resolves',
        ctx: 'base',
        xml: '<w:r><w:t>{Amt:cur</w:t></w:r><w:r><w:t>rency}</w:t></w:r>',
        mode: 'HAS',
        exp: '$75,000.50',
        sev: MAJOR,
        flags: 'MERGE'
    },
    {
        id: 'SPLIT_RAW',
        name: 'A split tag does NOT resolve without de-fragmentation (documents the dependency)',
        ctx: 'base',
        xml: '<w:r><w:t>{Na</w:t></w:r><w:r><w:t>me}</w:t></w:r>',
        mode: 'NOT',
        exp: 'Acme Corp',
        sev: MINOR
    },
    // {RepeatHeader} is consumed pre-merge by applyRepeatHeaderMarkers, which
    // mergeRunsInTagsForTest wraps — so both halves are testable here.
    {
        id: 'RH_MARKER',
        name: '{RepeatHeader} injects <w:tblHeader/> into its table row',
        ctx: 'base',
        xml: '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>{RepeatHeader}Head</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
        mode: 'HAS',
        exp: '<w:tblHeader/>',
        sev: MAJOR,
        flags: 'MERGE'
    },
    {
        id: 'RH_STRIPPED',
        name: '{RepeatHeader} text is stripped from the rendered row',
        ctx: 'base',
        xml: '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>{RepeatHeader}Head</w:t></w:r></w:p></w:tc></w:tr></w:tbl>',
        mode: 'NOT',
        exp: 'RepeatHeader',
        sev: MAJOR,
        flags: 'MERGE'
    },
    {
        id: 'RH_NO_LEAK',
        name: '{RepeatHeader} never renders as literal text even without a table row',
        ctx: 'base',
        xml: 'x{RepeatHeader}y',
        mode: 'EQ',
        exp: 'xy',
        sev: MAJOR
    },
    // ---- signing lifecycle tags
    {
        id: 'SIG_STRIPPED',
        name: '{@Signature_X} is stripped during normal generation',
        ctx: 'base',
        xml: 'a{@Signature_Buyer}b',
        mode: 'EQ',
        exp: 'ab',
        sev: BLOCKER
    },
    {
        id: 'SIG_PRESERVED',
        name: '{@Signature_X} is preserved when preserveSignatureTags is on',
        ctx: 'base',
        xml: '{@Signature_Buyer}',
        mode: 'EQ',
        exp: '{@Signature_Buyer}',
        sev: MAJOR,
        flags: 'SIG'
    },
    {
        id: 'FF_PRESERVED',
        name: '{?key} is preserved until the finalize re-render',
        ctx: 'ff',
        xml: '{?title}',
        mode: 'EQ',
        exp: '{?title}',
        sev: MAJOR
    },
    {
        id: 'FF_RESOLVED',
        name: '{?key} resolves from __formFields at finalize',
        ctx: 'ff',
        xml: '{?title}',
        mode: 'EQ',
        exp: 'CTO',
        sev: MAJOR,
        flags: 'FF'
    },
    {
        id: 'FF_FALLBACK',
        name: '{?key|fallback} uses the fallback when unanswered',
        ctx: 'ff',
        xml: '{?nope|N/A}',
        mode: 'EQ',
        exp: 'N/A',
        sev: MAJOR,
        flags: 'FF'
    },
    {
        id: 'FF_ESCAPED',
        name: '{?key} XML-escapes the collected value',
        ctx: 'ff',
        xml: '{?xml}',
        mode: 'HAS',
        exp: '&lt;b&gt;',
        sev: BLOCKER,
        flags: 'FF'
    }
];

/* --- Batch 6: {#ChartBucket} in-memory path --------------------------- */
const B6 = [
    {
        id: 'CB_KEYS',
        name: '{#ChartBucket:rel:field} buckets by value, sorted desc by count',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{key}:{count}]{/ChartBucket}',
        mode: 'EQ',
        exp: '[Bus:3][Car:2][Ash:1][Bike:1][:1]',
        sev: BLOCKER
    },
    {
        id: 'CB_TIE_ORDER',
        name: '{#ChartBucket} breaks count ties alphabetically by key',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}{key},{/ChartBucket}',
        mode: 'HAS',
        exp: 'Ash,Bike,',
        sev: MAJOR
    },
    {
        id: 'CB_PERCENT',
        name: '{percent} is the share of all rows',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{percent}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[37.5]',
        sev: MAJOR
    },
    {
        id: 'CB_MAXPCT',
        name: '{max_percent} is 100 for the largest bucket',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{max_percent}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[100.0]',
        sev: MAJOR
    },
    {
        id: 'CB_MAXPCT_REL',
        name: '{max_percent} scales the runner-up against the largest bucket',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{max_percent}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[66.7]',
        sev: MAJOR
    },
    {
        id: 'CB_INDEX',
        name: '{index} is a 1-based bucket counter',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}{index},{/ChartBucket}',
        mode: 'EQ',
        exp: '1,2,3,4,5,',
        sev: MAJOR
    },
    {
        id: 'CB_COLOR',
        name: '{color} cycles the default palette starting at #3b82f6',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{color}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[#3b82f6]',
        sev: MAJOR
    },
    // Word's w:shd w:fill rejects a leading '#', which is why color_hex exists.
    {
        id: 'CB_COLORHEX',
        name: '{color_hex} emits raw hex with no leading # (for Word w:shd)',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{color_hex}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[3b82f6]',
        sev: MAJOR
    },
    {
        id: 'CB_KEYLABEL',
        name: '{key_label} labels a null/blank bucket "Not Specified"',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{key_label}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Not Specified]',
        sev: MAJOR
    },
    {
        id: 'CB_NULLKEY',
        name: '{key} for a null value is empty, not the "__null__" sentinel',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{key}]{/ChartBucket}',
        mode: 'NOT',
        exp: '__null__',
        sev: BLOCKER
    },
    {
        id: 'CB_COLORS_MOD',
        name: 'colors= overrides the palette, cycling by row index',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c:colors=#111111,#222222}[{color}]{/ChartBucket}',
        mode: 'EQ',
        exp: '[#111111][#222222][#111111][#222222][#111111]',
        sev: MAJOR
    },
    {
        id: 'CB_SPLIT_MOD',
        name: 'split=; splits multi-select values per respondent',
        ctx: 'chart',
        xml: '{#ChartBucket:Multi:Modes__c:split=;}[{key}:{count}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bus:2]',
        sev: MAJOR
    },
    {
        id: 'CB_SPLIT_ALL',
        name: 'split=; counts every selection, not just the first',
        ctx: 'chart',
        xml: '{#ChartBucket:Multi:Modes__c:split=;}[{key}:{count}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bike:1]',
        sev: MAJOR
    },
    {
        id: 'CB_SPLIT_NO_COMBO',
        name: 'split=; produces no combined "Bus;Car" bucket',
        ctx: 'chart',
        xml: '{#ChartBucket:Multi:Modes__c:split=;}[{key}]{/ChartBucket}',
        mode: 'NOT',
        exp: 'Bus;Car',
        sev: BLOCKER
    },
    {
        id: 'CB_COMBO_MODS',
        name: 'colors= and split= compose in one tag',
        ctx: 'chart',
        xml: '{#ChartBucket:Multi:Modes__c:split=;&colors=#111111}[{key}{color}]{/ChartBucket}',
        mode: 'HAS',
        exp: '#111111',
        sev: MAJOR
    },
    {
        id: 'CB_EMPTY',
        name: '{#ChartBucket} over an empty collection renders nothing, leaks no tag',
        ctx: 'chart',
        xml: 'x{#ChartBucket:NoRows:Choice__c}[{key}]{/ChartBucket}y',
        mode: 'EQ',
        exp: 'xy',
        sev: MAJOR
    },
    // A chart inside a loop must resolve against the ITERATION item, not the
    // outer record — that is the whole reason preprocessInline defers nested tags.
    {
        id: 'CB_NESTED',
        name: '{#ChartBucket} nested inside a loop resolves against the iteration item',
        ctx: 'chart',
        xml: '{#Wrap}{#ChartBucket:Answers:Choice__c}[{key}]{/ChartBucket}{/Wrap}',
        mode: 'EQ',
        exp: '[Inner]',
        sev: MAJOR
    },
    {
        id: 'CB_MISSING_REL',
        name: '{#ChartBucket} on an unknown relationship renders nothing, no throw',
        ctx: 'chart',
        xml: 'x{#ChartBucket:Nope:Choice__c}[{key}]{/ChartBucket}y',
        mode: 'EQ',
        exp: 'xy',
        sev: MAJOR
    },
    {
        id: 'CB_MISSING_FLD',
        name: '{#ChartBucket} on an unknown field buckets everything as blank, no throw',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Nope__c}[{key}:{count}]{/ChartBucket}',
        mode: 'HAS',
        exp: ':8]',
        sev: MINOR
    },
    {
        id: 'CB_MALFORMED',
        name: '{#ChartBucket:onlyOneArg} fails loudly instead of rendering garbage',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers}[{key}]{/ChartBucket}',
        mode: 'THROW',
        exp: '',
        sev: MINOR
    },
    {
        id: 'CB_TWO_CHARTS',
        name: 'Two {#ChartBucket} tags on one page each get their own bucket list',
        ctx: 'chart',
        xml: '{#ChartBucket:Answers:Choice__c}[{key}]{/ChartBucket}|{#ChartBucket:Multi:Modes__c}[{key}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bus;Car]',
        sev: MAJOR
    }
];

/* ------------------------------------------------------------------ *
 * Batch 7 — {#ChartBucket} SOQL-fallback modifiers.
 *
 * `where=`, `groupBy=` and `colSort=` all FORCE the SOQL aggregate path, which
 * needs a real parent Id and a real child relationship. So this batch creates a
 * disposable Account + 5 Contacts, runs the tags, and deletes them again. Both
 * a pre-clean and a finally-clean run so an aborted transaction cannot leave
 * fixtures behind.
 *
 * Contacts: Title x Department
 *   Bus/Eng, Bus/Eng, Bus/Sales, Car/Sales, Bike/Eng
 * ------------------------------------------------------------------ */
const CHART_FIXTURE = `
List<Account> stale = [SELECT Id FROM Account WHERE Name = 'DGQA ChartBucket Parent' LIMIT 50];
if (!stale.isEmpty()) { delete stale; }
Account qaAcct = new Account(Name = 'DGQA ChartBucket Parent');
insert qaAcct;
insert new List<Contact>{
    new Contact(LastName = 'QA1', AccountId = qaAcct.Id, Title = 'Bus', Department = 'Eng'),
    new Contact(LastName = 'QA2', AccountId = qaAcct.Id, Title = 'Bus', Department = 'Eng'),
    new Contact(LastName = 'QA3', AccountId = qaAcct.Id, Title = 'Bus', Department = 'Sales'),
    new Contact(LastName = 'QA4', AccountId = qaAcct.Id, Title = 'Car', Department = 'Sales'),
    new Contact(LastName = 'QA5', AccountId = qaAcct.Id, Title = 'Bike', Department = 'Eng')
};
CTX.put('rec', new Map<String,Object>{ 'Id' => qaAcct.Id, 'Name' => qaAcct.Name });
`;

const CHART_CLEANUP = `
try {
    List<Account> done = [SELECT Id FROM Account WHERE Name = 'DGQA ChartBucket Parent' LIMIT 50];
    if (!done.isEmpty()) { delete done; }
} catch (Exception ce) {
    System.debug('T_CHART_CLEANUP=0~~clean~~' + ce.getMessage());
}
`;

const B7 = [
    // No relationship on the data map at all → the resolver must schema-discover
    // Account→Contacts and aggregate server-side. This is how 30K-row templates work.
    {
        id: 'SQ_PLAIN',
        name: '{#ChartBucket} falls back to a SOQL aggregate when the relationship is not pre-loaded',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title}[{key}:{count}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bus:3]',
        sev: BLOCKER
    },
    {
        id: 'SQ_PLAIN_ALL',
        name: 'The SOQL fallback returns every bucket, not just the largest',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title}[{key}:{count}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bike:1]',
        sev: MAJOR
    },
    {
        id: 'SQ_WHERE',
        name: 'where= filters the aggregate server-side',
        ctx: 'rec',
        xml: "{#ChartBucket:Contacts:Title:where=Department='Eng'}[{key}:{count}]{/ChartBucket}",
        mode: 'HAS',
        exp: '[Bus:2]',
        sev: MAJOR
    },
    {
        id: 'SQ_WHERE_EXCL',
        name: 'where= excludes non-matching rows entirely',
        ctx: 'rec',
        xml: "{#ChartBucket:Contacts:Title:where=Department='Eng'}[{key}]{/ChartBucket}",
        mode: 'NOT',
        exp: '[Car]',
        sev: BLOCKER
    },
    // An unsanitary WHERE must produce empty buckets, never run.
    {
        id: 'SQ_WHERE_INJECT',
        name: 'where= with an injection attempt renders nothing rather than running',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title:where=Name != null; DELETE Contact}[{key}]{/ChartBucket}',
        mode: 'BLANK',
        exp: '',
        sev: BLOCKER
    },
    {
        id: 'SQ_GROUPBY',
        name: 'groupBy= builds a cross-tab with a {#cols} sub-list',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title:groupBy=Department}[{key}{#cols}({key}:{count}){/cols}]{/ChartBucket}',
        mode: 'HAS',
        exp: '[Bus(',
        sev: MAJOR
    },
    {
        id: 'SQ_GROUPBY_CELL',
        name: 'groupBy= counts the right cell (Bus x Eng = 2)',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title:groupBy=Department}[{key}{#cols}({key}:{count}){/cols}]{/ChartBucket}',
        mode: 'HAS',
        exp: '(Eng:2)',
        sev: BLOCKER
    },
    {
        id: 'SQ_GROUPBY_TOTAL',
        name: 'groupBy= appends a synthetic Total column last',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title:groupBy=Department}[{key}{#cols}({key}:{count}){/cols}]{/ChartBucket}',
        mode: 'HAS',
        exp: '(Total:3)]',
        sev: MAJOR
    },
    {
        id: 'SQ_COLSORT',
        name: 'colSort= orders the pivot columns as the author named them',
        ctx: 'rec',
        xml: '{#ChartBucket:Contacts:Title:groupBy=Department&colSort=Sales,Eng}[{#cols}({key}){/cols}]{/ChartBucket}',
        mode: 'HAS',
        exp: '(Sales)(Eng)(Total)',
        sev: MAJOR
    },
    {
        id: 'SQ_BAD_FIELD',
        name: '{#ChartBucket} on a field the child object lacks renders nothing, no throw',
        ctx: 'rec',
        xml: 'x{#ChartBucket:Contacts:NoSuchField__c:where=Name != null}[{key}]{/ChartBucket}y',
        mode: 'EQ',
        exp: 'xy',
        sev: MAJOR
    }
];

/* ------------------------------------------------------------------ *
 * Execution
 * ------------------------------------------------------------------ */

/** Pull the first thing that looks like a compile/runtime failure out of a log. */
function apexFailure(log) {
    const s = String(log || '');
    const m =
        /(Compile error[^\n]*)/i.exec(s) ||
        /(Unexpected token[^\n]*)/i.exec(s) ||
        /(System\.LimitException[^\n]*)/.exec(s) ||
        /(FATAL_ERROR[^\n]*)/.exec(s) ||
        /(Error:\s*[^\n]*)/.exec(s);
    return m ? m[1].trim().slice(0, 200) : '';
}

/** Turn one probe row + the debug map into a Check. */
function toCheck(map, c) {
    const raw = map['T_' + c.id];
    if (raw === undefined) {
        return skip(c.name, `the probe printed no T_${c.id} line — the Apex batch did not reach this case`, c.sev);
    }
    const i1 = raw.indexOf('~~');
    const i2 = raw.indexOf('~~', i1 + 2);
    if (i1 === -1 || i2 === -1) {
        return skip(c.name, `unparseable probe line for T_${c.id}: ${raw.slice(0, 160)}`, c.sev);
    }
    const ok = raw.slice(0, i1) === '1';
    const expected = raw.slice(i1 + 2, i2);
    const actual = raw.slice(i2 + 2);
    return check(c.name, ok, ok ? `actual: ${actual}` : `expected [${expected}] — actual: [${actual}]`, c.sev);
}

/**
 * Run one batch. Never throws: a CLI failure or a non-compiling probe becomes
 * one failing "batch ran" check plus a skip per case, so the report says the
 * evidence is missing instead of quietly reporting a smaller 100%.
 */
async function runBatch(org, label, ctxKeys, cases, { fixture = '', cleanup = '' } = {}) {
    const apex = [preamble(ctxKeys), fixture, casesApex(cases), RUNNER, cleanup].filter(Boolean).join('\n');
    // Debug hook: `DGQA_DUMP=/tmp npm run qa -- --suite merge-tags` writes the
    // generated Apex so a compile error can be read (and re-run) directly.
    if (process.env.DGQA_DUMP) {
        try {
            writeFileSync(`${process.env.DGQA_DUMP}/merge-tags-${label.replace(/[^a-z0-9]+/gi, '-')}.apex`, apex);
        } catch (e) {
            /* diagnostics only — never let the dump break the run */
        }
    }
    const checks = [];
    let log = '';
    try {
        log = await runAnonymous(org, apex, { timeout: 300000 });
    } catch (e) {
        checks.push(
            check(
                `merge-tag probe "${label}" executed`,
                false,
                `sf apex run failed: ${String(e.message).slice(0, 180)}`,
                MAJOR
            )
        );
        for (const c of cases) checks.push(skip(c.name, `batch "${label}" could not run`, c.sev));
        return { checks, chars: apex.length };
    }
    const map = debugMap(log);
    const reported = cases.filter((c) => map['T_' + c.id] !== undefined).length;
    if (reported === 0) {
        checks.push(
            check(
                `merge-tag probe "${label}" executed`,
                false,
                `no results came back — ${apexFailure(log) || 'the anonymous Apex block produced no T_ output'}`,
                MAJOR
            )
        );
    }
    for (const c of cases) checks.push(toCheck(map, c));
    if (map['T_CHART_CLEANUP'] !== undefined) {
        checks.push(
            check(
                'ChartBucket SOQL fixtures were cleaned up',
                false,
                `test Account/Contacts may remain in the org: ${map['T_CHART_CLEANUP']}`,
                MINOR
            )
        );
    }
    return { checks, chars: apex.length };
}

export async function run({ org }) {
    if (!org) return suiteSkipped('merge-tags', 'Merge tags', 'no target org was supplied');

    const batches = [
        ['fields+built-ins', ['base'], B1, {}],
        ['formats', ['base'], B2, {}],
        ['sections+loops', ['base', 'items', 'many', 'nested'], B3, {}],
        ['aggregates+media', ['base', 'items'], B4, {}],
        ['edge cases', ['base', 'items', 'ff'], B5, {}],
        ['chart buckets (in-memory)', ['chart'], B6, {}],
        ['chart buckets (SOQL modifiers)', [], B7, { fixture: CHART_FIXTURE, cleanup: CHART_CLEANUP }]
    ];

    const checks = [];
    try {
        for (const [label, ctxKeys, cases, opts] of batches) {
            const r = await runBatch(org, label, ctxKeys, cases, opts);
            // Anonymous Apex hard-caps at 20,000 characters. A batch that grows
            // past it fails with an opaque CLI error, so surface the size as a
            // first-class check rather than letting a future edit break silently.
            checks.push(
                check(
                    `probe "${label}" stays under the 20,000-char anonymous Apex limit`,
                    r.chars < 19000,
                    `${r.chars} chars`,
                    MINOR
                )
            );
            checks.push(...r.checks);
        }
    } catch (e) {
        // Belt and braces — the contract is that a suite never throws.
        checks.push(
            check('merge-tags suite completed', false, `unexpected error: ${String(e.message).slice(0, 200)}`, MAJOR)
        );
    }

    // Coverage the public test seam simply cannot reach. Reported as skips so
    // the report shows them as gaps in the evidence, not as passes.
    checks.push(
        skip(
            'HTML-template escaping ({Field} newline → <br/>) behaves correctly',
            'processXmlForTest(xml, data, templateType) is @TestVisible private and unreachable from anonymous Apex, so every check here runs the Word branch; HTML/Excel/PowerPoint escaping needs a unit test or a real HTML template render',
            MAJOR
        ),
        skip(
            '{PageNumber}/{TotalPages} render real page numbers in the PDF',
            'processXml only preserves the tokens; the @page counter substitution happens in wrapHtmlForPdf and can only be verified on a rendered PDF (output-formats suite)',
            MAJOR
        ),
        skip(
            '{%ImageField} with a real ContentVersion renders an embedded image',
            'needs an uploaded ContentVersion fixture and a real DOCX/PDF render; covered by scripts/e2e-09-images.apex, not by this parser-level probe',
            MAJOR
        ),
        skip(
            'The giant-query parent path resolves the same tag surface',
            'DocGenGiantQueryAssembler.resolveParentMergeTags / resolveGiantChartBuckets do not go through processXmlForTest and need >2000 child rows to exercise',
            MAJOR
        )
    );

    return suiteResult('merge-tags', 'Merge tags', checks);
}
