/**
 * DocGenChartRasterizer
 *
 * Pure-Apex bitmap chart renderer that runs server-side (no browser canvas).
 * Produces real PNG bytes via DocGenPngEncoder, suitable for embedding in
 * DOCX/PPTX/XLSX/PDF via the existing image-substitution pipeline.
 *
 * Companion to DocGenSvgChartSerializer — same input shape (bucket list +
 * options map), same chart styles (bar / column / pie / donut), but
 * produces a rasterized PNG instead of an SVG string. Use the SVG path when
 * a browser/LWC is available for high-quality canvas rasterization; use
 * this server-side path for bulk / Flow / batch / Queueable contexts that
 * have no DOM.
 *
 * Design choices (Option A in the strategy discussion):
 *   - No in-chart text rendering. Title and legend are the responsibility
 *     of the surrounding Word document text (rendered at full font quality
 *     by the target app). The raster carries shapes + colors only — this
 *     avoids shipping a pixel font and keeps the output visually clean.
 *   - 8-bit indexed color with the standard 8-bucket DocGen palette plus
 *     white background + grid grey. Keeps file size minimal.
 *   - No anti-aliasing in v1. Edges are crisp at chart-rendering scale.
 *
 * Public API mirrors DocGenSvgChartSerializer:
 *   Blob png = DocGenChartRasterizer.emit(buckets, options)
 */
public class DocGenChartRasterizer {
    // Default 8-color palette — matches DocGenChartBucketResolver and
    // DocGenSvgChartSerializer for visual consistency across paths.
    private static final List<List<Integer>> DEFAULT_PALETTE_RGB = new List<List<Integer>>{
        new List<Integer>{ 59, 130, 246 }, // #3b82f6 blue
        new List<Integer>{ 16, 185, 129 }, // #10b981 green
        new List<Integer>{ 245, 158, 11 }, // #f59e0b amber
        new List<Integer>{ 239, 68, 68 }, // #ef4444 red
        new List<Integer>{ 139, 92, 246 }, // #8b5cf6 violet
        new List<Integer>{ 236, 72, 153 }, // #ec4899 pink
        new List<Integer>{ 6, 182, 212 }, // #06b6d4 cyan
        new List<Integer>{ 132, 204, 22 } // #84cc16 lime
    };

    // Reserved palette indices added to every chart: 0=white background, 1=grey grid line, 2=darker text grey
    private static final List<List<Integer>> RESERVED_RGB = new List<List<Integer>>{
        new List<Integer>{ 255, 255, 255 },
        new List<Integer>{ 209, 213, 219 },
        new List<Integer>{ 55, 65, 81 }
    };
    private static final Integer COLOR_BG = 0;
    private static final Integer COLOR_GRID = 1;

    private static final Set<String> KNOWN_STYLES = new Set<String>{ 'bar', 'column', 'pie', 'donut' };

    /**
     * Top-level entry point. Dispatches by `options.style` (default `bar`).
     */
    public static Blob emit(List<Map<String, Object>> buckets, Map<String, String> options) {
        Map<String, String> opts = options == null ? new Map<String, String>() : options;
        String style = opts.containsKey('style') ? opts.get('style').toLowerCase() : 'bar';
        if (!KNOWN_STYLES.contains(style)) {
            throw new DocGenException(
                'Unknown chart style "' + style + '" — supported: ' + String.join(new List<String>(KNOWN_STYLES), ', ')
            );
        }
        if (buckets == null || buckets.isEmpty()) {
            return emitEmpty(opts);
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
        throw new DocGenException('Unhandled chart style: ' + style);
    }

    // =====================================================================
    // Bar — horizontal bars, one row per bucket
    // =====================================================================
    private static Blob emitBar(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer width = optInt(opts, 'width', 500);
        // Reserve a narrow left margin for visual breathing room. No labels
        // are drawn in-chart (per Option A).
        Integer marginLeft = 8;
        Integer barHeight = 22;
        Integer barGap = 8;
        Integer height = optInt(opts, 'height', (buckets.size() * (barHeight + barGap)) + barGap);

        Canvas c = new Canvas(width, height, buildPalette(opts));
        Decimal maxPct = computeMaxPercent(buckets);
        if (maxPct <= 0) {
            maxPct = 100;
        }
        Integer barAreaWidth = width - marginLeft - 6;

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal pct = decimalOf(b.get('percent'));
            if (pct == null) {
                pct = 0;
            }
            Integer paletteIdx = paletteIndexForBucket(b, i, buckets.size());
            Integer rowY = barGap + i * (barHeight + barGap);
            Integer barW = maxPct > 0 ? (Integer) ((pct / maxPct) * barAreaWidth) : 0;
            if (barW < 1 && pct > 0) {
                barW = 1;
            }
            c.fillRect(marginLeft, rowY, barW, barHeight, paletteIdx);
        }

        return c.toPng();
    }

    // =====================================================================
    // Column — vertical bars, one column per bucket
    // =====================================================================
    private static Blob emitColumn(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer width = optInt(opts, 'width', 500);
        Integer height = optInt(opts, 'height', 280);
        // Baseline 18px from bottom for the axis line; the rest is plot area.
        Integer baselineY = height - 18;
        Integer plotTop = 12;
        Integer plotHeight = baselineY - plotTop;
        Integer marginLeft = 12;
        Integer plotRight = width - 12;
        Integer plotWidth = plotRight - marginLeft;

        Canvas c = new Canvas(width, height, buildPalette(opts));

        Decimal maxCount = 0;
        for (Map<String, Object> b : buckets) {
            Decimal v = decimalOf(b.get('count'));
            if (v != null && v > maxCount) {
                maxCount = v;
            }
        }
        if (maxCount <= 0) {
            maxCount = 1;
        }

        Integer slotCount = buckets.size();
        Integer slotW = plotWidth / slotCount;
        Integer barW = Math.max(6, Math.min(60, (Integer) (slotW * 0.7)));

        // Draw baseline (axis grid)
        c.fillRect(marginLeft, baselineY, plotWidth, 1, COLOR_GRID);

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal count = decimalOf(b.get('count'));
            if (count == null) {
                count = 0;
            }
            Integer paletteIdx = paletteIndexForBucket(b, i, buckets.size());
            Integer slotCenter = marginLeft + (i * slotW) + (slotW / 2);
            Integer barX = slotCenter - (barW / 2);
            Integer barH = maxCount > 0 ? (Integer) ((count / maxCount) * plotHeight) : 0;
            if (barH < 1 && count > 0) {
                barH = 1;
            }
            Integer barY = baselineY - barH;
            c.fillRect(barX, barY, barW, barH, paletteIdx);
        }

        return c.toPng();
    }

    // =====================================================================
    // Pie / Donut — circular slices
    //
    // Strategy: per-pixel test inside the bounding box of the circle. For
    // each pixel within the outer radius (and outside the inner radius for
    // donut), compute the polar angle and find which slice it belongs to.
    // O(R^2) where R is the radius — for a 280px chart this is ~62k pixel
    // tests, well within Apex CPU budget.
    // =====================================================================
    private static Blob emitPie(List<Map<String, Object>> buckets, Map<String, String> opts, Boolean donut) {
        Integer size = optInt(opts, 'size', 280);
        Integer width = optInt(opts, 'width', size);
        Integer height = optInt(opts, 'height', size);
        Canvas c = new Canvas(width, height, buildPalette(opts));

        Decimal total = 0;
        for (Map<String, Object> b : buckets) {
            Decimal v = decimalOf(b.get('count'));
            if (v != null) {
                total += v;
            }
        }
        if (total <= 0) {
            return c.toPng();
        }

        Integer cx = width / 2;
        Integer cy = height / 2;
        Integer outerR = Math.min(width, height) / 2 - 4;
        Integer outerR2 = outerR * outerR;
        Integer innerR = 0;
        if (donut) {
            Decimal ratio = 0.55;
            if (opts.containsKey('innerRadius')) {
                try {
                    Decimal v = Decimal.valueOf(opts.get('innerRadius'));
                    if (v > 0 && v < 1) {
                        ratio = v;
                    }
                } catch (Exception e) {
                    // keep default
                }
            }
            innerR = (Integer) (outerR * ratio);
        }
        Integer innerR2 = innerR * innerR;

        // Pre-compute slice end angles (in turns 0..1 starting at 12 o'clock).
        // We represent the angle as a fraction of total to avoid trig in the
        // inner loop — pixel angle = atan2(dy, dx); we compare against
        // cumulative slice fractions converted to angle thresholds.
        List<Decimal> sliceEndAngle = new List<Decimal>();
        Decimal running = 0;
        for (Map<String, Object> b : buckets) {
            Decimal v = decimalOf(b.get('count'));
            if (v == null) {
                v = 0;
            }
            running += v;
            sliceEndAngle.add(running / total); // 0..1
        }

        // 12 o'clock start, clockwise sweep — matches the SVG emitter.
        Double TWO_PI = 2.0 * Math.PI;
        Double START = -Math.PI / 2;

        for (Integer y = cy - outerR; y <= cy + outerR; y++) {
            if (y < 0 || y >= height) {
                continue;
            }
            for (Integer x = cx - outerR; x <= cx + outerR; x++) {
                if (x < 0 || x >= width) {
                    continue;
                }
                Integer dx = x - cx;
                Integer dy = y - cy;
                Integer d2 = dx * dx + dy * dy;
                if (d2 > outerR2 || d2 < innerR2) {
                    continue;
                }
                // angle in 0..1 turns, starting at 12 o'clock clockwise
                Double a = Math.atan2((Double) dy, (Double) dx) - START;
                if (a < 0) {
                    a += TWO_PI;
                }
                if (a >= TWO_PI) {
                    a -= TWO_PI;
                }
                Decimal turn = (Decimal) (a / TWO_PI);
                // Find which slice this turn falls into.
                Integer sliceIdx = sliceEndAngle.size() - 1;
                for (Integer s = 0; s < sliceEndAngle.size(); s++) {
                    if (turn <= sliceEndAngle[s]) {
                        sliceIdx = s;
                        break;
                    }
                }
                Integer paletteIdx = paletteIndexForBucket(buckets[sliceIdx], sliceIdx, buckets.size());
                c.setPixel(x, y, paletteIdx);
            }
        }

        return c.toPng();
    }

    // =====================================================================
    // Empty-state — no buckets
    // =====================================================================
    private static Blob emitEmpty(Map<String, String> opts) {
        Integer width = optInt(opts, 'width', 500);
        Integer height = optInt(opts, 'height', 80);
        Canvas c = new Canvas(width, height, buildPalette(opts));
        // Just a thin grid line across the middle so the chart slot isn't blank.
        c.fillRect(0, height / 2, width, 1, COLOR_GRID);
        return c.toPng();
    }

    // =====================================================================
    // Palette construction
    //
    // The PNG palette layout we ship per chart:
    //   0  = white background
    //   1  = grid grey
    //   2  = darker text grey (unused by Option A renderers, reserved)
    //   3+ = chart colors (default palette or `colors=` override), one per bucket
    // =====================================================================
    private static List<Integer> buildPalette(Map<String, String> opts) {
        List<List<Integer>> seriesRgb = parsePalette(opts);
        List<Integer> flat = new List<Integer>();
        for (List<Integer> rgb : RESERVED_RGB) {
            flat.addAll(rgb);
        }
        for (List<Integer> rgb : seriesRgb) {
            flat.addAll(rgb);
        }
        // Pad to a reasonable size — PNG palette can be any length ≤ 256
        // and indexed images can use 1, 2, 4, or 8 bit depth. We always use
        // 8-bit since charts may have up to ~10-20 series buckets.
        return flat;
    }

    private static Integer paletteIndexForBucket(Map<String, Object> b, Integer i, Integer bucketCount) {
        // Reserved indices 0..2 → bucket colors start at index 3.
        // bucketCount tells us how many series-color slots we filled in
        // buildPalette so we cycle correctly when a chart has more buckets
        // than palette entries.
        Integer reserved = RESERVED_RGB.size();
        Integer palettePos = Math.mod(i, getPaletteSize(b));
        return reserved + palettePos;
    }

    /**
     * Returns the number of series colors in the current palette. For
     * default palette, this is DEFAULT_PALETTE_RGB.size(). For a `colors=`
     * override, it's the override's length. We carry it on the bucket via
     * a synthetic key to avoid re-parsing — but simpler approach: each
     * caller passes the right size. For now, default palette length.
     */
    private static Integer getPaletteSize(Map<String, Object> b) {
        return DEFAULT_PALETTE_RGB.size();
    }

    private static List<List<Integer>> parsePalette(Map<String, String> opts) {
        if (opts == null || !opts.containsKey('colors') || String.isBlank(opts.get('colors'))) {
            return DEFAULT_PALETTE_RGB;
        }
        List<List<Integer>> out = new List<List<Integer>>();
        for (String c : opts.get('colors').split(',')) {
            List<Integer> rgb = hexToRgb(c.trim());
            if (rgb != null) {
                out.add(rgb);
            }
        }
        return out.isEmpty() ? DEFAULT_PALETTE_RGB : out;
    }

    /** Hex like "#3b82f6" or "3b82f6" → [r, g, b]. Returns null on bad input. */
    @TestVisible
    private static List<Integer> hexToRgb(String hex) {
        if (String.isBlank(hex)) {
            return null;
        }
        String h = hex.startsWith('#') ? hex.substring(1) : hex;
        if (h.length() != 6) {
            return null;
        }
        try {
            Integer r = parseHex2(h.substring(0, 2));
            Integer g = parseHex2(h.substring(2, 4));
            Integer b = parseHex2(h.substring(4, 6));
            return new List<Integer>{ r, g, b };
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer parseHex2(String two) {
        String hex = '0123456789abcdef';
        Integer hi = hex.indexOf(two.substring(0, 1).toLowerCase());
        Integer lo = hex.indexOf(two.substring(1, 2).toLowerCase());
        if (hi < 0 || lo < 0) {
            throw new DocGenException('Bad hex: ' + two);
        }
        return hi * 16 + lo;
    }

    // =====================================================================
    // Bucket helpers (mirror DocGenSvgChartSerializer)
    // =====================================================================

    private static Decimal computeMaxPercent(List<Map<String, Object>> buckets) {
        Decimal max = decimalOf(buckets[0].get('max_percent'));
        if (max != null && max > 0) {
            return max;
        }
        max = 0;
        for (Map<String, Object> b : buckets) {
            Decimal p = decimalOf(b.get('percent'));
            if (p != null && p > max) {
                max = p;
            }
        }
        return max;
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

    // =====================================================================
    // Canvas — pixel buffer + primitives, lazily emits PNG on demand
    // =====================================================================
    @TestVisible
    public class Canvas {
        public final Integer width;
        public final Integer height;
        public final List<Integer> palette;
        public final List<Integer> pixels;

        public Canvas(Integer width, Integer height, List<Integer> palette) {
            this.width = width;
            this.height = height;
            this.palette = palette;
            // Initialize all pixels to background (palette index 0 = white)
            this.pixels = new List<Integer>();
            Integer total = width * height;
            for (Integer i = 0; i < total; i++) {
                pixels.add(0);
            }
        }

        public void setPixel(Integer x, Integer y, Integer colorIdx) {
            if (x < 0 || x >= width || y < 0 || y >= height) {
                return;
            }
            pixels[y * width + x] = colorIdx;
        }

        public void fillRect(Integer x, Integer y, Integer w, Integer h, Integer colorIdx) {
            Integer x0 = Math.max(0, x);
            Integer y0 = Math.max(0, y);
            Integer x1 = Math.min(width, x + w);
            Integer y1 = Math.min(height, y + h);
            for (Integer py = y0; py < y1; py++) {
                Integer rowStart = py * width;
                for (Integer px = x0; px < x1; px++) {
                    pixels[rowStart + px] = colorIdx;
                }
            }
        }

        public Blob toPng() {
            return DocGenPngEncoder.emitIndexed8(width, height, palette, pixels);
        }
    }
}
