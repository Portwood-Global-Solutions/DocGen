/**
 * Emits chart SVG fragments from DocGenChartBucketResolver bucket data.
 *
 * Single dispatch entry point (`emit`) routes by `style` option to a
 * per-style emitter method. v1 ships `bar` only; subsequent PRs add `column`,
 * `line`, `pie`, `donut`, `stacked`, `clustered`, etc. — each emitter is a
 * self-contained method, free to use the shared helpers (color cycling, text
 * escaping, value formatting).
 *
 * Buckets are the same Map<String,Object> shape DocGenChartBucketResolver
 * already produces (`key`, `key_label`, `count`, `percent`, `max_percent`,
 * `color`, `index`). Cross-tab styles consume the same map plus its `cols`
 * sub-list.
 *
 * SVG strings are deterministic — pure function of (buckets, options). No DML,
 * no SOQL, no callouts. The output is suitable for client-side rasterization
 * in the LWC layer (#117 v1) or external rasterization service (v2).
 *
 * See #117 for the pipeline: Apex emits SVG → LWC <canvas>.drawImage → PNG →
 * saved as ContentVersion on the source record → existing image substitution
 * embeds it in every output format.
 */
public with sharing class DocGenSvgChartSerializer {
    // Same 8-color palette DocGenChartBucketResolver cycles when no
    // `colors=` modifier is supplied. Keeping the same default keeps charts
    // visually consistent whether they render via HTML+CSS bars or SVG→PNG.
    private static final List<String> DEFAULT_PALETTE = new List<String>{
        '#3b82f6',
        '#10b981',
        '#f59e0b',
        '#ef4444',
        '#8b5cf6',
        '#ec4899',
        '#06b6d4',
        '#84cc16'
    };

    private static final Set<String> KNOWN_STYLES = new Set<String>{ 'bar' };

    /**
     * Top-level entry point. Dispatches by `options.style` (default `bar`).
     * Unknown style throws — caller is responsible for vocabulary validation
     * via DocGenChartTagExpander before reaching this emitter.
     */
    public static String emit(List<Map<String, Object>> buckets, Map<String, String> options) {
        if (buckets == null || buckets.isEmpty()) {
            return emitEmpty(options);
        }
        Map<String, String> opts = options == null ? new Map<String, String>() : options;
        String style = opts.containsKey('style') ? opts.get('style').toLowerCase() : 'bar';
        if (!KNOWN_STYLES.contains(style)) {
            throw new DocGenException(
                'Unknown chart style "' +
                    style +
                    '". Supported in v1: ' +
                    String.join(new List<String>(KNOWN_STYLES), ', ')
            );
        }
        if (style == 'bar') {
            return emitBar(buckets, opts);
        }
        throw new DocGenException('Style "' + style + '" not yet implemented.');
    }

    // =====================================================================
    // Bar — horizontal bar chart, one row per bucket.
    //
    // Layout: [label] [bar (width ∝ percent / max_percent)] [count(percent%)]
    // Visual matches the existing HTML+CSS bar style so PDF / DOCX / etc.
    // look the same whether rendered via HTML+CSS bars (HTML / PDF outputs)
    // or via this SVG → PNG path (OOXML outputs).
    // =====================================================================
    private static String emitBar(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer width = optInt(opts, 'width', 500);
        Integer barHeight = 18;
        Integer barGap = 6;
        Integer labelWidth = 140;
        Integer valueWidth = 80;
        String title = opts.get('title');
        Integer titleHeight = String.isNotBlank(title) ? 28 : 0;
        Integer height = optInt(opts, 'height', titleHeight + (buckets.size() * (barHeight + barGap)) + barGap);

        List<String> palette = parsePalette(opts);
        Decimal maxPct = decimalOf(buckets[0].get('max_percent'));
        if (maxPct == null || maxPct <= 0) {
            // Fallback when max_percent isn't populated (shouldn't happen with
            // current resolver output but defensive): derive from this batch.
            maxPct = 0;
            for (Map<String, Object> b : buckets) {
                Decimal p = decimalOf(b.get('percent'));
                if (p != null && p > maxPct) {
                    maxPct = p;
                }
            }
            if (maxPct <= 0) {
                maxPct = 100;
            }
        }
        Integer barArea = width - labelWidth - valueWidth;

        List<String> parts = new List<String>();
        parts.add(
            '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="' +
                width +
                '" height="' +
                height +
                '" viewBox="0 0 ' +
                width +
                ' ' +
                height +
                '">'
        );
        parts.add('<rect x="0" y="0" width="' + width + '" height="' + height + '" fill="#ffffff"/>');
        if (String.isNotBlank(title)) {
            parts.add(
                '<text x="0" y="20" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="#111827">' +
                    escapeXml(title) +
                    '</text>'
            );
        }

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            String label = stringOf(b.get('key_label'));
            if (String.isBlank(label)) {
                label = stringOf(b.get('key'));
            }
            if (label == null) {
                label = '';
            }
            Decimal count = decimalOf(b.get('count'));
            Decimal pct = decimalOf(b.get('percent'));
            if (count == null) {
                count = 0;
            }
            if (pct == null) {
                pct = 0;
            }
            String color = stringOf(b.get('color'));
            if (String.isBlank(color)) {
                color = palette[Math.mod(i, palette.size())];
            }
            Integer rowY = titleHeight + barGap + i * (barHeight + barGap);
            Integer barWidth = maxPct > 0 ? (Integer) ((pct / maxPct) * barArea) : 0;
            if (barWidth < 1 && pct > 0) {
                barWidth = 1; // visible sliver for non-zero buckets
            }
            Integer textY = rowY + barHeight - 4;

            parts.add(
                '<text x="0" y="' +
                    textY +
                    '" font-family="Arial, sans-serif" font-size="11" fill="#374151">' +
                    escapeXml(label) +
                    '</text>'
            );
            parts.add(
                '<rect x="' +
                    labelWidth +
                    '" y="' +
                    rowY +
                    '" width="' +
                    barWidth +
                    '" height="' +
                    barHeight +
                    '" rx="2" fill="' +
                    escapeXmlAttr(color) +
                    '"/>'
            );
            String valueLabel = countAndPercent(count, pct);
            parts.add(
                '<text x="' +
                    (labelWidth +
                    barWidth +
                    6) +
                    '" y="' +
                    textY +
                    '" font-family="Arial, sans-serif" font-size="11" fill="#111827">' +
                    escapeXml(valueLabel) +
                    '</text>'
            );
        }

        parts.add('</svg>');
        return String.join(parts, '');
    }

    // =====================================================================
    // Empty-state — bucket list is empty (no data to chart). Render a
    // placeholder SVG with a "No data" label so the embedded image still
    // exists rather than the chart tag silently producing nothing.
    // =====================================================================
    private static String emitEmpty(Map<String, String> options) {
        Integer width = options != null && options.containsKey('width') ? Integer.valueOf(options.get('width')) : 500;
        Integer height = options != null && options.containsKey('height') ? Integer.valueOf(options.get('height')) : 80;
        return '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="' +
            width +
            '" height="' +
            height +
            '" viewBox="0 0 ' +
            width +
            ' ' +
            height +
            '">' +
            '<rect x="0" y="0" width="' +
            width +
            '" height="' +
            height +
            '" fill="#f3f4f6" stroke="#d1d5db"/>' +
            '<text x="' +
            (width / 2) +
            '" y="' +
            (height / 2 + 5) +
            '" font-family="Arial, sans-serif" font-size="13" fill="#9ca3af" text-anchor="middle">No data</text>' +
            '</svg>';
    }

    // =====================================================================
    // Shared helpers
    // =====================================================================

    @TestVisible
    private static List<String> parsePalette(Map<String, String> opts) {
        if (opts == null || !opts.containsKey('colors')) {
            return DEFAULT_PALETTE;
        }
        String raw = opts.get('colors');
        if (String.isBlank(raw)) {
            return DEFAULT_PALETTE;
        }
        List<String> out = new List<String>();
        for (String c : raw.split(',')) {
            String trimmed = c.trim();
            if (String.isNotBlank(trimmed)) {
                out.add(trimmed);
            }
        }
        return out.isEmpty() ? DEFAULT_PALETTE : out;
    }

    @TestVisible
    private static String countAndPercent(Decimal count, Decimal pct) {
        // Matches the existing HTML+CSS bar value-label format: "42 (80%)"
        // Drops decimals when whole; one decimal when fractional.
        String c = formatNumber(count);
        String p = formatNumber(pct);
        return c + ' (' + p + '%)';
    }

    private static String formatNumber(Decimal n) {
        if (n == null) {
            return '0';
        }
        if (n == n.setScale(0)) {
            return String.valueOf(n.intValue());
        }
        return String.valueOf(n.setScale(1));
    }

    private static String escapeXml(String s) {
        if (s == null) {
            return '';
        }
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }

    private static String escapeXmlAttr(String s) {
        if (s == null) {
            return '';
        }
        return s.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;');
    }

    private static Integer optInt(Map<String, String> opts, String key, Integer fallback) {
        if (opts == null || !opts.containsKey(key)) {
            return fallback;
        }
        try {
            return Integer.valueOf(opts.get(key));
        } catch (Exception e) {
            return fallback;
        }
    }

    private static Decimal decimalOf(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Decimal) {
            return (Decimal) v;
        }
        if (v instanceof Integer) {
            return Decimal.valueOf((Integer) v);
        }
        if (v instanceof Long) {
            return Decimal.valueOf((Long) v);
        }
        if (v instanceof Double) {
            return Decimal.valueOf((Double) v);
        }
        try {
            return Decimal.valueOf(String.valueOf(v));
        } catch (Exception e) {
            return null;
        }
    }

    private static String stringOf(Object v) {
        return v == null ? null : String.valueOf(v);
    }
}
