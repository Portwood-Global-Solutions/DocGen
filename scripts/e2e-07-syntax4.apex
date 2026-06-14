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
// Chart tag expander — unknown style + Word fallback (post-#117)
// ============================================================
try {
    String unknown = DocGenChartTagExpander.expand('{Chart:R__r:F__c:waterfall}', 'HTML');
    Boolean unknownErr = unknown.contains('Chart error') && unknown.contains('waterfall');
    // #117: Word + no chartCvMap → text placeholder, NOT a thrown exception.
    String wordPlaceholder = DocGenChartTagExpander.expand('{Chart:R__r:F__c:bar:title=Demo}', 'Word');
    Boolean wordPlaceholderOk = wordPlaceholder.contains('[Chart:') && wordPlaceholder.contains('Demo');
    if (unknownErr && wordPlaceholderOk) {
        pass++;
        System.debug('CHART TAG ERROR MODES: PASS');
    } else {
        fail++;
        System.debug(
            'CHART TAG ERROR MODES: FAIL — unknownErr=' +
                unknownErr +
                ' wordPlaceholderOk=' +
                wordPlaceholderOk +
                ' wordPlaceholder=' +
                wordPlaceholder
        );
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART TAG ERROR MODES: FAIL — ' + e.getMessage());
}

// ============================================================
// #117 chart pipeline — Word template + chartCvMap emits image tag
// ============================================================
try {
    Map<String, String> opts = new Map<String, String>();
    String sig = DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', opts);
    String fakeCvId = '0681x00000000000001';
    Map<String, String> chartCvMap = new Map<String, String>{ sig => fakeCvId };
    Map<String, Object> data = new Map<String, Object>();
    String out = DocGenChartTagExpander.expand('{Chart:R__r:F__c:bar}', 'Word', data, chartCvMap);
    Boolean tagOk = out.contains('{%__dgchart_' + fakeCvId + '}');
    Boolean dataSeeded = data.get('__dgchart_' + fakeCvId) == fakeCvId;
    if (tagOk && dataSeeded) {
        pass++;
        System.debug('CHART PIPELINE WORD SUBSTITUTION: PASS');
    } else {
        fail++;
        System.debug(
            'CHART PIPELINE WORD SUBSTITUTION: FAIL — tagOk=' + tagOk + ' dataSeeded=' + dataSeeded + ' out=' + out
        );
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART PIPELINE WORD SUBSTITUTION: FAIL — ' + e.getMessage());
}

// PowerPoint routes through the same PNG-via-CV branch as Word (PPTX charts).
try {
    Map<String, String> opts = new Map<String, String>();
    String sig = DocGenChartImageController.tagSignature('R__r', 'F__c', 'bar', opts);
    String fakeCvId = '0681x00000000000002';
    Map<String, String> chartCvMap = new Map<String, String>{ sig => fakeCvId };
    Map<String, Object> data = new Map<String, Object>();
    String out = DocGenChartTagExpander.expand('{Chart:R__r:F__c:bar}', 'PowerPoint', data, chartCvMap);
    Boolean tagOk = out.contains('{%__dgchart_' + fakeCvId + '}');
    Boolean dataSeeded = data.get('__dgchart_' + fakeCvId) == fakeCvId;
    if (tagOk && dataSeeded) {
        pass++;
        System.debug('CHART PIPELINE PPTX SUBSTITUTION: PASS');
    } else {
        fail++;
        System.debug('CHART PIPELINE PPTX SUBSTITUTION: FAIL — tagOk=' + tagOk + ' dataSeeded=' + dataSeeded);
    }
} catch (Exception e) {
    fail++;
    System.debug('CHART PIPELINE PPTX SUBSTITUTION: FAIL — ' + e.getMessage());
}

// ============================================================
// #115 — merge errors name the tag + show a snippet
// ============================================================

// Unclosed loop: message must carry the section name AND a snippet of context
try {
    DocGenService.processXmlForTest('<w:t>INTRO {#Items} body of loop</w:t>', new Map<String, Object>());
    fail++;
    System.debug('ERR ENRICH UNCLOSED LOOP: FAIL — no exception thrown');
} catch (Exception e) {
    String m = e.getMessage();
    if (m.contains('{#Items}') && m.contains('opened near') && m.contains('INTRO')) {
        pass++;
        System.debug('ERR ENRICH UNCLOSED LOOP: PASS');
    } else {
        fail++;
        System.debug('ERR ENRICH UNCLOSED LOOP: FAIL — ' + m);
    }
}

// Missing closing brace: message must include a snippet, not just a numeric offset
try {
    DocGenService.processXmlForTest('<w:t>before {Account.Name no close</w:t>', new Map<String, Object>());
    fail++;
    System.debug('ERR ENRICH MISSING BRACE: FAIL — no exception thrown');
} catch (Exception e) {
    String m = e.getMessage();
    if (m.contains('missing closing') && m.contains('near "') && m.contains('Account.Name')) {
        pass++;
        System.debug('ERR ENRICH MISSING BRACE: PASS');
    } else {
        fail++;
        System.debug('ERR ENRICH MISSING BRACE: FAIL — ' + m);
    }
}

// Unclosed inverse section: same enrichment as the loop path
try {
    DocGenService.processXmlForTest('<w:t>head {^Flag} hidden body</w:t>', new Map<String, Object>());
    fail++;
    System.debug('ERR ENRICH UNCLOSED INVERSE: FAIL — no exception thrown');
} catch (Exception e) {
    String m = e.getMessage();
    if (m.contains('{^Flag}') && m.contains('opened near')) {
        pass++;
        System.debug('ERR ENRICH UNCLOSED INVERSE: PASS');
    } else {
        fail++;
        System.debug('ERR ENRICH UNCLOSED INVERSE: FAIL — ' + m);
    }
}

// {RepeatHeader} marker → native <w:tblHeader/> (pre-merge), marker stripped
try {
    String rh = DocGenService.mergeRunsInTagsForTest(
        '<w:tbl><w:tblPr/><w:tr><w:tc><w:p><w:r><w:t>{RepeatHeader}Code</w:t></w:r></w:p></w:tc></w:tr>' +
        '<w:tr><w:tc><w:p><w:r><w:t>105</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
    );
    if (rh.contains('<w:tblHeader/>') && !rh.contains('{RepeatHeader}') && rh.contains('Code')) {
        pass++;
        System.debug('REPEAT HEADER MARKER: PASS');
    } else {
        fail++;
        System.debug('REPEAT HEADER MARKER: FAIL — ' + rh);
    }
} catch (Exception e) {
    fail++;
    System.debug('REPEAT HEADER MARKER: FAIL — ' + e.getMessage());
}

// Picklist label format suffix: {Field:label} renders stored label metadata, raw {Field} stays API value
try {
    Map<String, Object> labelData = new Map<String, Object>{ 'Stage__c' => 'QUAL' };
    labelData.put('__docgenPicklistLabels', new Map<String, String>{ 'Stage__c' => 'Qualified Lead' });
    String raw = DocGenService.processXmlForTest('{Stage__c}', labelData);
    String lbl = DocGenService.processXmlForTest('{Stage__c:label}', labelData);
    if (raw == 'QUAL' && lbl == 'Qualified Lead') {
        pass++;
        System.debug('PICKLIST LABEL SUFFIX: PASS');
    } else {
        fail++;
        System.debug('PICKLIST LABEL SUFFIX: FAIL — raw=' + raw + ' label=' + lbl);
    }
} catch (Exception e) {
    fail++;
    System.debug('PICKLIST LABEL SUFFIX: FAIL — ' + e.getMessage());
}

// ===== Barcode / QR tags in HTML templates (v3.15) =====
// processXml emits ##BARCODE:...## markers; the HTML path converts them to CSS
// via DocGenHtmlRenderer.replaceBarcodeMarkersInHtml (Word path uses renderBarcodeHtml).
try {
    String bt = '<td>SKU {*Code__c:code128:200x44} <span>scan {*Url__c:qr:160}</span></td>';
    String marked = DocGenService.processXmlForTest(
        bt,
        new Map<String, Object>{ 'Code__c' => 'PWG-1001', 'Url__c' => 'https://verify.portwood.dev/x' }
    );
    Boolean emitted = marked.contains('##BARCODE:code128') && marked.contains('##BARCODE:qr');
    String rendered = DocGenHtmlRenderer.replaceBarcodeMarkersInHtml(marked);
    Boolean ok =
        emitted &&
        !rendered.contains('##BARCODE:') &&
        rendered.contains('display:inline-block') &&
        rendered.contains('<td>'); // surrounding HTML preserved unescaped
    if (ok) {
        pass++;
        System.debug('HTML BARCODE+QR: PASS');
    } else {
        fail++;
        System.debug('HTML BARCODE+QR: FAIL — emitted=' + emitted + ' rendered=' + rendered.left(120));
    }
} catch (Exception e) {
    fail++;
    System.debug('HTML BARCODE+QR: FAIL — ' + e.getMessage());
}

System.debug('========================================');
System.debug(
    'E2E-07-SYNTAX4 — PASS: ' + pass + '  FAIL: ' + fail + (fail == 0 ? '  ALL TESTS PASSED' : '  FAILURES DETECTED')
);
System.debug('========================================');
