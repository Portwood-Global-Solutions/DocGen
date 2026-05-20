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
}
