/**
 * DocGenChartTagExpander
 *
 * Author-friendly wrapper around {#ChartBucket:...} that lets a template
 * author drop one short tag into an HTML template and get a fully-styled
 * chart block in return.
 *
 *   {Chart:Survey_Responses__r:Selected_Answer__c}                       (default: bar)
 *   {Chart:Survey_Responses__r:Selected_Answer__c:bar:title=How satisfied?}
 *   {Chart:Survey_Responses__r:Selected_Answer__c:pivot:groupBy=Department__c&colSort=Eng,Sales}
 *
 * The expander runs as a preprocessing pass inside DocGenService.processXml
 * BEFORE DocGenChartBucketResolver.preprocessInline. It rewrites each
 * {Chart:...} tag into an HTML snippet that itself contains a
 * {#ChartBucket:...} loop — so all the existing bucket-resolution machinery
 * (in-memory / SOQL fallback / parent-level / giant-query) keeps working
 * unchanged. The tag composes; styles are inline so Flying Saucer renders
 * them in PDF without CSS-class lookups.
 *
 * Styles (v1):
 *   bar       horizontal bar per bucket, label + colored fill + count(percent)
 *   pivot     cross-tab: rows = answers, cols = groupBy values (% per cell)
 *   clustered vertical clustered bar chart: column per answer, bar per groupBy
 *   stacked   horizontal stacked bar: one row per answer, segments per groupBy
 *
 * Cross-tab styles require groupBy=Field__c AND colSort=Val1,Val2,... — the
 * colSort drives header generation since column labels can't be known
 * without enumerating the groupBy values up front.
 *
 * Bad tags render an inline error block in HTML output so the author sees
 * the problem in their generated PDF rather than chasing a silent miss.
 * In Word templates (#117 PNG-via-CV pipeline), bad tags emit a `[Chart error: ...]`
 * text placeholder instead — keeping the document well-formed even when a
 * template author writes a malformed tag.
 */
public with sharing class DocGenChartTagExpander {
    private static final String OPEN_PREFIX = '{Chart:';
    private static final Set<String> ALLOWED_STYLES = new Set<String>{ 'bar', 'pivot', 'clustered', 'stacked' };
    private static final Set<String> CROSS_TAB_STYLES = new Set<String>{ 'pivot', 'clustered', 'stacked' };

    /**
     * Legacy two-arg entry point. Routes to the chart-CV-aware overload with
     * no map / no data so existing callers (and tests that exercised the
     * HTML-only behavior) keep their shape.
     */
    public static String expand(String xml, String templateType) {
        return expand(xml, templateType, null, null);
    }

    /**
     * Top-level entry point with chart-CV awareness (#117).
     *
     * For HTML templates: behavior unchanged — emits the existing CSS-bar
     * table per chart.
     *
     * For Word templates with `chartCvMap` populated: each chart tag whose
     * signature matches a CV in the map is substituted with `{%__dgchart_<cvId>}`,
     * and the data map is seeded with `__dgchart_<cvId> → cvId` so the existing
     * image-tag scanner at DocGenService:3079 resolves the synthetic field to
     * the CV Id. From there `buildImageXml` case-4 handles DOCX (blob embed)
     * vs PDF (relative CV URL) automatically.
     *
     * For Word templates with no matching CV (server-side flow with no LWC
     * to rasterize, or a chart added to the template after preflight): emits
     * a text placeholder `[Chart: rel.field]` rather than corrupting the
     * document with an unresolved image tag.
     */
    public static String expand(
        String xml,
        String templateType,
        Map<String, Object> data,
        Map<String, String> chartCvMap
    ) {
        if (xml == null || !xml.contains(OPEN_PREFIX)) {
            return xml;
        }

        List<String> out = new List<String>();
        Integer cursor = 0;
        Integer len = xml.length();
        Boolean isHtml = (templateType == 'HTML');

        while (cursor < len) {
            Integer next = xml.indexOf(OPEN_PREFIX, cursor);
            if (next == -1) {
                out.add(xml.substring(cursor));
                break;
            }
            out.add(xml.substring(cursor, next));
            Integer close = xml.indexOf('}', next);
            if (close == -1) {
                out.add(
                    renderError(
                        isHtml,
                        'Unterminated {Chart:...} tag — no closing brace.',
                        xml.substring(next, Math.min(next + 60, len))
                    )
                );
                break;
            }
            String tagBody = decodeEntities(xml.substring(next + OPEN_PREFIX.length(), close));
            String fullTag = xml.substring(next, close + 1);
            try {
                out.add(buildSnippet(tagBody, isHtml, templateType, data, chartCvMap));
            } catch (ChartTagException e) {
                out.add(renderError(isHtml, e.getMessage(), fullTag));
            }
            cursor = close + 1;
        }

        return String.join(out, '');
    }

    /**
     * Parses one tag body (everything between "{Chart:" and "}") and returns
     * the corresponding substitution snippet. Throws ChartTagException with a
     * human-readable reason on any validation failure — caller renders it as
     * an inline error block (HTML) or escalates (non-HTML).
     *
     * For non-HTML templates (Word): looks up the tag's signature in
     * `chartCvMap`; if found, emits `{%__dgchart_<cvId>}` and seeds `data`
     * with the synthetic key. If not found, emits a `[Chart: rel.field]`
     * text placeholder — documented v1 fallback for server-side flows.
     *
     * For HTML templates: behavior unchanged from pre-#117 — emits the
     * existing CSS-bar / pivot / clustered / stacked table.
     */
    private static String buildSnippet(
        String tagBody,
        Boolean isHtml,
        String templateType,
        Map<String, Object> data,
        Map<String, String> chartCvMap
    ) {
        // Tag form: REL:FIELD[:STYLE[:k=v&k=v...]]
        // We split on ':' up to 3 times so option values can contain ':'.
        List<String> parts = splitLimit(tagBody, ':', 4);
        if (parts.size() < 2) {
            throw new ChartTagException(
                'Need at least a relationship and a field, e.g. {Chart:Survey_Responses__r:Selected_Answer__c}.'
            );
        }
        String relationship = parts[0].trim();
        String field = parts[1].trim();
        String style = parts.size() >= 3 && String.isNotBlank(parts[2]) ? parts[2].trim().toLowerCase() : 'bar';
        String rawOpts = parts.size() >= 4 ? parts[3] : '';

        if (String.isBlank(relationship) || String.isBlank(field)) {
            throw new ChartTagException('Relationship and field are required.');
        }
        if (!ALLOWED_STYLES.contains(style)) {
            throw new ChartTagException('Unknown style "' + style + '". Allowed: bar, pivot, clustered, stacked.');
        }

        Map<String, String> opts = parseOptions(rawOpts);
        // Compute the chart signature BEFORE removing `title` from opts —
        // DocGenChartImageController.prepareChartImages hashes the full options
        // map (including title) when assigning a CV. If we strip title first
        // and then hash, expander signature ≠ controller signature, the CV
        // lookup misses, and every titled chart falls back to text. Must
        // mirror the controller's input exactly.
        String signature = isHtml ? null : DocGenChartImageController.tagSignature(relationship, field, style, opts);
        String title = opts.remove('title');

        if (CROSS_TAB_STYLES.contains(style)) {
            if (String.isBlank(opts.get('groupBy'))) {
                throw new ChartTagException('Style "' + style + '" requires groupBy=YourField__c.');
            }
            if (String.isBlank(opts.get('colSort'))) {
                throw new ChartTagException(
                    'Style "' + style + '" requires colSort=Val1,Val2,... so column headers can be generated.'
                );
            }
        }

        // Non-HTML templates (Word/PPT/Excel for #117): route to the PNG-via-CV
        // pipeline. The LWC has already rasterized each chart's SVG to a PNG and
        // uploaded it as a ContentVersion; `chartCvMap[signature]` is the CV Id.
        // Server-side flows (Flow / batch / async) hit this path with an empty
        // map and get a text placeholder — documented v1 limitation.
        if (!isHtml) {
            // `signature` was precomputed above against the options map that
            // still included title — matches what the controller hashed.
            String cvId = (chartCvMap == null) ? null : chartCvMap.get(signature);
            if (String.isNotBlank(cvId)) {
                if (data != null) {
                    // Synthetic key seeding mirrors how DocGenChartBucketResolver.
                    // preprocessInline injects _cb_N for bucket lists.
                    data.put('__dgchart_' + cvId, cvId);
                }
                return '{%__dgchart_' + cvId + '}';
            }
            String labelText = String.isNotBlank(title) ? title : (relationship + '.' + field);
            return '[Chart: ' + labelText + ']';
        }

        String chartBucketTag = buildChartBucketTag(relationship, field, opts);

        if (style == 'bar') {
            return renderBar(title, chartBucketTag);
        } else if (style == 'pivot') {
            return renderPivot(title, chartBucketTag, opts.get('colSort'));
        } else if (style == 'clustered') {
            return renderClustered(title, chartBucketTag, opts.get('colSort'));
        } else if (style == 'stacked') {
            return renderStacked(title, chartBucketTag, opts.get('colSort'));
        }
        // Unreachable due to ALLOWED_STYLES guard above.
        throw new ChartTagException('Unhandled style: ' + style);
    }

    /**
     * Reassembles the inner {#ChartBucket:rel:field:opts} tag from the options
     * map (sans title, which is consumed by the expander).
     */
    private static String buildChartBucketTag(String relationship, String field, Map<String, String> opts) {
        String tag = '{#ChartBucket:' + relationship + ':' + field;
        if (!opts.isEmpty()) {
            List<String> kvs = new List<String>();
            for (String key : opts.keySet()) {
                kvs.add(key + '=' + opts.get(key));
            }
            tag += ':' + String.join(kvs, '&');
        }
        return tag + '}';
    }

    // ─── style renderers ─────────────────────────────────────────────────

    private static String renderBar(String title, String chartBucketTag) {
        String h = String.isBlank(title)
            ? ''
            : '<h2 style="margin:18px 0 10px 0; color:#1e3a8a; font-size:16pt; font-weight:bold; line-height:1.25;">' +
              escape(title) +
              '</h2>';
        return h +
            '<table style="width:100%; border-collapse:collapse; margin:6px 0 18px 0;">' +
            chartBucketTag +
            '<tr>' +
            '<td style="padding:7px 6px; vertical-align:middle; border-bottom:1px solid #e5e7eb; font-weight:bold; color:#1f2937; padding-right:14px; width:28%;">{key_label}</td>' +
            '<td style="padding:7px 6px; vertical-align:middle; border-bottom:1px solid #e5e7eb; width:55%;">' +
            '<div style="width:100%; background-color:#f3f4f6; height:18px; border:1px solid #e5e7eb;">' +
            '<div style="height:18px; line-height:18px; font-size:1px; width:{percent}%; background-color:{color};">&nbsp;</div>' +
            '</div>' +
            '</td>' +
            '<td style="padding:7px 6px; vertical-align:middle; border-bottom:1px solid #e5e7eb; width:17%; text-align:right; color:#6b7280; font-size:10pt; padding-left:14px; white-space:nowrap;">{count} ({percent}%)</td>' +
            '</tr>' +
            '{:else}' +
            '<tr><td colspan="3" style="padding:14px; background-color:#fef3c7; border-left:4px solid #fbbf24; color:#92400e; font-style:italic;">No data available for this chart.</td></tr>' +
            '{/ChartBucket}' +
            '</table>';
    }

    private static String renderPivot(String title, String chartBucketTag, String colSort) {
        String h = String.isBlank(title)
            ? ''
            : '<h2 style="margin:18px 0 10px 0; color:#1e3a8a; font-size:16pt; font-weight:bold; line-height:1.25;">' +
              escape(title) +
              '</h2>';

        List<String> headerCells = new List<String>();
        headerCells.add(
            '<div style="display:table-cell; padding:8px 10px; background-color:#1e3a8a; color:#fff; font-weight:bold; font-size:9pt; letter-spacing:1px; text-transform:uppercase; border-bottom:2px solid #fbbf24; text-align:left;">Answer</div>'
        );
        for (String col : colSort.split(',')) {
            headerCells.add(
                '<div style="display:table-cell; padding:8px 10px; background-color:#1e3a8a; color:#fff; font-weight:bold; font-size:9pt; letter-spacing:1px; text-transform:uppercase; border-bottom:2px solid #fbbf24; text-align:right;">' +
                    escape(col.trim()) +
                    '</div>'
            );
        }
        headerCells.add(
            '<div style="display:table-cell; padding:8px 10px; background-color:#fbbf24; color:#1f2937; font-weight:bold; font-size:9pt; letter-spacing:1px; text-transform:uppercase; border-bottom:2px solid #fbbf24; text-align:right;">Total</div>'
        );

        return h +
            '<div style="display:table; width:100%; border-collapse:collapse; margin:6px 0 18px 0;">' +
            '<div style="display:table-row;">' +
            String.join(headerCells, '') +
            '</div>' +
            chartBucketTag +
            '<div style="display:table-row;">' +
            '<div style="display:table-cell; padding:7px 10px; border-bottom:1px solid #e5e7eb; font-weight:bold; color:#1e3a8a;">{key_label}</div>' +
            '{#cols}' +
            '<div style="display:table-cell; padding:7px 10px; border-bottom:1px solid #e5e7eb; text-align:right; color:#1f2937;">{percent}%</div>' +
            '{/cols}' +
            '</div>' +
            '{:else}' +
            '<div style="display:table-row;"><div style="display:table-cell; padding:14px; background-color:#fef3c7; color:#92400e; font-style:italic;">No data available for this chart.</div></div>' +
            '{/ChartBucket}' +
            '</div>';
    }

    private static String renderClustered(String title, String chartBucketTag, String colSort) {
        String h = String.isBlank(title)
            ? ''
            : '<h2 style="margin:18px 0 10px 0; color:#1e3a8a; font-size:16pt; font-weight:bold; line-height:1.25;">' +
              escape(title) +
              '</h2>';

        // Legend: one swatch per colSort value, palette-cycled.
        List<String> swatches = new List<String>();
        Integer i = 0;
        for (String col : colSort.split(',')) {
            String color = paletteColor(i++);
            swatches.add(
                '<td style="padding:4px 14px 4px 0; font-size:9pt; color:#374151; vertical-align:middle;">' +
                    '<span style="display:inline-block; width:14px; height:10px; margin-right:6px; vertical-align:middle; border:1px solid #d1d5db; background-color:' +
                    color +
                    ';">&nbsp;</span>' +
                    escape(col.trim()) +
                    '</td>'
            );
        }

        return h +
            '<table style="margin:6px auto 12px auto; border-collapse:collapse;"><tr>' +
            String.join(swatches, '') +
            '</tr></table>' +
            '<div style="display:table; width:100%; margin:8px 0 12px 0;">' +
            chartBucketTag +
            '<div style="display:table-cell; vertical-align:bottom; text-align:center; padding:0 4px; border-bottom:2px solid #1e3a8a;">' +
            '<div style="display:table; margin:0 auto; border-collapse:separate; border-spacing:1px 0;">' +
            '{#cols}' +
            '<div style="display:table-cell; vertical-align:bottom; width:22px; padding:0;">' +
            '<div style="font-size:7pt; color:#6b7280; text-align:center; line-height:1.1; margin-bottom:1px; white-space:nowrap;">{percent_int}%</div>' +
            '<div style="width:22px; min-height:1px; height:{percent_int}px; background-color:{color};">&nbsp;</div>' +
            '</div>' +
            '{/cols}' +
            '</div>' +
            '<div style="padding-top:8px; font-size:9pt; font-weight:bold; color:#1e3a8a; line-height:1.2;">{key_label}</div>' +
            '</div>' +
            '{:else}' +
            '<div style="padding:14px; background-color:#fef3c7; color:#92400e; font-style:italic;">No data available for this chart.</div>' +
            '{/ChartBucket}' +
            '</div>';
    }

    private static String renderStacked(String title, String chartBucketTag, String colSort) {
        String h = String.isBlank(title)
            ? ''
            : '<h2 style="margin:18px 0 10px 0; color:#1e3a8a; font-size:16pt; font-weight:bold; line-height:1.25;">' +
              escape(title) +
              '</h2>';

        // Legend mirrors clustered.
        List<String> swatches = new List<String>();
        Integer i = 0;
        for (String col : colSort.split(',')) {
            String color = paletteColor(i++);
            swatches.add(
                '<td style="padding:4px 14px 4px 0; font-size:9pt; color:#374151; vertical-align:middle;">' +
                    '<span style="display:inline-block; width:14px; height:10px; margin-right:6px; vertical-align:middle; border:1px solid #d1d5db; background-color:' +
                    color +
                    ';">&nbsp;</span>' +
                    escape(col.trim()) +
                    '</td>'
            );
        }

        return h +
            '<table style="margin:0 0 14px 0; border-collapse:collapse;"><tr>' +
            String.join(swatches, '') +
            '</tr></table>' +
            '<div style="display:table; width:100%; border-collapse:collapse; margin:0 0 18px 0;">' +
            chartBucketTag +
            '<div style="display:table-row;">' +
            '<div style="display:table-cell; padding:9px 8px; vertical-align:middle; border-bottom:1px solid #e5e7eb; width:30%; font-weight:bold; color:#1f2937;">{key_label}</div>' +
            '<div style="display:table-cell; padding:9px 8px; vertical-align:middle; border-bottom:1px solid #e5e7eb; width:55%;">' +
            '<div style="display:table; width:100%; height:18px; border:1px solid #d1d5db;">' +
            '{#cols}' +
            '<div style="display:table-cell; font-size:1px; line-height:1px; vertical-align:middle; background-color:{color}; width:{percent_of_row}%;">&nbsp;</div>' +
            '{/cols}' +
            '</div>' +
            '</div>' +
            '<div style="display:table-cell; padding:9px 8px; vertical-align:middle; border-bottom:1px solid #e5e7eb; width:15%; text-align:right; color:#6b7280; font-size:10pt; white-space:nowrap;">{count} total</div>' +
            '</div>' +
            '{:else}' +
            '<div style="display:table-row;"><div style="display:table-cell; padding:14px; background-color:#fef3c7; color:#92400e; font-style:italic;">No data available for this chart.</div></div>' +
            '{/ChartBucket}' +
            '</div>';
    }

    // ─── helpers ─────────────────────────────────────────────────────────

    /**
     * Renders a visually obvious error in HTML output, or a plain-text
     * placeholder in Word/PPT/Excel where injecting HTML into OOXML would
     * corrupt the document. Pre-#117 this threw for non-HTML — that gate is
     * gone now that Word supports charts via the PNG-via-CV pipeline; a
     * malformed tag should never halt the whole document, just flag itself
     * inline so the author sees it.
     */
    private static String renderError(Boolean isHtml, String reason, String snippet) {
        if (!isHtml) {
            return '[Chart error: ' + reason + ']';
        }
        // escapeForDisplay turns the original tag's curly braces into HTML
        // entities so the rendered error block can't be re-parsed as a tag on
        // a subsequent processXml pass — which would otherwise produce a
        // confusing chain of nested error blocks or, worse, fail with the
        // wrong templateType on the second pass.
        return '<div style="margin:12px 0; padding:12px 16px; background-color:#fef2f2; border-left:4px solid #ef4444; color:#991b1b; font-family:monospace; font-size:10pt;">' +
            '<strong>Chart error:</strong> ' +
            escapeForDisplay(reason) +
            '<br/><span style="color:#7f1d1d; font-size:9pt;">at ' +
            escapeForDisplay(snippet) +
            '</span></div>';
    }

    private static String escapeForDisplay(String s) {
        if (s == null) {
            return '';
        }
        return s.escapeXml().replace('{', '&#123;').replace('}', '&#125;');
    }

    /**
     * Decode the small set of XML entities that survive a docx/HTML round-trip
     * (Google Docs "Save as Web Page" escapes & → &amp;, ' → &apos;, etc.).
     * Without this, tags authored in Docs lose their & option separators —
     * the parser would split on the literal & inside &amp; and mangle every
     * cross-tab option string. Apply once on the tag body before parsing.
     * Numeric character refs like &#38; cover ampersands typed by hand or
     * emitted by some HTML pipelines.
     */
    private static String decodeEntities(String s) {
        if (s == null || s.indexOf('&') == -1) {
            return s;
        }
        return s.replace('&amp;', '&')
            .replace('&lt;', '<')
            .replace('&gt;', '>')
            .replace('&quot;', '"')
            .replace('&apos;', '\'')
            .replace('&#39;', '\'')
            .replace('&#34;', '"')
            .replace('&#38;', '&');
    }

    /**
     * Parses "k=v&k=v" into a Map. Preserves insertion order via LinkedHashMap-
     * equivalent (Apex Map<String,String> doesn't guarantee order, so we build
     * the rebuilt tag from the map keys regardless — order doesn't matter for
     * ChartBucket parsing).
     */
    private static Map<String, String> parseOptions(String raw) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(raw)) {
            return out;
        }
        for (String chunk : raw.split('&')) {
            Integer eq = chunk.indexOf('=');
            if (eq <= 0) {
                continue;
            }
            String k = chunk.substring(0, eq).trim();
            String v = chunk.substring(eq + 1).trim();
            if (String.isNotBlank(k)) {
                out.put(k, v);
            }
        }
        return out;
    }

    /**
     * Apex String.split takes a regex; for fixed delimiters this is overkill
     * and brittle when the delimiter is a regex metachar. We split on ':' with
     * a hard limit so option values can contain ':' (e.g. URLs in titles).
     */
    private static List<String> splitLimit(String s, String delim, Integer maxParts) {
        List<String> out = new List<String>();
        if (s == null) {
            return out;
        }
        Integer cursor = 0;
        Integer len = s.length();
        while (out.size() < maxParts - 1) {
            Integer at = s.indexOf(delim, cursor);
            if (at == -1) {
                break;
            }
            out.add(s.substring(cursor, at));
            cursor = at + delim.length();
        }
        out.add(s.substring(cursor, len));
        return out;
    }

    /**
     * Cycle through the same palette DocGenChartBucketResolver uses for {color}.
     * Kept private rather than referencing the resolver's PALETTE to avoid a
     * test-time circular dependency.
     */
    private static String paletteColor(Integer index) {
        List<String> palette = new List<String>{
            '#3b82f6',
            '#10b981',
            '#f59e0b',
            '#ef4444',
            '#8b5cf6',
            '#ec4899',
            '#06b6d4',
            '#84cc16'
        };
        Integer n = palette.size();
        return palette[Math.mod(index, n)];
    }

    private static String escape(String s) {
        return s == null ? '' : s.escapeXml();
    }

    public class ChartTagException extends Exception {
    }
}
