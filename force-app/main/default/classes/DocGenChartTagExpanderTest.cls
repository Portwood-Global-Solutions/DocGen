@IsTest
private class DocGenChartTagExpanderTest {
    @IsTest
    static void noTags_returnsInputUnchanged() {
        String input = '<html><body><p>Hello {Name}</p></body></html>';
        System.assertEquals(input, DocGenChartTagExpander.expand(input, 'HTML'));
    }

    @IsTest
    static void nullInput_returnsNull() {
        System.assertEquals(null, DocGenChartTagExpander.expand(null, 'HTML'));
    }

    @IsTest
    static void barMinimal_emitsChartBucketLoop() {
        String input = '<body>{Chart:Survey_Responses__r:Selected_Answer__c}</body>';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(
            out.contains('{#ChartBucket:Survey_Responses__r:Selected_Answer__c}'),
            'Expected expanded snippet to contain a ChartBucket open tag. Got: ' + out
        );
        System.assert(out.contains('{/ChartBucket}'), 'Expected matching close tag.');
        System.assert(out.contains('{key_label}'), 'Bar style should reference key_label.');
        System.assert(out.contains('{percent}'), 'Bar style should reference percent.');
    }

    @IsTest
    static void barWithTitle_emitsHeading() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=How satisfied?}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('<h2'), 'Expected heading for title.');
        System.assert(out.contains('How satisfied?'), 'Title text should pass through.');
    }

    @IsTest
    static void barWithWhere_passesOptionToChartBucket() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:bar:where=Q__c=1}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('where=Q__c=1'), 'where clause should pass through to ChartBucket tag.');
    }

    @IsTest
    static void pivot_requiresGroupBy() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:pivot}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Chart error'), 'Missing groupBy should render error block.');
        System.assert(out.contains('groupBy='), 'Error should hint at groupBy.');
    }

    @IsTest
    static void pivot_requiresColSort() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:pivot:groupBy=Dept__c}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Chart error'), 'Missing colSort should render error block.');
        System.assert(out.contains('colSort='), 'Error should hint at colSort.');
    }

    @IsTest
    static void pivot_emitsHeadersFromColSort() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:pivot:groupBy=Dept__c&colSort=Eng,Sales,Mkt}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Eng'), 'Header should include Eng.');
        System.assert(out.contains('Sales'), 'Header should include Sales.');
        System.assert(out.contains('Mkt'), 'Header should include Mkt.');
        System.assert(out.contains('Total'), 'Pivot should emit a Total column.');
        System.assert(out.contains('{#cols}'), 'Pivot body should iterate columns.');
    }

    @IsTest
    static void clustered_emitsLegendAndCols() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:clustered:groupBy=Dept__c&colSort=Eng,Sales}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('{percent_int}'), 'Clustered uses percent_int for px heights.');
        System.assert(out.contains('{#cols}'), 'Clustered iterates columns inside each answer group.');
    }

    @IsTest
    static void stacked_emitsPercentOfRow() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:stacked:groupBy=Dept__c&colSort=Eng,Sales}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('{percent_of_row}'), 'Stacked uses percent_of_row for segment widths.');
    }

    @IsTest
    static void unknownStyle_rendersErrorBlock() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:waterfall}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Chart error'), 'Unknown style should render error block.');
        System.assert(out.contains('waterfall'), 'Error should mention the bad style.');
    }

    @IsTest
    static void missingField_rendersError() {
        String input = '{Chart:Survey_Responses__r}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Chart error'), 'Missing field should render error.');
    }

    @IsTest
    static void unterminatedTag_rendersError() {
        String input = '<p>{Chart:Survey_Responses__r:Selected_Answer__c';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(
            out.contains('Chart error') || out.contains('Unterminated'),
            'Unterminated tag should render error.'
        );
    }

    @IsTest
    static void wordTemplate_noChartCvMap_emitsTextPlaceholder() {
        // Post-#117: Word templates no longer throw on {Chart:...}. The
        // server-side path with no LWC to rasterize emits a text placeholder
        // identifying the chart so authors see the gap rather than silent loss.
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=How satisfied?}';
        String out = DocGenChartTagExpander.expand(input, 'Word');
        System.assert(out.contains('[Chart:'), 'Word + no chartCvMap should emit text placeholder. Got: ' + out);
        System.assert(out.contains('How satisfied?'), 'Placeholder should include the chart title. Got: ' + out);
        System.assert(!out.contains('<h2'), 'Placeholder must NOT emit HTML in Word output (would corrupt OOXML).');
    }

    @IsTest
    static void wordTemplate_withChartCvMap_emitsImageTag() {
        String input = '{Chart:Responses__r:A__c:bar}';
        // Same option set produces the same signature both sides; here we
        // pre-compute the signature with the controller's helper so the test
        // doesn't have to hand-roll a SHA-256.
        Map<String, String> opts = new Map<String, String>();
        String sig = DocGenChartImageController.tagSignature('Responses__r', 'A__c', 'bar', opts);
        String fakeCvId = '0681x00000000000001';
        Map<String, String> chartCvMap = new Map<String, String>{ sig => fakeCvId };
        Map<String, Object> data = new Map<String, Object>();

        String out = DocGenChartTagExpander.expand(input, 'Word', data, chartCvMap);

        System.assert(
            out.contains('{%__dgchart_' + fakeCvId + '}'),
            'Word + chartCvMap should emit synthetic image tag. Got: ' + out
        );
        System.assertEquals(
            fakeCvId,
            (String) data.get('__dgchart_' + fakeCvId),
            'Data map should be seeded with the synthetic key → CV Id.'
        );
    }

    @IsTest
    static void wordTemplate_titledChart_signatureMatchesController() {
        // Regression guard: pre-fix, the expander stripped `title` from opts
        // before hashing while the controller hashed with title intact. Result:
        // every titled chart fell back to text in Word. Both sides must hash
        // the SAME map shape.
        String tag = '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=How Satisfied?}';
        Map<String, String> opts = new Map<String, String>{ 'title' => 'How Satisfied?' };
        String controllerSig = DocGenChartImageController.tagSignature(
            'Survey_Responses__r',
            'Selected_Answer__c',
            'bar',
            opts
        );

        String fakeCvId = '0681x00000000000099';
        Map<String, String> chartCvMap = new Map<String, String>{ controllerSig => fakeCvId };
        Map<String, Object> data = new Map<String, Object>();

        String out = DocGenChartTagExpander.expand(tag, 'Word', data, chartCvMap);

        System.assert(
            out.contains('{%__dgchart_' + fakeCvId + '}'),
            'Expander must hash the same map shape as the controller, including title. Got: ' + out
        );
        System.assert(
            !out.contains('[Chart:'),
            'Should NOT fall back to text placeholder when CV is present in the map.'
        );
    }

    @IsTest
    static void wordTemplate_signatureStable_acrossOptionOrder() {
        // Same options in different order must hash to the same signature so
        // the LWC and the expander agree on which CV maps to which tag.
        Map<String, String> aFirst = new Map<String, String>{ 'colors' => '#aaa,#bbb', 'width' => '400' };
        Map<String, String> bFirst = new Map<String, String>{ 'width' => '400', 'colors' => '#aaa,#bbb' };
        System.assertEquals(
            DocGenChartImageController.tagSignature('Rel__r', 'F__c', 'bar', aFirst),
            DocGenChartImageController.tagSignature('Rel__r', 'F__c', 'bar', bFirst),
            'Signature must be order-independent.'
        );
    }

    @IsTest
    static void multipleTags_allExpanded() {
        String input =
            '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Q1}' +
            '<p>middle</p>' +
            '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Q2}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('Q1'), 'First tag expanded.');
        System.assert(out.contains('Q2'), 'Second tag expanded.');
        System.assert(out.contains('middle'), 'Static content preserved between tags.');
        Integer chartBucketOpens = out.countMatches('{#ChartBucket:');
        System.assertEquals(2, chartBucketOpens, 'Should emit two ChartBucket open tags.');
    }

    /**
     * The integration test: expand a {Chart:...} tag, feed the result into
     * DocGenService.processXmlForTest (HTML mode), and confirm bucket data
     * actually fills in. Verifies the expander's output is a valid template
     * that the downstream ChartBucket resolver consumes correctly.
     */
    @IsTest
    static void barTag_resolvesEndToEnd() {
        String tag = '{Chart:Responses__r:A__c:bar}';
        String expanded = DocGenChartTagExpander.expand(tag, 'HTML');
        Map<String, Object> data = new Map<String, Object>{
            'Responses__r' => new List<Object>{
                new Map<String, Object>{ 'A__c' => 'Yes' },
                new Map<String, Object>{ 'A__c' => 'Yes' },
                new Map<String, Object>{ 'A__c' => 'No' }
            }
        };
        Test.startTest();
        String rendered = DocGenService.processXmlForTest(expanded, data, 'HTML');
        Test.stopTest();

        System.assert(
            rendered.contains('Yes') && rendered.contains('No'),
            'Both bucket keys should appear in rendered output. Got: ' + rendered
        );
        System.assert(rendered.contains('66.7'), 'Yes bucket = 66.7%. Got: ' + rendered);
        System.assert(rendered.contains('33.3'), 'No bucket = 33.3%. Got: ' + rendered);
        System.assert(!rendered.contains('{key_label}'), 'Template placeholders should be replaced.');
        System.assert(!rendered.contains('{percent}'), 'Template placeholders should be replaced.');
    }

    /**
     * Google Docs / pandoc HTML-escape & to &amp; on export. The expander must
     * decode common XML entities so cross-tab option strings (which use & as
     * the option separator) parse correctly when the template came from a
     * Docs / Word round-trip rather than direct HTML authoring.
     */
    @IsTest
    static void htmlEntitiesInTagAreDecoded() {
        String input = '{Chart:R__r:F__c:pivot:groupBy=Dept__c&amp;colSort=Eng,Sales&amp;title=Q&apos;s}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(out.contains('groupBy=Dept__c'), 'groupBy option should survive &amp; decode. Got: ' + out);
        System.assert(out.contains('colSort=Eng,Sales'), 'colSort option should survive &amp; decode. Got: ' + out);
        System.assert(out.contains('Eng'), 'Pivot headers should appear from colSort.');
        System.assert(!out.contains('Chart error'), 'Decoded tag should parse cleanly.');
    }

    @IsTest
    static void titleIsEscaped() {
        String input = '{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=<script>alert(1)</script>}';
        String out = DocGenChartTagExpander.expand(input, 'HTML');
        System.assert(!out.contains('<script>'), 'Title HTML must be escaped.');
        System.assert(out.contains('&lt;script&gt;'), 'Title HTML should be XML-escaped.');
    }
}
