/**
 * The Canvas scene graph, and the only place that knows how it becomes HTML.
 *
 * WHY A MODEL AND NOT THE DOM
 * ---------------------------
 * The existing designer treats the rendered DOM as the document: it reads the canvas
 * back with innerHTML and re-parses it. Under Lightning Web Security's per-namespace
 * sandbox that has repeatedly bitten us — `ChildNode.replaceWith` missing on proxied
 * nodes, `cloneNode(true)` silently dropping browser-inserted nodes — because the
 * browser is allowed to restructure contenteditable output and LWS distorts what you
 * read back.
 *
 * Here the model is the truth. Boxes are plain objects with inch coordinates; the DOM
 * is a projection of them that is thrown away and re-rendered. Nothing is ever parsed
 * back out of the live tree, so there is no tree to be distorted. contenteditable
 * survives only INSIDE a single text box, where the browser's restructuring can't
 * escape the box it belongs to.
 *
 * UNITS
 * -----
 * The model stores INCHES because that is what the PDF is measured in and what the
 * author is really choosing. Pixels appear only at render time (inches x 96 x zoom),
 * so changing zoom can never drift the document — a class of bug the old caret/marker
 * code had to divide the zoom back out of by hand at every site.
 */

/** CSS reference pixels per inch. Fixed by the CSS spec, not by the display. */
export const PX_PER_IN = 96;

/** Page geometry in inches, content area only (page size minus 0.5in margins). */
const PAGE_GEOMETRY = {
    'Letter|portrait': { css: 'Letter portrait', w: 7.5, h: 10 },
    'Letter|landscape': { css: 'Letter landscape', w: 10, h: 7.5 },
    'A4|portrait': { css: 'A4 portrait', w: 7.27, h: 10.69 },
    'A4|landscape': { css: 'A4 landscape', w: 10.69, h: 7.27 },
    'Legal|portrait': { css: 'Legal portrait', w: 7.5, h: 13 },
    'Legal|landscape': { css: 'Legal landscape', w: 13, h: 7.5 }
};

export function pageGeometry(pageSize, orientation) {
    const key = (pageSize || 'Letter') + '|' + (orientation || 'Portrait').toLowerCase();
    return PAGE_GEOMETRY[key] || PAGE_GEOMETRY['Letter|portrait'];
}

let seq = 0;
/** Ids are per-session only — they never reach the serialized document. */
function nextId(prefix) {
    seq += 1;
    return prefix + '_' + seq;
}

/**
 * The ONLY font stacks Flying Saucer actually resolves, measured 2026-08-05 against a
 * real render (scripts/css-probe-fonts.apex, docs/css-probe-fonts.png).
 *
 * Every NAMED family — Helvetica, Arial, Georgia, Verdana, Tahoma, Impact, Times New
 * Roman, Courier New — silently falls back to the serif default. Only the generic
 * keywords resolve, plus bare `Courier`. Offering "Arial" in a picker would render
 * Times and quietly make the canvas stop being WYSIWYG, which is the one thing this
 * editor exists to guarantee.
 */
export const FONT_CHOICES = [
    { label: 'Sans-serif', value: 'sans-serif' },
    { label: 'Serif', value: 'serif' },
    { label: 'Monospace', value: 'monospace' }
];

export const DEFAULT_STYLE = {
    font: 'sans-serif',
    size: 11,
    bold: false,
    italic: false,
    underline: false,
    color: '#1a1a1a',
    fill: '',
    align: 'left',
    borderWidth: 0,
    borderColor: '#333333',
    padding: 2
};

export function newTextBox(xIn, yIn, wIn, hIn) {
    return {
        id: nextId('box'),
        kind: 'text',
        style: { ...DEFAULT_STYLE },
        // `pinned` boxes are position:absolute and land exactly where dropped.
        // `flow` boxes sit in normal flow so their content can paginate — that is
        // how a {#Loop} of 60 rows spills onto the next page instead of being
        // clipped at the artboard edge.
        mode: 'pinned',
        x: round3(xIn),
        y: round3(yIn),
        w: round3(wIn),
        h: round3(hIn),
        // PLAIN TEXT, not HTML.
        //
        // A canvas text box is edited in a real <textarea>, for two reasons that both
        // matter more than inline formatting would. First, Lightning's global "/"
        // hotkey steals focus to the search box from a contenteditable — the flow
        // designer had to detect the theft after the fact and steal focus BACK, because
        // LWS never delivers the window-capture listener that would let it be
        // prevented. Lightning ignores its shortcuts inside a textarea, so the problem
        // stops existing rather than being recovered from. Second, a textarea's value
        // is a plain string: there is no contenteditable DOM for LWS to distort, which
        // is the entire bug class this editor was built to escape.
        //
        // The trade is no bold-one-word-inside-a-box. That is the Canva model anyway —
        // styling belongs to the object, and every style here is already per-box.
        text: 'Text'
    };
}

export const DEFAULT_TABLE_STYLE = {
    headerFill: '#eeeeee',
    headerBold: true,
    gridColor: '#999999',
    gridWidth: 0.5,
    cellPadding: 3
};

/**
 * A table box. Defaults to FLOW mode, and that default is the whole point: a table
 * bound to a {#Loop} grows to whatever the merge produces, and only a flow box
 * paginates. Pinned would clip it at the artboard edge the moment the data outgrew
 * the page — measured in scripts/canvas-layout-model-probe.apex.
 */
export function newTableBox(xIn, yIn, wIn) {
    return {
        id: nextId('box'),
        kind: 'table',
        mode: 'flow',
        style: { ...DEFAULT_STYLE, padding: 0 },
        table: {
            ...DEFAULT_TABLE_STYLE,
            showHeader: true,
            // Blank relationship = a static table. Set it and every row repeats per
            // child record.
            relationship: '',
            // Extra literal rows, each an array of cell strings. Used on their own for
            // a fixed table, or appended after the loop when one is bound.
            rows: [],
            // A totals row. Emitted as the LAST <tr> of <tbody>, deliberately not in
            // <tfoot>: a table-footer-group repeats on EVERY page, and a grand total
            // that appears on every page of a long invoice is wrong.
            totals: { enabled: false, cells: [] },
            columns: [
                { label: 'Item', tag: '{Name}', width: '' },
                { label: 'Amount', tag: '{Amount}', width: '' }
            ]
        },
        x: round3(xIn),
        y: round3(yIn),
        w: round3(wIn),
        h: 1,
        html: ''
    };
}

/** Field names that plausibly hold a number worth totalling. */
const NUMERIC_HINT =
    /(amount|total|price|cost|qty|quantity|count|sum|rate|discount|tax|subtotal|fee|balance|revenue|margin|hours|units)/i;

/**
 * Suggests a totals cell per column.
 *
 * Two things it deliberately gets right, both learned by looking at its own output:
 *
 *  - It carries the column's FORMAT through. A column showing
 *    {Amount:currency:USD} becomes {SUM:Rel.Amount:currency:USD}, because the engine
 *    supports format suffixes on aggregates and a raw unformatted total sitting under
 *    a column of formatted currency looks broken.
 *  - It does NOT suggest for fields that are not plausibly numeric. The first version
 *    happily proposed {SUM:Opportunities.Name}, which renders as an error or a zero.
 *    A blank cell the author fills in beats a confident wrong one.
 *
 * The numeric test is a name heuristic, not a describe — the canvas has no field
 * metadata. It is a suggestion the author edits, so a miss costs a keystroke; the
 * thing worth avoiding is a plausible-looking total that is nonsense.
 */
export function suggestTotals(table) {
    const rel = (table && table.relationship) || '';
    return (table.columns || []).map((c) => {
        const m = /^\{([A-Za-z0-9_.]+)((?::[^}]*)?)\}$/.exec((c.tag || '').trim());
        if (!rel || !m) {
            return '';
        }
        const field = m[1];
        const format = m[2] || '';
        if (!NUMERIC_HINT.test(field)) {
            return '';
        }
        return '{SUM:' + rel + '.' + field + format + '}';
    });
}

export function newArtboard() {
    return { id: nextId('board'), boxes: [] };
}

export function blankDocument() {
    return { artboards: [newArtboard()] };
}

function round3(n) {
    return Math.round(n * 1000) / 1000;
}

export function inToPx(inches, zoom) {
    return inches * PX_PER_IN * (zoom || 1);
}

export function pxToIn(px, zoom) {
    return round3(px / (PX_PER_IN * (zoom || 1)));
}

/**
 * Clamps a box inside its artboard. Width and height are preserved where possible —
 * a box dragged off the right edge slides back in rather than being squashed, which
 * is what every design tool does and what authors expect.
 */
export function clampBox(box, geo) {
    const w = Math.min(box.w, geo.w);
    const h = Math.min(box.h, geo.h);
    return {
        ...box,
        w: round3(w),
        h: round3(h),
        x: round3(Math.max(0, Math.min(box.x, geo.w - w))),
        y: round3(Math.max(0, Math.min(box.y, geo.h - h)))
    };
}

/** Snap distance in inches. ~5px at 100%: close enough to feel magnetic, far enough
 *  that a deliberate 0.1in offset is still reachable. */
export const SNAP_IN = 0.05;

/**
 * Snaps a moving box to its neighbours and to the page, and reports which lines to
 * draw.
 *
 * Guides are computed from the MODEL in inches, not from measured pixels, so they
 * stay true at any zoom — a guide that drifts from the thing it claims to align to is
 * worse than no guide.
 *
 * Returns { x, y, guides: [{ axis: 'v'|'h', at: inches }] }.
 */
export function snapBox(box, others, geo) {
    const guides = [];
    const targetsX = [0, geo.w / 2, geo.w];
    const targetsY = [0, geo.h / 2, geo.h];
    for (const o of others) {
        targetsX.push(o.x, o.x + o.w / 2, o.x + o.w);
        targetsY.push(o.y, o.y + o.h / 2, o.y + o.h);
    }

    // Each edge of the moving box is a candidate; the offset converts an edge match
    // back into a box origin.
    const edgesX = [
        { at: box.x, offset: 0 },
        { at: box.x + box.w / 2, offset: box.w / 2 },
        { at: box.x + box.w, offset: box.w }
    ];
    const edgesY = [
        { at: box.y, offset: 0 },
        { at: box.y + box.h / 2, offset: box.h / 2 },
        { at: box.y + box.h, offset: box.h }
    ];

    let x = box.x;
    let y = box.y;
    let bestX = SNAP_IN;
    let bestY = SNAP_IN;
    for (const e of edgesX) {
        for (const t of targetsX) {
            const d = Math.abs(e.at - t);
            if (d < bestX) {
                bestX = d;
                x = round3(t - e.offset);
                guides.push({ axis: 'v', at: t });
            }
        }
    }
    for (const e of edgesY) {
        for (const t of targetsY) {
            const d = Math.abs(e.at - t);
            if (d < bestY) {
                bestY = d;
                y = round3(t - e.offset);
                guides.push({ axis: 'h', at: t });
            }
        }
    }
    // Only the winning line per axis is worth drawing — every near-miss considered
    // along the way would paint the canvas with lines that mean nothing.
    const finalGuides = [];
    const vHit = guides.filter((g) => g.axis === 'v').pop();
    const hHit = guides.filter((g) => g.axis === 'h').pop();
    if (vHit && bestX < SNAP_IN) finalGuides.push(vHit);
    if (hHit && bestY < SNAP_IN) finalGuides.push(hHit);
    return { x, y, guides: finalGuides };
}

// ---------------------------------------------------------------------------
// Serialization — model -> the CANVAS_CSS contract
// ---------------------------------------------------------------------------

/**
 * Every rule below was measured against a real Blob.toPdf render, not assumed.
 * See scripts/canvas-layout-model-probe.apex and docs/canvas-layout-model-p*.png.
 *
 *   min-height, never height   a pinned height is OVERRUN by growing merge content
 *                              instead of growing with it
 *   page-break-BEFORE          on each artboard after the first. page-break-after on
 *                              the previous one gets swallowed when a flow region
 *                              spills, and the next artboard then paints its pinned
 *                              boxes on top of the overflow
 */
export function buildCanvasCss(geo) {
    return (
        '@page { size: ' +
        geo.css +
        '; margin: 0.5in; }\n' +
        'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color: #1a1a1a; margin: 0; }\n' +
        '.dg-artboard { position: relative; width: ' +
        geo.w +
        'in; min-height: ' +
        geo.h +
        'in; }\n' +
        '.dg-artboard_break { page-break-before: always; }\n' +
        '.dg-pin { position: absolute; }\n' +
        '.dg-flow { position: relative; }\n' +
        'table { border-collapse: collapse; width: 100%; -fs-table-paginate: paginate; }\n' +
        'thead { display: table-header-group; }\n' +
        'td, th { border: 0.5pt solid #999; padding: 2pt 4pt; }\n'
    );
}

/** Box styling as inline CSS. Only properties the engine honours are emitted. */
function styleCss(box) {
    const st = { ...DEFAULT_STYLE, ...(box.style || {}) };
    let css =
        'font-family: ' +
        st.font +
        '; font-size: ' +
        st.size +
        'pt; color: ' +
        st.color +
        '; text-align: ' +
        st.align +
        '; padding: ' +
        st.padding +
        'pt;';
    if (st.bold) css += ' font-weight: bold;';
    if (st.italic) css += ' font-style: italic;';
    if (st.underline) css += ' text-decoration: underline;';
    // A flat hex, never rgba(): rgba resolves to nothing in this engine and the fill
    // disappears completely rather than degrading to a solid colour.
    if (st.fill) css += ' background: ' + st.fill + ';';
    if (st.borderWidth > 0) css += ' border: ' + st.borderWidth + 'pt solid ' + st.borderColor + ';';
    return css;
}

/** Escapes only what would break the markup — merge tags must survive verbatim. */
function esc(v) {
    return String(v == null ? '' : v)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

/**
 * A table box becomes a real <table>. When a relationship is set, the {#Rel} wrapper
 * goes INSIDE <tbody> around the <tr> — that is the shape the merge engine's row
 * expansion looks for, and the same pattern the reference templates use. The header
 * lives in <thead> so it repeats on every continuation page.
 */
function tableToHtml(box) {
    const t = box.table || {};
    const cols = t.columns || [];
    const st = { ...DEFAULT_STYLE, ...(box.style || {}) };
    // Typography goes onto the CELLS, not left to inherit. Flying Saucer gives
    // tables their own defaults, so a cell inheriting nothing renders at the
    // engine's font no matter what the box says — and the canvas would stop
    // matching the PDF, which is the one promise this editor makes.
    const typo = ' font-family: ' + st.font + '; font-size: ' + st.size + 'pt; color: ' + st.color + ';';
    const cellCss = 'border: ' + t.gridWidth + 'pt solid ' + t.gridColor + '; padding: ' + t.cellPadding + 'pt;' + typo;
    let out = '<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">';
    if (t.showHeader) {
        out += '<thead style="display: table-header-group;"><tr>';
        for (const c of cols) {
            const w = c.width ? ' width: ' + c.width + ';' : '';
            out +=
                '<th style="' +
                cellCss +
                w +
                ' background: ' +
                t.headerFill +
                ';' +
                (t.headerBold ? ' font-weight: bold;' : ' font-weight: normal;') +
                ' text-align: left;">' +
                esc(c.label) +
                '</th>';
        }
        out += '</tr></thead>';
    }
    const cell = (v) => '<td style="' + cellCss + '">' + (v || '') + '</td>';
    // data-dg-row is why rows survive a round-trip. The first version INFERRED roles
    // ("the last row is totals if its first cell is bold"); any cell the browser
    // re-serialized differently broke the guess, so a totals row came back as a
    // literal row AND a fresh totals row was appended on the next save. Rows
    // multiplied every time the template was opened.
    const loopRow = '<tr data-dg-row="loop">' + cols.map((c) => cell(c.tag)).join('') + '</tr>';
    out += '<tbody>';
    if (t.relationship) {
        out += '{#' + t.relationship + '}' + loopRow + '{/' + t.relationship + '}';
    } else if (!(t.rows || []).length) {
        // No loop and no literal rows — keep one row so the table is not just a header.
        out += loopRow;
    }
    for (const r of t.rows || []) {
        out += '<tr data-dg-row="extra">' + cols.map((c, i) => cell(esc(r[i] || ''))).join('') + '</tr>';
    }
    if (t.totals && t.totals.enabled) {
        const tc = t.totals.cells || [];
        out +=
            '<tr data-dg-row="totals">' +
            cols
                .map(
                    (c, i) =>
                        '<td style="' +
                        cellCss +
                        ' font-weight: bold; background: ' +
                        t.headerFill +
                        ';">' +
                        (tc[i] || '') +
                        '</td>'
                )
                .join('') +
            '</tr>';
    }
    out += '</tbody></table>';
    return out;
}

/**
 * The table as the CANVAS should show it: same cells, same widths, same borders, but
 * the {#Rel} loop markers replaced by two sample rows. Showing the raw marker would
 * put stray text in the artboard; showing one row would hide the fact that it repeats.
 */
export function tablePreviewHtml(box) {
    const t = box.table || {};
    const cols = t.columns || [];
    const cellCss = 'border: ' + t.gridWidth + 'pt solid ' + t.gridColor + '; padding: ' + t.cellPadding + 'pt;';
    let out = '<table style="border-collapse: collapse; width: 100%;">';
    if (t.showHeader) {
        out += '<thead><tr>';
        for (const c of cols) {
            const w = c.width ? ' width: ' + c.width + ';' : '';
            out +=
                '<th style="' +
                cellCss +
                w +
                ' background: ' +
                t.headerFill +
                ';' +
                (t.headerBold ? ' font-weight: bold;' : ' font-weight: normal;') +
                ' text-align: left;">' +
                esc(c.label) +
                '</th>';
        }
        out += '</tr></thead>';
    }
    out += '<tbody>';
    const rows = t.relationship ? 2 : 1;
    for (let i = 0; i < rows; i++) {
        out += '<tr>' + cols.map((c) => '<td style="' + cellCss + '">' + esc(c.tag || '') + '</td>').join('') + '</tr>';
    }
    if (t.relationship) {
        out +=
            '<tr><td colspan="' +
            Math.max(1, cols.length) +
            '" style="' +
            cellCss +
            ' font-style: italic; color: #6b7280;">… one row per ' +
            esc(t.relationship) +
            ' record</td></tr>';
    }
    out += '</tbody></table>';
    return out;
}

/**
 * The markup a box may carry, and the only markup the PDF engine reliably renders.
 *
 * lightning-input-rich-text emits whatever its toolbar produced, which is more than
 * Flying Saucer honours and occasionally things it chokes on. Reducing it here means
 * the canvas and the PDF agree, and that a paste from a web page cannot inject an
 * absolutely-positioned div into an artboard whose whole layout contract is position.
 *
 * TABLE tags are allowed: authoring a table inside the text box is the point of moving
 * editing into the panel, and tables render correctly (measured — nested tables and
 * per-cell borders both work).
 */
const SAFE_TAGS = new Set([
    'B',
    'STRONG',
    'I',
    'EM',
    'U',
    'S',
    'STRIKE',
    'BR',
    'SPAN',
    'P',
    'DIV',
    'UL',
    'OL',
    'LI',
    'TABLE',
    'THEAD',
    'TBODY',
    'TR',
    'TD',
    'TH',
    'H1',
    'H2',
    'H3',
    'H4',
    'H5',
    'H6'
]);

/** Only properties measured to work. rgba and opacity are dropped on purpose: rgba
 *  renders NOTHING in this engine and opacity is ignored, so both are traps. */
const SAFE_STYLE = [
    'color',
    'background-color',
    'font-weight',
    'font-style',
    'text-decoration',
    'font-size',
    'font-family',
    'text-align',
    'width',
    'border',
    'padding',
    'vertical-align'
];

function dropUnsafeStyle(value) {
    // A colour the engine cannot resolve is worse than no colour: rgba() makes the
    // whole background disappear rather than degrading.
    return /rgba?\(|hsla?\(|var\(|calc\(/i.test(value || '');
}

/**
 * Repairs merge tags that inline formatting has cut in half.
 *
 * Select the middle of {Description}, press italic, and the editor emits
 * `{De<i>scription}</i>` — the tag now spans an element boundary, so the merge engine
 * never sees `{Description}` and the reader gets the braces printed literally. It is
 * silent: nothing errors, the tag simply does not resolve.
 *
 * This is the same failure Word has had for years (issue #130, tags split across runs
 * by character formatting), arriving on the canvas by a different route. The fix is
 * the same shape: a tag is an atom, so any markup INSIDE the braces is dropped and the
 * formatting around it survives. Losing italic on one word beats shipping a document
 * with {De scription} printed in it.
 */
function healSplitTags(html) {
    return String(html == null ? '' : html).replace(/\{[^{}]*\}/g, (tag) =>
        tag.indexOf('<') === -1 ? tag : tag.replace(/<[^>]*>/g, '')
    );
}

export function sanitizeInline(html) {
    const tpl = document.createElement('template');
    // Heal first, then parse: stripping tags out of the braces can leave an orphan
    // closing tag, and the parser is what tidies that up.
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    tpl.innerHTML = healSplitTags(html);
    const walk = (node) => {
        for (const child of [...node.childNodes]) {
            if (child.nodeType === 3) {
                continue;
            }
            if (child.nodeType !== 1) {
                child.remove();
                continue;
            }
            if (!SAFE_TAGS.has(child.tagName)) {
                // Unwrap, never delete — the TEXT the author wrote is the point.
                while (child.firstChild) node.insertBefore(child.firstChild, child);
                child.remove();
                continue;
            }
            const keep = [];
            const style = child.getAttribute('style');
            if (style) {
                for (const prop of SAFE_STYLE) {
                    const m = new RegExp('(?:^|;)\\s*' + prop + '\\s*:\\s*([^;]+)').exec(style);
                    if (m && !dropUnsafeStyle(m[1])) {
                        keep.push(prop + ': ' + m[1].trim());
                    }
                }
            }
            const colspan = child.getAttribute('colspan');
            const rowspan = child.getAttribute('rowspan');
            for (const attr of [...child.attributes]) child.removeAttribute(attr.name);
            if (keep.length) child.setAttribute('style', keep.join('; '));
            if (colspan) child.setAttribute('colspan', colspan);
            if (rowspan) child.setAttribute('rowspan', rowspan);
            walk(child);
        }
    };
    walk(tpl.content);
    return tpl.innerHTML;
}

/**
 * Inline formatting marks, applied to a SELECTION inside the plain-text box.
 *
 * Marks in the text rather than HTML in a contenteditable, deliberately. A
 * contenteditable box reintroduces Lightning's "/" hotkey stealing focus mid-typing —
 * measured, not theorised — because Lightning binds it on window capture and LWS does
 * not deliver window-capture listeners to component code. A textarea is exempt from
 * those shortcuts, so keeping the box a textarea keeps typing safe; the formatting
 * rides along as marks the serializer expands.
 *
 * Chosen to be things nobody types by accident in a business document, and to avoid
 * the braces and colons that merge tags already use.
 */
export const INLINE_MARKS = [
    { name: 'bold', open: '**', close: '**', tag: 'b' },
    { name: 'italic', open: '//', close: '//', tag: 'i' },
    { name: 'underline', open: '__', close: '__', tag: 'u' },
    { name: 'strike', open: '~~', close: '~~', tag: 's' }
];

function escapeRe(v) {
    return v.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Expands inline marks into tags. Runs on ALREADY-ESCAPED text, so a literal "<" the
 * author typed stays escaped and only the marks become markup.
 */
function expandMarks(escaped) {
    let out = escaped;
    for (const m of INLINE_MARKS) {
        const re = new RegExp(escapeRe(m.open) + '([\\s\\S]+?)' + escapeRe(m.close), 'g');
        out = out.replace(re, '<' + m.tag + '>$1</' + m.tag + '>');
    }
    return out;
}

/** Inverse of expandMarks, for reading a stored document back into the editor. */
export function collapseMarks(html) {
    let out = String(html == null ? '' : html);
    for (const m of INLINE_MARKS) {
        const re = new RegExp('<' + m.tag + '>([\\s\\S]*?)</' + m.tag + '>', 'gi');
        out = out.replace(re, m.open + '$1' + m.close);
    }
    return out;
}

/**
 * Plain text to safe markup: escaped, marks expanded, newlines becoming line breaks.
 *
 * Escaping does NOT break conditionals that use angle brackets. `{#IF Amount > 100}`
 * serializes as `{#IF Amount &gt; 100}` and the engine decodes it —
 * DocGenService.evaluateIfExpression already un-escapes &gt;/&lt;/&amp;/&apos;/&quot;
 * because Word escapes exactly the same characters in its text runs. Do not "fix" this
 * by leaving text unescaped: a stray `<` in someone's address block would then break
 * the document's markup.
 */
function textToHtml(box) {
    return expandMarks(esc(box.text == null ? '' : box.text)).replace(/\n/g, '<br />');
}

/**
 * A flow box's vertical margin is the GAP from the previous flow box, not its y.
 *
 * This is the whole mechanism behind "a table that grows pushes what is under it
 * down". Flow boxes sit in normal flow, so margin-top is measured from the bottom of
 * the one before — emitting the box's absolute y there put a box authored at y=5in
 * five inches BELOW the table instead of five inches down the page, and the error
 * compounded with every additional flow box.
 *
 * Computing the gap means the layout matches the canvas exactly at minimum content,
 * and everything after a growing table moves down by however much it grew. Pinned
 * boxes are absolute and take no part in this, which is precisely what pinning is for.
 */
function flowMarginTop(box, cursor) {
    return round3(Math.max(0, box.y - cursor));
}

function boxToHtml(box, cursor) {
    const inner = box.kind === 'table' ? tableToHtml(box) : textToHtml(box);
    if (box.mode === 'flow') {
        return (
            '<div class="dg-flow" style="margin: ' +
            flowMarginTop(box, cursor || 0) +
            'in 0 0 ' +
            box.x +
            'in; width: ' +
            box.w +
            'in; ' +
            styleCss(box) +
            '">' +
            inner +
            '</div>'
        );
    }
    // Height is deliberately NOT emitted for a pinned box. Declaring it would cap the
    // box and let merged content overflow past its own background and border; leaving
    // it off lets the box grow to whatever the merge produces. The model still tracks
    // h so the editor can show a real rectangle to drag.
    return (
        '<div class="dg-pin" style="left: ' +
        box.x +
        'in; top: ' +
        box.y +
        'in; width: ' +
        box.w +
        'in; ' +
        styleCss(box) +
        '">' +
        inner +
        '</div>'
    );
}

export function serialize(doc, geo) {
    const boards = doc.artboards
        .map((b, i) => {
            const cls = i === 0 ? 'dg-artboard' : 'dg-artboard dg-artboard_break';
            // Pinned boxes first — they are absolute, so their position in the markup
            // does not matter and emitting them up front leaves the flow starting at
            // the top of the artboard. Flow boxes then follow IN Y ORDER, because
            // normal flow is document order and authoring order is not.
            const pinned = (b.boxes || []).filter((x) => x.mode !== 'flow');
            const flowing = (b.boxes || [])
                .filter((x) => x.mode === 'flow')
                .slice()
                .sort((p, q) => p.y - q.y);
            let cursor = 0;
            const flowHtml = flowing.map((x) => {
                const out = boxToHtml(x, cursor);
                cursor = x.y + x.h;
                return out;
            });
            const inner = [...pinned.map((x) => boxToHtml(x, 0)), ...flowHtml].join('\n  ');
            return '<div class="' + cls + '" data-dg-artboard="' + (i + 1) + '">\n  ' + inner + '\n</div>';
        })
        .join('\n');
    return (
        '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8" />\n<style>\n' +
        buildCanvasCss(geo) +
        '</style>\n</head>\n<body>\n' +
        boards +
        '\n</body>\n</html>\n'
    );
}

// ---------------------------------------------------------------------------
// Deserialization — the CANVAS_CSS contract -> model
// ---------------------------------------------------------------------------

function readInches(style, prop) {
    const m = new RegExp(prop + '\\s*:\\s*(-?[0-9.]+)in').exec(style || '');
    return m ? parseFloat(m[1]) : null;
}

/**
 * Reads a stored Canvas body back into the model.
 *
 * Parses from a detached <template> rather than by touching the live canvas — the
 * same discipline the upload path already uses, and the reason LWS node distortion
 * cannot reach this.
 *
 * Returns null when the body is not canvas-shaped, so the caller can tell "empty new
 * template" from "someone pointed this at an HTML template" instead of silently
 * showing a blank artboard over content that is really still there.
 */
/** Inverse of textToHtml — <br> back to newlines, entities back to characters. */
function htmlToText(html) {
    const tmp = document.createElement('div');
    html = collapseMarks(html);
    // eslint-disable-next-line @lwc/lwc/no-inner-html
    tmp.innerHTML = String(html == null ? '' : html).replace(/<br\s*\/?>/gi, '\n');
    return tmp.textContent || '';
}

function readCss(style, prop) {
    const m = new RegExp('(?:^|;)\\s*' + prop + '\\s*:\\s*([^;]+)').exec(style || '');
    return m ? m[1].trim() : null;
}

/** Recovers box styling from the serialized inline CSS, falling back per-property. */
function readStyle(style) {
    const st = { ...DEFAULT_STYLE };
    const font = readCss(style, 'font-family');
    if (font) st.font = font;
    const size = readCss(style, 'font-size');
    if (size) st.size = parseFloat(size) || st.size;
    const color = readCss(style, 'color');
    if (color) st.color = color;
    const align = readCss(style, 'text-align');
    if (align) st.align = align;
    const pad = readCss(style, 'padding');
    if (pad) st.padding = parseFloat(pad) || 0;
    st.bold = /font-weight:\s*bold/.test(style || '');
    st.italic = /font-style:\s*italic/.test(style || '');
    st.underline = /text-decoration:\s*underline/.test(style || '');
    st.fill = readCss(style, 'background') || '';
    const border = readCss(style, 'border');
    if (border) {
        const bm = /([0-9.]+)pt\s+solid\s+(\S+)/.exec(border);
        if (bm) {
            st.borderWidth = parseFloat(bm[1]);
            st.borderColor = bm[2];
        }
    }
    return st;
}

/** Recovers a table box's columns and loop binding from the serialized markup. */
function readTable(wrapper, tableEl) {
    const t = { ...DEFAULT_TABLE_STYLE, showHeader: false, relationship: '', columns: [] };
    const ths = [...tableEl.querySelectorAll('thead th')];
    t.showHeader = ths.length > 0;
    const tds = [...tableEl.querySelectorAll('tbody tr td')];
    // The loop marker lives as a text node inside <tbody>, around the <tr>.
    // Read the loop marker from the WRAPPER, not from <tbody>.
    //
    // We serialize `<tbody>{#Rel}<tr>…</tr>{/Rel}</tbody>`, which is what the merge
    // engine's row expansion expects. But the HTML parser does not allow text as a
    // direct child of <tbody> — it FOSTER-PARENTS those text nodes out, to just before
    // the <table>. So on the way back in, tbody.innerHTML no longer contains the
    // marker and the binding read as blank: open a table template, save, and the
    // {#Rel} was silently gone. The wrapper still holds it wherever the parser moved it.
    const m = /\{#([A-Za-z0-9_]+)\}/.exec((wrapper && wrapper.innerHTML) || '');
    t.relationship = m ? m[1] : '';
    const count = Math.max(ths.length, tds.length);
    for (let i = 0; i < count; i++) {
        const th = ths[i];
        const td = tds[i];
        t.columns.push({
            label: th ? (th.textContent || '').trim() : 'Column ' + (i + 1),
            tag: td ? (td.innerHTML || '').trim() : '',
            width: th ? readCss(th.getAttribute('style'), 'width') || '' : ''
        });
    }
    // Roles are READ from data-dg-row, never inferred. Rows without the marker come
    // from a pre-marker document: treat them as literal rows, which is lossless —
    // worst case the author re-ticks the totals box once.
    t.rows = [];
    t.totals = { enabled: false, cells: [] };
    for (const tr of tableEl.querySelectorAll('tbody tr')) {
        const role = tr.getAttribute('data-dg-row');
        if (role === 'loop') {
            continue;
        }
        const cells = [...tr.querySelectorAll('td')].map((td) => (td.textContent || '').trim());
        if (role === 'totals') {
            t.totals = { enabled: true, cells };
        } else {
            t.rows.push(cells);
        }
    }

    const firstCell = ths[0] || tds[0];
    if (firstCell) {
        const cs = firstCell.getAttribute('style') || '';
        const bm = /([0-9.]+)pt\s+solid\s+(\S+)/.exec(readCss(cs, 'border') || '');
        if (bm) {
            t.gridWidth = parseFloat(bm[1]);
            t.gridColor = bm[2];
        }
        const pad = readCss(cs, 'padding');
        if (pad) t.cellPadding = parseFloat(pad) || t.cellPadding;
    }
    if (ths[0]) {
        t.headerFill = readCss(ths[0].getAttribute('style'), 'background') || t.headerFill;
        t.headerBold = /font-weight:\s*bold/.test(ths[0].getAttribute('style') || '');
    }
    return t;
}

export function deserialize(html) {
    if (!html || html.indexOf('dg-artboard') === -1) {
        return null;
    }
    const tpl = document.createElement('template');
    tpl.innerHTML = html;
    const boards = [...tpl.content.querySelectorAll('.dg-artboard')];
    if (!boards.length) {
        return null;
    }
    return {
        artboards: boards.map((boardEl) => {
            const board = newArtboard();
            board.boxes = [...boardEl.querySelectorAll('.dg-pin, .dg-flow')].map((el) => {
                const style = el.getAttribute('style') || '';
                const isFlow = el.classList.contains('dg-flow');
                const box = newTextBox(0, 0, 2, 0.5);
                box.mode = isFlow ? 'flow' : 'pinned';
                box.w = readInches(style, 'width') || 2;
                if (isFlow) {
                    // margin: <top>in 0 0 <left>in
                    const m = /margin:\s*(-?[0-9.]+)in\s+0\s+0\s+(-?[0-9.]+)in/.exec(style);
                    box.y = m ? parseFloat(m[1]) : 0;
                    box.x = m ? parseFloat(m[2]) : 0;
                } else {
                    box.x = readInches(style, 'left') || 0;
                    box.y = readInches(style, 'top') || 0;
                }
                // Height is never serialized (see boxToHtml) — recover a sensible
                // editing rectangle instead of collapsing the box to nothing.
                box.h = readInches(style, 'height') || 0.5;
                box.style = readStyle(style);
                const tableEl = el.querySelector('table');
                if (tableEl) {
                    box.kind = 'table';
                    box.table = readTable(el, tableEl);
                    box.html = '';
                } else {
                    box.text = htmlToText(el.innerHTML);
                }
                return box;
            });
            return board;
        })
    };
}

// ---------------------------------------------------------------------------
// Query generation — the canvas tells the query what it needs
// ---------------------------------------------------------------------------

/** Tags that resolve without being queried, so they must never reach the SELECT. */
const NON_FIELD_TAGS =
    /^(Today|Now|PageNumber|TotalPages|RowNumber|RunningUser(\.[A-Za-z0-9_]+)?|SUM|COUNT|AVG|MIN|MAX|IF|ELSE)/i;

function collectFromText(text, out, rel) {
    for (const m of String(text || '').matchAll(/\{([#/^%]?)([A-Za-z0-9_.:=&'"\s-]+?)\}/g)) {
        const prefix = m[1];
        let body = m[2].trim();
        if (prefix === '#' || prefix === '/' || prefix === '^' || prefix === '%') {
            continue;
        }
        // Strip a format suffix: {Amount:currency:USD} is still the Amount field.
        body = body.split(':')[0].trim();
        if (!body || NON_FIELD_TAGS.test(body)) {
            continue;
        }
        // Aggregates name their own relationship and are resolved from it, not selected.
        if (body.indexOf('(') !== -1 || body.indexOf(' ') !== -1) {
            continue;
        }
        if (rel) {
            if (!out.children[rel]) out.children[rel] = new Set();
            out.children[rel].add(body);
        } else {
            out.base.add(body);
        }
    }
}

/**
 * Walks the document and reports every field it actually references, split into
 * base/parent fields and per-relationship child fields.
 *
 * This is what lets the Query Config be DERIVED rather than maintained by hand. The
 * commonest failure with this product is a tag that renders blank because its field
 * was never queried — the template looks broken and the cause is invisible. Reading
 * the requirement off the document removes the whole class.
 */
export function collectUsedFields(doc) {
    const out = { base: new Set(), children: {} };
    for (const board of doc.artboards || []) {
        for (const box of board.boxes || []) {
            if (box.kind === 'table') {
                const t = box.table || {};
                const rel = t.relationship || '';
                for (const c of t.columns || []) {
                    collectFromText(c.tag, out, rel);
                }
                for (const r of t.rows || []) {
                    for (const cell of r) collectFromText(cell, out, rel);
                }
                for (const cell of (t.totals || {}).cells || []) {
                    // Totals are aggregates over the relationship — the field they name
                    // has to be queried even though the tag itself is not a plain field.
                    const m = /\{(?:SUM|COUNT|AVG|MIN|MAX):([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)/i.exec(cell || '');
                    if (m) {
                        if (!out.children[m[1]]) out.children[m[1]] = new Set();
                        out.children[m[1]].add(m[2]);
                    }
                }
            } else {
                collectFromText(box.text, out, '');
            }
        }
    }
    return out;
}

/**
 * Builds a V1 flat Query Config from what the canvas uses.
 *
 * V1 (not the V3 node tree) on purpose: it is the format a human can read in the
 * Query Configuration tab and correct, which matters because this is a SUGGESTION the
 * author accepts, never a silent overwrite. A generated query that quietly replaced a
 * hand-tuned WHERE clause would be a worse bug than the one it solves.
 */
export function buildQueryConfig(doc) {
    const used = collectUsedFields(doc);
    const base = [...used.base];
    if (!base.length) {
        base.push('Name');
    }
    const parts = [...base];
    for (const rel of Object.keys(used.children)) {
        const fields = [...used.children[rel]];
        if (fields.length) {
            parts.push('(SELECT ' + fields.join(', ') + ' FROM ' + rel + ')');
        }
    }
    return parts.join(', ');
}
