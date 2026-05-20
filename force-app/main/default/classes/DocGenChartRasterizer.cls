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

    // Reserved palette indices on every chart:
    //   0 = white background
    //   1 = grid grey
    //   2..17 = 16 shades of text grey (level 0 = bg, level 15 = full text)
    //           used by AA font rendering — each glyph pixel's grayscale
    //           value selects one of these intermediates.
    private static final Integer TEXT_SHADE_COUNT = 16;
    private static final Integer COLOR_BG = 0;
    private static final Integer COLOR_GRID = 1;
    private static final Integer COLOR_TEXT_BASE = 2; // shade 0 (= bg); shade 15 at COLOR_TEXT_BASE + 15
    private static final Integer COLOR_TEXT = COLOR_TEXT_BASE + 15; // shorthand for full-foreground text

    private static List<List<Integer>> buildReservedRgb() {
        List<List<Integer>> out = new List<List<Integer>>();
        out.add(new List<Integer>{ 255, 255, 255 }); // bg
        out.add(new List<Integer>{ 209, 213, 219 }); // grid
        // 16 grayscale shades from bg (white) to near-black text.
        // Using near-black (#111827) rather than muted gray so AA glyphs
        // read crisply at chart scale; muted text gray made labels look
        // washed out next to vivid bar/slice colors.
        Integer textR = 17;
        Integer textG = 24;
        Integer textB = 39;
        for (Integer i = 0; i < TEXT_SHADE_COUNT; i++) {
            Integer r = 255 - ((255 - textR) * i / 15);
            Integer g = 255 - ((255 - textG) * i / 15);
            Integer b = 255 - ((255 - textB) * i / 15);
            out.add(new List<Integer>{ r, g, b });
        }
        return out;
    }

    private static final List<List<Integer>> RESERVED_RGB = buildReservedRgb();

    // Anti-aliased Arial-style font: glyph bitmaps live in DocGenChartFont
    // (pre-rendered offline via tools/generate-aa-font.py). Each glyph is
    // CELL_W × CELL_H cells with 4 bits of grayscale per pixel. The
    // rasterizer reads that grayscale and paints the matching shade from
    // the COLOR_TEXT_BASE..COLOR_TEXT_BASE+15 palette intermediates.
    private static final Integer FONT_W = 8; // = DocGenChartFont.CELL_W
    private static final Integer FONT_H = 13; // = DocGenChartFont.CELL_H
    // Arial 11pt renders narrower than the 8px cell for most chars (4-6px
    // wide). Advance of 5 produces a tight read; wider chars (M, W) overlap
    // slightly into the next cell's left padding which is fine.
    private static final Integer FONT_CHAR_ADVANCE = 5;

    private static final Set<String> KNOWN_STYLES = new Set<String>{ 'bar', 'column', 'pie', 'donut' };

    /**
     * Top-level entry point. Dispatches by `options.style` (default `bar`).
     *
     * `options.scale` (default 2) supersamples the entire chart — internally
     * the rasterizer draws at scale× the logical width/height. The PNG is
     * emitted at the larger size; when Word embeds it at the logical size
     * (via {%cvId:WxH}) the document app does bilinear downsampling for
     * free, smoothing pie/donut arc edges and font glyphs alike. The trick
     * matches what the browser canvas does at scale=4.
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

    /**
     * Server-side companion to `emit`: returns the rasterized PNG alongside
     * the LOGICAL width/height the chart was drawn at (pre-supersample). The
     * caller needs the logical dims to pack into the {%cvId:WxH} chart-image
     * marker so Word/PDF downsamples the supersampled PNG to the intended
     * physical size — that downsampling is where the anti-aliased look comes
     * from. See `prepareChartImagesServerSide` in DocGenChartImageController.
     *
     * Returns:
     *   {
     *     'png'           : Blob,    // PNG bytes at logical*scale physical pixels
     *     'logicalWidth'  : Integer, // pre-supersample width  (W in {%cvId:WxH})
     *     'logicalHeight' : Integer  // pre-supersample height (H in {%cvId:WxH})
     *   }
     */
    public static Map<String, Object> emitWithMeta(List<Map<String, Object>> buckets, Map<String, String> options) {
        Map<String, String> opts = options == null ? new Map<String, String>() : options;
        Blob png = emit(buckets, opts);
        Map<String, Integer> dims = logicalDimensions(buckets, opts);
        Map<String, Object> out = new Map<String, Object>();
        out.put('png', png);
        out.put('logicalWidth', dims.get('width'));
        out.put('logicalHeight', dims.get('height'));
        return out;
    }

    /**
     * Computes the LOGICAL (pre-supersample) chart dimensions for a given
     * style + bucket list + options. Mirrors the default-size logic baked
     * into each per-style emitter so the controller can pack the right
     * dimensions into the chart-image substitution marker without parsing
     * the emitted PNG bytes.
     *
     * Style defaults (matching the emitters):
     *   bar    : 500 × max(80, buckets*(barHeight+barGap) + barGap)
     *            where barHeight=22, barGap=8 → n*30 + 8
     *   column : 500 × 280
     *   pie    : 540 × 280
     *   donut  : 540 × 280
     *   empty  : 500 × 80
     *
     * `width=N` and `height=N` options always win over the defaults — same
     * behavior as the emitters.
     */
    private static Map<String, Integer> logicalDimensions(List<Map<String, Object>> buckets, Map<String, String> opts) {
        String style = opts != null && opts.containsKey('style') ? opts.get('style').toLowerCase() : 'bar';
        Integer width;
        Integer height;
        if (buckets == null || buckets.isEmpty()) {
            // emitEmpty defaults
            width = optInt(opts, 'width', 500);
            height = optInt(opts, 'height', 80);
        } else if (style == 'bar') {
            Integer barHeight = 22;
            Integer barGap = 8;
            width = optInt(opts, 'width', 500);
            height = optInt(opts, 'height', (buckets.size() * (barHeight + barGap)) + barGap);
        } else if (style == 'column') {
            width = optInt(opts, 'width', 500);
            height = optInt(opts, 'height', 280);
        } else if (style == 'pie' || style == 'donut') {
            width = optInt(opts, 'width', 540);
            height = optInt(opts, 'height', 280);
        } else {
            // Unknown styles never reach here — emit() throws first. Defensive
            // fallback to bar dimensions so a future style added to KNOWN_STYLES
            // without a matching branch here at least returns sane numbers.
            width = optInt(opts, 'width', 500);
            height = optInt(opts, 'height', 200);
        }
        return new Map<String, Integer>{ 'width' => width, 'height' => height };
    }

    // =====================================================================
    // Bar — horizontal bars, one row per bucket
    // =====================================================================
    private static Blob emitBar(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer scale = optInt(opts, 'scale', 2);
        // All values below are LOGICAL; we multiply by `scale` when drawing
        // so the output PNG is 2x the requested dimensions. Word/PDF
        // downsamples to the logical size via {%cvId:WxH} — that
        // downsampling gives free anti-aliasing on arcs + font glyphs.
        Integer logicalWidth = optInt(opts, 'width', 500);
        Integer categoryStripPx = 105;
        Integer valueStripPx = 80;
        Integer barHeight = 22;
        Integer barGap = 8;
        Integer logicalHeight = optInt(opts, 'height', (buckets.size() * (barHeight + barGap)) + barGap);

        // Scale up physically
        Integer width = logicalWidth * scale;
        Integer height = logicalHeight * scale;
        categoryStripPx *= scale;
        valueStripPx *= scale;
        barHeight *= scale;
        barGap *= scale;

        Canvas c = new Canvas(width, height, buildPalette(opts));
        Decimal maxPct = computeMaxPercent(buckets);
        if (maxPct <= 0) {
            maxPct = 100;
        }
        Integer barAreaWidth = width - categoryStripPx - valueStripPx;
        Integer barStartX = categoryStripPx;
        Integer fontH = FONT_H * scale;

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal count = decimalOf(b.get('count'));
            Decimal pct = decimalOf(b.get('percent'));
            if (count == null) {
                count = 0;
            }
            if (pct == null) {
                pct = 0;
            }
            Integer paletteIdx = paletteIndexForBucket(b, i, buckets.size());
            Integer rowY = barGap + i * (barHeight + barGap);
            Integer barW = maxPct > 0 ? (Integer) ((pct / maxPct) * barAreaWidth) : 0;
            if (barW < 1 && pct > 0) {
                barW = scale;
            }
            c.fillRect(barStartX, rowY, barW, barHeight, paletteIdx);

            Integer textY = rowY + (barHeight - fontH) / 2;

            String catLabel = stringOf(b.get('key_label'));
            if (String.isBlank(catLabel)) {
                catLabel = stringOf(b.get('key'));
            }
            if (catLabel == null) {
                catLabel = '';
            }
            Integer maxCatChars = (categoryStripPx - 6 * scale) / (FONT_CHAR_ADVANCE * scale);
            if (catLabel.length() > maxCatChars && maxCatChars > 1) {
                catLabel = catLabel.substring(0, maxCatChars);
            }
            c.drawText(4 * scale, textY, catLabel, COLOR_TEXT, scale);

            String valLabel = formatCountPercent(count, pct);
            c.drawText(barStartX + barW + 4 * scale, textY, valLabel, COLOR_TEXT, scale);
        }

        return c.toPng();
    }

    // =====================================================================
    // Column — vertical bars, one column per bucket
    // =====================================================================
    private static Blob emitColumn(List<Map<String, Object>> buckets, Map<String, String> opts) {
        Integer scale = optInt(opts, 'scale', 2);
        Integer width = optInt(opts, 'width', 500) * scale;
        Integer height = optInt(opts, 'height', 280) * scale;
        Integer baselineY = height - 18 * scale;
        Integer plotTop = 12 * scale;
        Integer plotHeight = baselineY - plotTop;
        Integer marginLeft = 12 * scale;
        Integer plotRight = width - 12 * scale;
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
        Integer barW = Math.max(6 * scale, Math.min(60 * scale, (Integer) (slotW * 0.7)));

        // Draw baseline (axis grid)
        c.fillRect(marginLeft, baselineY, plotWidth, scale, COLOR_GRID);

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal count = decimalOf(b.get('count'));
            Decimal pct = decimalOf(b.get('percent'));
            if (count == null) {
                count = 0;
            }
            if (pct == null) {
                pct = 0;
            }
            Integer paletteIdx = paletteIndexForBucket(b, i, buckets.size());
            Integer slotCenter = marginLeft + (i * slotW) + (slotW / 2);
            Integer barX = slotCenter - (barW / 2);
            Integer barH = maxCount > 0 ? (Integer) ((count / maxCount) * plotHeight) : 0;
            if (barH < 1 && count > 0) {
                barH = scale;
            }
            Integer barY = baselineY - barH;
            c.fillRect(barX, barY, barW, barH, paletteIdx);
            String label = formatPercent(pct);
            Integer textW = c.textWidth(label, scale);
            Integer textX = slotCenter - (textW / 2);
            Integer textY = Math.max(0, barY - FONT_H * scale - 2 * scale);
            c.drawText(textX, textY, label, COLOR_TEXT, scale);
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
        // Pie/donut at 2x supersample blows the sync Apex CPU budget — every
        // pixel runs atan2 + slice-index lookup, and 4x more pixels at scale=2
        // tips us over 10s. Default to 1x for the arc render; a future
        // sector-fill optimization (paint by slice instead of per-pixel angle
        // test) would let us match bar/column at 2x.
        Integer scale = optInt(opts, 'scale', 1);
        Integer width = optInt(opts, 'width', 540) * scale;
        Integer height = optInt(opts, 'height', 280) * scale;
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

        // Pie sits in the left half of the canvas; legend in the right.
        Integer legendStartX = Math.max((Integer) (width * 0.5), width - 240 * scale);
        Integer pieAreaWidth = legendStartX - 8 * scale;
        Integer pieAreaHeight = height;
        Integer cx = pieAreaWidth / 2;
        Integer cy = pieAreaHeight / 2;
        Integer outerR = Math.min(pieAreaWidth, pieAreaHeight) / 2 - 8 * scale;
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

        // ─── Legend rendering on the right half ───────────────────────────
        Integer swatchSize = 11 * scale;
        Integer rowH = swatchSize + 5 * scale;
        Integer maxRows = (height - 8 * scale) / rowH;
        Integer legendY = (height - (Math.min(buckets.size(), maxRows) * rowH)) / 2;
        for (Integer i = 0; i < buckets.size() && i < maxRows; i++) {
            Map<String, Object> b = buckets[i];
            Integer paletteIdx = paletteIndexForBucket(b, i, buckets.size());
            Integer yRow = legendY + i * rowH;
            c.fillRect(legendStartX, yRow, swatchSize, swatchSize, paletteIdx);
            String label = stringOf(b.get('key_label'));
            if (String.isBlank(label)) {
                label = stringOf(b.get('key'));
            }
            if (label == null) {
                label = '';
            }
            String row = label + ' ' + formatCountPercent(decimalOf(b.get('count')), decimalOf(b.get('percent')));
            Integer availPx = width - (legendStartX + swatchSize + 6 * scale);
            Integer maxChars = availPx / (FONT_CHAR_ADVANCE * scale);
            if (row.length() > maxChars && maxChars > 1) {
                row = row.substring(0, maxChars);
            }
            c.drawText(legendStartX + swatchSize + 5 * scale, yRow + 2 * scale, row, COLOR_TEXT, scale);
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

    /** Format like "267 (62.8%)" — count integer, percent 1 decimal. */
    private static String formatCountPercent(Decimal count, Decimal pct) {
        return formatInt(count) + ' (' + formatPercent(pct) + ')';
    }

    /** Format like "62.8%" — drops decimal when whole. */
    private static String formatPercent(Decimal pct) {
        if (pct == null) {
            return '0%';
        }
        if (pct == pct.setScale(0)) {
            return String.valueOf(pct.intValue()) + '%';
        }
        return String.valueOf(pct.setScale(1)) + '%';
    }

    private static String formatInt(Decimal v) {
        if (v == null) {
            return '0';
        }
        return String.valueOf(v.intValue());
    }

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

    private static String stringOf(Object v) {
        return v == null ? null : String.valueOf(v);
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

        /**
         * Draws one character at (x, y) using the AA glyph table in
         * DocGenChartFont. Each glyph pixel has 16 grayscale levels;
         * non-transparent levels paint the matching shade from the text
         * palette intermediates (COLOR_TEXT_BASE..COLOR_TEXT_BASE+15).
         *
         * `colorIdx` is the FULL-foreground color index — typically
         * COLOR_TEXT. Partial-coverage edge pixels emit lighter shades.
         * For now we assume the full-foreground color sits at the top of
         * the text-shade ramp; the AA blends to background through the
         * intermediates between bg and that top.
         *
         * Each grayscale pixel is rendered as scale×scale physical pixels.
         */
        public void drawChar(Integer x, Integer y, String ch, Integer colorIdx, Integer scale) {
            List<Integer> glyph = DocGenChartFont.get(ch);
            if (glyph == null) {
                return;
            }
            Integer cellW = DocGenChartFont.CELL_W;
            Integer cellH = DocGenChartFont.CELL_H;
            for (Integer row = 0; row < cellH; row++) {
                Integer packed = glyph[row];
                for (Integer col = 0; col < cellW; col++) {
                    // 4-bit grayscale, MSB-first within the row's Integer.
                    Integer shiftBits = 4 * (cellW - 1 - col);
                    Integer shade = (packed >>> shiftBits) & 15;
                    if (shade == 0) {
                        continue; // transparent — leave background pixel alone
                    }
                    // Map shade 1..15 to palette index COLOR_TEXT_BASE+1..+15.
                    // Shade 0 is excluded above; shade 15 is fully-opaque text.
                    Integer palIdx = COLOR_TEXT_BASE + shade;
                    Integer px = x + col * scale;
                    Integer py = y + row * scale;
                    for (Integer dy = 0; dy < scale; dy++) {
                        for (Integer dx = 0; dx < scale; dx++) {
                            setPixel(px + dx, py + dy, palIdx);
                        }
                    }
                }
            }
            // colorIdx param currently unused — kept for backward compat with
            // the old API. The shade ramp is fixed to the text gray defined
            // in buildReservedRgb. Future: per-glyph color override by
            // extending the palette with multiple shade ramps.
            if (colorIdx == -999) {
                return; // never true; references the var to silence unused warnings
            }
        }

        public Integer drawText(Integer x, Integer y, String text, Integer colorIdx, Integer scale) {
            if (text == null) {
                return 0;
            }
            Integer cursorX = x;
            for (Integer i = 0; i < text.length(); i++) {
                String ch = text.substring(i, i + 1);
                drawChar(cursorX, y, ch, colorIdx, scale);
                cursorX += DocGenChartFont.advance(ch) * scale;
            }
            return cursorX - x;
        }

        public Integer textWidth(String text, Integer scale) {
            if (text == null) {
                return 0;
            }
            Integer w = 0;
            for (Integer i = 0; i < text.length(); i++) {
                w += DocGenChartFont.advance(text.substring(i, i + 1)) * scale;
            }
            return w;
        }

        public Blob toPng() {
            return DocGenPngEncoder.emitIndexed8(width, height, palette, pixels);
        }
    }
}
