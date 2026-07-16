/**
 * Authoring kit for the HTML-first template creation wizard.
 *
 * Three exports drive the "Start from a Design" and "Generate with AI" paths:
 *  - extractQueryShape(queryConfig, baseObject) — normalizes V1 SOQL strings,
 *    V3 node trees, and V4 provider configs into one { object, baseFields,
 *    parentFields, children } shape the builders consume.
 *  - buildStarterHtml(starterKey, shape) — renders a complete, CSS 2.1-safe
 *    HTML template body with the author's real merge fields injected, ready
 *    to save as v1 and generate on first click.
 *  - buildAiPrompt(shape, options) — assembles a copy-paste LLM prompt with
 *    the full DocGen tag cheat sheet, the Flying Saucer rendering constraints,
 *    and the template's actual schema.
 *
 * Every starter obeys the Flying Saucer envelope: CSS 2.1 only (no flex/grid/
 * calc/variables/gradients), table-based layout, solid colors, @page in the
 * source so the engine defers to it.
 */
import { parseSOQLFields } from 'c/docGenUtils';

/** 'Total_Amount__c' → 'Total Amount'; 'Owner.Name' → 'Owner Name'; 'FirstName' → 'First Name' */
export function humanizeField(apiName) {
    return (apiName || '')
        .replace(/__c$/i, '')
        .replace(/__r\./gi, ' ')
        .replace(/\./g, ' ')
        .replace(/_/g, ' ')
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/\s+/g, ' ')
        .trim();
}

/** Money-shaped field name → render with :currency and right-align. */
export function isMoneyField(apiName) {
    return /amount|total|price|cost|revenue|budget/i.test(apiName || '');
}

/** Quantity-shaped field name → summable, but no currency symbol. */
export function isQuantityField(apiName) {
    return /qty|quantity|hours|units|weight|points|score|seats|licenses/i.test(apiName || '');
}

/**
 * Normalize any Query_Config__c flavor into one simple shape.
 * Never throws — falls back to a Name-only shape so the starter/prompt
 * builders always have something render-worthy.
 */
export function extractQueryShape(queryConfig, baseObject) {
    const shape = {
        object: baseObject || 'Record',
        baseFields: [],
        parentFields: [],
        children: [],
        provider: null
    };
    const q = (queryConfig || '').trim();
    if (!q) {
        shape.baseFields = ['Name'];
        return shape;
    }
    try {
        if (q.startsWith('{')) {
            const cfg = JSON.parse(q);
            if (cfg.v === 4 && cfg.provider) {
                shape.provider = cfg.provider;
                shape.baseFields = ['Name'];
                return shape;
            }
            if (cfg.v === 3 && Array.isArray(cfg.nodes)) {
                const root = cfg.nodes.find((n) => !n.parentNode) || {};
                shape.baseFields = [...(root.fields || [])];
                shape.parentFields = [...(root.parentFields || [])];
                const collectKids = (parentId) => {
                    for (const k of cfg.nodes.filter((n) => n.parentNode === parentId)) {
                        shape.children.push({
                            relationshipName: k.alias || k.relationshipName,
                            fields: [...(k.fields || []), ...(k.parentFields || [])]
                        });
                        // Grandchildren flatten into the list too — starters render
                        // top-level child sections only, but the AI prompt lists all.
                        collectKids(k.id);
                    }
                };
                collectKids(root.id);
            }
        } else {
            const parsed = parseSOQLFields(q);
            shape.baseFields = parsed.baseFields || [];
            shape.parentFields = parsed.parentFields || [];
            const flatten = (subs) => {
                for (const sq of subs || []) {
                    shape.children.push({ relationshipName: sq.relationshipName, fields: sq.fields || [] });
                    flatten(sq.children);
                }
            };
            flatten(parsed.subqueries);
        }
    } catch (e) {
        // eslint-disable-line no-unused-vars
        // Unparseable config — keep going with a minimal shape.
    }
    if (shape.baseFields.length === 0 && shape.parentFields.length === 0) {
        shape.baseFields = ['Name'];
    }
    return shape;
}

// ---------------------------------------------------------------------------
// Shared HTML fragments
// ---------------------------------------------------------------------------

const BASE_CSS = `
        @page { size: Letter portrait; margin: 0.75in; }
        body { font-family: Helvetica, Arial, sans-serif; font-size: 10.5pt; color: #1a1a1a; margin: 0; }
        h1 { font-size: 20pt; margin: 0 0 2pt 0; color: #1f3a5f; }
        h2 { font-size: 13pt; margin: 18pt 0 6pt 0; color: #1f3a5f; border-bottom: 2pt solid #1f3a5f; padding-bottom: 3pt; }
        table { width: 100%; border-collapse: collapse; border-spacing: 0; }
        td, th { padding: 5pt 7pt; vertical-align: top; }
        .meta { color: #666666; font-size: 9pt; }
        .label-cell { width: 35%; font-weight: bold; color: #444444; background: #f2f4f7; border-bottom: 1pt solid #ffffff; }
        .value-cell { border-bottom: 1pt solid #eeeeee; }
        .data-table th { background: #1f3a5f; color: #ffffff; text-align: left; font-size: 9.5pt; }
        .data-table td { border-bottom: 0.75pt solid #dddddd; }
        .footer-note { margin-top: 24pt; padding-top: 6pt; border-top: 1pt solid #cccccc; color: #888888; font-size: 8.5pt; }`;

function detailRows(fields) {
    return fields
        .map((f) => {
            const tag = isMoneyField(f) ? `{${f}:currency}` : `{${f}}`;
            return `            <tr>\n                <td class="label-cell">${humanizeField(f)}</td>\n                <td class="value-cell">${tag}</td>\n            </tr>`;
        })
        .join('\n');
}

// Loop tags must open in the first cell and close in the last so container
// auto-expansion repeats the whole <tr> per child row.
export function childLoopTable(child) {
    const rel = child.relationshipName;
    const fields = child.fields.length ? child.fields : ['Name'];
    const headCells = fields
        .map((f) => {
            const align = isMoneyField(f) ? ' style="text-align: right"' : '';
            return `                    <th${align}>${humanizeField(f)}</th>`;
        })
        .join('\n');
    const cells = fields
        .map((f, i) => {
            const money = isMoneyField(f);
            let inner = money ? `{${f}:currency}` : `{${f}}`;
            if (i === 0) inner = `{#${rel}}` + inner;
            if (i === fields.length - 1) inner = inner + `{/${rel}}`;
            const align = money ? ' style="text-align: right"' : '';
            return `                    <td${align}>${inner}</td>`;
        })
        .join('\n');
    return `        <table class="data-table">
            <thead>
                <tr>
${headCells}
                </tr>
            </thead>
            <tbody>
                <tr>
${cells}
                </tr>
            </tbody>
        </table>`;
}

function docShell(title, bodyInner, extraCss) {
    return `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>${title}</title>
    <style>${BASE_CSS}${extraCss || ''}
    </style>
</head>
<body>
${bodyInner}
</body>
</html>
`;
}

// ---------------------------------------------------------------------------
// Starters
// ---------------------------------------------------------------------------

function buildReport(shape) {
    const detailFields = [...shape.baseFields, ...shape.parentFields];
    const sections = shape.children
        .map((c) => `\n    <h2>${humanizeField(c.relationshipName)}</h2>\n${childLoopTable(c)}`)
        .join('\n');
    const inner = `    <table>
        <tr>
            <td>
                <h1>{Name}</h1>
                <div class="meta">${humanizeField(shape.object)} Report</div>
            </td>
            <td style="text-align: right" class="meta">
                Prepared by {RunningUser.Name}<br />
                {Today:MMMM d, yyyy}
            </td>
        </tr>
    </table>

    <h2>Details</h2>
    <table>
${detailRows(detailFields)}
    </table>
${sections}

    <div class="footer-note">Generated with Portwood DocGen &#8226; {Today:MM/dd/yyyy}</div>`;
    return docShell('Record Report', inner);
}

function buildLetter(shape) {
    const inner = `    <table>
        <tr>
            <td>
                <h1 style="font-size: 14pt">Your Company Name</h1>
                <div class="meta">123 Your Street &#8226; Your City, ST 00000 &#8226; (555) 555-0100</div>
            </td>
            <td style="text-align: right" class="meta">{Today:MMMM d, yyyy}</td>
        </tr>
    </table>

    <p style="margin-top: 28pt">{Name}</p>

    <p style="margin-top: 18pt">Dear {Name},</p>

    <p>
        Replace this paragraph with your letter body. Any field from your Query Config drops in with a merge
        tag &#8212; for example, this record is {Name}. Format dates and money with suffixes like
        &#123;CloseDate:MMMM d, yyyy&#125; and &#123;Amount:currency&#125;.
    </p>

    <p>
        A second paragraph of your letter. Conditional blocks let you include text only when a field has a
        value, and loops repeat a block for every child record.
    </p>

    <p style="margin-top: 30pt">
        Sincerely,<br /><br /><br />
        {RunningUser.Name}<br />
        <span class="meta">{RunningUser.Title}</span>
    </p>`;
    return docShell('Business Letter', inner);
}

function buildInvoice(shape) {
    const child = shape.children[0];
    const rel = child ? child.relationshipName : null;
    const sumField = child ? child.fields.find(isMoneyField) : null;
    const lineTable = child
        ? childLoopTable(child)
        : `        <table class="data-table">
            <thead>
                <tr>
                    <th>Description</th>
                    <th style="text-align: right">Amount</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Add a child relationship in your Query Config to loop line items here.</td>
                    <td style="text-align: right">&#8212;</td>
                </tr>
            </tbody>
        </table>`;
    const totalRow =
        rel && sumField
            ? `\n    <table style="margin-top: 8pt">
        <tr>
            <td style="width: 70%"></td>
            <td class="label-cell" style="text-align: right">Total</td>
            <td class="value-cell" style="text-align: right; font-weight: bold">{SUM:${rel}.${sumField}:currency}</td>
        </tr>
    </table>`
            : '';
    const inner = `    <table>
        <tr>
            <td>
                <h1>INVOICE</h1>
                <div class="meta">Your Company Name</div>
            </td>
            <td style="text-align: right" class="meta">
                Date: {Today:MM/dd/yyyy}<br />
                Reference: {Name}
            </td>
        </tr>
    </table>

    <h2>Billed To</h2>
    <table>
${detailRows([...shape.baseFields, ...shape.parentFields])}
    </table>

    <h2>Line Items</h2>
${lineTable}${totalRow}

    <div class="footer-note">Payment due within 30 days &#8226; Generated {Today:MMMM d, yyyy} by {RunningUser.Name}</div>`;
    return docShell('Invoice', inner);
}

function buildAgreement(shape) {
    const inner = `    <h1 style="text-align: center">Agreement</h1>
    <p class="meta" style="text-align: center">Effective {Today:MMMM d, yyyy}</p>

    <p style="margin-top: 20pt">
        This Agreement is entered into between <strong>Your Company Name</strong> ("Company") and
        <strong>{Name}</strong> ("Customer").
    </p>

    <h2>1. Scope</h2>
    <p>Describe the goods or services covered by this agreement. Merge any field from your Query Config, e.g. {Name}.</p>

    <h2>2. Term</h2>
    <p>This agreement begins on {Today:MMMM d, yyyy} and continues until terminated by either party.</p>

    <h2>3. Signatures</h2>
    <p>Signed and agreed by the parties below.</p>

    <table style="margin-top: 30pt">
        <tr>
            <td style="width: 48%">
                {@Signature_Customer:1:Full}
                <div style="border-top: 1pt solid #333333; margin-top: 4pt; padding-top: 3pt" class="meta">
                    Customer &#8226; Date: {@Signature_Customer:1:Date}
                </div>
            </td>
            <td style="width: 4%"></td>
            <td style="width: 48%">
                {@Signature_Company_Representative:2:Full}
                <div style="border-top: 1pt solid #333333; margin-top: 4pt; padding-top: 3pt" class="meta">
                    Company Representative &#8226; Date: {@Signature_Company_Representative:2:Date}
                </div>
            </td>
        </tr>
    </table>`;
    return docShell('Agreement', inner);
}

export const STARTERS = [
    {
        key: 'report',
        label: 'Record Report',
        icon: 'utility:summarydetail',
        description:
            'Title band, a details table of your fields, and a table per child relationship. The safe default for any object.'
    },
    {
        key: 'invoice',
        label: 'Invoice / Line Items',
        icon: 'utility:money',
        description:
            'Billed-to block plus a line-item loop table from your first child relationship, with an automatic total row.'
    },
    {
        key: 'letter',
        label: 'Business Letter',
        icon: 'utility:email',
        description: 'Letterhead, date, salutation, and body copy with merge fields — signed by the running user.'
    },
    {
        key: 'agreement',
        label: 'Agreement (Signature-ready)',
        icon: 'utility:signature',
        description: 'Numbered terms with a two-party e-signature block wired to DocGen signature tags.'
    }
];

const BUILDERS = { report: buildReport, invoice: buildInvoice, letter: buildLetter, agreement: buildAgreement };

export function buildStarterHtml(starterKey, shape) {
    const builder = BUILDERS[starterKey] || buildReport;
    return builder(shape);
}

// ---------------------------------------------------------------------------
// AI prompt
// ---------------------------------------------------------------------------

/**
 * Assemble a self-contained LLM prompt: rendering constraints + tag syntax +
 * this template's actual schema. Works pasted into any assistant.
 */
export function buildAiPrompt(shape, options) {
    const opts = options || {};
    const lines = [];
    lines.push(
        'You are writing an HTML document template for Portwood DocGen, a native Salesforce document-generation package. The template is a single self-contained HTML file. DocGen replaces {merge tags} with Salesforce record data, then renders the HTML to PDF with the Flying Saucer engine.'
    );
    lines.push('');
    lines.push('HARD RENDERING CONSTRAINTS (Flying Saucer = CSS 2.1 plus a small CSS 3 subset):');
    lines.push('- Layout with <table>/<tr>/<td>, or <div> with display:table / table-row / table-cell.');
    lines.push(
        '- NEVER use: flexbox, grid, gap, calc(), CSS variables, linear-gradient or any gradient, position:sticky, transforms. They are silently ignored and the layout collapses.'
    );
    lines.push('- Solid colors only. No web fonts — stick to Helvetica/Arial/Times/Georgia/Courier.');
    lines.push(
        "- No <svg> and no JavaScript — they are dropped. Images must be <img> with regular src URLs; don't invent image URLs."
    );
    lines.push(
        '- Avoid child selectors involving tbody (e.g. table > tbody > tr) — they silently fail. Use classes on cells instead.'
    );
    lines.push(
        '- Declare the page setup with an @page rule in a <style> block, e.g. @page { size: Letter portrait; margin: 0.75in; }'
    );
    lines.push(
        '- Every {...} pair is treated as a merge tag: unknown names render as empty text, and an unclosed { fails the merge. For literal braces use &#123; and &#125;.'
    );
    lines.push('');
    lines.push('DOCGEN MERGE TAG SYNTAX:');
    lines.push(
        '- Field: {FieldName} — e.g. {Name}, {Status__c}. Parent lookups dot through: {Account.Name}, {Owner.Profile.Name}. Null renders as empty string.'
    );
    lines.push(
        '- Format suffixes: {CloseDate:MMMM d, yyyy} (Java SimpleDateFormat), {CloseDate:date} (user locale), {Amount:currency}, {Amount:currency:EUR}, {Qty:number}, {Qty:#,##0.00}, {Rate:percent}, {IsActive:checkbox} ([X]/[ ]), {Status__c:label} (picklist label).'
    );
    lines.push(
        '- Child loop: {#RelationshipName} ... {/RelationshipName} repeats the block per child record; child fields are bare inside the loop. If the tags sit inside a table row, the whole <tr> repeats — put {#Rel} in the first cell and {/Rel} in the last cell of the data row. Use a real <thead> for column headers. Nested loops are supported.'
    );
    lines.push('- Conditional: {#SomeField} shown when truthy {:else} otherwise {/SomeField}.');
    lines.push(
        '- Aggregates: {SUM:Rel.Field}, plus AVG/MIN/MAX/COUNT — format suffixes apply, e.g. {SUM:Lines.Amount:currency}.'
    );
    lines.push(
        '- Built-ins: {Today:MMMM d, yyyy}, {Now:yyyy-MM-dd HH:mm}, and running-user tags {RunningUser.Name}, {RunningUser.Email}, {RunningUser.Title}.'
    );
    lines.push(
        '- E-signature placeholders (only if asked for a signable document): {@Signature_RoleName:1:Full}, {@Signature_RoleName:1:Date}.'
    );
    lines.push('');
    lines.push('DATA SHAPE — use ONLY these fields (any other tag renders empty):');
    if (opts.dataSourceMode === 'flow') {
        lines.push(
            '- Data arrives at runtime as JSON from a Salesforce Flow. Describe your JSON keys to me here, then use them as {key} tags. Lists loop with {#listKey}...{/listKey}.'
        );
    } else if (shape.provider) {
        lines.push(`- Data comes from the Apex provider class ${shape.provider}. Fields available:`);
        for (const f of opts.providerFields || []) {
            lines.push(`  - {${f}}`);
        }
        if (!(opts.providerFields || []).length) {
            lines.push('  - (list your provider field names here before pasting)');
        }
    } else {
        lines.push(`- Base object: ${shape.object}`);
        for (const f of [...shape.baseFields, ...shape.parentFields]) {
            lines.push(`  - {${f}}${f.includes('.') ? ' (parent lookup)' : ''}`);
        }
        for (const c of shape.children) {
            lines.push(
                `- Child relationship {#${c.relationshipName}}...{/${c.relationshipName}} with fields: ${c.fields.map((f) => '{' + f + '}').join(', ')}`
            );
        }
    }
    lines.push('');
    lines.push('WHAT I WANT THIS DOCUMENT TO BE:');
    lines.push(
        '<<DESCRIBE YOUR DOCUMENT HERE: purpose, sections, tone, branding colors. Example: "A two-page account summary: header with account name and logo placeholder, key details table, then a table of open opportunities with a total row.">>'
    );
    lines.push('');
    lines.push('OUTPUT REQUIREMENTS:');
    lines.push(
        '1. Return ONE complete self-contained HTML file (<!DOCTYPE html> ... </html>) with all CSS inline in a single <style> block. No commentary, no markdown fences.'
    );
    lines.push('2. Professional print-ready design within the CSS 2.1 constraints above.');
    lines.push('3. Use only the merge tags listed in DATA SHAPE (plus {Today}/{RunningUser.*} built-ins).');
    return lines.join('\n');
}

// ---------------------------------------------------------------------------
// HTML pretty-printer (Format Code button)
// ---------------------------------------------------------------------------

const VOID_TAGS = /^(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)$/i;

/**
 * Conservative HTML formatter for the template editors. Only inserts
 * whitespace BETWEEN adjacent tags (never inside text runs), so merge tags
 * and inline text spacing are untouched. <style>/<script>/<pre>/<textarea>
 * blocks pass through verbatim.
 */
export function prettyPrintHtml(html) {
    if (!html || typeof html !== 'string') {
        return html;
    }
    const protectedBlocks = [];
    let work = html.replace(/<(style|script|pre|textarea)\b[\s\S]*?<\/\1\s*>/gi, (m) => {
        protectedBlocks.push(m);
        return '@@DGBLK' + (protectedBlocks.length - 1) + '@@';
    });
    // Break only where two tags touch (optionally separated by pure whitespace),
    // and around protected-block placeholders so they land on their own line.
    work = work
        .replace(/>\s*</g, '>\n<')
        .replace(/(@@DGBLK\d+@@)\s*</g, '$1\n<')
        .replace(/>\s*(@@DGBLK\d+@@)/g, '>\n$1');
    const lines = work.split('\n');
    const out = [];
    let depth = 0;
    for (const raw of lines) {
        const line = raw.trim();
        if (!line) {
            continue;
        }
        const isClosing = /^<\//.test(line);
        if (isClosing) {
            depth = Math.max(0, depth - 1);
        }
        out.push('    '.repeat(depth) + line);
        const openMatch = line.match(/^<([a-zA-Z][\w-]*)/);
        if (openMatch && !isClosing) {
            const tag = openMatch[1];
            const selfClosed = /\/>\s*$/.test(line) || VOID_TAGS.test(tag);
            const closedSameLine = new RegExp('</' + tag + '\\s*>\\s*$', 'i').test(line);
            if (!selfClosed && !closedSameLine) {
                depth++;
            }
        }
    }
    return out.join('\n').replace(/@@DGBLK(\d+)@@/g, (m, i) => protectedBlocks[Number(i)]);
}

// ---------------------------------------------------------------------------
// Inline preview (Code ⇄ Preview toggle)
// ---------------------------------------------------------------------------

/**
 * Prepare template HTML for INLINE rendering inside the admin UI.
 *
 * Lightning Web Security blocks iframe srcdoc/document.write, so the preview
 * renders straight into a lwc:dom="manual" div. To keep the template's CSS
 * from leaking into the admin page, every selector is prefixed with the
 * .dg-pv scope class (html/body selectors are remapped to the scope itself),
 * @page rules are dropped (meaningless inline), and scripts/event handlers
 * are stripped. Merge tags render as-is — this is a layout preview, not a
 * data merge.
 */
export function scopeHtmlForInlinePreview(html) {
    let work = (html || '').replace(/<script\b[\s\S]*?<\/script\s*>/gi, '').replace(/<link\b[^>]*>/gi, '');
    const styles = [];
    work = work.replace(/<style\b[^>]*>([\s\S]*?)<\/style\s*>/gi, (m, css) => {
        styles.push(css);
        return '';
    });
    const bodyMatch = work.match(/<body\b[^>]*>([\s\S]*?)<\/body\s*>/i);
    let content = bodyMatch ? bodyMatch[1] : work.replace(/<\/?(?:!DOCTYPE|html|head|body|meta|title)\b[^>]*>/gi, '');
    // Strip inline event handlers (on*="...") — static preview only.
    content = content.replace(/\son\w+\s*=\s*(["'])[\s\S]*?\1/gi, '');

    let css = styles.join('\n').replace(/@page\b[^{]*{[^}]*}/gi, '');
    // Prefix every selector with the scope class. Handles the flat CSS 2.1
    // rules templates use; at-rule headers (@media etc.) pass through and
    // their inner rules get scoped by the same pass.
    css = css.replace(/(^|})([^{}@]+){/g, (m, brace, selectors) => {
        const scoped = selectors
            .split(',')
            .map((s) => {
                const sel = s.trim();
                if (!sel) {
                    return sel;
                }
                if (/^(html|body)$/i.test(sel)) {
                    return '.dg-pv';
                }
                return '.dg-pv ' + sel.replace(/^(html|body)\s+/i, '');
            })
            .join(', ');
        return brace + '\n' + scoped + ' {';
    });

    // Baseline "paper sheet" look, injected with the content because
    // component CSS can't reach lwc:dom="manual" children. Declared first so
    // the template's own (scoped) rules win any conflicts.
    const baseline =
        '.dg-pv { background: #fff; max-width: 850px; margin: 0 auto; padding: 48px 56px; ' +
        'box-shadow: 0 2px 12px rgba(0, 0, 0, 0.18); font-family: Helvetica, Arial, sans-serif; ' +
        'font-size: 10.5pt; color: #1a1a1a; min-height: 380px; box-sizing: border-box; }';
    return '<div class="dg-pv"><style>' + baseline + css + '</style>' + content + '</div>';
}

// ---------------------------------------------------------------------------
// Tag palette (Insert Tags panel)
// ---------------------------------------------------------------------------

/**
 * Build the click-to-insert tag palette from the template's actual Query
 * Config shape: its record fields, its child relationships (with a
 * ready-made loop table), plus the universal built-ins, signature tags,
 * conditionals, and aggregates.
 */
export function buildTagPalette(shape) {
    const sections = [];
    const tagFor = (f) => (isMoneyField(f) ? '{' + f + ':currency}' : '{' + f + '}');

    const fieldItems = [...(shape.baseFields || []), ...(shape.parentFields || [])].map((f) => ({
        key: 'f_' + f,
        label: humanizeField(f),
        snippet: tagFor(f),
        title: 'Insert ' + tagFor(f)
    }));
    if (fieldItems.length) {
        sections.push({
            key: 'fields',
            label: 'Record Fields',
            hint: 'From this template’s Query Config — click to insert at your cursor.',
            items: fieldItems
        });
    }

    for (const child of shape.children || []) {
        const rel = child.relationshipName;
        // Aggregates generated from the loop's OWN fields — no placeholder
        // editing. Money fields get SUM/AVG with :currency, quantity-shaped
        // fields plain SUM, and every loop gets a record count.
        const aggregateItems = [];
        for (const f of child.fields || []) {
            if (isMoneyField(f)) {
                aggregateItems.push(
                    {
                        key: rel + '_sum_' + f,
                        label: 'Total ' + humanizeField(f),
                        snippet: '{SUM:' + rel + '.' + f + ':currency}',
                        title:
                            'Sum of ' +
                            humanizeField(f) +
                            ' across all ' +
                            humanizeField(rel) +
                            ' — goes OUTSIDE the loop'
                    },
                    {
                        key: rel + '_avg_' + f,
                        label: 'Average ' + humanizeField(f),
                        snippet: '{AVG:' + rel + '.' + f + ':currency}',
                        title: 'Average ' + humanizeField(f) + ' — goes OUTSIDE the loop'
                    }
                );
            } else if (isQuantityField(f)) {
                aggregateItems.push({
                    key: rel + '_sum_' + f,
                    label: 'Total ' + humanizeField(f),
                    snippet: '{SUM:' + rel + '.' + f + '}',
                    title:
                        'Sum of ' + humanizeField(f) + ' across all ' + humanizeField(rel) + ' — goes OUTSIDE the loop'
                });
            }
        }
        aggregateItems.push({
            key: rel + '_count',
            label: 'Count of ' + humanizeField(rel),
            snippet: '{COUNT:' + rel + '.Id}',
            title: 'Number of ' + humanizeField(rel) + ' records — goes OUTSIDE the loop'
        });
        sections.push({
            key: 'rel_' + rel,
            label: humanizeField(rel) + ' — child loop',
            hint:
                'Child fields only resolve inside the {#' + rel + '}…{/' + rel + '} loop. Totals/counts go outside it.',
            items: [
                {
                    key: rel + '_table',
                    label: 'Loop table (all fields)',
                    snippet: '\n' + childLoopTable(child) + '\n',
                    title: 'A table that repeats one row per ' + rel + ' record'
                },
                {
                    key: rel + '_loop',
                    label: 'Inline loop block',
                    snippet: '{#' + rel + '} … {/' + rel + '}',
                    title: 'Repeats its contents once per ' + rel + ' record'
                },
                ...(child.fields || []).map((f) => ({
                    key: rel + '_' + f,
                    label: humanizeField(f),
                    snippet: tagFor(f),
                    title: tagFor(f) + ' — place inside the {#' + rel + '} loop'
                })),
                ...aggregateItems
            ]
        });
    }

    sections.push({
        key: 'builtins',
        label: 'Built-ins',
        hint: 'Work on every template, no configuration.',
        items: [
            { key: 'today_long', label: 'Today (long)', snippet: '{Today:MMMM d, yyyy}', title: 'April 17, 2026' },
            { key: 'today_num', label: 'Today (numeric)', snippet: '{Today:MM/dd/yyyy}', title: '04/17/2026' },
            { key: 'now', label: 'Now (timestamp)', snippet: '{Now:yyyy-MM-dd HH:mm}', title: 'Current date-time' },
            {
                key: 'ru_name',
                label: 'Running user',
                snippet: '{RunningUser.Name}',
                title: 'Whoever generates the document'
            },
            {
                key: 'ru_title',
                label: 'Running user title',
                snippet: '{RunningUser.Title}',
                title: '{RunningUser.Title}'
            },
            {
                key: 'ru_email',
                label: 'Running user email',
                snippet: '{RunningUser.Email}',
                title: '{RunningUser.Email}'
            }
        ]
    });

    sections.push({
        key: 'sig',
        label: 'E-Signature',
        hint: 'Role + order + type. Roles are free-form — Buyer, Seller, Witness…',
        items: [
            {
                key: 'sig_full',
                label: 'Signature (Customer)',
                snippet: '{@Signature_Customer:1:Full}',
                title: 'Full signature stamp'
            },
            {
                key: 'sig_date',
                label: 'Signed date (Customer)',
                snippet: '{@Signature_Customer:1:Date}',
                title: 'Auto-filled when signed'
            },
            {
                key: 'sig_init',
                label: 'Initials (Customer)',
                snippet: '{@Signature_Customer:1:Initials}',
                title: 'Initials stamp'
            },
            {
                key: 'sig_rep',
                label: 'Signature (Company rep)',
                snippet: '{@Signature_Company_Representative:2:Full}',
                title: 'Second signer, order 2'
            }
        ]
    });

    // Real aggregates live in each relationship's own section, built from its
    // actual fields. Generic placeholders only appear as a fallback when the
    // Query Config has no child relationships to build from.
    const logicItems = [
        {
            key: 'ifelse',
            label: 'If / else block',
            snippet: '{#FieldName}shown when set{:else}shown when empty{/FieldName}',
            title: 'Conditional content — swap FieldName for one of yours'
        },
        {
            key: 'checkbox',
            label: 'Checkbox render',
            snippet: '{FieldName:checkbox}',
            title: '[X] when true, [ ] when false'
        }
    ];
    if (!(shape.children || []).length) {
        logicItems.push(
            {
                key: 'sum',
                label: 'SUM of child field',
                snippet: '{SUM:Relationship.Field:currency}',
                title: 'Total across child records — add a child relationship to your Query Config for ready-made totals'
            },
            {
                key: 'count',
                label: 'COUNT of children',
                snippet: '{COUNT:Relationship.Id}',
                title: 'Number of child records'
            }
        );
    }
    sections.push({
        key: 'logic',
        label: 'Conditionals',
        hint: 'Swap FieldName for one of your fields.',
        items: logicItems
    });

    return sections;
}
