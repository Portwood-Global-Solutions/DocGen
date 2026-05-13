@IsTest
private class DocGenChartBucketResolverTest {
    // -------------------------------------------------------------------------
    // computeBuckets — in-memory path
    // -------------------------------------------------------------------------

    @IsTest
    static void testBasicCountsDescendingOrder() {
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'Answer__c' => 'Excellent' },
            new Map<String, Object>{ 'Answer__c' => 'Good' },
            new Map<String, Object>{ 'Answer__c' => 'Excellent' },
            new Map<String, Object>{ 'Answer__c' => 'Excellent' },
            new Map<String, Object>{ 'Answer__c' => 'Fair' },
            new Map<String, Object>{ 'Answer__c' => 'Good' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'Answer__c', null);
        Test.stopTest();

        System.assertEquals(3, buckets.size(), '3 distinct values → 3 buckets');
        System.assertEquals('Excellent', buckets[0].get('key'), 'highest count first');
        System.assertEquals(3, buckets[0].get('count'), 'Excellent counted 3 times');
        System.assertEquals('Good', buckets[1].get('key'), '2nd by count');
        System.assertEquals('Fair', buckets[2].get('key'), '3rd by count');
        // Percent sum = 100 (3/6 + 2/6 + 1/6 = 50 + 33.3 + 16.7 = 100)
        Decimal p0 = (Decimal) buckets[0].get('percent');
        Decimal p1 = (Decimal) buckets[1].get('percent');
        Decimal p2 = (Decimal) buckets[2].get('percent');
        System.assertEquals(50.0, p0, '3 of 6 = 50.0');
        System.assertEquals(33.3, p1, '2 of 6 = 33.3');
        System.assertEquals(16.7, p2, '1 of 6 = 16.7');
        System.assertEquals(100.0, p0 + p1 + p2, 'percents sum to 100 within rounding');
        // Indices 1-based
        System.assertEquals(1, buckets[0].get('index'));
        System.assertEquals(2, buckets[1].get('index'));
        System.assertEquals(3, buckets[2].get('index'));
    }

    @IsTest
    static void testNullAndBlankCollapseToNotSpecified() {
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'Answer__c' => 'Yes' },
            new Map<String, Object>{ 'Answer__c' => null },
            new Map<String, Object>{ 'Answer__c' => '' },
            new Map<String, Object>{ 'Answer__c' => '   ' }, // whitespace-only
            new Map<String, Object>{ 'Answer__c' => 'Yes' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'Answer__c', null);
        Test.stopTest();

        System.assertEquals(2, buckets.size(), 'Yes + Not-Specified bucket');
        // Sorted desc by count: tie at 3 vs 2 — depends; here 3 vs 2 means Not Specified leads
        Map<String, Object> top = buckets[0];
        Map<String, Object> bot = buckets[1];
        // Not Specified bucket has count 3 (null + '' + '   ')
        if (top.get('count') == 3) {
            System.assertEquals('', top.get('key'), 'null bucket key is empty string');
            System.assertEquals('Not Specified', top.get('key_label'), 'null label is "Not Specified"');
            System.assertEquals('Yes', bot.get('key'));
        } else {
            System.assert(false, 'Expected null bucket to have count 3');
        }
    }

    @IsTest
    static void testSingleBucketIsFullPercent() {
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'F__c', null);
        Test.stopTest();

        System.assertEquals(1, buckets.size());
        System.assertEquals(3, buckets[0].get('count'));
        System.assertEquals(100.0, (Decimal) buckets[0].get('percent'), 'single bucket = 100%');
        System.assertEquals(100, buckets[0].get('percent_int'));
        System.assertEquals(100.0, (Decimal) buckets[0].get('max_percent'), 'single bucket max_percent = 100');
    }

    @IsTest
    static void testEmptyRecordsReturnsEmptyList() {
        Test.startTest();
        List<Map<String, Object>> empty = DocGenChartBucketResolver.computeBuckets(new List<Object>(), 'F__c', null);
        List<Map<String, Object>> nullCase = DocGenChartBucketResolver.computeBuckets(null, 'F__c', null);
        List<Map<String, Object>> blankField = DocGenChartBucketResolver.computeBuckets(
            new List<Object>{ new Map<String, Object>{ 'F__c' => 'X' } },
            '',
            null
        );
        Test.stopTest();

        System.assertEquals(0, empty.size());
        System.assertEquals(0, nullCase.size());
        System.assertEquals(0, blankField.size());
    }

    @IsTest
    static void testMaxPercentNormalization() {
        // 8 + 4 + 2 + 1 = 15 records. Largest bucket = 8 → max_percent = 100.0.
        // Bucket 4: 4/8 = 50%; bucket 2: 25%; bucket 1: 12.5%.
        List<Object> records = new List<Object>();
        for (Integer i = 0; i < 8; i++) {
            records.add(new Map<String, Object>{ 'F__c' => 'A' });
        }
        for (Integer i = 0; i < 4; i++) {
            records.add(new Map<String, Object>{ 'F__c' => 'B' });
        }
        for (Integer i = 0; i < 2; i++) {
            records.add(new Map<String, Object>{ 'F__c' => 'C' });
        }
        records.add(new Map<String, Object>{ 'F__c' => 'D' });

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'F__c', null);
        Test.stopTest();

        System.assertEquals(4, buckets.size());
        System.assertEquals(100.0, (Decimal) buckets[0].get('max_percent'), 'largest bucket normalizes to 100');
        System.assertEquals(50.0, (Decimal) buckets[1].get('max_percent'), '4 / 8 = 50');
        System.assertEquals(25.0, (Decimal) buckets[2].get('max_percent'), '2 / 8 = 25');
        System.assertEquals(12.5, (Decimal) buckets[3].get('max_percent'), '1 / 8 = 12.5');
    }

    @IsTest
    static void testColorCyclesThroughPalette() {
        // 10 distinct buckets — palette has 8, so buckets 9 and 10 wrap around.
        List<Object> records = new List<Object>();
        for (Integer i = 0; i < 10; i++) {
            // counts 10, 9, 8, ... so ordering is deterministic
            for (Integer j = 0; j <= 10 - i; j++) {
                records.add(new Map<String, Object>{ 'F__c' => 'K' + i });
            }
        }

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'F__c', null);
        Test.stopTest();

        System.assertEquals(10, buckets.size());
        // First color = first palette entry
        System.assertEquals('#3b82f6', buckets[0].get('color'));
        // 9th bucket (index 9 → palette[(9-1) mod 8] = palette[0]) wraps to first color
        System.assertEquals('#3b82f6', buckets[8].get('color'), '9th bucket wraps palette');
        System.assertEquals('#10b981', buckets[9].get('color'), '10th wraps to palette[1]');
        // Each adjacent pair within first 8 differs
        System.assertNotEquals(buckets[0].get('color'), buckets[1].get('color'));
    }

    @IsTest
    static void testCaseInsensitiveFieldLookupOnMaps() {
        // Maps may come from JSON deserialization with mixed case keys.
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'answer__c' => 'A' }, // all lowercase
            new Map<String, Object>{ 'Answer__c' => 'A' }, // proper case
            new Map<String, Object>{ 'ANSWER__C' => 'B' } // uppercase
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'Answer__c', null);
        Test.stopTest();

        System.assertEquals(2, buckets.size(), 'Case-insensitive lookup finds all 3 values');
        System.assertEquals(2, buckets[0].get('count'), 'A counted across both case-variant keys');
    }

    @IsTest
    static void testCaseInsensitiveValueGrouping() {
        // "Yes" and "yes" should bucket together.
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'Yes' },
            new Map<String, Object>{ 'F__c' => 'yes' },
            new Map<String, Object>{ 'F__c' => 'YES' },
            new Map<String, Object>{ 'F__c' => 'No' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'F__c', null);
        Test.stopTest();

        System.assertEquals(2, buckets.size(), 'Yes/yes/YES collapse together');
        System.assertEquals(3, buckets[0].get('count'));
        System.assertEquals(1, buckets[1].get('count'));
    }

    @IsTest
    static void testPicklistLabelResolutionAgainstAccountIndustry() {
        // Use Account.Industry (a universally-available picklist).
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'Industry' => 'Technology' },
            new Map<String, Object>{ 'Industry' => 'Technology' },
            new Map<String, Object>{ 'Industry' => 'Banking' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(
            records,
            'Industry',
            Account.SObjectType
        );
        Test.stopTest();

        System.assertEquals(2, buckets.size());
        // For standard picklists, API value and label are typically identical for
        // these entries — but the key_label should at least resolve (non-null and
        // matches one of the picklist entries).
        for (Map<String, Object> b : buckets) {
            System.assertNotEquals(null, b.get('key_label'), 'label resolved');
            System.assert(((String) b.get('key_label')).length() > 0, 'label not empty');
        }
    }

    @IsTest
    static void testPicklistLabelFallbackForUnknownField() {
        // Field that doesn't exist on Account — label falls back to raw key.
        List<Object> records = new List<Object>{ new Map<String, Object>{ 'Bogus__c' => 'XYZ' } };
        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(
            records,
            'Bogus__c',
            Account.SObjectType
        );
        Test.stopTest();
        System.assertEquals(1, buckets.size());
        System.assertEquals('XYZ', buckets[0].get('key_label'), 'falls back to raw value when picklist lookup fails');
    }

    @IsTest
    static void testSObjectRecordsAreSupported() {
        // Insert two Accounts with different Industry, ensure SObject path works.
        Account a1 = new Account(Name = 'Acme', Industry = 'Technology');
        Account a2 = new Account(Name = 'Wile', Industry = 'Technology');
        Account a3 = new Account(Name = 'Pyx', Industry = 'Banking');
        insert new List<Account>{ a1, a2, a3 };
        List<SObject> accts = [SELECT Id, Industry FROM Account WHERE Id IN (:a1.Id, :a2.Id, :a3.Id)];

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(
            (List<Object>) accts,
            'Industry',
            Account.SObjectType
        );
        Test.stopTest();

        System.assertEquals(2, buckets.size());
        System.assertEquals(2, buckets[0].get('count'), 'Technology counted twice');
    }

    // -------------------------------------------------------------------------
    // preprocessInline — XML rewriting
    // -------------------------------------------------------------------------

    @IsTest
    static void testPreprocessRewritesTagAndInjectsKey() {
        String xml = '<tr>{#ChartBucket:Responses__r:Answer__c}<td>{key} {count}</td>{/ChartBucket}</tr>';
        Map<String, Object> data = new Map<String, Object>{
            'Responses__r' => new List<Object>{
                new Map<String, Object>{ 'Answer__c' => 'Yes' },
                new Map<String, Object>{ 'Answer__c' => 'Yes' },
                new Map<String, Object>{ 'Answer__c' => 'No' }
            }
        };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#_cb_0}'), 'synthetic opener appears');
        System.assert(out.contains('{/_cb_0}'), 'synthetic closer appears');
        System.assert(!out.contains('{#ChartBucket:'), 'original opener replaced');
        System.assert(!out.contains('{/ChartBucket}'), 'original closer replaced');
        System.assert(data.containsKey('_cb_0'), 'bucket list injected under _cb_0');
        // Stored as List<Object> (not List<Map<...>>) — required so processXml's
        // `val instanceof List<Object>` check triggers the loop branch.
        Object stored = data.get('_cb_0');
        System.assert(stored instanceof List<Object>, 'must be List<Object> for processXml');
        List<Object> buckets = (List<Object>) stored;
        System.assertEquals(2, buckets.size());
    }

    @IsTest
    static void testPreprocessTwoChartsGetDistinctKeys() {
        String xml = '<div>{#ChartBucket:A__r:F__c}x{/ChartBucket}' + '{#ChartBucket:B__r:G__c}y{/ChartBucket}</div>';
        Map<String, Object> data = new Map<String, Object>{
            'A__r' => new List<Object>{ new Map<String, Object>{ 'F__c' => 'a' } },
            'B__r' => new List<Object>{ new Map<String, Object>{ 'G__c' => 'b' } }
        };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#_cb_0}'), 'first chart → _cb_0');
        System.assert(out.contains('{#_cb_1}'), 'second chart → _cb_1');
        System.assert(data.containsKey('_cb_0'));
        System.assert(data.containsKey('_cb_1'));
    }

    @IsTest
    static void testPreprocessRespectsExistingSynthKeys() {
        // Counter must start past pre-existing _cb_N keys to avoid collision.
        String xml = '{#ChartBucket:R__r:F__c}body{/ChartBucket}';
        Map<String, Object> data = new Map<String, Object>{
            '_cb_0' => new List<Object>(),
            '_cb_1' => new List<Object>(),
            'R__r' => new List<Object>{ new Map<String, Object>{ 'F__c' => 'x' } }
        };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#_cb_2}'), 'starts at _cb_2 to skip existing keys');
    }

    @IsTest
    static void testPreprocessDefersChartInsideOuterLoop() {
        // Chart nested inside another {#…}{/…} section must NOT be expanded at the
        // outer level — let the inner processXml recursion handle it.
        String xml = '{#Questions__r}<tr>{#ChartBucket:Responses__r:F__c}<td>{key}</td>{/ChartBucket}</tr>{/Questions__r}';
        Map<String, Object> data = new Map<String, Object>{ 'Questions__r' => new List<Object>() };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#ChartBucket:Responses__r:F__c}'), 'chart tag preserved for inner recursion');
        System.assert(out.contains('{/ChartBucket}'), 'closer preserved');
        // No synthetic key should be injected for the deferred chart.
        System.assert(!data.containsKey('_cb_0'), 'no premature injection');
    }

    @IsTest
    static void testPreprocessMalformedTagPassthrough() {
        // Missing field segment — should pass through without rewriting.
        String xml = '{#ChartBucket:OnlyRel}body{/ChartBucket}';
        Map<String, Object> data = new Map<String, Object>();

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#ChartBucket:OnlyRel}'), 'malformed opener left alone');
        System.assert(!data.containsKey('_cb_0'), 'no injection on malformed');
    }

    @IsTest
    static void testPreprocessUnmatchedCloserPassthrough() {
        // Opener with no matching closer — leave it for the main scanner to surface.
        String xml = '{#ChartBucket:R__r:F__c}body without closer';
        Map<String, Object> data = new Map<String, Object>{
            'R__r' => new List<Object>{ new Map<String, Object>{ 'F__c' => 'x' } }
        };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#ChartBucket:R__r:F__c}'), 'unmatched opener preserved');
        System.assert(!data.containsKey('_cb_0'), 'no synth key injected');
    }

    @IsTest
    static void testPreprocessUnknownModifierIsTolerated() {
        // Unknown modifier keys (no `colors=`) should be ignored without breaking
        // the chart — the default palette applies and the chart renders normally.
        String xml = '{#ChartBucket:R__r:F__c:histogram=5}body{/ChartBucket}';
        Map<String, Object> data = new Map<String, Object>{
            'R__r' => new List<Object>{ new Map<String, Object>{ 'F__c' => 'a' } }
        };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#_cb_0}'), 'unknown modifier still allows chart rewrite');
        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(1, buckets.size(), 'chart still computes despite unknown modifier');
    }

    @IsTest
    static void testPreprocessEmptyRelationshipInjectsEmptyList() {
        // Relationship missing on data → empty bucket list, body renders zero times.
        String xml = '{#ChartBucket:R__r:F__c}body{/ChartBucket}';
        Map<String, Object> data = new Map<String, Object>();

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assert(out.contains('{#_cb_0}'), 'synth opener appears');
        System.assert(data.get('_cb_0') instanceof List<Object>, 'stored as List<Object>');
        System.assertEquals(0, ((List<Object>) data.get('_cb_0')).size(), 'empty bucket list');
    }

    @IsTest
    static void testPreprocessNoChartTagsReturnsUnchanged() {
        String xml = '<tr><td>{Name}</td><td>{#Items}{Foo}{/Items}</td></tr>';
        Map<String, Object> data = new Map<String, Object>{ 'Name' => 'X' };

        Test.startTest();
        String out = DocGenChartBucketResolver.preprocessInline(xml, data);
        Test.stopTest();

        System.assertEquals(xml, out, 'no-chart input returned unchanged');
        System.assert(!data.containsKey('_cb_0'), 'no map mutation when no charts present');
    }

    // -------------------------------------------------------------------------
    // computeBucketsFromAggregate — giant-query path
    // -------------------------------------------------------------------------

    @IsTest
    static void testComputeBucketsFromAggregateHappyPath() {
        // Seed Accounts with distinct industries, GROUP BY, then verify bucket shape.
        insert new List<Account>{
            new Account(Name = 'A1', Industry = 'Technology'),
            new Account(Name = 'A2', Industry = 'Technology'),
            new Account(Name = 'A3', Industry = 'Technology'),
            new Account(Name = 'A4', Industry = 'Banking'),
            new Account(Name = 'A5', Industry = 'Banking'),
            new Account(Name = 'A6', Industry = 'Energy')
        };

        Test.startTest();
        List<AggregateResult> ar = [
            SELECT Industry, COUNT(Id) cnt
            FROM Account
            WHERE Industry IN ('Technology', 'Banking', 'Energy')
            GROUP BY Industry
            ORDER BY COUNT(Id) DESC
        ];
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBucketsFromAggregate(
            ar,
            'Industry',
            Account.SObjectType
        );
        Test.stopTest();

        System.assertEquals(3, buckets.size());
        System.assertEquals(3, buckets[0].get('count'), 'top bucket has 3');
        System.assertEquals(50.0, (Decimal) buckets[0].get('percent'), '3 of 6 = 50');
        System.assertEquals(100.0, (Decimal) buckets[0].get('max_percent'), 'largest = 100');
        System.assertNotEquals(null, buckets[0].get('color'));
        System.assertEquals(1, buckets[0].get('index'));
    }

    @IsTest
    static void testComputeBucketsFromAggregateEmptyAndNull() {
        Test.startTest();
        List<Map<String, Object>> empty = DocGenChartBucketResolver.computeBucketsFromAggregate(
            new List<AggregateResult>(),
            'Industry',
            Account.SObjectType
        );
        List<Map<String, Object>> nullCase = DocGenChartBucketResolver.computeBucketsFromAggregate(
            null,
            'Industry',
            Account.SObjectType
        );
        Test.stopTest();

        System.assertEquals(0, empty.size());
        System.assertEquals(0, nullCase.size());
    }

    // -------------------------------------------------------------------------
    // SOQL fallback — Path 1b, the 30K-scale path
    // -------------------------------------------------------------------------

    @IsTest
    static void testSoqlFallbackAgainstAccountIndustry() {
        // Insert Accounts with known industry distribution; the chart's
        // relationship isn't in the data map, so preprocessInline must fall
        // back to a GROUP BY aggregate against Account.Industry.
        // Note: Account has no "Survey_Responses__r"-style child relationship
        // we control, so we use User.OwnerId → Account as a proxy: chart against
        // a parent record's children via a real relationship. Simpler: use
        // an Account as parent, its Contacts as the child relationship.
        Account a = new Account(Name = 'Fallback Parent');
        insert a;
        insert new List<Contact>{
            new Contact(LastName = 'C1', AccountId = a.Id, Department = 'Sales'),
            new Contact(LastName = 'C2', AccountId = a.Id, Department = 'Sales'),
            new Contact(LastName = 'C3', AccountId = a.Id, Department = 'Sales'),
            new Contact(LastName = 'C4', AccountId = a.Id, Department = 'Engineering'),
            new Contact(LastName = 'C5', AccountId = a.Id, Department = 'Engineering')
        };

        // Data map carries the parent Id but NOT the Contacts relationship.
        // This simulates a template where Query_Config__c omits Contacts to
        // avoid loading thousands of rows.
        Map<String, Object> data = new Map<String, Object>{ 'Id' => a.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50; // reset for test isolation
        String out = DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department}[{key_label}={count}]{/ChartBucket}',
            data
        );
        Test.stopTest();

        // Bucket data should appear under a synthetic key
        System.assert(out.contains('{#_cb_0}'), 'synth opener appears');
        Object stored = data.get('_cb_0');
        System.assert(stored instanceof List<Object>);
        List<Object> buckets = (List<Object>) stored;
        System.assertEquals(2, buckets.size(), 'Sales + Engineering buckets');
        Map<String, Object> top = (Map<String, Object>) buckets[0];
        System.assertEquals('Sales', top.get('key'), 'Sales leads by count');
        System.assertEquals(3, top.get('count'));
        System.assertEquals(60.0, (Decimal) top.get('percent'));
    }

    @IsTest
    static void testSoqlFallbackMissingIdReturnsEmpty() {
        // No Id on the data map → fallback can't construct the SOQL, returns
        // empty bucket list (chart body renders 0 times; {:else} fires).
        Map<String, Object> data = new Map<String, Object>(); // no Id

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        String out = DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department}body{:else}NONE{/ChartBucket}',
            data
        );
        Test.stopTest();

        System.assert(out.contains('{#_cb_0}'), 'synth opener still injected for {:else} support');
        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(0, buckets.size(), 'empty bucket list when no Id available');
    }

    @IsTest
    static void testSoqlFallbackUnknownRelationshipReturnsEmpty() {
        Account a = new Account(Name = 'Unknown Rel Parent');
        insert a;
        Map<String, Object> data = new Map<String, Object>{ 'Id' => a.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        String out = DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:NotAReal__r:Field__c}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(0, buckets.size(), 'unknown relationship → empty buckets');
    }

    @IsTest
    static void testSoqlBudgetExhaustionShowsSentinel() {
        Account a = new Account(Name = 'Budget Parent');
        insert a;
        insert new Contact(LastName = 'C1', AccountId = a.Id, Department = 'X');

        Map<String, Object> data = new Map<String, Object>{ 'Id' => a.Id };

        Test.startTest();
        // Drain budget to 0 — next SOQL fallback should return the sentinel
        DocGenChartBucketResolver.chartSoqlBudget = 0;
        String out = DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department}[{key_label}]{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(1, buckets.size(), 'sentinel bucket present');
        Map<String, Object> sentinel = (Map<String, Object>) buckets[0];
        String label = (String) sentinel.get('key_label');
        System.assert(label.contains('Chart limit reached'), 'sentinel notice text: ' + label);
        System.assertEquals(0, sentinel.get('count'));
    }

    @IsTest
    static void testSoqlBudgetDecrementsAcrossCharts() {
        // Two charts on one preprocess call should each consume a budget unit.
        Account a = new Account(Name = 'Decrement Parent');
        insert a;
        insert new List<Contact>{
            new Contact(LastName = 'C1', AccountId = a.Id, Department = 'A'),
            new Contact(LastName = 'C2', AccountId = a.Id, Department = 'B')
        };
        Map<String, Object> data = new Map<String, Object>{ 'Id' => a.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        Integer before = DocGenChartBucketResolver.chartSoqlBudget;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department}x{/ChartBucket}' + '{#ChartBucket:Contacts:Department}y{/ChartBucket}',
            data
        );
        Integer after = DocGenChartBucketResolver.chartSoqlBudget;
        Test.stopTest();

        System.assertEquals(before - 2, after, 'budget decremented twice for two charts');
    }

    // -------------------------------------------------------------------------
    // Palette override — `colors=...` modifier
    // -------------------------------------------------------------------------

    @IsTest
    static void testPaletteOverrideAppliesCustomColors() {
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'B' }
        };
        Map<String, Object> data = new Map<String, Object>{ 'R__r' => records };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:R__r:F__c:colors=#000000,#ffffff}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(2, buckets.size());
        System.assertEquals(
            '#000000',
            ((Map<String, Object>) buckets[0]).get('color'),
            'first bucket uses first custom color'
        );
        System.assertEquals(
            '#ffffff',
            ((Map<String, Object>) buckets[1]).get('color'),
            'second bucket uses second custom color'
        );
    }

    @IsTest
    static void testPaletteOverrideCyclesWhenMoreBucketsThanColors() {
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'B' },
            new Map<String, Object>{ 'F__c' => 'C' }
        };
        Map<String, Object> data = new Map<String, Object>{ 'R__r' => records };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline('{#ChartBucket:R__r:F__c:colors=#111,#222}body{/ChartBucket}', data);
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(3, buckets.size());
        System.assertEquals('#111', ((Map<String, Object>) buckets[0]).get('color'));
        System.assertEquals('#222', ((Map<String, Object>) buckets[1]).get('color'));
        System.assertEquals('#111', ((Map<String, Object>) buckets[2]).get('color'), 'cycles back to first');
    }

    @IsTest
    static void testInvalidPaletteFallsBackToDefault() {
        // Garbage `colors=` → silently use default palette, never fail the render.
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'B' }
        };
        Map<String, Object> data = new Map<String, Object>{ 'R__r' => records };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:R__r:F__c:colors=not-a-hex,also-bad}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals('#3b82f6', ((Map<String, Object>) buckets[0]).get('color'), 'first default palette color');
    }

    @IsTest
    static void testParsePaletteModifierDirectly() {
        // Direct coverage of the parser since it's a public helper for the
        // giant-query path. Tests the edge cases the inline tests don't reach.
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier(null), 'null input');
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier(''), 'empty input');
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier('sort=asc'), 'no colors= present');
        System.assertEquals(null, DocGenChartBucketResolver.parsePaletteModifier('colors='), 'colors with empty value');
        System.assertEquals(new List<String>{ '#abc' }, DocGenChartBucketResolver.parsePaletteModifier('colors=#abc'));
        System.assertEquals(
            new List<String>{ '#aabbcc', '#112233' },
            DocGenChartBucketResolver.parsePaletteModifier('colors=#aabbcc,#112233')
        );
        // Whitespace tolerance
        System.assertEquals(
            new List<String>{ '#aaa', '#bbb' },
            DocGenChartBucketResolver.parsePaletteModifier('colors= #aaa , #bbb ')
        );
        // Future modifiers don't break colors=
        System.assertEquals(
            new List<String>{ '#aaa' },
            DocGenChartBucketResolver.parsePaletteModifier('colors=#aaa&sort=asc')
        );
    }

    // -------------------------------------------------------------------------
    // where= filter modifier
    // -------------------------------------------------------------------------

    @IsTest
    static void testWhereFilterNarrowsAggregate() {
        // Insert Accounts with mixed industries; chart filtered to Industry='Technology'.
        Account parent = new Account(Name = 'Where Filter Parent');
        insert parent;
        insert new List<Contact>{
            new Contact(LastName = 'C1', AccountId = parent.Id, Department = 'Sales'),
            new Contact(LastName = 'C2', AccountId = parent.Id, Department = 'Sales'),
            new Contact(LastName = 'C3', AccountId = parent.Id, Department = 'Engineering'),
            new Contact(LastName = 'C4', AccountId = parent.Id, Department = 'Engineering'),
            new Contact(LastName = 'C5', AccountId = parent.Id, Department = 'Marketing')
        };
        Map<String, Object> data = new Map<String, Object>{ 'Id' => parent.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department:where=Department=\'Sales\'}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(1, buckets.size(), 'where= filtered out Engineering/Marketing');
        Map<String, Object> b = (Map<String, Object>) buckets[0];
        System.assertEquals('Sales', b.get('key'));
        System.assertEquals(2, b.get('count'));
    }

    @IsTest
    static void testWhereFilterRejectsInjection() {
        // SQL injection attempts should fail sanitization → empty buckets.
        Account parent = new Account(Name = 'Injection Parent');
        insert parent;
        insert new Contact(LastName = 'C1', AccountId = parent.Id, Department = 'X');
        Map<String, Object> data = new Map<String, Object>{ 'Id' => parent.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department:where=Department=\'X\';DELETE FROM Account}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(0, buckets.size(), 'injection rejected → empty buckets');
    }

    // -------------------------------------------------------------------------
    // split= multi-select modifier
    // -------------------------------------------------------------------------

    @IsTest
    static void testSplitMultiSelectInMemory() {
        // Each respondent picks one or more values from a delimited multi-select.
        // Math: 3 respondents total, A picked by 2 (60% of resp), B by 2, C by 1.
        // Sum of percents > 100% is expected for multi-select.
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A;B' }, // picks A and B
            new Map<String, Object>{ 'F__c' => 'A;C' }, // picks A and C
            new Map<String, Object>{ 'F__c' => 'B' } // picks only B
        };
        Map<String, Object> data = new Map<String, Object>{ 'R__r' => records };

        Test.startTest();
        DocGenChartBucketResolver.preprocessInline('{#ChartBucket:R__r:F__c:split=;}body{/ChartBucket}', data);
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(3, buckets.size(), 'A + B + C distinct pieces');
        Map<String, Object> countByKey = new Map<String, Object>();
        for (Object o : buckets) {
            Map<String, Object> m = (Map<String, Object>) o;
            countByKey.put((String) m.get('key'), m.get('count'));
        }
        System.assertEquals(2, countByKey.get('A'), 'A picked by 2 respondents');
        System.assertEquals(2, countByKey.get('B'), 'B picked by 2 respondents');
        System.assertEquals(1, countByKey.get('C'), 'C picked by 1 respondent');
    }

    @IsTest
    static void testSplitDedupesWithinCombo() {
        // "A;A;B" should count "A" once for this respondent (Set dedup).
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A;A;B' },
            new Map<String, Object>{ 'F__c' => 'A' }
        };
        Map<String, Object> data = new Map<String, Object>{ 'R__r' => records };

        Test.startTest();
        DocGenChartBucketResolver.preprocessInline('{#ChartBucket:R__r:F__c:split=;}body{/ChartBucket}', data);
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        for (Object o : buckets) {
            Map<String, Object> m = (Map<String, Object>) o;
            if (m.get('key') == 'A') {
                System.assertEquals(2, m.get('count'), 'A counted twice (once per respondent), NOT 3 times');
            }
        }
    }

    @IsTest
    static void testSplitMultiSelectHelperDirectly() {
        // Direct coverage of splitMultiSelect for various inputs.
        List<String> r1 = DocGenChartBucketResolver.splitMultiSelect('A;B;C', ';');
        System.assertEquals(new List<String>{ 'A', 'B', 'C' }, r1);
        List<String> r2 = DocGenChartBucketResolver.splitMultiSelect('Single', ';');
        System.assertEquals(new List<String>{ 'Single' }, r2);
        List<String> r3 = DocGenChartBucketResolver.splitMultiSelect(null, ';');
        System.assertEquals(1, r3.size(), 'null → 1-element sentinel list');
        List<String> r4 = DocGenChartBucketResolver.splitMultiSelect('', ';');
        System.assertEquals(1, r4.size(), 'blank → 1-element sentinel list');
        // Whitespace trim
        List<String> r5 = DocGenChartBucketResolver.splitMultiSelect(' A ; B ', ';');
        System.assertEquals(new List<String>{ 'A', 'B' }, r5);
        // Delim that's a regex metachar — \Q\E protects it
        List<String> r6 = DocGenChartBucketResolver.splitMultiSelect('A|B|C', '|');
        System.assertEquals(new List<String>{ 'A', 'B', 'C' }, r6);
    }

    // -------------------------------------------------------------------------
    // groupBy= pivot modifier
    // -------------------------------------------------------------------------

    @IsTest
    static void testPivotExposesColsAndTotal() {
        // Cross-tab: rows by Department, cols by LeadSource.
        // 8 Sales/Web + 4 Sales/Phone + 4 Engineering/Web + 4 Marketing/Phone = 20 total
        Account parent = new Account(Name = 'Pivot Parent');
        insert parent;
        List<Contact> cs = new List<Contact>();
        for (Integer i = 0; i < 8; i++) {
            cs.add(new Contact(LastName = 'SW' + i, AccountId = parent.Id, Department = 'Sales', LeadSource = 'Web'));
        }
        for (Integer i = 0; i < 4; i++) {
            cs.add(new Contact(LastName = 'SP' + i, AccountId = parent.Id, Department = 'Sales', LeadSource = 'Phone'));
        }
        for (Integer i = 0; i < 4; i++) {
            cs.add(
                new Contact(LastName = 'EW' + i, AccountId = parent.Id, Department = 'Engineering', LeadSource = 'Web')
            );
        }
        for (Integer i = 0; i < 4; i++) {
            cs.add(
                new Contact(LastName = 'MP' + i, AccountId = parent.Id, Department = 'Marketing', LeadSource = 'Phone')
            );
        }
        insert cs;
        Map<String, Object> data = new Map<String, Object>{ 'Id' => parent.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department:groupBy=LeadSource}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(3, buckets.size(), 'Sales/Engineering/Marketing rows');
        // Top row should be Sales (highest count, 12)
        Map<String, Object> top = (Map<String, Object>) buckets[0];
        System.assertEquals('Sales', top.get('key'));
        System.assertEquals(12, top.get('count'), 'Sales row total = 8+4');
        System.assertEquals(60.0, (Decimal) top.get('total_percent'), '12 of 20 = 60%');
        // Sales has cols [Phone, Web, Total] (alpha sorted, Total appended)
        List<Object> cols = (List<Object>) top.get('cols');
        System.assertEquals(3, cols.size(), 'Phone + Web + Total');
        Map<String, Object> phone = (Map<String, Object>) cols[0];
        Map<String, Object> web = (Map<String, Object>) cols[1];
        Map<String, Object> tot = (Map<String, Object>) cols[2];
        System.assertEquals('Phone', phone.get('key'));
        System.assertEquals(4, phone.get('count'));
        System.assertEquals('Web', web.get('key'));
        System.assertEquals(8, web.get('count'));
        System.assertEquals('Total', tot.get('key'));
        System.assertEquals(12, tot.get('count'));
        // Phone col total = 8 (4 Sales + 4 Marketing); Sales/Phone = 4/8 = 50%
        System.assertEquals(50.0, (Decimal) phone.get('percent'), 'Sales/Phone is 50% of Phone col');
        // Web col total = 12 (8 Sales + 4 Engineering); Sales/Web = 8/12 = 66.7%
        System.assertEquals(66.7, (Decimal) web.get('percent'), 'Sales/Web is 66.7% of Web col');
        // Total col percent = 12/20 = 60%
        System.assertEquals(60.0, (Decimal) tot.get('percent'));
    }

    @IsTest
    static void testPivotPlusSplit() {
        // Pivot + multi-select combined (the commute "Reasons × Location" shape).
        // Two respondents at Marina: one picked "A;B", one picked "A".
        // Pivot: rows by F__c (split), cols by Loc__c.
        // Expected at Marina col: A = 2 picks, B = 1 pick.
        Account parent = new Account(Name = 'Pivot Plus Split Parent');
        insert parent;
        // Use AccountSource as a stand-in for Location, AccountNumber as combo field
        insert new List<Contact>{
            new Contact(LastName = 'R1', AccountId = parent.Id, Department = 'A;B', LeadSource = 'Marina'),
            new Contact(LastName = 'R2', AccountId = parent.Id, Department = 'A', LeadSource = 'Marina'),
            new Contact(LastName = 'R3', AccountId = parent.Id, Department = 'A;C', LeadSource = 'Bayshore')
        };
        Map<String, Object> data = new Map<String, Object>{ 'Id' => parent.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department:groupBy=LeadSource&split=;}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        // Three distinct row values after split: A, B, C
        System.assertEquals(3, buckets.size());
        // Find row "A" — should have count=3 (in all three respondents)
        Map<String, Object> a = null;
        for (Object o : buckets) {
            Map<String, Object> m = (Map<String, Object>) o;
            if ((String) m.get('key') == 'A') {
                a = m;
                break;
            }
        }
        System.assertNotEquals(null, a, 'A row exists');
        System.assertEquals(3, a.get('count'), 'A row total = 3');
        // A's Marina cell = 2 (R1+R2), Bayshore cell = 1 (R3)
        List<Object> aCols = (List<Object>) a.get('cols');
        Map<String, Object> aBayshore = (Map<String, Object>) aCols[0]; // alphabetical: Bayshore < Marina
        Map<String, Object> aMarina = (Map<String, Object>) aCols[1];
        System.assertEquals('Bayshore', aBayshore.get('key'));
        System.assertEquals(1, aBayshore.get('count'));
        System.assertEquals('Marina', aMarina.get('key'));
        System.assertEquals(2, aMarina.get('count'));
    }

    @IsTest
    static void testPivotUnknownGroupByFieldReturnsEmpty() {
        Account parent = new Account(Name = 'Bad Pivot Parent');
        insert parent;
        insert new Contact(LastName = 'C', AccountId = parent.Id, Department = 'X');
        Map<String, Object> data = new Map<String, Object>{ 'Id' => parent.Id };

        Test.startTest();
        DocGenChartBucketResolver.chartSoqlBudget = 50;
        DocGenChartBucketResolver.preprocessInline(
            '{#ChartBucket:Contacts:Department:groupBy=NotARealField}body{/ChartBucket}',
            data
        );
        Test.stopTest();

        List<Object> buckets = (List<Object>) data.get('_cb_0');
        System.assertEquals(0, buckets.size(), 'invalid groupBy → empty buckets');
    }

    @IsTest
    static void testParseTagModifiersAllKeys() {
        Map<String, String> m1 = DocGenChartBucketResolver.parseTagModifiers(
            'colors=#a&where=X=\'1\'&split=;&groupBy=F'
        );
        System.assertEquals('#a', m1.get('colors'));
        System.assertEquals('X=\'1\'', m1.get('where'));
        System.assertEquals(';', m1.get('split'));
        System.assertEquals('F', m1.get('groupby'), 'keys lower-cased');
        Map<String, String> empty = DocGenChartBucketResolver.parseTagModifiers(null);
        System.assertEquals(0, empty.size());
        // Tolerates malformed input
        Map<String, String> malformed = DocGenChartBucketResolver.parseTagModifiers('no-equals&another=valid');
        System.assertEquals(1, malformed.size(), 'only the well-formed pair is kept');
        System.assertEquals('valid', malformed.get('another'));
    }

    @IsTest
    static void testTieBreakingByKeyAlphabetic() {
        // Two buckets with equal counts must sort alphabetically by key for stability.
        List<Object> records = new List<Object>{
            new Map<String, Object>{ 'F__c' => 'Charlie' },
            new Map<String, Object>{ 'F__c' => 'Alpha' },
            new Map<String, Object>{ 'F__c' => 'Bravo' },
            new Map<String, Object>{ 'F__c' => 'Charlie' },
            new Map<String, Object>{ 'F__c' => 'Alpha' },
            new Map<String, Object>{ 'F__c' => 'Bravo' }
        };

        Test.startTest();
        List<Map<String, Object>> buckets = DocGenChartBucketResolver.computeBuckets(records, 'F__c', null);
        Test.stopTest();

        System.assertEquals(3, buckets.size());
        // All counts = 2 → stable alpha order
        System.assertEquals('Alpha', buckets[0].get('key'));
        System.assertEquals('Bravo', buckets[1].get('key'));
        System.assertEquals('Charlie', buckets[2].get('key'));
    }
}
