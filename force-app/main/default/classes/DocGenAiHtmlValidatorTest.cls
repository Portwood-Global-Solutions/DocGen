/**
 * Every assertion here encodes a MEASURED Flying Saucer behaviour, not a guess.
 * Sources: UserGuide 5.7.3 / 15.11, scripts/css-capability-probe.apex and the
 * rendered proof in docs/css-capability-probe.png.
 */
@isTest
private class DocGenAiHtmlValidatorTest {
    private static DocGenAiHtmlValidator.Finding findRule(DocGenAiHtmlValidator.Result r, String rule) {
        for (DocGenAiHtmlValidator.Finding f : r.findings) {
            if (f.rule == rule) {
                return f;
            }
        }
        return null;
    }

    @isTest
    static void rgbaIsFlattenedNotDropped() {
        // The one that quietly ruins a layout: rgba() resolves to nothing and
        // the panel renders invisible rather than falling back to a colour.
        String html = '<div style="background: rgba(11,61,145,0.12);">x</div>';
        Test.startTest();
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        Test.stopTest();

        System.assert(!r.html.containsIgnoreCase('rgba('), 'rgba() must not survive: ' + r.html);
        // 11,61,145 at 12% over white -> 226, 232, 242
        System.assert(r.html.contains('#e2e8f2'), 'Expected the composited hex #e2e8f2, got: ' + r.html);
        System.assertNotEquals(null, findRule(r, 'rgba() colour'), 'Should report the repair');
        System.assertEquals(1, findRule(r, 'rgba() colour').occurrences);
    }

    @isTest
    static void hslaIsFlattened() {
        String html = '<div style="color: hsla(210, 100%, 50%, 1);">x</div>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.containsIgnoreCase('hsla('), 'hsla() must not survive: ' + r.html);
        System.assert(r.html.contains('#0080ff'), 'Expected #0080ff, got: ' + r.html);
    }

    @isTest
    static void gradientBecomesItsFirstStop() {
        String html = '<style>.b{background:linear-gradient(90deg,#0b3d91,#63b3ed);}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.containsIgnoreCase('gradient'), 'Gradient must not survive: ' + r.html);
        System.assert(r.html.contains('#0b3d91'), 'Expected the first stop kept: ' + r.html);
    }

    @isTest
    static void ignoredDeclarationsAreRemoved() {
        String html =
            '<style>.a{border-radius:6pt;-fs-border-radius:8pt;box-shadow:2pt 2pt 4pt #888;' +
            'opacity:0.45;transform:rotate(-4deg);outline:2pt solid #b02b2b;box-sizing:border-box;' +
            'word-break:break-all;overflow-wrap:break-word;width:calc(100% - 40pt);}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);

        for (
            String dead : new List<String>{
                'border-radius',
                'box-shadow',
                'opacity',
                'transform',
                'outline',
                'box-sizing',
                'word-break',
                'overflow-wrap',
                'calc('
            }
        ) {
            System.assert(!r.html.containsIgnoreCase(dead), dead + ' should have been removed: ' + r.html);
        }
        System.assert(r.removedCount >= 9, 'Expected at least 9 removals, got ' + r.removedCount);
    }

    @isTest
    static void borderDashedAndNthChildSurvive() {
        // Both are CSS 2.1 / measured-working. Stripping them would be a bug.
        String html = '<style>.d{border:2pt dashed #2b6cb0;} tr:nth-child(even){background:#f5f7fa;}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(r.html.contains('dashed'), 'border: dashed renders and must be kept');
        System.assert(r.html.contains('nth-child(even)'), ':nth-child is supported and must be kept');
    }

    @isTest
    static void flexIsRemovedAndReportedAsAWarning() {
        String html = '<style>.h{display:flex;justify-content:space-between;align-items:center;gap:8pt;}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);

        System.assert(!r.html.containsIgnoreCase('display:flex'), 'flex must go: ' + r.html);
        System.assert(!r.html.containsIgnoreCase('justify-content'), 'companion props must go');
        System.assert(!r.html.containsIgnoreCase('gap:'), 'gap must go');
        DocGenAiHtmlValidator.Finding f = findRule(r, 'display:flex / display:grid');
        System.assertNotEquals(null, f, 'flex must be reported');
        System.assertEquals('warning', f.action, 'flex changes the layout — the author has to rebuild it as a table');
    }

    @isTest
    static void displayTableIsNotTouched() {
        String html = '<style>.r{display:table-row;} .c{display:table-cell;} .t{display:table;}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(r.html.contains('table-row'), 'display:table-row is the supported layout primitive');
        System.assert(r.html.contains('table-cell'), 'display:table-cell must survive');
    }

    @isTest
    static void cssVariablesAreSubstituted() {
        String html = '<style>:root{--brand:#0b3d91;} .x{color:var(--brand);} .y{color:var(--nope,#333);}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.contains('var('), 'var() must be resolved away: ' + r.html);
        System.assert(r.html.contains('#0b3d91'), 'defined variable should be substituted');
        System.assert(r.html.contains('#333'), 'fallback should be used when undefined');
        System.assert(!r.html.contains('--brand:'), 'the custom property declaration is inert afterwards');
    }

    @isTest
    static void numericFontWeightIsMapped() {
        String html = '<style>.a{font-weight:600;} .b{font-weight:300;}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(r.html.contains('font-weight: bold'), '600 maps to bold: ' + r.html);
        System.assert(r.html.contains('font-weight: normal'), '300 maps to normal: ' + r.html);
    }

    @isTest
    static void dingbatFontIsWarnedAbout() {
        // Worse than an ignored property: it silently typesets a literal "l".
        String html = '<span style="font-family: ZapfDingbats;">l</span>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        DocGenAiHtmlValidator.Finding f = findRule(r, 'Dingbat font');
        System.assertNotEquals(null, f, 'ZapfDingbats must be flagged');
        System.assertEquals('warning', f.action);
        System.assert(!r.html.containsIgnoreCase('ZapfDingbats'), 'the missing font must be removed');
    }

    @isTest
    static void mediaQueryBlockIsRemovedWholesale() {
        String html = '<style>body{color:#111;}@media print{body{padding:0;}.x{color:red;}}.after{margin:0;}</style>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.contains('@media'), '@media must be removed: ' + r.html);
        System.assert(!r.html.contains('padding:0'), 'rules inside the block go with it');
        System.assert(r.html.contains('.after'), 'content after the block must survive: ' + r.html);
        System.assert(r.html.contains('color:#111'), 'content before the block must survive');
    }

    @isTest
    static void scriptAndSvgAreStripped() {
        String html = '<div><script>alert(1)</script><svg><circle r="4"/></svg><p>keep</p></div>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.containsIgnoreCase('<script'), 'script must go');
        System.assert(!r.html.containsIgnoreCase('<svg'), 'svg must go');
        System.assert(r.html.contains('keep'), 'real content must survive');
    }

    @isTest
    static void markdownFenceIsStripped() {
        String html = '```html\n<div>hi</div>\n```';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assert(!r.html.contains('```'), 'fence must go: ' + r.html);
        System.assert(r.html.contains('<div>hi</div>'), 'content must survive');
    }

    @isTest
    static void loopTagBetweenRowsIsMovedIntoTheCells() {
        // The #248 mistake, reproduced verbatim on the first real generation.
        String html =
            '<table><thead><tr><th>P</th><th>Q</th></tr></thead><tbody>\n' +
            '{#OpportunityLineItems}\n<tr><td>{Product2.Name}</td><td>{Quantity}</td></tr>\n{/OpportunityLineItems}\n' +
            '</tbody></table>';
        Test.startTest();
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        Test.stopTest();

        System.assert(
            r.html.contains('<td>{#OpportunityLineItems}{Product2.Name}</td>'),
            'opening tag belongs inside the first cell: ' + r.html
        );
        System.assert(
            r.html.contains('<td>{Quantity}{/OpportunityLineItems}</td>'),
            'closing tag belongs inside the last cell: ' + r.html
        );
        System.assert(!r.html.contains('\n{#OpportunityLineItems}\n'), 'the stray between-rows tag must be gone');
        DocGenAiHtmlValidator.Finding f = findRule(r, 'Loop tag placed between rows');
        System.assertNotEquals(null, f, 'the repair must be reported');
        System.assertEquals('repaired', f.action);
        // The <thead> must not have been pulled into the loop.
        System.assert(r.html.contains('<th>P</th>'), 'header row must stay outside the loop');
    }

    @isTest
    static void loopWrappingWholeTableIsWarnedNotSilentlyMangled() {
        String html = '{#Lines}<table><tr><td>{Name}</td></tr></table>{/Lines}';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assertNotEquals(null, findRule(r, 'Loop wraps the whole table'), 'must warn');
    }

    @isTest
    static void pageCountersInBodyAreWarnedAbout() {
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize('<p>Page {PageNumber} of {TotalPages}</p>');
        System.assertNotEquals(
            null,
            findRule(r, '{PageNumber} in the body'),
            'must warn — they only resolve in header/footer'
        );
    }

    @isTest
    static void unbalancedBracesAreReported() {
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize('<p>{Name</p>');
        System.assertNotEquals(null, findRule(r, 'Unbalanced merge braces'), 'an unclosed brace fails the whole merge');
    }

    @isTest
    static void cleanTemplatePassesUntouched() {
        String html =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;margin:0.6in;}' +
            'body{font-family:Helvetica,Arial,sans-serif;font-size:11pt;color:#333;}' +
            'table{width:100%;border-collapse:collapse;}td{padding:4pt;border:0.5pt solid #ccc;}' +
            'tr:nth-child(even){background:#f5f7fa;}</style></head><body>' +
            '<table><tr><td>{Name}</td><td>{Amount:currency}</td></tr></table></body></html>';
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(html);
        System.assertEquals(0, r.findings.size(), 'A CSS 2.1-clean template must report nothing: ' + r.summary);
        System.assertEquals(html, r.html, 'and must come back byte-identical');
        System.assert(r.summary.startsWithIgnoreCase('Clean'), 'summary: ' + r.summary);
    }

    @isTest
    static void blankInputIsHandled() {
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(null);
        System.assertEquals('', r.html);
        System.assertEquals(0, r.findings.size());

        DocGenAiHtmlValidator.Result r2 = DocGenAiHtmlValidator.sanitize('   ');
        System.assertEquals('', r2.html);
    }

    @isTest
    static void theDirtySampleIsCleanedEndToEnd() {
        // The stub's canned response reproduces a real model's output.
        DocGenAiProvider p = new DocGenAiStubProvider();
        Test.startTest();
        DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(p.generateHtml('anything'));
        Test.stopTest();

        for (
            String dead : new List<String>{
                'display: flex',
                'display:flex',
                'border-radius',
                'box-shadow',
                'rgba(',
                'gradient',
                'opacity:',
                'box-sizing',
                '@media',
                'var(',
                'calc('
            }
        ) {
            System.assert(!r.html.containsIgnoreCase(dead), dead + ' survived sanitizing: ' + r.html);
        }
        System.assert(r.findings.size() >= 8, 'Expected a substantial report, got ' + r.findings.size());
        System.assert(r.summary.length() > 10, 'summary should be a sentence: ' + r.summary);
        // Structure and merge tags must survive intact.
        System.assert(r.html.contains('{Account.Name}'), 'merge tags must survive');
        System.assert(r.html.contains('{SUM:OpportunityLineItems.TotalPrice:currency}'), 'aggregates must survive');
        System.assert(
            r.html.contains('<td>{#OpportunityLineItems}{Product2.Name}</td>'),
            'loop repaired into the cell: ' + r.html
        );
        System.assert(r.html.contains('@page'), '@page must survive — it is how the page is set up');
    }
}
