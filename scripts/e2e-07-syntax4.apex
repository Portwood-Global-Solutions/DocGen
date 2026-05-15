// DocGen E2E Test 07.4 — {#ChartBucket} aggregation tag via processXmlForTest()
// Run: sf apex run --target-org <org> -f scripts/e2e-07-syntax4.apex
// Depends on: nothing (uses DocGenService.processXmlForTest directly)
// Expected: PASS: N  FAIL: 0

Integer pass = 0;
Integer fail = 0;
String r;

// ============================================================
// ChartBucket — basic three-bucket count + descending order + percent math
// ============================================================
try {
    Map<String, Object> data = new Map<String, Object>{
        'Responses__r' => new List<Object>{
            new Map<String, Object>{ 'A__c' => 'Yes' },
            new Map<String, Object>{ 'A__c' => 'Yes' },
            new Map<String, Object>{ 'A__c' => 'Yes' },
            new Map<String, Object>{ 'A__c' => 'No' },
            new Map<String, Object>{ 'A__c' => 'No' },
            new Map<String, Object>{ 'A__c' => 'Maybe' }
        }
    };
    r = DocGenService.processXmlForTest(
        '{#ChartBucket:Responses__r:A__c}[{key}:{count}/{percent}%/{color}]{/ChartBucket}',
        data
    );
    Boolean orderOk = r.indexOf('[Yes:3') < r.indexOf('[No:2') && r.indexOf('[No:2') < r.indexOf('[Maybe:1');
    Boolean math =
        r.contains('[Yes:3/50.0%/#3b82f6]') &&
        r.contains('[No:2/33.3%/#10b981]') &&
        r.contains('[Maybe:1/16.7%/#f59e0b]');
    if (math && orderOk) {
        pass++;
        System.debug('CHARTBUCKET BASIC: PASS');
    } else {
        fail++;
        System.debug('CHARTBUCKET BASIC: FAIL — ' + r);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHARTBUCKET BASIC: FAIL — ' + e.getMessage());
}

// ============================================================
// ChartBucket — empty relationship + {:else} branch fires
// ============================================================
try {
    r = DocGenService.processXmlForTest(
        '{#ChartBucket:Empty__r:F__c}[bar]{:else}NO_DATA{/ChartBucket}',
        new Map<String, Object>{ 'Empty__r' => new List<Object>() }
    );
    if (r.contains('NO_DATA') && !r.contains('[bar]')) {
        pass++;
        System.debug('CHARTBUCKET EMPTY+ELSE: PASS');
    } else {
        fail++;
        System.debug('CHARTBUCKET EMPTY+ELSE: FAIL — ' + r);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHARTBUCKET EMPTY+ELSE: FAIL — ' + e.getMessage());
}

// ============================================================
// ChartBucket — null/blank values collapse to "Not Specified"
// ============================================================
try {
    Map<String, Object> data = new Map<String, Object>{
        'R__r' => new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => null },
            new Map<String, Object>{ 'F__c' => '' },
            new Map<String, Object>{ 'F__c' => '   ' }
        }
    };
    r = DocGenService.processXmlForTest('{#ChartBucket:R__r:F__c}[{key_label}:{count}]{/ChartBucket}', data);
    if (r.contains('[Not Specified:3]') && r.contains('[A:1]')) {
        pass++;
        System.debug('CHARTBUCKET NULL → NOT SPECIFIED: PASS');
    } else {
        fail++;
        System.debug('CHARTBUCKET NULL → NOT SPECIFIED: FAIL — ' + r);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHARTBUCKET NULL → NOT SPECIFIED: FAIL — ' + e.getMessage());
}

// ============================================================
// ChartBucket — nested inside outer loop resolves against iteration item
// (the load-bearing test: validates depth-aware preprocess deferral)
// ============================================================
try {
    Map<String, Object> data = new Map<String, Object>{
        'Questions__r' => new List<Object>{
            new Map<String, Object>{
                'Q__c' => 'Q1',
                'Responses__r' => new List<Object>{
                    new Map<String, Object>{ 'A__c' => 'Y' },
                    new Map<String, Object>{ 'A__c' => 'Y' },
                    new Map<String, Object>{ 'A__c' => 'N' }
                }
            },
            new Map<String, Object>{
                'Q__c' => 'Q2',
                'Responses__r' => new List<Object>{
                    new Map<String, Object>{ 'A__c' => 'Y' },
                    new Map<String, Object>{ 'A__c' => 'N' }
                }
            }
        }
    };
    r = DocGenService.processXmlForTest(
        '{#Questions__r}<h>{Q__c}</h>{#ChartBucket:Responses__r:A__c}[{key}:{count}]{/ChartBucket}{/Questions__r}',
        data
    );
    // Q1: Y=2,N=1 (Y leads). Q2: tied 1/1 — alpha order N then Y.
    Boolean q1Ok = r.contains('<h>Q1</h>[Y:2][N:1]');
    Boolean q2Ok = r.contains('<h>Q2</h>[N:1][Y:1]');
    if (q1Ok && q2Ok) {
        pass++;
        System.debug('CHARTBUCKET NESTED IN LOOP: PASS');
    } else {
        fail++;
        System.debug('CHARTBUCKET NESTED IN LOOP: FAIL — ' + r);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHARTBUCKET NESTED IN LOOP: FAIL — ' + e.getMessage());
}

// ============================================================
// ChartBucket — max_percent normalization (largest bucket = 100)
// ============================================================
try {
    Map<String, Object> data = new Map<String, Object>{
        'R__r' => new List<Object>{
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'A' },
            new Map<String, Object>{ 'F__c' => 'B' }
        }
    };
    r = DocGenService.processXmlForTest('{#ChartBucket:R__r:F__c}[{key}:{max_percent}]{/ChartBucket}', data);
    if (r.contains('[A:100.0]') && r.contains('[B:25.0]')) {
        pass++;
        System.debug('CHARTBUCKET MAX_PERCENT: PASS');
    } else {
        fail++;
        System.debug('CHARTBUCKET MAX_PERCENT: FAIL — ' + r);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHARTBUCKET MAX_PERCENT: FAIL — ' + e.getMessage());
}

// ============================================================
// Chart tag expander — {Chart:rel:field} rewrites to ChartBucket loop
// ============================================================
try {
    String exp = DocGenChartTagExpander.expand('{Chart:Survey_Responses__r:Selected_Answer__c}', 'HTML');
    Boolean hasOpen = exp.contains('{#ChartBucket:Survey_Responses__r:Selected_Answer__c}');
    Boolean hasClose = exp.contains('{/ChartBucket}');
    Boolean hasBarMarkup = exp.contains('{key_label}') && exp.contains('{percent}') && exp.contains('{color}');
    if (hasOpen && hasClose && hasBarMarkup) {
        pass++;
        System.debug('CHART TAG BAR EXPANSION: PASS');
    } else {
        fail++;
        System.debug('CHART TAG BAR EXPANSION: FAIL — ' + exp);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART TAG BAR EXPANSION: FAIL — ' + e.getMessage());
}

// ============================================================
// Chart tag expander — title=... emits heading, options pass through
// ============================================================
try {
    String exp = DocGenChartTagExpander.expand('{Chart:R__r:F__c:bar:title=How happy?&where=X__c=1}', 'HTML');
    if (exp.contains('How happy?') && exp.contains('<h2') && exp.contains('where=X__c=1')) {
        pass++;
        System.debug('CHART TAG TITLE+OPTS: PASS');
    } else {
        fail++;
        System.debug('CHART TAG TITLE+OPTS: FAIL — ' + exp);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART TAG TITLE+OPTS: FAIL — ' + e.getMessage());
}

// ============================================================
// Chart tag expander — pivot/clustered/stacked require groupBy + colSort
// ============================================================
try {
    String missingGroupBy = DocGenChartTagExpander.expand('{Chart:R__r:F__c:pivot}', 'HTML');
    String missingColSort = DocGenChartTagExpander.expand('{Chart:R__r:F__c:pivot:groupBy=D__c}', 'HTML');
    String good = DocGenChartTagExpander.expand('{Chart:R__r:F__c:pivot:groupBy=D__c&colSort=Eng,Sales}', 'HTML');
    Boolean missingErrors = missingGroupBy.contains('Chart error') && missingColSort.contains('Chart error');
    Boolean goodEmits =
        good.contains('Eng') &&
        good.contains('Sales') &&
        good.contains('Total') &&
        good.contains('{#cols}');
    if (missingErrors && goodEmits) {
        pass++;
        System.debug('CHART TAG PIVOT VALIDATION: PASS');
    } else {
        fail++;
        System.debug(
            'CHART TAG PIVOT VALIDATION: FAIL — missingGroupBy=' +
                missingGroupBy +
                ' | missingColSort=' +
                missingColSort +
                ' | good=' +
                good
        );
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART TAG PIVOT VALIDATION: FAIL — ' + e.getMessage());
}

// ============================================================
// Chart tag expander — unknown style + Word template error modes
// ============================================================
try {
    String unknown = DocGenChartTagExpander.expand('{Chart:R__r:F__c:waterfall}', 'HTML');
    Boolean unknownErr = unknown.contains('Chart error') && unknown.contains('waterfall');
    Boolean wordThrew = false;
    try {
        DocGenChartTagExpander.expand('{Chart:R__r:F__c}', 'Word');
    } catch (DocGenException e) {
        wordThrew = e.getMessage().contains('HTML-only') || e.getMessage().contains('HTML');
    }
    if (unknownErr && wordThrew) {
        pass++;
        System.debug('CHART TAG ERROR MODES: PASS');
    } else {
        fail++;
        System.debug('CHART TAG ERROR MODES: FAIL — unknownErr=' + unknownErr + ' wordThrew=' + wordThrew);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART TAG ERROR MODES: FAIL — ' + e.getMessage());
}

System.debug('========================================');
System.debug(
    'E2E-07-SYNTAX4 — PASS: ' + pass + '  FAIL: ' + fail + (fail == 0 ? '  ALL TESTS PASSED' : '  FAILURES DETECTED')
);
System.debug('========================================');
