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

    private static final Set<String> KNOWN_STYLES = new Set<String>{
        'bar',
        'column',
        'pie',
        'donut',
        'stacked',
        'clustered',
        'line',
        'area'
    };

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
        if (style == 'stacked') {
            return emitStacked(buckets, opts);
        }
        if (style == 'clustered') {
            return emitClustered(buckets, opts);
        }
        if (style == 'line') {
            return emitLine(buckets, opts, false);
        }
        if (style == 'area') {
            return emitLine(buckets, opts, true);
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
     *   pie    : 360 × 190
     *   donut  : 360 × 190
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
            // Smaller than bar/column because the downstream PNG encoder
            // is the dominant cost at scale=2 and a 540×280 logical pie
            // (=605k physical pixels) exceeds the 10s sync CPU budget on
            // its own. See the comment in emitPie for full context.
            width = optInt(opts, 'width', 360);
            height = optInt(opts, 'height', 190);
        } else if (style == 'stacked') {
            Integer barHeight = 22;
            Integer barGap = 8;
            Integer legendH = hasCols(buckets) ? 22 : 0;
            width = optInt(opts, 'width', 540);
            height = optInt(opts, 'height', legendH + (buckets.size() * (barHeight + barGap)) + barGap + 4);
        } else if (style == 'clustered') {
            Integer legendH = hasCols(buckets) ? 22 : 0;
            width = optInt(opts, 'width', 540);
            height = optInt(opts, 'height', legendH + 14 + 200 + 64);
        } else if (style == 'line' || style == 'area') {
            Integer legendH = hasCols(buckets) ? 22 : 0;
            width = optInt(opts, 'width', 500);
            height = optInt(opts, 'height', legendH + 14 + 200 + 60);
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
    // Strategy: sector-based scanline fill. For each scanline y inside the
    // outer disk we compute (a) the disk's x-range from the implicit-circle
    // equation `dx² ≤ outerR² - dy²`, (b) the donut hole x-range from the
    // inner-circle equation, and (c) the x-intersections of each slice's
    // boundary rays via the closed-form parametric formula
    // `x = cx - dy · tan θ`. Sorting those x-values along the scanline gives
    // us a small set of horizontal spans (≤ 2·nSlices+4 per row), each
    // belonging to exactly one slice. The spans are filled in tight inline
    // loops — no atan2 or per-pixel angle test ever runs.
    //
    // Per-scanline cost is O(nSlices²) for the insertion sort plus O(R) for
    // the actual pixel writes. At a 360×190 logical chart with scale=2
    // (720×380 physical) this is roughly 380 scanlines × (~30 ops + ~200
    // pixel writes) = comfortably under the 10s sync Apex CPU budget where
    // the previous per-pixel atan2 path tipped over even at scale=1.
    // =====================================================================
    private static Blob emitPie(List<Map<String, Object>> buckets, Map<String, String> opts, Boolean donut) {
        Integer scale = optInt(opts, 'scale', 2);
        // Pie/donut default logical dimensions sit below the bar/column
        // defaults so that at scale=2 the total pixel count
        // (~360 × 190 × 4 ≈ 274k) stays comfortably under the sync Apex CPU
        // budget when the downstream PNG encoder iterates the pixel buffer
        // for filter emission, adler-32, and CRC. The encoder cost scales
        // linearly with pixel count and is the dominant term at scale=2 —
        // empirically a 540×280 logical pie exceeds 10s on its own.
        // Callers wanting larger pies can override via opts.width / .height.
        Integer width = optInt(opts, 'width', 360) * scale;
        Integer height = optInt(opts, 'height', 190) * scale;
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

        Integer nSlices = buckets.size();

        // Slice boundary angles in radians, measured CLOCKWISE from 12 o'clock.
        // sliceEndAngle[i] = end of slice i = start of slice (i+1). The
        // start of slice 0 is implicitly 0 (12 o'clock).
        //
        // Screen coords: y grows DOWN. A ray at angle θ (clockwise from 12
        // o'clock) has direction vector (sin θ, -cos θ).
        List<Double> sliceEndAngle = new List<Double>();
        List<Double> sinTheta = new List<Double>();
        List<Double> cosTheta = new List<Double>();
        Double TWO_PI = 2.0 * Math.PI;
        Decimal running = 0;
        for (Integer i = 0; i < nSlices; i++) {
            Decimal v = decimalOf(buckets[i].get('count'));
            if (v == null) {
                v = 0;
            }
            running += v;
            Double theta = (Double) (running / total) * TWO_PI;
            sliceEndAngle.add(theta);
            sinTheta.add(Math.sin(theta));
            cosTheta.add(Math.cos(theta));
        }

        // Slice START angles (sin/cos) for the cross-product half-plane
        // test used to classify a span midpoint to a slice. start[0] = 0.
        List<Double> sinStart = new List<Double>();
        List<Double> cosStart = new List<Double>();
        sinStart.add(0.0);
        cosStart.add(1.0);
        for (Integer i = 1; i < nSlices; i++) {
            sinStart.add(sinTheta[i - 1]);
            cosStart.add(cosTheta[i - 1]);
        }

        // A slice with arc length > π requires inverted half-plane logic
        // (a point is in the slice iff it is on the clockwise side of
        // EITHER ray, not BOTH).
        List<Boolean> sliceIsLarge = new List<Boolean>();
        Double prev = 0.0;
        for (Integer i = 0; i < nSlices; i++) {
            sliceIsLarge.add((sliceEndAngle[i] - prev) > Math.PI);
            prev = sliceEndAngle[i];
        }

        // Pre-resolve per-slice palette indices.
        List<Integer> slicePalette = new List<Integer>();
        for (Integer i = 0; i < nSlices; i++) {
            slicePalette.add(paletteIndexForBucket(buckets[i], i, nSlices));
        }

        // Pre-compute tan(θ_end) for each slice boundary so the per-scanline
        // intersection x = cx - dy · tan(θ) is a single multiply per ray.
        // Rays with |cos θ| ≈ 0 (3 o'clock / 9 o'clock) only touch the
        // y == cy scanline; flagged separately.
        List<Double> tanTheta = new List<Double>();
        List<Boolean> isHorizontal = new List<Boolean>();
        for (Integer i = 0; i < nSlices; i++) {
            Double cosT = cosTheta[i];
            Double sinT = sinTheta[i];
            if (Math.abs(cosT) < 0.000000001) {
                tanTheta.add(0.0);
                isHorizontal.add(true);
            } else {
                tanTheta.add(sinT / cosT);
                isHorizontal.add(false);
            }
        }

        Integer yMin = Math.max(0, cy - outerR);
        Integer yMax = Math.min(height - 1, cy + outerR);
        Integer canvasW = c.width;
        List<Integer> px = c.pixels;

        // Pre-allocate per-scanline scratch storage so the hot loop reuses
        // the same backing List on every iteration instead of allocating.
        // Each slice contributes up to 2 break-points (bx and bx+1) plus the
        // two disk endpoints.
        Integer maxBreaks = 2 * nSlices + 4;
        List<Integer> breakXs = new List<Integer>();
        for (Integer i = 0; i < maxBreaks; i++) {
            breakXs.add(0);
        }

        for (Integer y = yMin; y <= yMax; y++) {
            Integer dy = y - cy;
            Integer dy2 = dy * dy;
            Integer outerSpan2 = outerR2 - dy2;
            if (outerSpan2 < 0) {
                continue;
            }
            Integer dxOuter = (Integer) Math.sqrt((Double) outerSpan2);
            Integer xLeft = Math.max(0, cx - dxOuter);
            Integer xRight = Math.min(width - 1, cx + dxOuter);
            if (xLeft > xRight) {
                continue;
            }

            // Donut hole on this scanline. holeMax = -1 means "no hole".
            Integer holeMax = -1;
            if (donut && dy2 < innerR2) {
                Integer innerSpan2 = innerR2 - dy2;
                holeMax = (Integer) Math.sqrt((Double) innerSpan2);
            }

            Integer rowBase = y * canvasW;
            Double ddy = (Double) dy;

            // Analytical x-intersection of each slice boundary ray with this
            // scanline. A ray (sin θ, -cos θ) hits y when
            //   t = -dy / cos θ ≥ 0
            // i.e. dy and cos θ have opposite signs (or one is 0). The
            // intersection x is x = cx + t · sin θ = cx - dy · tan θ.
            Integer breakN = 0;
            breakXs[breakN++] = xLeft;
            breakXs[breakN++] = xRight + 1;
            for (Integer i = 0; i < nSlices; i++) {
                Double cosT = cosTheta[i];
                Integer bx;
                if (isHorizontal[i]) {
                    if (dy != 0) {
                        continue;
                    }
                    bx = sinTheta[i] > 0 ? xRight : xLeft;
                } else {
                    // Skip rays whose t < 0 (don't reach this scanline).
                    if ((dy > 0 && cosT > 0) || (dy < 0 && cosT < 0)) {
                        continue;
                    }
                    Double xExact = (Double) cx - ddy * tanTheta[i];
                    bx = (Integer) Math.round(xExact);
                }
                if (bx < xLeft) {
                    bx = xLeft;
                }
                if (bx > xRight) {
                    bx = xRight;
                }
                breakXs[breakN++] = bx;
                // Add bx+1 so both sides of the boundary form distinct spans.
                if (bx + 1 <= xRight) {
                    breakXs[breakN++] = bx + 1;
                }
            }

            // Insertion sort the active prefix. n ≤ ~14 entries in practice;
            // insertion sort beats List.sort() (Comparable boxing) at this
            // size and avoids the allocation List.sort() does internally.
            for (Integer i = 1; i < breakN; i++) {
                Integer v = breakXs[i];
                Integer j = i - 1;
                while (j >= 0 && breakXs[j] > v) {
                    breakXs[j + 1] = breakXs[j];
                    j--;
                }
                breakXs[j + 1] = v;
            }

            // Walk the sorted breakpoints in pairs, classify each span by
            // its midpoint, and fill.
            Integer prevBp = -1;
            Integer holeLeftX = holeMax >= 0 ? (cx - holeMax) : -2;
            Integer holeRightX = holeMax >= 0 ? (cx + holeMax) : -2;
            for (Integer k = 0; k < breakN; k++) {
                Integer bp = breakXs[k];
                if (bp == prevBp) {
                    continue; // dedup
                }
                if (prevBp >= 0 && bp > prevBp) {
                    Integer sa = prevBp;
                    Integer sb = bp - 1; // inclusive right end of span
                    if (sa <= xRight && sb >= xLeft) {
                        if (sa < xLeft) {
                            sa = xLeft;
                        }
                        if (sb > xRight) {
                            sb = xRight;
                        }
                        Boolean spanInHole = (holeMax >= 0) && (sa >= holeLeftX) && (sb <= holeRightX);
                        if (!spanInHole) {
                            Integer mid = (sa + sb) / 2;
                            Integer mdx = mid - cx;
                            Integer sliceIdx = locateSlice(
                                (Double) mdx,
                                ddy,
                                nSlices,
                                sinStart,
                                cosStart,
                                sinTheta,
                                cosTheta,
                                sliceIsLarge
                            );
                            Integer color = slicePalette[sliceIdx];
                            if (holeMax < 0) {
                                for (Integer xp = sa; xp <= sb; xp++) {
                                    px[rowBase + xp] = color;
                                }
                            } else {
                                // Span may straddle the donut hole — split fill.
                                if (sb < holeLeftX || sa > holeRightX) {
                                    for (Integer xp = sa; xp <= sb; xp++) {
                                        px[rowBase + xp] = color;
                                    }
                                } else {
                                    if (sa < holeLeftX) {
                                        Integer leftEnd = Math.min(sb, holeLeftX - 1);
                                        for (Integer xp = sa; xp <= leftEnd; xp++) {
                                            px[rowBase + xp] = color;
                                        }
                                    }
                                    if (sb > holeRightX) {
                                        Integer rightStart = Math.max(sa, holeRightX + 1);
                                        for (Integer xp = rightStart; xp <= sb; xp++) {
                                            px[rowBase + xp] = color;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                prevBp = bp;
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

    /**
     * Classify a point (ddx, ddy) — offset from pie center — into one of
     * the slices using the cross-product half-plane test. No atan2.
     *
     * A ray at angle θ (clockwise from 12 o'clock, screen coords with y
     * growing down) has direction r_θ = (sin θ, -cos θ). The 2D cross of
     * r_θ with point P = (dx, dy) is sin(θ)·dy + cos(θ)·dx; positive means
     * P sits clockwise of the ray, negative counter-clockwise.
     *
     * A slice spans [θ_start, θ_end] clockwise. For arc length ≤ π:
     *   in-slice iff cross_S ≥ 0 AND cross_E ≤ 0
     * For arc length > π (slice covers more than half the pie) the test
     * inverts to OR — equivalent to "NOT in the small complement slice".
     */
    private static Integer locateSlice(
        Double ddx,
        Double ddy,
        Integer nSlices,
        List<Double> sinStart,
        List<Double> cosStart,
        List<Double> sinEnd,
        List<Double> cosEnd,
        List<Boolean> sliceIsLarge
    ) {
        for (Integer i = 0; i < nSlices; i++) {
            Double crossS = sinStart[i] * ddy + cosStart[i] * ddx;
            Double crossE = sinEnd[i] * ddy + cosEnd[i] * ddx;
            Boolean inSlice;
            if (sliceIsLarge[i]) {
                inSlice = (crossS >= 0) || (crossE <= 0);
            } else {
                inSlice = (crossS >= 0) && (crossE <= 0);
            }
            if (inSlice) {
                return i;
            }
        }
        // Numerical edge — pick the last slice. This shouldn't happen for
        // points strictly inside the disk by construction.
        return nSlices - 1;
    }

    // =====================================================================
    // Stacked — horizontal stacked bar, one row per bucket. Each row is
    // segmented by the bucket's `cols` cross-tab list (Total column
    // excluded). Mirrors DocGenSvgChartSerializer.emitStacked layout so
    // the rasterized output matches the SVG output visually.
    // =====================================================================
    private static Blob emitStacked(List<Map<String, Object>> buckets, Map<String, String> opts) {
        // scale=1 default: at scale=2 the encoder pass over 540×~300×4 pixels
        // exceeds the 10s sync Apex CPU budget. Bars/segments are rectilinear
        // so they don't need the curve-AA boost that pie/donut get from
        // scale=2 + Word downsample. Caller can opt into scale=2 explicitly.
        Integer scale = optInt(opts, 'scale', 1);
        Integer logicalWidth = optInt(opts, 'width', 540);
        Integer barHeight = 22;
        Integer barGap = 8;
        Integer labelWidth = 150;
        Integer valueWidth = 90;
        Boolean crossTab = hasCols(buckets);
        Integer legendHeight = crossTab ? 22 : 0;
        Integer logicalHeight = optInt(
            opts,
            'height',
            legendHeight + (buckets.size() * (barHeight + barGap)) + barGap + 4
        );

        Integer width = logicalWidth * scale;
        Integer height = logicalHeight * scale;
        Integer pBarHeight = barHeight * scale;
        Integer pBarGap = barGap * scale;
        Integer pLabelWidth = labelWidth * scale;
        Integer pValueWidth = valueWidth * scale;
        Integer pLegendHeight = legendHeight * scale;

        Canvas c = new Canvas(width, height, buildPalette(opts));
        List<Map<String, Object>> legendCols = collectLegendCols(buckets, true);
        if (crossTab) {
            drawLegendRow(c, legendCols, 0, 0, width, scale);
        }

        Integer barAreaX = pLabelWidth;
        Integer barAreaWidth = width - pLabelWidth - pValueWidth;
        Integer fontH = FONT_H * scale;
        Integer rowsTop = pLegendHeight;

        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            Decimal rowTotal = decimalOf(b.get('count'));
            if (rowTotal == null) {
                rowTotal = 0;
            }
            Integer rowY = rowsTop + pBarGap + i * (pBarHeight + pBarGap);
            Integer textY = rowY + (pBarHeight - fontH) / 2;

            // Left label (bucket key)
            String label = bucketLabel(b);
            Integer maxLabelChars = (pLabelWidth - 6 * scale) / (FONT_CHAR_ADVANCE * scale);
            if (label.length() > maxLabelChars && maxLabelChars > 1) {
                label = label.substring(0, maxLabelChars);
            }
            c.drawText(4 * scale, textY, label, COLOR_TEXT, scale);

            // Empty bar slot outline (lets blank rows still show a slot).
            c.fillRect(barAreaX, rowY, barAreaWidth, pBarHeight, COLOR_GRID);
            // Fill the interior with bg so only the outline remains.
            c.fillRect(barAreaX + scale, rowY + scale, barAreaWidth - 2 * scale, pBarHeight - 2 * scale, COLOR_BG);

            List<Object> cols = (List<Object>) b.get('cols');
            if (cols != null && !cols.isEmpty()) {
                Integer segIdx = 0;
                Double offset = 0.0;
                for (Object co : cols) {
                    Map<String, Object> col = (Map<String, Object>) co;
                    if (isTotalCol(col)) {
                        continue;
                    }
                    Decimal pct = decimalOf(col.get('percent_of_row'));
                    if (pct == null) {
                        pct = 0;
                    }
                    Double segW = (pct.doubleValue() / 100.0) * barAreaWidth;
                    if (segW > 0) {
                        Integer paletteIdx = RESERVED_RGB.size() + Math.mod(segIdx, DEFAULT_PALETTE_RGB.size());
                        c.fillRect((Integer) (barAreaX + offset), rowY, (Integer) segW, pBarHeight, paletteIdx);
                    }
                    offset += segW;
                    segIdx++;
                }
            }

            // Right total label
            String totalLabel = formatInt(rowTotal) + ' total';
            c.drawText(barAreaX + barAreaWidth + 6 * scale, textY, totalLabel, COLOR_TEXT, scale);
        }

        return c.toPng();
    }

    // =====================================================================
    // Clustered — vertical clustered bar chart, one cluster per bucket.
    // Each cluster has one mini-bar per visible (non-Total) col. Bar heights
    // auto-scale to peak observed percent so values fill the plot area.
    // =====================================================================
    private static Blob emitClustered(List<Map<String, Object>> buckets, Map<String, String> opts) {
        // scale=1 default — see emitStacked comment for the CPU rationale.
        Integer scale = optInt(opts, 'scale', 1);
        Integer logicalWidth = optInt(opts, 'width', 540);
        Boolean crossTab = hasCols(buckets);
        Integer legendHeight = crossTab ? 22 : 0;
        Integer labelArea = 64;
        Integer plotPaddingTop = 14;
        Integer plotPaddingLeft = 30;
        Integer logicalHeight = optInt(opts, 'height', legendHeight + plotPaddingTop + 200 + labelArea);

        Integer width = logicalWidth * scale;
        Integer height = logicalHeight * scale;
        Integer pLegendH = legendHeight * scale;
        Integer pLabelArea = labelArea * scale;
        Integer pPlotPadTop = plotPaddingTop * scale;
        Integer pPlotPadLeft = plotPaddingLeft * scale;

        Canvas c = new Canvas(width, height, buildPalette(opts));
        List<Map<String, Object>> legendCols = collectLegendCols(buckets, true);
        if (crossTab) {
            drawLegendRow(c, legendCols, 0, 0, width, scale);
        }

        Integer plotTop = pLegendH + pPlotPadTop;
        Integer plotBottom = height - pLabelArea;
        Integer plotHeight = plotBottom - plotTop;
        Integer plotLeft = pPlotPadLeft;
        Integer plotRight = width - 10 * scale;
        Integer plotWidth = plotRight - plotLeft;

        // Find peak percent across visible cols.
        Decimal peakPct = 0;
        for (Map<String, Object> b : buckets) {
            List<Object> cols = (List<Object>) b.get('cols');
            if (cols == null) {
                continue;
            }
            for (Object co : cols) {
                Map<String, Object> col = (Map<String, Object>) co;
                if (isTotalCol(col)) {
                    continue;
                }
                Decimal pct = decimalOf(col.get('percent_int'));
                if (pct == null) {
                    pct = decimalOf(col.get('percent'));
                }
                if (pct != null && pct > peakPct) {
                    peakPct = pct;
                }
            }
        }
        if (peakPct <= 0) {
            peakPct = 100;
        }

        Integer slotCount = Math.max(1, buckets.size());
        Integer slotWidth = plotWidth / slotCount;
        Integer visibleColCount = legendCols.size();
        Integer barSlotWidth = Math.max(4 * scale, (Integer) (slotWidth * 0.72));
        Integer perBarWidth = visibleColCount > 0 ? Math.max(3 * scale, barSlotWidth / visibleColCount) : barSlotWidth;

        // Baseline
        c.fillRect(plotLeft, plotBottom, plotWidth, scale, COLOR_GRID);

        Integer fontH = FONT_H * scale;
        for (Integer i = 0; i < buckets.size(); i++) {
            Map<String, Object> b = buckets[i];
            String label = bucketLabel(b);
            Integer slotCenter = plotLeft + (i * slotWidth) + (slotWidth / 2);

            // Filter visible cols for placement.
            List<Map<String, Object>> visible = new List<Map<String, Object>>();
            List<Object> cols = (List<Object>) b.get('cols');
            if (cols != null) {
                for (Object co : cols) {
                    Map<String, Object> col = (Map<String, Object>) co;
                    if (!isTotalCol(col)) {
                        visible.add(col);
                    }
                }
            }
            Integer clusterWidth = perBarWidth * visible.size();
            Integer clusterX = slotCenter - (clusterWidth / 2);

            for (Integer j = 0; j < visible.size(); j++) {
                Map<String, Object> col = visible[j];
                Decimal pct = decimalOf(col.get('percent_int'));
                if (pct == null) {
                    pct = decimalOf(col.get('percent'));
                }
                if (pct == null) {
                    pct = 0;
                }
                Integer barH = ((pct * plotHeight) / peakPct).intValue();
                if (barH < 1 && pct > 0) {
                    barH = scale;
                }
                Integer barX = clusterX + (j * perBarWidth);
                Integer barY = plotBottom - barH;
                Integer paletteIdx = RESERVED_RGB.size() + Math.mod(j, DEFAULT_PALETTE_RGB.size());
                c.fillRect(barX, barY, Math.max(scale, perBarWidth - scale), barH, paletteIdx);
            }

            // Bucket label centered under the cluster — truncated, not rotated.
            // (The SVG variant rotates -25° but bitmap rotation is expensive
            // and noisy at chart resolution; we accept truncation instead.)
            Integer maxChars = Math.max(2, slotWidth / (FONT_CHAR_ADVANCE * scale));
            String truncated = label;
            if (truncated.length() > maxChars) {
                truncated = truncated.substring(0, maxChars);
            }
            Integer labelW = c.textWidth(truncated, scale);
            Integer labelX = slotCenter - labelW / 2;
            c.drawText(labelX, plotBottom + 6 * scale, truncated, COLOR_TEXT, scale);
        }

        return c.toPng();
    }

    // =====================================================================
    // Line / Area — sequential line chart through (x=bucket index, y=count).
    // Multi-series when cross-tab `cols` is populated. `filled=true` adds a
    // dot-pattern area fill below each polyline (indexed color has no alpha
    // so we substitute a checkered fill — every-other-pixel — as a stylistic
    // stand-in for SVG's semi-transparent polygon).
    // =====================================================================
    private static Blob emitLine(List<Map<String, Object>> buckets, Map<String, String> opts, Boolean filled) {
        // scale=1 default — see emitStacked comment for the CPU rationale.
        // Polyline 2px thickening is implemented in pixels (not via scale)
        // so visual weight stays consistent.
        Integer scale = optInt(opts, 'scale', 1);
        Integer logicalWidth = optInt(opts, 'width', 500);
        Boolean multiSeries = hasCols(buckets);
        Integer legendHeight = multiSeries ? 22 : 0;
        Integer labelArea = 60;
        Integer plotPaddingTop = 14;
        Integer plotPaddingLeft = 60;
        Integer logicalHeight = optInt(opts, 'height', legendHeight + plotPaddingTop + 200 + labelArea);

        Integer width = logicalWidth * scale;
        Integer height = logicalHeight * scale;
        Integer pLegendH = legendHeight * scale;
        Integer pLabelArea = labelArea * scale;
        Integer pPlotPadTop = plotPaddingTop * scale;
        Integer pPlotPadLeft = plotPaddingLeft * scale;

        Canvas c = new Canvas(width, height, buildPalette(opts));
        List<Map<String, Object>> legendCols = multiSeries
            ? collectLegendCols(buckets, true)
            : new List<Map<String, Object>>();
        if (multiSeries) {
            drawLegendRow(c, legendCols, 0, 0, width, scale);
        }

        Integer plotTop = pLegendH + pPlotPadTop;
        Integer plotBottom = height - pLabelArea;
        Integer plotHeight = plotBottom - plotTop;
        Integer plotLeft = pPlotPadLeft;
        Integer plotRight = width - 14 * scale;
        Integer plotWidth = plotRight - plotLeft;

        // Find peak count across whichever series are in scope.
        Decimal peakCount = 0;
        if (multiSeries) {
            for (Map<String, Object> b : buckets) {
                List<Object> cols = (List<Object>) b.get('cols');
                if (cols == null) {
                    continue;
                }
                for (Object co : cols) {
                    Map<String, Object> col = (Map<String, Object>) co;
                    if (isTotalCol(col)) {
                        continue;
                    }
                    Decimal cnt = decimalOf(col.get('count'));
                    if (cnt != null && cnt > peakCount) {
                        peakCount = cnt;
                    }
                }
            }
        } else {
            for (Map<String, Object> b : buckets) {
                Decimal cnt = decimalOf(b.get('count'));
                if (cnt != null && cnt > peakCount) {
                    peakCount = cnt;
                }
            }
        }
        if (peakCount <= 0) {
            peakCount = 1;
        }

        // Y axis
        c.fillRect(plotLeft, plotTop, scale, plotHeight, COLOR_GRID);
        // X axis baseline
        c.fillRect(plotLeft, plotBottom, plotWidth + scale, scale, COLOR_GRID);

        // Y axis ticks: peak at top, 0 at bottom.
        Integer fontH = FONT_H * scale;
        String peakLabel = formatInt(peakCount);
        Integer peakLabelW = c.textWidth(peakLabel, scale);
        c.drawText(plotLeft - peakLabelW - 4 * scale, plotTop - fontH / 2, peakLabel, COLOR_TEXT, scale);
        Integer zeroLabelW = c.textWidth('0', scale);
        c.drawText(plotLeft - zeroLabelW - 4 * scale, plotBottom - fontH / 2, '0', COLOR_TEXT, scale);

        Integer n = buckets.size();
        // X positions per bucket (physical, integer for setPixel calls).
        List<Integer> xs = new List<Integer>();
        if (n == 1) {
            xs.add(plotLeft + plotWidth / 2);
        } else if (n > 1) {
            for (Integer i = 0; i < n; i++) {
                xs.add(plotLeft + (i * plotWidth) / (n - 1));
            }
        }

        // Render series.
        if (multiSeries) {
            for (Integer s = 0; s < legendCols.size(); s++) {
                Map<String, Object> legend = legendCols[s];
                String seriesKeyLower = stringOf(legend.get('_keyLower'));
                Integer paletteIdx = RESERVED_RGB.size() + Math.mod(s, DEFAULT_PALETTE_RGB.size());
                drawLineSeries(
                    c,
                    buckets,
                    xs,
                    plotBottom,
                    plotHeight,
                    peakCount,
                    paletteIdx,
                    seriesKeyLower,
                    filled,
                    scale
                );
            }
        } else {
            Integer paletteIdx = RESERVED_RGB.size();
            drawLineSeries(c, buckets, xs, plotBottom, plotHeight, peakCount, paletteIdx, null, filled, scale);
        }

        // X axis category labels — truncated, not rotated (see emitClustered note).
        Integer labelY = plotBottom + 6 * scale;
        Integer maxLabelChars = Math.max(2, ((n > 1 ? plotWidth / (n - 1) : plotWidth)) / (FONT_CHAR_ADVANCE * scale));
        for (Integer i = 0; i < n; i++) {
            String label = bucketLabel(buckets[i]);
            if (label.length() > maxLabelChars) {
                label = label.substring(0, maxLabelChars);
            }
            Integer lw = c.textWidth(label, scale);
            c.drawText(xs[i] - lw / 2, labelY, label, COLOR_TEXT, scale);
        }

        return c.toPng();
    }

    /**
     * Draws a single line/area series onto the canvas. When `seriesKeyLower`
     * is null, pulls each point's value from bucket.count (single-series).
     * Otherwise matches each bucket's `cols` entry by key (case-insensitive)
     * to find the series value.
     */
    private static void drawLineSeries(
        Canvas c,
        List<Map<String, Object>> buckets,
        List<Integer> xs,
        Integer plotBottom,
        Integer plotHeight,
        Decimal peakCount,
        Integer colorIdx,
        String seriesKeyLower,
        Boolean filled,
        Integer scale
    ) {
        Integer n = buckets.size();
        if (n == 0 || xs.isEmpty()) {
            return;
        }
        List<Integer> ys = new List<Integer>();
        for (Integer i = 0; i < n; i++) {
            Decimal cnt = null;
            if (seriesKeyLower == null) {
                cnt = decimalOf(buckets[i].get('count'));
            } else {
                List<Object> cols = (List<Object>) buckets[i].get('cols');
                if (cols != null) {
                    for (Object co : cols) {
                        Map<String, Object> col = (Map<String, Object>) co;
                        String k = stringOf(col.get('key'));
                        if (k != null && k.toLowerCase() == seriesKeyLower) {
                            cnt = decimalOf(col.get('count'));
                            break;
                        }
                    }
                }
            }
            if (cnt == null) {
                cnt = 0;
            }
            Integer y = plotBottom - (Integer) ((cnt.doubleValue() / peakCount.doubleValue()) * plotHeight);
            ys.add(y);
        }

        // Area fill (drawn first so the line overdraws it).
        // Indexed-color "alpha": draw the series color at every (x+y) even
        // pixel within the area polygon. The dot pattern lets the bg show
        // through and reads visually as a lighter shade of the series color.
        if (filled && n > 0) {
            for (Integer i = 0; i < n - 1; i++) {
                Integer x0 = xs[i];
                Integer x1 = xs[i + 1];
                Integer y0 = ys[i];
                Integer y1 = ys[i + 1];
                // For each scanline column between x0 and x1, compute the
                // interpolated y on the line and fill from there to baseline
                // using the dot pattern.
                Integer dx = x1 - x0;
                if (dx <= 0) {
                    continue;
                }
                for (Integer x = x0; x <= x1; x++) {
                    Integer interpY = y0 + ((y1 - y0) * (x - x0)) / dx;
                    for (Integer y = interpY; y <= plotBottom; y++) {
                        if (Math.mod(x + y, 2) == 0) {
                            c.setPixel(x, y, colorIdx);
                        }
                    }
                }
            }
        }

        // Polyline (Bresenham). 2x supersample + Word downsample provides
        // free anti-aliasing; we don't pay Wu's per-pixel intensity cost.
        for (Integer i = 0; i < n - 1; i++) {
            drawBresenhamLine(c, xs[i], ys[i], xs[i + 1], ys[i + 1], colorIdx);
            // Thicken: also draw shifted-by-1 line so the polyline reads as
            // ~2px wide before downsampling. Keeps the line visible after
            // the Word downsample step.
            drawBresenhamLine(c, xs[i], ys[i] + 1, xs[i + 1], ys[i + 1] + 1, colorIdx);
        }

        // Point markers (filled dots at each data point).
        Integer dotR = Math.max(2, scale + 1);
        for (Integer i = 0; i < n; i++) {
            fillCircle(c, xs[i], ys[i], dotR, colorIdx);
        }
    }

    // =====================================================================
    // Shared helpers for stacked/clustered/line/area
    // =====================================================================

    /** True when any bucket carries a non-empty `cols` sub-list (cross-tab). */
    private static Boolean hasCols(List<Map<String, Object>> buckets) {
        if (buckets == null) {
            return false;
        }
        for (Map<String, Object> b : buckets) {
            List<Object> cols = (List<Object>) b.get('cols');
            if (cols != null && !cols.isEmpty()) {
                return true;
            }
        }
        return false;
    }

    /** Detects the synthetic "Total" col the resolver appends to cross-tab rows. */
    private static Boolean isTotalCol(Map<String, Object> col) {
        if (col == null) {
            return false;
        }
        String k = stringOf(col.get('key'));
        return k != null && k.equalsIgnoreCase('Total');
    }

    /** Bucket display label: key_label, else key, else empty string. */
    private static String bucketLabel(Map<String, Object> b) {
        String label = stringOf(b.get('key_label'));
        if (String.isBlank(label)) {
            label = stringOf(b.get('key'));
        }
        return label == null ? '' : label;
    }

    /**
     * Walks the first bucket with `cols` and returns a list of legend
     * entries (excluding Total when requested). Each entry includes a
     * `_keyLower` field for case-insensitive series-key matching in
     * drawLineSeries.
     */
    private static List<Map<String, Object>> collectLegendCols(
        List<Map<String, Object>> buckets,
        Boolean excludeTotal
    ) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (buckets == null) {
            return out;
        }
        for (Map<String, Object> b : buckets) {
            List<Object> cols = (List<Object>) b.get('cols');
            if (cols == null || cols.isEmpty()) {
                continue;
            }
            for (Object co : cols) {
                Map<String, Object> col = (Map<String, Object>) co;
                if (excludeTotal && isTotalCol(col)) {
                    continue;
                }
                Map<String, Object> entry = new Map<String, Object>(col);
                String k = stringOf(entry.get('key'));
                entry.put('_keyLower', k == null ? '' : k.toLowerCase());
                out.add(entry);
            }
            return out;
        }
        return out;
    }

    /**
     * Draws a top-of-chart legend strip — swatch + label per cross-tab col.
     * Layout mirrors DocGenSvgChartSerializer.appendLegendRow: ~110px per
     * entry, wraps when out of horizontal room.
     */
    private static void drawLegendRow(
        Canvas c,
        List<Map<String, Object>> legendCols,
        Integer startX,
        Integer startY,
        Integer maxWidth,
        Integer scale
    ) {
        if (legendCols == null || legendCols.isEmpty()) {
            return;
        }
        Integer entryWidth = 110 * scale;
        Integer swatchSize = 10 * scale;
        Integer y = startY + 4 * scale;
        Integer x = startX;
        Integer fontH = FONT_H * scale;
        for (Integer i = 0; i < legendCols.size(); i++) {
            Map<String, Object> col = legendCols[i];
            String label = stringOf(col.get('key_label'));
            if (String.isBlank(label)) {
                label = stringOf(col.get('key'));
            }
            if (label == null) {
                label = '';
            }
            if (label.length() > 14) {
                label = label.substring(0, 13);
            }
            Integer paletteIdx = RESERVED_RGB.size() + Math.mod(i, DEFAULT_PALETTE_RGB.size());
            if (x + entryWidth > maxWidth) {
                x = startX;
                y += 16 * scale;
            }
            c.fillRect(x, y, 14 * scale, swatchSize, paletteIdx);
            c.drawText(x + 20 * scale, y + (swatchSize - fontH) / 2, label, COLOR_TEXT, scale);
            x += entryWidth;
        }
    }

    /**
     * Bresenham's line algorithm. Sets pixels along the integer line from
     * (x0,y0) to (x1,y1). Crisp 1-pixel-wide; AA is achieved at scale=2 via
     * the Word downsample step (same trick as bar/column).
     */
    private static void drawBresenhamLine(Canvas c, Integer x0, Integer y0, Integer x1, Integer y1, Integer colorIdx) {
        Integer dx = Math.abs(x1 - x0);
        Integer sx = x0 < x1 ? 1 : -1;
        Integer dy = -Math.abs(y1 - y0);
        Integer sy = y0 < y1 ? 1 : -1;
        Integer err = dx + dy;
        Integer x = x0;
        Integer y = y0;
        while (true) {
            c.setPixel(x, y, colorIdx);
            if (x == x1 && y == y1) {
                return;
            }
            Integer e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y += sy;
            }
        }
    }

    /**
     * Filled circle via the midpoint algorithm: fill horizontal spans for
     * each scanline within the circle. Used for line-chart data point dots.
     */
    private static void fillCircle(Canvas c, Integer cx, Integer cy, Integer r, Integer colorIdx) {
        Integer r2 = r * r;
        for (Integer dy = -r; dy <= r; dy++) {
            Integer dx = (Integer) Math.sqrt((Double) (r2 - dy * dy));
            for (Integer x = cx - dx; x <= cx + dx; x++) {
                c.setPixel(x, cy + dy, colorIdx);
            }
        }
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
