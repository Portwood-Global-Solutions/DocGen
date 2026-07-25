/**
 * WHAT IS ACTUALLY ON THE PAGE — the giant-query path, asserted by reading the PDF.
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * Two regressions have SHIPPED in this area, and both produced a PDF that every
 * existing check called healthy:
 *
 *   v2.5.0 (#134/#135) — templates over the ~2000-child-row giant-query
 *     threshold rendered ONLY their data rows. Title, the text above the table,
 *     the column headers and the footer were all silently dropped. The file was
 *     a valid PDF of a plausible size. Nothing noticed.
 *   v2.9.0 — the header stopped repeating on page 2+ of a giant table, so a
 *     68-page document had column headings on page 1 only.
 *
 * Neither is detectable from bytes. Both are obvious the moment you read the
 * text off the page, which is what this does.
 *
 * The dataset is >2000 children ON PURPOSE — that is the branch under test.
 * Below the threshold DocGen takes the ordinary path and none of this applies,
 * so a cheaper seed would test the wrong code.
 */
import { runAnonymous, debugMap, soql } from '../lib/sf.mjs';
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';
import { available, pdfText, pagesContaining, textHas } from '../lib/pdf.mjs';

/** Crossing the ~2000-child-row giant-query threshold with room to spare. */
const CHILD_ROWS = 2100;
const PREFIX = 'PDFQA';

/** Strings the template puts on the page, each guarding a different piece of chrome. */
const TITLE = 'PDFQA Master Roster';
const INTRO = 'This paragraph sits above the table';
const COL_HEADER = 'Contact Full Name';
const FOOTER_MARK = 'PDFQA confidential footer';
const HEADER_MARK = 'PDFQA running header';

const SEED = `
Integer WANT = ${CHILD_ROWS};
String NAME = '${PREFIX} Giant Account';

// Idempotent: reuse the account and its children when they already exist.
// Re-seeding 2,100 contacts on every run is slow and pointless, and deleting
// them costs more governor budget than creating them.
List<Account> accts = [SELECT Id FROM Account WHERE Name = :NAME LIMIT 1];
Account a;
if (accts.isEmpty()) { a = new Account(Name = NAME, Industry = 'Technology'); insert a; }
else { a = accts[0]; }

Integer have = [SELECT COUNT() FROM Contact WHERE AccountId = :a.Id];
if (have < WANT) {
    List<Contact> rows = new List<Contact>();
    for (Integer i = have; i < WANT; i++) {
        rows.add(new Contact(
            AccountId = a.Id,
            FirstName = 'Row' + i,
            LastName = '${PREFIX}-' + String.valueOf(1000000 + i),
            Title = 'Title ' + Math.mod(i, 40),
            Email = 'row' + i + '@pdfqa.example.com'
        ));
    }
    // AllowSave on the duplicate-rule header. The standard Contact duplicate
    // rule fires on synthetic rows that share an account and a name pattern,
    // and the insert dies partway through ("DUPLICATES_DETECTED ... first
    // exception on row 200"). That is the org's matching rule doing its job on
    // test data, not anything about DocGen — but it stops the seed dead, so the
    // whole suite reports a blocker for a reason that has no bearing on it.
    Database.DMLOptions dml = new Database.DMLOptions();
    dml.DuplicateRuleHeader.AllowSave = true;
    dml.OptAllOrNone = true;
    Database.insert(rows, dml);
}

// A template whose chrome is entirely distinguishable from its data, so a
// missing piece names itself rather than blending into the rows.
String body =
    '<!DOCTYPE html><html><head><meta charset="utf-8"/><style>' +
    '@page { size: Letter portrait; margin: 0.7in; }' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 9pt; }' +
    'h1 { font-size: 15pt; }' +
    'table { border-collapse: collapse; width: 100%; }' +
    'th, td { border: 0.5pt solid #999; padding: 3pt 5pt; text-align: left; }' +
    'thead { display: table-header-group; }' +
    '</style></head><body>' +
    '<h1>${TITLE}</h1>' +
    '<p>${INTRO} and must survive the giant-query path.</p>' +
    '<table><thead><tr>' +
    '<th>${COL_HEADER}</th><th>Job Title</th><th>Email Address</th>' +
    '</tr></thead><tbody>' +
    '{#Contacts}<tr><td>{FirstName} {LastName}</td><td>{Title}</td><td>{Email}</td></tr>{/Contacts}' +
    '</tbody></table></body></html>';

String tname = '${PREFIX} Giant Chrome';
delete [SELECT Id FROM DocGen_Template__c WHERE Name = :tname];
DocGen_Template__c t = new DocGen_Template__c(
    Name = tname,
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Base_Object_API__c = 'Account',
    // V3 NODE TREE, not the V1 flat string. The flat form
    // ('Name, Contacts.FirstName, ...') is accepted without complaint and
    // generates a document whose title, intro and column headers are all
    // correct — and whose <tbody> is EMPTY. It fails as a silently childless
    // document, not as an error, which is precisely the failure mode this
    // suite exists to catch. Child collections need a node with lookupField
    // and relationshipName.
    Query_Config__c =
        '{"v":3,"root":"Account","nodes":[' +
        '{"id":"n0","object":"Account","fields":["Name"],' +
        '"parentNode":null,"lookupField":null,"relationshipName":null},' +
        '{"id":"n1","object":"Contact","fields":["FirstName","LastName","Title","Email"],' +
        '"parentNode":"n0","lookupField":"AccountId","relationshipName":"Contacts",' +
        '"orderBy":"LastName ASC"}]}',
    Is_Active__c = true,
    Test_Record_Id__c = a.Id,
    Header_Html__c = '<div style="font-size:8pt;">${HEADER_MARK}</div>',
    Footer_Html__c = '<div style="font-size:8pt;">${FOOTER_MARK} — page {PageNumber} of {TotalPages}</div>'
);
insert t;
ContentVersion cv = new ContentVersion(
    Title = 'pdfqa_giant_body', PathOnClient = 'giant.html',
    VersionData = Blob.valueOf(body), FirstPublishLocationId = t.Id
);
insert cv;
cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
insert new DocGen_Template_Version__c(Template__c = t.Id, Content_Version_Id__c = cv.Id, Is_Active__c = true);

System.debug('ACCT=' + a.Id);
System.debug('TPL=' + t.Id);
System.debug('KIDS=' + [SELECT COUNT() FROM Contact WHERE AccountId = :a.Id]);
`;

const GENERATE = (tplId, acctId) => `
Long t0 = System.currentTimeMillis();
Map<String, Object> r = DocGenService.processDocument('${tplId}', '${acctId}', null, null);
Blob pdf = (Blob) r.get('blob');
System.debug('MS=' + (System.currentTimeMillis() - t0));
System.debug('BYTES=' + pdf.size());
System.debug('CPU=' + Limits.getCpuTime());
// WHICH PATH RAN. The giant-query branch is chosen on an ESTIMATED HEAP
// (DocGenController: estimatedPeak > safeHeapBytes), not on a row count — the
// "~2000 rows" in the docs is a description of when that usually happens, not
// the test. Its signature in the output is the -fs-table-paginate CSS, which
// only the giant/HTML-backed assembler injects. Without knowing this, a header
// that does not repeat looks like a regression when it is simply a different
// code path that never promised one.
String h = DocGenService.lastRenderedHtml;
System.debug('PAGINATE=' + (h != null && h.contains('-fs-table-paginate')));
System.debug('ROWS=' + (h == null ? 0 : h.split('<tr').size() - 1));
// Handed back through a ContentVersion: a multi-hundred-KB base64 string does
// not survive the debug log, which truncates and would corrupt the PDF.
ContentVersion out = new ContentVersion(
    Title = 'pdfqa_giant_output', PathOnClient = 'giant.pdf', VersionData = pdf
);
insert out;
System.debug('OUTCV=' + out.Id);
`;

export async function run({ org }) {
    const checks = [];
    const add = (c) => checks.push(c);

    if (!(await available())) {
        return suiteResult('pdf-content', 'PDF content', [
            skip(
                'the generated PDF contains its title, headers and footer',
                'pdftotext (poppler) is not installed, so nothing here can read the page. ' +
                    'Install it (brew install poppler) to enable these checks — they are the only ones ' +
                    'that would have caught the v2.5.0 missing-chrome regression.',
                SEVERITY.MAJOR
            )
        ]);
    }

    // ---- seed -----------------------------------------------------------
    let ids;
    try {
        ids = debugMap(await runAnonymous(org, SEED, { timeout: 900000 }));
    } catch (e) {
        return suiteResult('pdf-content', 'PDF content', [
            check('the giant dataset seeds', false, String(e.message).slice(0, 200), SEVERITY.BLOCKER)
        ]);
    }
    if (!ids.TPL || !ids.ACCT) {
        return suiteResult('pdf-content', 'PDF content', [
            check('the giant dataset seeds', false, `seed printed no ids (KIDS=${ids.KIDS})`, SEVERITY.BLOCKER)
        ]);
    }
    add(
        check(
            'the dataset is large enough to exercise multi-page rendering',
            Number(ids.KIDS) > 2000,
            // Deliberately NOT called "crosses the giant-query threshold".
            // There is no row threshold: DocGenController picks the giant branch
            // when estimatedPeak > safeHeapBytes, so 2,100 slim rows stay on the
            // ordinary path. Naming this check after a row count would assert a
            // rule the product does not have, and quietly mislabel every result
            // below it.
            `${ids.KIDS} child rows across many pages (the giant branch is chosen on estimated heap, not on this count)`,
            SEVERITY.BLOCKER
        )
    );

    // ---- generate -------------------------------------------------------
    let gen;
    try {
        gen = debugMap(await runAnonymous(org, GENERATE(ids.TPL, ids.ACCT), { timeout: 900000 }));
    } catch (e) {
        return suiteResult('pdf-content', 'PDF content', [
            ...checks,
            check('the giant template generates', false, String(e.message).slice(0, 200), SEVERITY.BLOCKER)
        ]);
    }
    if (!gen.OUTCV) {
        return suiteResult('pdf-content', 'PDF content', [
            ...checks,
            check('the giant template generates', false, 'no PDF was produced', SEVERITY.BLOCKER)
        ]);
    }
    add(
        check(
            'the giant template generates',
            Number(gen.BYTES) > 10000,
            `${gen.BYTES} bytes in ${gen.MS}ms (CPU ${gen.CPU}ms of 10000)`,
            SEVERITY.BLOCKER
        )
    );

    // The synchronous CPU ceiling is the real limit on this path, and a run that
    // creeps toward it is a warning worth having BEFORE a customer's dataset
    // grows past it.
    const cpu = Number(gen.CPU || 0);
    add(
        check(
            'the giant render leaves CPU headroom',
            cpu < 8000,
            `${cpu}ms of the 10000ms synchronous limit (${Math.round((cpu / 10000) * 100)}%) at ${ids.KIDS} rows`,
            SEVERITY.MINOR
        )
    );

    // ---- read the page --------------------------------------------------
    const rows = await soql(org, `SELECT VersionData FROM ContentVersion WHERE Id = '${gen.OUTCV}'`);
    if (!rows.length) {
        add(skip('the PDF could be read back', 'the output ContentVersion could not be queried', SEVERITY.MAJOR));
        return suiteResult('pdf-content', 'PDF content', checks);
    }
    // soql returns VersionData as a REST path, not bytes — fetch it.
    let pdf;
    try {
        const { sf } = await import('../lib/sf.mjs');
        const raw = await sf(['org', 'display', '--target-org', org, '--json'], { retries: 1 });
        const info = JSON.parse(raw).result;
        const url = `${info.instanceUrl}/services/data/v62.0/sobjects/ContentVersion/${gen.OUTCV}/VersionData`;
        const res = await fetch(url, { headers: { Authorization: `Bearer ${info.accessToken}` } });
        pdf = Buffer.from(await res.arrayBuffer());
    } catch (e) {
        add(skip('the PDF could be read back', String(e.message).slice(0, 160), SEVERITY.MAJOR));
        return suiteResult('pdf-content', 'PDF content', checks);
    }

    const { pages, text, pageCount } = await pdfText(pdf);
    add(
        check(
            'the giant document spans many pages',
            pageCount > 15,
            `${pageCount} pages from ${ids.KIDS} rows`,
            SEVERITY.MAJOR
        )
    );

    // ---- the v2.5.0 regression, one check per piece of chrome ------------
    // Separate checks on purpose: when the assembler dropped the chrome it
    // dropped ALL of it, and a single bundled check would have said "chrome
    // missing" without saying which part or which code path to look at.
    add(
        check(
            'the document title survives the giant-query path',
            textHas(text, TITLE),
            textHas(text, TITLE)
                ? `"${TITLE}" is on the page`
                : `"${TITLE}" is MISSING — the giant path is emitting data rows without the template chrome (#134)`,
            SEVERITY.BLOCKER
        )
    );
    add(
        check(
            'text above the table survives the giant-query path',
            textHas(text, INTRO),
            textHas(text, INTRO) ? 'intro paragraph present' : 'the paragraph above the table was dropped (#134)',
            SEVERITY.BLOCKER
        )
    );
    add(
        check(
            'the column headers are rendered',
            textHas(text, COL_HEADER),
            textHas(text, COL_HEADER)
                ? `"${COL_HEADER}" present`
                : 'the table rendered with no column headings at all (#135)',
            SEVERITY.BLOCKER
        )
    );

    // ---- v2.9.0: the header must repeat, but ONLY where it was promised ----
    // Conditional on the path that actually ran. v2.9.0 injects
    // -fs-table-paginate for giant/HTML-backed tables so a Word-authored header
    // repeats; the ordinary path does not, and `thead { display:
    // table-header-group }` alone is not enough to make Flying Saucer repeat it.
    // Asserting the repeat unconditionally reported the ordinary path as a
    // v2.9.0 regression — a confident, specific and entirely wrong accusation.
    const headerPages = pagesContaining(pages, COL_HEADER);
    if (gen.PAGINATE === 'true') {
        add(
            check(
                'the table header repeats on later pages (giant path)',
                headerPages > 1,
                headerPages > 1
                    ? `column headings on ${headerPages} of ${pageCount} pages`
                    : `column headings appear on ${headerPages} page only, but -fs-table-paginate WAS injected — ` +
                          'the v2.9.0 repeating-header behaviour has regressed',
                SEVERITY.MAJOR
            )
        );
    } else {
        add(
            skip(
                'the table header repeats on later pages (giant path)',
                `this render took the ORDINARY path — no -fs-table-paginate in the output, ${gen.ROWS} rows in ` +
                    'one table — so per-page headers were never promised for it, and the headings correctly ' +
                    `appear on ${headerPages} of ${pageCount} pages. The giant branch is chosen on an estimated ` +
                    'HEAP, not a row count, so slim rows never reach it however many there are. Covering the ' +
                    'repeat needs a seed whose rows are fat enough to cross that estimate.',
                SEVERITY.MINOR
            )
        );
    }

    // ---- running header / footer on every page ---------------------------
    const footerPages = pagesContaining(pages, 'confidential footer');
    add(
        check(
            'the footer appears on every page',
            footerPages === pageCount,
            `footer on ${footerPages} of ${pageCount} pages`,
            SEVERITY.MAJOR
        )
    );
    const headerMarkPages = pagesContaining(pages, 'running header');
    add(
        check(
            'the running header appears on every page',
            headerMarkPages === pageCount,
            `header on ${headerMarkPages} of ${pageCount} pages`,
            SEVERITY.MAJOR
        )
    );

    // ---- page numbering --------------------------------------------------
    // {PageNumber}/{TotalPages} compile to Flying Saucer counters. If they fail
    // they leave the literal tag on the page, which is worse than absent —
    // every page of a customer's document shows "{PageNumber}".
    const leaked = textHas(text, '{PageNumber}') || textHas(text, '{TotalPages}');
    add(
        check(
            'page-number tags resolve rather than printing literally',
            !leaked,
            leaked ? 'the literal {PageNumber}/{TotalPages} tag is printed on the page' : 'counters resolved',
            SEVERITY.MAJOR
        )
    );
    add(
        check(
            'the footer reports the true page total',
            textHas(text, `of ${pageCount}`),
            textHas(text, `of ${pageCount}`)
                ? `footer says "of ${pageCount}", matching the actual page count`
                : `the footer's total does not match the ${pageCount} pages actually rendered`,
            SEVERITY.MAJOR
        )
    );

    // ---- the data itself --------------------------------------------------
    // Chrome can be perfect while the rows are empty or unmerged.
    const firstRow = textHas(text, `${PREFIX}-1000000`);
    const anyEmail = textHas(text, '@pdfqa.example.com');
    add(
        check(
            'merged child data is on the page',
            firstRow && anyEmail,
            // Named separately. A single shared message reported "first seeded
            // row and an email address both present" on a FAILING check, which
            // is worse than no evidence at all — it says the opposite of what
            // happened.
            firstRow && anyEmail
                ? 'first seeded row and an email address both present'
                : `the table body rendered no child rows (firstRow=${firstRow}, anyEmail=${anyEmail}) — ` +
                      'chrome can be perfect while the loop emits nothing',
            SEVERITY.BLOCKER
        )
    );
    const unresolved = /\{[A-Za-z#/][^}\n]{0,40}\}/.exec(text.replace(/\{PageNumber\}|\{TotalPages\}/g, ''));
    add(
        check(
            'no unresolved merge tag is printed',
            !unresolved,
            unresolved ? `a raw tag reached the page: ${unresolved[0]}` : 'no raw tags on the page',
            SEVERITY.BLOCKER
        )
    );
    // The LAST row matters as much as the first: a truncated loop still renders
    // a document that looks entirely correct until someone counts.
    add(
        check(
            'the last child row is present, not truncated',
            textHas(text, `${PREFIX}-${1000000 + CHILD_ROWS - 1}`),
            textHas(text, `${PREFIX}-${1000000 + CHILD_ROWS - 1}`)
                ? `row ${CHILD_ROWS} of ${CHILD_ROWS} rendered`
                : `the final row (${PREFIX}-${1000000 + CHILD_ROWS - 1}) is missing — the loop truncated`,
            SEVERITY.BLOCKER
        )
    );

    // ---- teardown ---------------------------------------------------------
    // Output only. The account and its 2,100 contacts are deliberately kept:
    // re-seeding them each run is slow, and the seed is idempotent.
    await runAnonymous(
        org,
        `Database.delete([SELECT Id FROM ContentDocument WHERE Id IN
       (SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'pdfqa_giant_output')], false);`
    ).catch(() => {});

    return suiteResult('pdf-content', 'PDF content', checks);
}
