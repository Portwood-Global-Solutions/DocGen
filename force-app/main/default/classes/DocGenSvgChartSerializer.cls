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

    private static final Set<String> KNOWN_STYLES = new Set<String>{ 'bar', 'column', 'pie', 'donut' };

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
                'Unknown chart style "' + style + '". Supported: ' + String.join(new List<String>(KNOWN_STYLES), ', ')
            );
        }
        if (style == 'bar') {
            return emitBar(buckets, opts);
        }
        if (style == 'column') {
            return emitColumn(buckets, opts);
        }
        if (style == 'pie') {
            return emitPie(buckets, opts, false);
        }
        if (style == 'donut') {
            return emitPie(buckets, opts, true);
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
    // Column — vertical bar chart, one column per bucket.
    //
    // Layout: bars rise from a shared baseline, labels rotated below, value
    // labels above each bar. Same data model as `bar`; the rotation suits
    // category lists where short labels read better horizontally and the
    // value magnitude reads better vertically.
    // =====================================================================
    private static String emitColumn(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer width = optInt(opts, 'width', 500);
        String title = opts.get('title');
        Integer titleHeight = String.isNotBlank(title) ? 28 : 0;
        Integer labelArea = 60; // bottom space for rotated category labels
        Integer plotPaddingTop = 18; // headroom for value labels above bars
        Integer plotPaddingLeft = 28; // y-axis breathing room
        Integer height = optInt(opts, 'height', titleHeight + plotPaddingTop + 200 + labelArea);
        Integer plotTop = titleHeight + plotPaddingTop;
        Integer plotBottom = height - labelArea;
        Integer plotHeight = plotBottom - plotTop;
        Integer plotLeft = plotPaddingLeft;
        Integer plotRight = width - 10;
        Integer plotWidth = plotRight - plotLeft;

        List<String> palette = parsePalette(opts);
        Decimal maxPct = decimalOf(buckets[0].get('max_percent'));
        Decimal maxCount = 0;
        for (Map<String, Object> b : buckets) {
            Decimal c = decimalOf(b.get('count'));
            if (c != null && c > maxCount) {
                maxCount = c;
            }
        }
        if (maxCount <= 0) {
            maxCount = 1;
        }

        Integer slotCount = buckets.size();
        Integer slotWidth = plotWidth / slotCount;
        Integer barWidth = Math.max(8, Math.min(48, (Integer) (slotWidth * 0.6)));

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
        // Baseline + simple y-axis line
        parts.add(
            '<line x1="' +
                plotLeft +
                '" y1="' +
                plotBottom +
                '" x2="' +
                plotRight +
                '" y2="' +
                plotBottom +
                '" stroke="#d1d5db" stroke-width="1"/>'
        );

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

            Integer slotCenter = plotLeft + (i * slotWidth) + (slotWidth / 2);
            Integer barX = slotCenter - (barWidth / 2);
            Integer barHeight = maxCount > 0 ? (Integer) ((count / maxCount) * plotHeight) : 0;
            if (barHeight < 1 && count > 0) {
                barHeight = 1;
            }
            Integer barY = plotBottom - barHeight;

            // Bar
            parts.add(
                '<rect x="' +
                    barX +
                    '" y="' +
                    barY +
                    '" width="' +
                    barWidth +
                    '" height="' +
                    barHeight +
                    '" rx="2" fill="' +
                    escapeXmlAttr(color) +
                    '"/>'
            );
            // Value label above the bar
            String valueLabel = countAndPercent(count, pct);
            parts.add(
                '<text x="' +
                    slotCenter +
                    '" y="' +
                    (barY - 6) +
                    '" font-family="Arial, sans-serif" font-size="10" fill="#111827" text-anchor="middle">' +
                    escapeXml(valueLabel) +
                    '</text>'
            );
            // Category label below baseline, rotated 30° for legibility on
            // long answer text without consuming horizontal slot.
            Integer labelY = plotBottom + 14;
            parts.add(
                '<text x="' +
                    slotCenter +
                    '" y="' +
                    labelY +
                    '" font-family="Arial, sans-serif" font-size="10" fill="#374151" text-anchor="end" transform="rotate(-30 ' +
                    slotCenter +
                    ' ' +
                    labelY +
                    ')">' +
                    escapeXml(label) +
                    '</text>'
            );
        }

        parts.add('</svg>');
        return String.join(parts, '');
    }

    // =====================================================================
    // Pie / Donut — circular slices, one per bucket.
    //
    // `donut` is `pie` with an inner hole (innerR = 0.55 * outerR by default;
    // override via opts.innerRadius). The math is identical: slice angle
    // proportional to count/total. Donut renders annular sector paths using
    // outer arc + inner reverse arc.
    //
    // Layout: pie left-of-center, legend on the right (one row per bucket
    // showing color swatch + label + count + percent).
    // =====================================================================
    private static String emitPie(List<Map<String, Object>> buckets, Map<String, String> opts, Boolean donut) {
        Integer width = optInt(opts, 'width', 540);
        String title = opts.get('title');
        Integer titleHeight = String.isNotBlank(title) ? 28 : 0;
        Integer rowHeight = 22;
        Integer legendHeight = buckets.size() * rowHeight + 10;
        Integer minHeight = Math.max(legendHeight, 220);
        Integer height = optInt(opts, 'height', titleHeight + minHeight + 10);

        Integer legendWidth = 240;
        Integer chartArea = width - legendWidth - 10;
        Integer chartHeight = height - titleHeight - 20;

        Integer cx = chartArea / 2;
        Integer cy = titleHeight + (chartHeight / 2) + 10;
        Integer radius = Math.max(40, Math.min(chartArea, chartHeight) / 2 - 10);
        Decimal innerRatio = 0.55;
        if (opts.containsKey('innerRadius')) {
            try {
                Decimal v = Decimal.valueOf(opts.get('innerRadius'));
                if (v > 0 && v < 1) {
                    innerRatio = v;
                }
            } catch (Exception e) {
                // ignore, keep default
            }
        }
        Integer innerR = donut ? (Integer) (radius * innerRatio) : 0;

        Decimal total = 0;
        for (Map<String, Object> b : buckets) {
            Decimal c = decimalOf(b.get('count'));
            if (c != null) {
                total += c;
            }
        }
        if (total <= 0) {
            return emitEmpty(opts);
        }

        List<String> palette = parsePalette(opts);
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

        // Start at the top of the circle (12 o'clock, angle = -π/2).
        Double startAngle = -Math.PI / 2;

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal count = decimalOf(b.get('count'));
            if (count == null || count <= 0) {
                continue;
            }
            Double sliceAngle = (count.doubleValue() / total.doubleValue()) * 2.0 * Math.PI;
            Double endAngle = startAngle + sliceAngle;

            String color = stringOf(b.get('color'));
            if (String.isBlank(color)) {
                color = palette[Math.mod(i, palette.size())];
            }

            Double sxOuter = cx + radius * Math.cos(startAngle);
            Double syOuter = cy + radius * Math.sin(startAngle);
            Double exOuter = cx + radius * Math.cos(endAngle);
            Double eyOuter = cy + radius * Math.sin(endAngle);
            Integer largeArc = (sliceAngle > Math.PI) ? 1 : 0;

            String path;
            if (donut) {
                Double sxInner = cx + innerR * Math.cos(startAngle);
                Double syInner = cy + innerR * Math.sin(startAngle);
                Double exInner = cx + innerR * Math.cos(endAngle);
                Double eyInner = cy + innerR * Math.sin(endAngle);
                path =
                    'M ' +
                    fmtNum(sxOuter) +
                    ',' +
                    fmtNum(syOuter) +
                    ' A ' +
                    radius +
                    ',' +
                    radius +
                    ' 0 ' +
                    largeArc +
                    ' 1 ' +
                    fmtNum(exOuter) +
                    ',' +
                    fmtNum(eyOuter) +
                    ' L ' +
                    fmtNum(exInner) +
                    ',' +
                    fmtNum(eyInner) +
                    ' A ' +
                    innerR +
                    ',' +
                    innerR +
                    ' 0 ' +
                    largeArc +
                    ' 0 ' +
                    fmtNum(sxInner) +
                    ',' +
                    fmtNum(syInner) +
                    ' Z';
            } else {
                path =
                    'M ' +
                    cx +
                    ',' +
                    cy +
                    ' L ' +
                    fmtNum(sxOuter) +
                    ',' +
                    fmtNum(syOuter) +
                    ' A ' +
                    radius +
                    ',' +
                    radius +
                    ' 0 ' +
                    largeArc +
                    ' 1 ' +
                    fmtNum(exOuter) +
                    ',' +
                    fmtNum(eyOuter) +
                    ' Z';
            }
            parts.add('<path d="' + path + '" fill="' + escapeXmlAttr(color) + '" stroke="#ffffff" stroke-width="1"/>');

            startAngle = endAngle;
        }

        // Legend column on the right
        Integer legendX = chartArea + 10;
        Integer legendY = titleHeight + 10;
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

            Integer swatchY = legendY + (i * rowHeight);
            parts.add(
                '<rect x="' +
                    legendX +
                    '" y="' +
                    swatchY +
                    '" width="14" height="14" rx="2" fill="' +
                    escapeXmlAttr(color) +
                    '"/>'
            );
            parts.add(
                '<text x="' +
                    (legendX + 22) +
                    '" y="' +
                    (swatchY + 11) +
                    '" font-family="Arial, sans-serif" font-size="11" fill="#374151">' +
                    escapeXml(label) +
                    ' — ' +
                    escapeXml(countAndPercent(count, pct)) +
                    '</text>'
            );
        }

        parts.add('</svg>');
        return String.join(parts, '');
    }

    /**
     * Formats a Double as a string with no decimal point for whole numbers,
     * one decimal otherwise. Used inside SVG path `d=` attributes where
     * shorter strings keep the rendered output readable in debug dumps.
     */
    private static String fmtNum(Double v) {
        if (v == null) {
            return '0';
        }
        Decimal d = Decimal.valueOf(v);
        if (d == d.setScale(0)) {
            return String.valueOf(d.intValue());
        }
        return String.valueOf(d.setScale(2));
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
