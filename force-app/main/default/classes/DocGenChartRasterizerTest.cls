@IsTest
private class DocGenChartRasterizerTest {
    private static final List<Integer> PNG_SIG = new List<Integer>{ 137, 80, 78, 71, 13, 10, 26, 10 };

    private static void assertPngSignature(Blob png, String label) {
        System.assertNotEquals(null, png, label + ' produced null Blob');
        Integer sz = png.size();
        System.assert(sz > 100, label + ' too small: ' + sz + ' bytes');
        List<Integer> hdr = blobBytes(png, 8);
        for (Integer i = 0; i < 8; i++) {
            System.assertEquals(PNG_SIG[i], hdr[i], label + ' PNG signature byte ' + i + ' mismatch');
        }
    }

    private static List<Integer> blobBytes(Blob b, Integer count) {
        String b64 = EncodingUtil.base64Encode(b);
        Blob slice = EncodingUtil.base64Decode(b64);
        String hex = EncodingUtil.convertToHex(slice).substring(0, count * 2);
        List<Integer> out = new List<Integer>();
        for (Integer i = 0; i < count; i++) {
            String byteHex = hex.substring(i * 2, i * 2 + 2);
            Integer hi = '0123456789abcdef'.indexOf(byteHex.substring(0, 1).toLowerCase());
            Integer lo = '0123456789abcdef'.indexOf(byteHex.substring(1, 2).toLowerCase());
            out.add(hi * 16 + lo);
        }
        return out;
    }

    private static List<Map<String, Object>> simpleBuckets() {
        List<Map<String, Object>> buckets = new List<Map<String, Object>>();
        buckets.add(
            new Map<String, Object>{ 'key' => 'Alpha', 'key_label' => 'Alpha', 'count' => 30, 'percent' => 50 }
        );
        buckets.add(new Map<String, Object>{ 'key' => 'Beta', 'key_label' => 'Beta', 'count' => 18, 'percent' => 30 });
        buckets.add(
            new Map<String, Object>{ 'key' => 'Gamma', 'key_label' => 'Gamma', 'count' => 12, 'percent' => 20 }
        );
        return buckets;
    }

    private static List<Map<String, Object>> crossTabBuckets() {
        // 3 buckets × 3 cols (+ Total). cols carry count + percent_of_row + percent_int.
        List<Map<String, Object>> buckets = new List<Map<String, Object>>();
        for (Integer i = 0; i < 3; i++) {
            List<Object> cols = new List<Object>();
            cols.add(
                new Map<String, Object>{
                    'key' => 'Sales',
                    'key_label' => 'Sales',
                    'count' => 10 + i * 2,
                    'percent_of_row' => 40,
                    'percent_int' => 40
                }
            );
            cols.add(
                new Map<String, Object>{
                    'key' => 'Eng',
                    'key_label' => 'Engineering',
                    'count' => 6 + i,
                    'percent_of_row' => 35,
                    'percent_int' => 35
                }
            );
            cols.add(
                new Map<String, Object>{
                    'key' => 'Ops',
                    'key_label' => 'Ops',
                    'count' => 4 + i,
                    'percent_of_row' => 25,
                    'percent_int' => 25
                }
            );
            cols.add(
                new Map<String, Object>{
                    'key' => 'Total',
                    'key_label' => 'Total',
                    'count' => 20 + i * 4,
                    'percent_of_row' => 100,
                    'percent_int' => 100
                }
            );
            buckets.add(
                new Map<String, Object>{
                    'key' => 'Q' + (i + 1),
                    'key_label' => 'Q' +
                    (i + 1) +
                    ' 2026',
                    'count' => 20 + i * 4,
                    'percent' => 33,
                    'cols' => cols
                }
            );
        }
        return buckets;
    }

    @IsTest
    static void emitStacked_producesPng() {
        Blob png = DocGenChartRasterizer.emit(crossTabBuckets(), new Map<String, String>{ 'style' => 'stacked' });
        assertPngSignature(png, 'stacked');
    }

    @IsTest
    static void emitClustered_producesPng() {
        Blob png = DocGenChartRasterizer.emit(crossTabBuckets(), new Map<String, String>{ 'style' => 'clustered' });
        assertPngSignature(png, 'clustered');
    }

    @IsTest
    static void emitLine_singleSeries_producesPng() {
        Blob png = DocGenChartRasterizer.emit(simpleBuckets(), new Map<String, String>{ 'style' => 'line' });
        assertPngSignature(png, 'line-single');
    }

    @IsTest
    static void emitLine_multiSeries_producesPng() {
        Blob png = DocGenChartRasterizer.emit(crossTabBuckets(), new Map<String, String>{ 'style' => 'line' });
        assertPngSignature(png, 'line-multi');
    }

    @IsTest
    static void emitArea_singleSeries_producesPng() {
        Blob png = DocGenChartRasterizer.emit(simpleBuckets(), new Map<String, String>{ 'style' => 'area' });
        assertPngSignature(png, 'area-single');
    }

    @IsTest
    static void emitArea_multiSeries_producesPng() {
        Blob png = DocGenChartRasterizer.emit(crossTabBuckets(), new Map<String, String>{ 'style' => 'area' });
        assertPngSignature(png, 'area-multi');
    }

    @IsTest
    static void emitWithMeta_stacked_returnsLogicalDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            crossTabBuckets(),
            new Map<String, String>{ 'style' => 'stacked' }
        );
        System.assertNotEquals(null, result.get('png'));
        Integer w = (Integer) result.get('logicalWidth');
        Integer h = (Integer) result.get('logicalHeight');
        System.assert(w > 0, 'logicalWidth: ' + w);
        System.assert(h > 0, 'logicalHeight: ' + h);
        System.assertEquals(540, w, 'stacked default logical width');
    }

    @IsTest
    static void emitWithMeta_clustered_returnsLogicalDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            crossTabBuckets(),
            new Map<String, String>{ 'style' => 'clustered' }
        );
        System.assertEquals(540, (Integer) result.get('logicalWidth'));
        System.assertEquals(
            300,
            (Integer) result.get('logicalHeight'),
            'clustered default height (22 legend + 14 pad + 200 plot + 64 label)'
        );
    }

    @IsTest
    static void emitWithMeta_line_returnsLogicalDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'line' }
        );
        System.assertEquals(500, (Integer) result.get('logicalWidth'));
        // No cross-tab → no legend → 0 + 14 + 200 + 60 = 274
        System.assertEquals(274, (Integer) result.get('logicalHeight'), 'line default height single-series');
    }

    @IsTest
    static void unknownStyle_throws() {
        try {
            DocGenChartRasterizer.emit(simpleBuckets(), new Map<String, String>{ 'style' => 'spaghetti' });
            System.assert(false, 'Expected throw for unknown style');
        } catch (DocGenException e) {
            System.assert(
                e.getMessage().contains('spaghetti'),
                'Exception should mention the bad style: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void widthOverride_isRespected() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            crossTabBuckets(),
            new Map<String, String>{ 'style' => 'stacked', 'width' => '400' }
        );
        System.assertEquals(400, (Integer) result.get('logicalWidth'));
    }

    // ─── Original 4 styles: bar / column / pie / donut ──────────────────────

    @IsTest
    static void emitBar_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1' }
        );
        assertPngSignature(png, 'bar');
    }

    @IsTest
    static void emitBar_withTitle_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1', 'title' => 'My Bar Chart' }
        );
        assertPngSignature(png, 'bar-titled');
    }

    @IsTest
    static void emitColumn_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'column', 'scale' => '1' }
        );
        assertPngSignature(png, 'column');
    }

    @IsTest
    static void emitPie_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'pie', 'scale' => '1' }
        );
        assertPngSignature(png, 'pie');
    }

    @IsTest
    static void emitDonut_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'donut', 'scale' => '1' }
        );
        assertPngSignature(png, 'donut');
    }

    @IsTest
    static void emitDonut_withInnerRadiusOverride_producesPng() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'donut', 'scale' => '1', 'innerRadius' => '0.7' }
        );
        assertPngSignature(png, 'donut-custom-radius');
    }

    // ─── Palette + color overrides ──────────────────────────────────────────

    @IsTest
    static void colorsModifier_acceptsHexPalette() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1', 'colors' => '#1e40af,#b91c1c,#16a34a' }
        );
        assertPngSignature(png, 'bar-custom-palette');
    }

    @IsTest
    static void colorsModifier_acceptsBareHexWithoutHash() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1', 'colors' => '1e40af,b91c1c' }
        );
        assertPngSignature(png, 'bar-bare-hex');
    }

    @IsTest
    static void colorsModifier_blankFallsBackToDefaultPalette() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1', 'colors' => '' }
        );
        assertPngSignature(png, 'bar-blank-colors');
    }

    @IsTest
    static void colorsModifier_badHexSkipped_falsThroughToDefault() {
        Blob png = DocGenChartRasterizer.emit(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar', 'scale' => '1', 'colors' => '#xyz123,not_a_color' }
        );
        // Bad hex parses to null and falls through to default palette — should
        // still produce a real PNG, not throw.
        assertPngSignature(png, 'bar-bad-hex-fallback');
    }

    // ─── Empty / edge cases ─────────────────────────────────────────────────

    @IsTest
    static void emitEmpty_nullBuckets_producesPlaceholderPng() {
        Blob png = DocGenChartRasterizer.emit(null, new Map<String, String>{ 'style' => 'bar' });
        assertPngSignature(png, 'empty-null');
    }

    @IsTest
    static void emitEmpty_emptyList_producesPlaceholderPng() {
        Blob png = DocGenChartRasterizer.emit(
            new List<Map<String, Object>>(),
            new Map<String, String>{ 'style' => 'pie' }
        );
        assertPngSignature(png, 'empty-list');
    }

    @IsTest
    static void singleBucket_producesPng() {
        List<Map<String, Object>> single = new List<Map<String, Object>>{
            new Map<String, Object>{ 'key' => 'Only', 'key_label' => 'Only', 'count' => 5, 'percent' => 100 }
        };
        Blob png = DocGenChartRasterizer.emit(single, new Map<String, String>{ 'style' => 'line', 'scale' => '1' });
        assertPngSignature(png, 'line-single-bucket');
    }

    @IsTest
    static void zeroCountBuckets_producesPng() {
        List<Map<String, Object>> zeroes = new List<Map<String, Object>>{
            new Map<String, Object>{ 'key' => 'A', 'count' => 0, 'percent' => 0 },
            new Map<String, Object>{ 'key' => 'B', 'count' => 0, 'percent' => 0 }
        };
        Blob png = DocGenChartRasterizer.emit(zeroes, new Map<String, String>{ 'style' => 'bar', 'scale' => '1' });
        assertPngSignature(png, 'bar-zeroes');
    }

    @IsTest
    static void bucketWithKeyLabel_overridesKey() {
        List<Map<String, Object>> buckets = new List<Map<String, Object>>{
            new Map<String, Object>{
                'key' => 'RAW_VAL',
                'key_label' => 'Pretty Label',
                'count' => 10,
                'percent' => 100
            }
        };
        Blob png = DocGenChartRasterizer.emit(buckets, new Map<String, String>{ 'style' => 'bar', 'scale' => '1' });
        assertPngSignature(png, 'bar-key-label');
    }

    @IsTest
    static void emitWithMeta_bar_returnsCorrectHeightForBuckets() {
        // bar height auto-grows: legendH + buckets*(22+8) + 8 + 4 + ...
        // simpleBuckets has 3 buckets, no legend → 0 + 3*30 + 8 = 98 → with adjustments
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'bar' }
        );
        Integer h = (Integer) result.get('logicalHeight');
        System.assert(h > 80, 'bar height should grow with buckets: ' + h);
    }

    @IsTest
    static void emitWithMeta_pie_defaultDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'pie' }
        );
        System.assertEquals(360, (Integer) result.get('logicalWidth'));
        System.assertEquals(190, (Integer) result.get('logicalHeight'));
    }

    @IsTest
    static void emitWithMeta_donut_defaultDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'donut' }
        );
        System.assertEquals(360, (Integer) result.get('logicalWidth'));
    }

    @IsTest
    static void emitWithMeta_area_singleSeries_returnsCorrectDims() {
        Map<String, Object> result = DocGenChartRasterizer.emitWithMeta(
            simpleBuckets(),
            new Map<String, String>{ 'style' => 'area' }
        );
        System.assertEquals(500, (Integer) result.get('logicalWidth'));
        // No cross-tab → no legend → matches line single-series
        System.assertEquals(274, (Integer) result.get('logicalHeight'));
    }

    // ─── hexToRgb helper coverage ───────────────────────────────────────────

    @IsTest
    static void hexToRgb_validHex_returnsRgb() {
        List<Integer> rgb = DocGenChartRasterizer.hexToRgb('#3b82f6');
        System.assertEquals(3, rgb.size());
        System.assertEquals(59, rgb[0]);
        System.assertEquals(130, rgb[1]);
        System.assertEquals(246, rgb[2]);
    }

    @IsTest
    static void hexToRgb_bareWithoutHash_returnsRgb() {
        List<Integer> rgb = DocGenChartRasterizer.hexToRgb('ffffff');
        System.assertEquals(255, rgb[0]);
        System.assertEquals(255, rgb[1]);
        System.assertEquals(255, rgb[2]);
    }

    @IsTest
    static void hexToRgb_blank_returnsNull() {
        System.assertEquals(null, DocGenChartRasterizer.hexToRgb(''));
        System.assertEquals(null, DocGenChartRasterizer.hexToRgb(null));
    }

    @IsTest
    static void hexToRgb_wrongLength_returnsNull() {
        System.assertEquals(null, DocGenChartRasterizer.hexToRgb('#abc'));
        System.assertEquals(null, DocGenChartRasterizer.hexToRgb('#abcde'));
    }

    @IsTest
    static void hexToRgb_invalidChars_returnsNull() {
        System.assertEquals(null, DocGenChartRasterizer.hexToRgb('#zzzzzz'));
    }
}
