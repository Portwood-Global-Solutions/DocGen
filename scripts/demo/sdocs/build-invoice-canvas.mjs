// ============================================================================
// Builds the Canvas invoice body for the SDocs demo.
//
//   node scripts/demo/sdocs/build-invoice-canvas.mjs
//     -> "DEMO TEMPLATES/html/prof-services/project-invoice.canvas.html"
//
// WHY THIS IS GENERATED RATHER THAN HAND-WRITTEN
// ----------------------------------------------
// A Canvas template body is not free-form HTML — it is the exact contract that
// canvasModel.deserialize() reads back. Hand-writing it produces markup that
// RENDERS but does not re-open as editable boxes, which is the one thing the
// Canvas designer is for. Building the model and running the SHIPPED serializer
// means the body is, by construction, something the editor can round-trip.
//
// This is the same discipline scripts/qa/canvas-serializer-check.mjs uses.
// ============================================================================
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '..', '..', '..');
const OUT = path.join(REPO_ROOT, 'DEMO TEMPLATES', 'html', 'prof-services', 'project-invoice.canvas.html');

// The LWC is an ES module already; copying it out lets Node import it without a
// bundler and without the '@salesforce/*' resolution the component itself never uses.
const modelSrc = path.join(REPO_ROOT, 'force-app', 'main', 'default', 'lwc', 'docGenCanvas', 'canvasModel.js');
const tmp = path.join(REPO_ROOT, 'node_modules', '.canvasModel.invoice.mjs');
mkdirSync(path.dirname(tmp), { recursive: true });
writeFileSync(tmp, readFileSync(modelSrc, 'utf8'));
const m = await import(tmp + '?v=' + Date.now());

// ---------------------------------------------------------------------------
// Palette. Flat hex only — rgba() renders NOTHING in Flying Saucer.
// ---------------------------------------------------------------------------
const NAVY = '#12324f';
const GOLD = '#c9a227';
const INK = '#1a2733';
const MUTED = '#6b7c8f';
const LABEL = '#8496a8';
const ONNAVY = '#ffffff';
const ONNAVY_DIM = '#b8cbe0';
const RULE = '#dde5ee';
const TINT = '#f4f7fb';

// BOLD DOES NOT RENDER IN THIS ENGINE. DO NOT BUILD HIERARCHY OUT OF WEIGHT.
//
// Measured on the real PDF at 260dpi, not assumed. The totals row carries
// `font-weight: bold` and came out at exactly the same weight as the data row
// above it; so did every section heading. An inline `<b>`, and a `<b>` with its
// own explicit `font-weight: bold`, were equally ineffective. The property is
// present in the markup at every one of those sites.
//
// Switching the whole document to 'Arial Unicode MS' — the one FONT_CHOICES entry
// documented to embed a bold face — did NOT fix it either, and grew the PDF from
// 9.5KB to 85KB by embedding the font. Reverted: the Unicode face bought nothing
// here, because the ·, — and – glyphs this document uses already render under the
// generic family.
//
// So hierarchy in this template comes from SIZE, COLOUR and FILL BANDS: the navy
// letterhead, the navy table headers reversed to white, the tinted subtotal row,
// the solid navy AMOUNT DUE band. That reads as designed rather than as a
// weightless document — which is what relying on bold would have produced.
const FONT = 'sans-serif';

const geo = m.pageGeometry('Letter', 'Portrait');
const doc = m.blankDocument();
const page1 = doc.artboards[0];
doc.artboards.push(m.newArtboard());
const page2 = doc.artboards[1];

// The invoice number has no field behind it — the demo org has no invoice object,
// so it is derived from the project code. Stated here once so it stays consistent
// across the header, the appendix and the remittance line.
const INVOICE_NO = 'INV-{Project_Code__c}-08';

// ---------------------------------------------------------------------------
// Small builders. Each returns the box so callers can tweak and push.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// TEXT BOXES ARE AUTHORED AS `html`, NOT `text`. THIS IS NOT A STYLE CHOICE.
//
// A canvas text box's plain-text `text` field runs through expandMarks(), and the
// underline mark is `__ … __`. Every Salesforce relationship and custom field
// carries a double underscore, so a box reading
//
//     {Client__r.Name} … {Client_Contact__r.FirstName}
//
// has its two `__` paired off as an underline span and serializes as
//
//     {Client<u>r.Name} … {Client_Contact</u>r.FirstName}
//
// which is no longer a merge tag. It round-trips back into the editor intact
// (collapseMarks is a faithful inverse), so the damage is invisible on the canvas
// and only shows up as an unresolved tag in the PDF.
//
// `textToHtml` returns box.html verbatim when it is set — the path the shipped
// rich-text editor already writes — so authoring the markup directly skips mark
// expansion entirely. `text` is still populated as the plain-text fallback.
// ---------------------------------------------------------------------------
function escHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function text(board, x, y, w, h, body, style = {}, extra = {}) {
    const b = m.newTextBox(x, y, w, h);
    b.text = body;
    b.html = escHtml(body).replace(/\n/g, '<br />');
    Object.assign(b.style, { font: FONT }, style);
    Object.assign(b, extra);
    board.boxes.push(b);
    return b;
}

/**
 * A text box whose markup is written by hand rather than escaped from plain text.
 *
 * The `<b>` it carries is honest intent, not a working effect — see the note on FONT
 * above. It is left in because it is what an author would write and it costs nothing;
 * the line does not depend on it to read correctly.
 */
function richText(board, x, y, w, h, markup, style = {}, extra = {}) {
    const b = m.newTextBox(x, y, w, h);
    b.html = markup;
    b.text = markup.replace(/<[^>]+>/g, '');
    Object.assign(b.style, { font: FONT }, style);
    Object.assign(b, extra);
    board.boxes.push(b);
    return b;
}

function shape(board, x, y, w, h, shapeProps, z = 0) {
    const b = m.newShapeBox(x, y, w, h);
    Object.assign(b.shape, shapeProps);
    b.z = z;
    board.boxes.push(b);
    return b;
}

function table(board, x, y, w, cfg) {
    const b = m.newTableBox(x, y, w);
    Object.assign(b.table, cfg);
    Object.assign(b.style, { font: FONT });
    if (cfg.mode) {
        b.mode = cfg.mode;
    }
    board.boxes.push(b);
    return b;
}

// A key/value block, drawn as an unheaded table so the two columns stay aligned
// however long the merged value turns out to be.
function keyValue(board, x, y, w, rows, opts = {}) {
    return table(board, x, y, w, {
        mode: opts.mode || 'pinned',
        showHeader: false,
        relationship: '',
        gridStyle: 'rows',
        gridColor: RULE,
        gridWidth: 0.5,
        cellPadding: 5,
        rows,
        totals: opts.totals || { enabled: false, cells: [] },
        totalsFill: opts.totalsFill || TINT,
        totalsText: { size: 11, color: NAVY, bold: true, align: 'left', ...(opts.totalsText || {}) },
        rowText: { size: 9.5, color: INK, bold: false, align: 'left' },
        columns: [
            { label: '', tag: '', width: opts.labelWidth || '46%' },
            { label: '', tag: '', width: opts.valueWidth || '54%' }
        ]
    });
}

// ===========================================================================
// LAYOUT IS PACED FOR THE CANVAS, NOT FOR THE PDF. THIS IS DELIBERATE.
//
// The canvas lays out RAW MERGE TAGS; the PDF lays out MERGED VALUES. Those are
// different lengths, so the two disagree about how tall every box is, and the
// disagreement is large: measured on this document, the canvas rendered ~13.5in
// of content for an 11in page. `{Schedule_Impact_Days__c}` is 25 characters on
// the canvas and `14` in the PDF.
//
// Nothing in the editor reconciles that — `newTableBox` hardcodes `h: 1` and no
// code path ever measures a box and writes its real height back, so snap guides
// (which align to `y + h`) and flow gaps (`y - (prev.y + prev.h)`) are both
// computed from numbers that are 2-5x too small.
//
// So the H values below are CANVAS-MEASURED, read straight off the live editor
// with getBoundingClientRect, and the boxes are stacked against them. The PDF
// renders shorter than every one of them, which is why the output is airier than
// a PDF-first layout would be. That is the trade: an author can actually see
// where things go.
//
// Two structural cuts were needed to fit 11in at canvas scale, both of which
// also improve the PDF:
//   - column widths sized so no TAG wraps (a wrapped tag triples a row's height
//     on the canvas while changing the PDF not at all)
//   - the change-order 'Schedule impact days' column dropped entirely; its tag is
//     longer than any column an invoice appendix should give a 1-2 digit number
// ===========================================================================

// Canvas-measured heights, in inches. Re-measure with the snippet in
// docs/ if the type sizes or column widths here change.
const H = {
    band1: 1.51,
    rule: 0.06,
    mark: 0.32,
    coName: 0.35,
    coAddr: 0.58,
    wordmark: 0.45,
    invNo: 0.58,
    label: 0.35,
    billTo: 1.75,
    details: 2.26,
    badge: 0.45,
    section: 0.35,
    lineItems: 2.69,
    due: 1.26,
    remit: 1.43,
    band2: 0.74,
    intro: 0.58,
    changeOrders: 3.05,
    reconcile: 1.89,
    sigFull: 0.67,
    sigDate: 0.56,
    sigName: 0.8,
    qr: 1.52,
    footer: 0.8
};

// ===========================================================================
// PAGE 1 — the invoice
// ===========================================================================

// --- letterhead ------------------------------------------------------------
shape(page1, 0, 0, 8.5, 1.45, { type: 'rect', fill: NAVY, borderWidth: 0 }, 0);
shape(page1, 0, 1.45, 8.5, H.rule, { type: 'rect', fill: GOLD, borderWidth: 0 }, 1);

// Wordmark. A shape + type rather than an image asset on purpose: the demo org
// has no Portwood Asset uploaded, and {%asset:...} that does not resolve throws
// at generation rather than degrading.
shape(page1, 0.6, 0.42, 0.26, 0.26, { type: 'rect', fill: GOLD, borderWidth: 0 }, 2);
text(
    page1,
    0.98,
    0.34,
    4.4,
    H.coName,
    'Portwood Professional Services',
    { size: 16, bold: true, color: ONNAVY },
    { z: 2 }
);
text(
    page1,
    0.6,
    0.74,
    4.6,
    H.coAddr,
    '1200 Market Street, Suite 400 · Seattle, WA 98104\n(206) 555-0180 · billing@portwoodps.example · EIN 91-0000000',
    { size: 8.5, color: ONNAVY_DIM },
    { z: 2 }
);
text(page1, 5.2, 0.26, 2.7, H.wordmark, 'INVOICE', { size: 28, bold: true, color: ONNAVY, align: 'right' }, { z: 2 });
text(page1, 5.2, 0.82, 2.7, H.invNo, INVOICE_NO + '\nIssued {Today:date}', {
    size: 9.5,
    color: ONNAVY_DIM,
    align: 'right'
});

// --- bill to ---------------------------------------------------------------
text(page1, 0.6, 1.6, 3.4, H.label, 'BILL TO', { size: 8, bold: true, color: LABEL });
text(
    page1,
    0.6,
    1.98,
    3.6,
    H.billTo,
    '{Client__r.Name}\n{Client_Contact__r.FirstName} {Client_Contact__r.LastName} — {Client_Contact__r.Title}\n' +
        '{Client__r.BillingStreet}\n{Client__r.BillingCity}, {Client__r.BillingState} {Client__r.BillingPostalCode}',
    { size: 10, color: INK }
);

// --- invoice details -------------------------------------------------------
// Four rows, not five. 'Engagement lead' was the fifth; it now rides on the
// remittance line, which already names who prepared the invoice. Dropping it
// bought the ~0.5in that lets the badge below clear this block on the canvas.
//
// The 52% label column is sized so 'Payment terms' and 'Service period' sit on
// one line — a wrapped label costs a full row of height on the canvas.
text(page1, 4.55, 1.6, 3.35, H.label, 'INVOICE DETAILS', { size: 8, bold: true, color: LABEL });
const details = keyValue(
    page1,
    4.55,
    1.98,
    3.35,
    [
        ['Invoice date', '{Today:date}'],
        ['Payment terms', 'Net 30'],
        ['Service period', '{Start_Date__c:date} – {Target_Completion__c:date}'],
        ['Project', '{Project_Code__c} · {Name}']
    ],
    { labelWidth: '38%', valueWidth: '62%' }
);
details.h = H.details;

// --- billing-basis badge, shown by condition -------------------------------
// {#IF} doing something an invoice genuinely needs rather than a contrived demo
// of it: a progress bill and a final bill are not the same document.
//
// Full width and BELOW both columns, so it clears whichever of them runs longer.
const progress = text(
    page1,
    0.6,
    4.34,
    7.3,
    H.badge,
    'PROGRESS INVOICE · {Percent_Complete__c}% complete · {Phase__c}',
    { size: 8.5, bold: true, color: NAVY, fill: TINT, padding: 5 }
);
progress.condition = 'Percent_Complete__c < 100';

// --- line items ------------------------------------------------------------
text(page1, 0.6, 4.9, 5, H.section, 'PROFESSIONAL SERVICES — MILESTONE BILLING', {
    size: 10,
    bold: true,
    color: NAVY
});

// FLOW, not pinned. A pinned table is clipped at the artboard edge the moment
// the milestone list outgrows the page; only a flow box paginates.
//
// Column widths are set by the LONGEST TAG, not by the merged value. '#' at 6%
// wrapped `{Sequence__c}` onto three lines and nearly doubled the table's canvas
// height for a column that prints a single digit. 12% costs the PDF almost
// nothing and halves what the author has to look at.
const lineItems = table(page1, 0.6, 5.3, 7.3, {
    relationship: 'Milestones__r',
    showHeader: true,
    headerFill: NAVY,
    gridStyle: 'rows',
    gridColor: RULE,
    gridWidth: 0.75,
    cellPadding: 4,
    headerText: { size: 9.5, color: ONNAVY, bold: true, align: 'left' },
    rowText: { size: 9.5, color: INK, bold: false, align: 'left' },
    totalsFill: TINT,
    totalsText: { size: 10.5, color: NAVY, bold: true, align: 'left' },
    columns: [
        { label: '#', tag: '{Sequence__c}', width: '12%' },
        { label: 'Milestone', tag: '{Name}', width: '34%' },
        { label: 'Accepted', tag: '{Completed_Date__c:date}', width: '21%' },
        { label: 'Status', tag: '{Status__c}', width: '14%' },
        { label: 'Amount', tag: '{Value__c:currency}', width: '19%' }
    ],
    totals: {
        enabled: true,
        cells: ['', 'Subtotal — professional services', '', '', '{SUM:Milestones__r.Value__c:currency}']
    }
});
lineItems.h = H.lineItems;

// --- amount due ------------------------------------------------------------
// The AMOUNT DUE repeats the milestone SUM rather than adding anything to it.
// That is deliberate and it is why the change orders live in an appendix: the
// merge engine has aggregate tags but no arithmetic BETWEEN them, so a total
// built from two SUMs could not be made to add up. One tag, one number, exact.
//
// 3.8in wide, not 3.35 — `{SUM:Milestones__r.Value__c:currency}` is 36 characters
// and wrapped to two lines in the narrower panel, on every one of its three rows.
const due = keyValue(
    page1,
    3.9,
    8.12,
    4.0,
    [['Milestones invoiced to date', '{SUM:Milestones__r.Value__c:currency}']],
    {
        mode: 'flow',
        labelWidth: '40%',
        valueWidth: '60%',
        totals: { enabled: true, cells: ['AMOUNT DUE', '{SUM:Milestones__r.Value__c:currency}'] },
        totalsFill: NAVY,
        totalsText: { size: 11, color: ONNAVY, bold: true, align: 'left' }
    }
);
due.h = H.due;

// --- remittance ------------------------------------------------------------
// The standalone footnote that used to sit under this is now its last line.
// Two boxes did not fit the canvas page; one does, and it reads no differently.
richText(
    page1,
    0.6,
    9.52,
    7.3,
    H.remit,
    '<b>Remit payment to</b> — Portwood Professional Services · Cascadia First Bank<br />' +
        'ACH / wire · Routing 125000024 · Account 8842019773 · Reference ' +
        INVOICE_NO +
        '<br />Engagement lead {Project_Manager__c} · billing@portwoodps.example · (206) 555-0180<br />' +
        'Amounts in USD. Milestones are invoiced on client acceptance. Approved change orders are listed in Appendix A.',
    { size: 9, color: INK, fill: TINT, padding: 8 },
    { mode: 'flow' }
);

// ===========================================================================
// PAGE 2 — Appendix A
// ===========================================================================
shape(page2, 0, 0, 8.5, 0.68, { type: 'rect', fill: NAVY, borderWidth: 0 }, 0);
shape(page2, 0, 0.68, 8.5, 0.04, { type: 'rect', fill: GOLD, borderWidth: 0 }, 1);
text(page2, 0.6, 0.19, 5, H.coName, 'Appendix A — Approved change orders', {
    size: 14,
    bold: true,
    color: ONNAVY
});
text(page2, 5.2, 0.26, 2.7, H.label, INVOICE_NO, { size: 9.5, color: ONNAVY_DIM, align: 'right' });

text(
    page2,
    0.6,
    1.0,
    7.3,
    H.intro,
    'The change orders below were approved during the engagement and are already reflected in the ' +
        'revised contract value. They are listed for reference.',
    { size: 9.5, color: MUTED }
);

// Four columns, not five. The dropped one was 'Days' bound to
// {Schedule_Impact_Days__c} — 25 characters of tag for a 1-2 digit value, which
// wrapped to three lines in any column width an invoice would give it and made
// this the tallest box in the document (5.2in on canvas against 1.7in in the PDF).
const changeOrders = table(page2, 0.6, 1.72, 7.3, {
    relationship: 'Change_Orders__r',
    showHeader: true,
    headerFill: NAVY,
    gridStyle: 'rows',
    gridColor: RULE,
    gridWidth: 0.75,
    cellPadding: 5,
    headerText: { size: 9.5, color: ONNAVY, bold: true, align: 'left' },
    rowText: { size: 9.5, color: INK, bold: false, align: 'left' },
    totalsFill: TINT,
    totalsText: { size: 10.5, color: NAVY, bold: true, align: 'left' },
    columns: [
        { label: 'Change order', tag: '{Name}', width: '15%' },
        { label: 'Requested', tag: '{Request_Date__c:date}', width: '21%' },
        { label: 'Description', tag: '{Description__c}', width: '44%' },
        { label: 'Amount', tag: '{Amount__c:currency}', width: '20%' }
    ],
    totals: {
        enabled: true,
        cells: ['', '', 'Total approved change orders', '{SUM:Change_Orders__r.Amount__c:currency}']
    }
});
changeOrders.h = H.changeOrders;

const reconcile = keyValue(
    page2,
    4.1,
    4.85,
    3.8,
    [
        ['Original contract value', '{Contract_Value__c:currency}'],
        ['Approved change orders', '{SUM:Change_Orders__r.Amount__c:currency}']
    ],
    {
        mode: 'flow',
        labelWidth: '46%',
        valueWidth: '54%',
        totals: { enabled: true, cells: ['Revised contract value', '{Revised_Contract_Value__c:currency}'] },
        totalsFill: TINT,
        totalsText: { size: 11, color: NAVY, bold: true, align: 'left' }
    }
);
reconcile.h = H.reconcile;

// --- approval + signature --------------------------------------------------
// Pinned rather than flowed: an approval block that slides up under a short
// change-order list stops reading as a signature panel.
text(page2, 0.6, 7.0, 3.4, H.label, 'APPROVED FOR PAYMENT', { size: 8, bold: true, color: LABEL });

const sig = m.newSignatureBox(0.6, 7.42);
sig.signature = { role: 'Client', order: 1, type: 'Full', inline: false };
sig.w = 2.6;
sig.h = H.sigFull;
page2.boxes.push(sig);
shape(page2, 0.6, 8.15, 3.4, 0, { type: 'hline', fill: '', borderWidth: 1, borderColor: '#33475b' }, 1);
text(
    page2,
    0.6,
    8.35,
    3.4,
    H.sigName,
    '{Client_Contact__r.FirstName} {Client_Contact__r.LastName}\n{Client_Contact__r.Title}, {Client__r.Name}',
    { size: 9, color: INK }
);

text(page2, 4.35, 7.0, 1.7, H.label, 'DATE', { size: 8, bold: true, color: LABEL });
const sigDate = m.newSignatureBox(4.35, 7.45);
sigDate.signature = { role: 'Client', order: 1, type: 'Date', inline: false };
sigDate.w = 1.7;
sigDate.h = H.sigDate;
page2.boxes.push(sigDate);
shape(page2, 4.35, 8.15, 1.7, 0, { type: 'hline', fill: '', borderWidth: 1, borderColor: '#33475b' }, 1);
text(page2, 4.35, 8.35, 1.7, H.label, 'Date signed', { size: 9, color: MUTED });

// --- QR ---------------------------------------------------------------------
const qr = m.newCodeBox(6.5, 7.0);
qr.code = { field: 'Project_Code__c', type: 'qr', size: 130, height: 80 };
qr.w = 1.4;
qr.h = H.qr;
page2.boxes.push(qr);
text(page2, 6.5, 8.6, 1.4, H.label, 'Scan for project', { size: 7.5, color: MUTED, align: 'center' });

// --- footer -----------------------------------------------------------------
shape(page2, 0.6, 9.9, 7.3, 0, { type: 'hline', fill: '', borderWidth: 0.75, borderColor: RULE }, 1);
text(
    page2,
    0.6,
    10.05,
    7.3,
    H.footer,
    'Portwood Professional Services · 1200 Market Street, Suite 400, Seattle WA 98104 · Net 30 · ' +
        'Late balances accrue 1.0% per month.\nGenerated from Salesforce project {Project_Code__c} on {Today:date}.',
    { size: 8, color: MUTED }
);

// ---------------------------------------------------------------------------
const html = m.serialize(doc, geo);
writeFileSync(OUT, html, 'utf8');

const boxes = doc.artboards.reduce((n, b) => n + b.boxes.length, 0);
console.log('wrote ' + OUT);
console.log('  artboards=' + doc.artboards.length + ' boxes=' + boxes + ' bytes=' + html.length);
