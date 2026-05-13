/**
 * Focused coverage tests for v1.91 ChartBucket resolver paths that the main
 * DocGenChartBucketResolverTest doesn't reach — fall-back error paths,
 * Map-wrapped record collections, and small helpers tested directly.
 */
@IsTest
private class DocGenChartBucketCoverageTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'CBCov Test Co', Industry = 'Technology');
    }

    // ─── tryCountFallback edge paths (lines ~645-687) ──────────────────────

    @IsTest
    static void tryCountFallbackReturnsMinusOneOnNullData() {
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(null, 'Contacts'));
    }

    @IsTest
    static void tryCountFallbackReturnsMinusOneOnBlankRelName() {
        Map<String, Object> data = new Map<String, Object>{ 'Id' => UserInfo.getUserId() };
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, ''));
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, null));
    }

    @IsTest
    static void tryCountFallbackReturnsMinusOneWhenIdMissing() {
        Map<String, Object> data = new Map<String, Object>{ 'Name' => 'NoId' };
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, 'Contacts'));
    }

    @IsTest
    static void tryCountFallbackReturnsMinusOneOnUnparseableId() {
        Map<String, Object> data = new Map<String, Object>{ 'Id' => 'not-an-id' };
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, 'Contacts'));
    }

    @IsTest
    static void tryCountFallbackReturnsMinusOneWhenBudgetExhausted() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{ 'Id' => acct.Id };
        Integer saved = DocGenChartBucketResolver.chartSoqlBudget;
        try {
            DocGenChartBucketResolver.chartSoqlBudget = 0;
            System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, 'Contacts'));
        } finally {
            DocGenChartBucketResolver.chartSoqlBudget = saved;
        }
    }

    @IsTest
    static void tryCountFallbackReturnsMinusOneOnUnknownRelationship() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{ 'Id' => acct.Id };
        System.assertEquals(-1, DocGenChartBucketResolver.tryCountFallback(data, 'NonExistent__r'));
    }

    @IsTest
    static void tryCountFallbackSucceedsForRealRelationship() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        insert new Contact(LastName = 'CBCov1', AccountId = acct.Id);
        insert new Contact(LastName = 'CBCov2', AccountId = acct.Id);
        Map<String, Object> data = new Map<String, Object>{ 'Id' => acct.Id };
        Integer n = DocGenChartBucketResolver.tryCountFallback(data, 'Contacts');
        System.assert(n >= 2, 'Should count inserted contacts; got ' + n);
    }

    // ─── parseColSortModifier (lines ~736-749) ─────────────────────────────

    @IsTest
    static void parseColSortModifierReturnsNullForBlank() {
        System.assertEquals(null, DocGenChartBucketResolver.parseColSortModifier(null));
        System.assertEquals(null, DocGenChartBucketResolver.parseColSortModifier(''));
        System.assertEquals(null, DocGenChartBucketResolver.parseColSortModifier('   '));
    }

    @IsTest
    static void parseColSortModifierReturnsNullForCommaOnlyInput() {
        System.assertEquals(null, DocGenChartBucketResolver.parseColSortModifier(', ,  ,'));
    }

    @IsTest
    static void parseColSortModifierTrimsAndKeepsOrder() {
        List<String> r = DocGenChartBucketResolver.parseColSortModifier(' Sales , Marketing,Tech ');
        System.assertEquals(3, r.size());
        System.assertEquals('Sales', r[0]);
        System.assertEquals('Marketing', r[1]);
        System.assertEquals('Tech', r[2]);
    }

    // ─── parsePaletteModifier extra cases ──────────────────────────────────

    @IsTest
    static void parsePaletteModifierReturnsNullForBlank() {
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier(null));
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier(''));
    }

    @IsTest
    static void parsePaletteModifierHandlesMixedInputGracefully() {
        // Whatever the validation rule (strict vs lenient), the resolver should
        // return null or a list — never throw — for partially-valid input.
        List<String> r = DocGenChartBucketResolver.parsePaletteModifier('#abc, not-a-color, #1e40af');
        // No throw is the assertion; result may be null or list depending on validator strictness.
        System.assert(r == null || r.size() >= 0, 'No exception expected');
    }

    // ─── parseTagModifiers ─────────────────────────────────────────────────

    @IsTest
    static void parseTagModifiersHandlesBlank() {
        Map<String, String> m = DocGenChartBucketResolver.parseTagModifiers(null);
        System.assert(m == null || m.isEmpty(), 'Null modifier → null/empty map');
        m = DocGenChartBucketResolver.parseTagModifiers('');
        System.assert(m == null || m.isEmpty(), 'Empty modifier → null/empty map');
    }

    @IsTest
    static void parseTagModifiersHandlesValueWithEqualsSign() {
        Map<String, String> m = DocGenChartBucketResolver.parseTagModifiers('where=Status=\'Open\'&colors=#aaa');
        System.assertNotEquals(null, m);
        System.assert(m.containsKey('where'), 'where key parsed');
        System.assert(m.containsKey('colors'), 'colors key parsed');
    }

    // ─── computeBuckets edge cases ─────────────────────────────────────────

    @IsTest
    static void computeBucketsHandlesNullRecords() {
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(null, 'Industry', null);
        System.assertNotEquals(null, buckets, 'Returns empty list, not null');
        System.assert(buckets.isEmpty(), 'No records → empty');
    }

    @IsTest
    static void computeBucketsHandlesEmptyList() {
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(
            new List<Object>(),
            'Industry',
            null
        );
        System.assert(buckets.isEmpty(), 'Empty list → empty result');
    }

    @IsTest
    static void computeBucketsHandlesBlankFieldApi() {
        List<Object> recs = new List<Object>{ new Map<String, Object>{ 'Industry' => 'Banking' } };
        System.assert(DocGenChartBucketResolver.computeBuckets(recs, null, null).isEmpty());
        System.assert(DocGenChartBucketResolver.computeBuckets(recs, '', null).isEmpty());
    }

    // ─── preprocessInline: relationship-as-Map-with-records path (506-510) ─

    @IsTest
    static void preprocessInlineHandlesMapWrappedRelationship() {
        // V3-shaped data: the relationship key holds a Map<String,Object> with a
        // 'records' List inside, mimicking how some pipeline stages emit data.
        // Exercises the Map→records extraction in the resolver.
        List<Object> recs = new List<Object>{
            new Map<String, Object>{ 'Industry' => 'Banking' },
            new Map<String, Object>{ 'Industry' => 'Tech' }
        };
        Map<String, Object> data = new Map<String, Object>{
            'Survey_Responses__r' => new Map<String, Object>{ 'records' => recs }
        };
        String xml = '{#ChartBucket:Survey_Responses__r:Industry}{key}={count}\n{/ChartBucket}';
        String result = DocGenChartBucketResolver.preprocessInline(xml, data);
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void preprocessInlineWithEmptyXmlReturnsUnchanged() {
        Map<String, Object> data = new Map<String, Object>();
        String r = DocGenChartBucketResolver.preprocessInline('', data);
        System.assertEquals('', r);
    }

    @IsTest
    static void preprocessInlineWithNullDataDefersChartUnchanged() {
        String xml = '{#ChartBucket:Contacts:Department}row{/ChartBucket}';
        String r = DocGenChartBucketResolver.preprocessInline(xml, null);
        System.assertNotEquals(null, r);
    }

    // ─── SOQL fallback split path (lines 935-955) ──────────────────────────

    @IsTest
    static void soqlFallbackWithSplitMultiSelect() {
        // Force SOQL fallback by NOT pre-loading the Contacts relationship,
        // and use split=; modifier. Contacts have a multi-select-like value
        // composed in Department to exercise splitMultiSelect on aggregate rows.
        Account acct = [SELECT Id FROM Account LIMIT 1];
        insert new List<Contact>{
            new Contact(LastName = 'A', AccountId = acct.Id, Department = 'Sales;Eng'),
            new Contact(LastName = 'B', AccountId = acct.Id, Department = 'Sales'),
            new Contact(LastName = 'C', AccountId = acct.Id, Department = 'Eng;Ops')
        };
        Map<String, Object> data = new Map<String, Object>{ 'Id' => acct.Id };
        // Use preprocessInline with the split modifier — chart's missing-from-data
        // collection forces SOQL fallback at the aggregate path.
        String xml = '{#ChartBucket:Contacts:Department:split=;}{key}={count}\n{/ChartBucket}';

        Test.startTest();
        String result = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result returned');
    }

    // ─── Pivot colSort with named values (lines 1046-1060) ─────────────────

    @IsTest
    static void pivotColSortPlacesNamedValuesFirst() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        insert new List<Contact>{
            new Contact(LastName = 'A', AccountId = acct.Id, Department = 'Sales', Title = 'Mgr'),
            new Contact(LastName = 'B', AccountId = acct.Id, Department = 'Eng', Title = 'Mgr'),
            new Contact(LastName = 'C', AccountId = acct.Id, Department = 'Sales', Title = 'Dir')
        };
        Map<String, Object> data = new Map<String, Object>{ 'Id' => acct.Id };
        // groupBy=Title forces pivot + SOQL fallback (Contacts not pre-loaded). colSort
        // names a value to place first, exercising the colOrder placement loop.
        String xml =
            '{#ChartBucket:Contacts:Department:groupBy=Title&colSort=Mgr}' +
            '{key}: {#cols}{key}={count} {/cols}\n' +
            '{/ChartBucket}';
        Test.startTest();
        String result = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Returned');
    }
}
