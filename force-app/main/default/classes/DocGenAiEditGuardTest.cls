/**
 * The edit guard exists because a bad EDIT is invisible in a way a bad
 * generation is not — a dropped {Amount:currency} renders as nothing, and the
 * canvas looks fine. These tests pin the cases that actually cost a customer
 * document.
 */
@isTest
private class DocGenAiEditGuardTest {
    private static Boolean hasRule(List<DocGenAiHtmlValidator.Finding> fs, String rule) {
        for (DocGenAiHtmlValidator.Finding f : fs) {
            if (f.rule == rule) {
                return true;
            }
        }
        return false;
    }

    private static DocGenAiHtmlValidator.Finding get(List<DocGenAiHtmlValidator.Finding> fs, String rule) {
        for (DocGenAiHtmlValidator.Finding f : fs) {
            if (f.rule == rule) {
                return f;
            }
        }
        return null;
    }

    private static final String BEFORE =
        '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;margin:0.6in;}</style></head><body>' +
        '<h1>{Account.Name}</h1>' +
        '<table><tr><td>{Name}</td><td>{Amount:currency}</td></tr></table>' +
        '<table><tr><td>{#Lines}{Product2.Name}</td><td>{TotalPrice:currency}{/Lines}</td></tr></table>' +
        '<p>{Today:MMMM d, yyyy} — {RunningUser.Name}</p></body></html>';

    @isTest
    static void faithfulEditReportsNothing() {
        // Only the requested change: a colour. Everything else identical.
        String after = BEFORE.replace('<h1>', '<h1 style="color:#184d47;">');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        System.assertEquals(0, fs.size(), 'A faithful edit must be silent, or the warnings become noise: ' + fs);
    }

    @isTest
    static void aDroppedMergeTagIsReportedByName() {
        // The failure this class exists for.
        String after = BEFORE.replace('{Amount:currency}', '&nbsp;');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();

        DocGenAiHtmlValidator.Finding f = get(fs, 'Merge tags lost in the edit');
        System.assertNotEquals(null, f, 'a lost tag must be reported');
        System.assertEquals('warning', f.action);
        System.assert(
            f.detail.contains('{Amount:currency}'),
            'the tag must be named so it can be put back: ' + f.detail
        );
        System.assert(f.detail.containsIgnoreCase('Reload'), 'the author needs to be told how to recover: ' + f.detail);
    }

    @isTest
    static void severalDroppedTagsAreCounted() {
        String after = BEFORE.replace('{Amount:currency}', '')
            .replace('{Today:MMMM d, yyyy}', '')
            .replace('{RunningUser.Name}', '');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        DocGenAiHtmlValidator.Finding f = get(fs, 'Merge tags lost in the edit');
        System.assertNotEquals(null, f);
        System.assertEquals(3, f.occurrences, 'all three losses counted: ' + f.detail);
    }

    @isTest
    static void closingLoopTagsAreNotReportedSeparately() {
        // {/Lines} vanishing alongside {#Lines} is one problem, not two.
        String after = BEFORE.replace('{#Lines}', '').replace('{/Lines}', '');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        DocGenAiHtmlValidator.Finding f = get(fs, 'Merge tags lost in the edit');
        System.assertNotEquals(null, f);
        System.assert(f.detail.contains('{#Lines}'), 'the opener is what matters: ' + f.detail);
        System.assert(!f.detail.contains('{/Lines}'), 'the closer must not be double-reported: ' + f.detail);
    }

    @isTest
    static void truncationIsReported() {
        // The "model summarised instead of editing" / ran-out-of-tokens failure.
        String after = BEFORE.substring(0, 120);
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        System.assert(hasRule(fs, 'The edit came back much shorter'), 'truncation must be flagged: ' + fs);
    }

    @isTest
    static void aGrowingEditIsNotFlaggedAsShrinkage() {
        String after = BEFORE.replace('</body>', '<p>An added paragraph of extra content here.</p></body>');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        System.assert(!hasRule(fs, 'The edit came back much shorter'), 'adding content is normal: ' + fs);
    }

    @isTest
    static void droppedPageRuleIsReported() {
        String after = BEFORE.replace('@page{size:Letter portrait;margin:0.6in;}', '');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        System.assert(hasRule(fs, 'Page setup rule dropped'), 'losing @page changes every page: ' + fs);
    }

    @isTest
    static void aLostTableIsReported() {
        String after = BEFORE.replace(
            '<table><tr><td>{#Lines}{Product2.Name}</td><td>{TotalPrice:currency}{/Lines}</td></tr></table>',
            ''
        );
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        DocGenAiHtmlValidator.Finding f = get(fs, 'A table disappeared');
        System.assertNotEquals(null, f, 'tables carry the layout: ' + fs);
        System.assertEquals(1, f.occurrences);
    }

    @isTest
    static void addingATableIsNotFlagged() {
        String after = BEFORE.replace('</body>', '<table><tr><td>new</td></tr></table></body>');
        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(BEFORE, after);
        Test.stopTest();
        System.assert(!hasRule(fs, 'A table disappeared'), 'adding a table is a normal edit: ' + fs);
    }

    @isTest
    static void cssBlocksAreNotMistakenForMergeTags() {
        // Measured on a real edit 2026-07-26: the extractor reported
        // "{display:block; font-size:16pt; color:#0b4a6f; }" as a lost merge tag
        // three times. A guard that cries wolf is worse than no guard, because
        // it teaches people to skip the warnings that are real.
        String before =
            '<html><head><style>' +
            '.band{display:block; font-size:16pt; font-weight: bold; color:#0b4a6f; }' +
            '.sub{font-size:12pt; margin:0; color:#0b4a6f;}' +
            'tr:nth-child(even){background:#f5f7fa}' +
            '</style></head><body><p style="color:#111; margin:0;">{Name}</p></body></html>';
        // Same document, restyled — no merge tag lost.
        String after =
            '<html><head><style>' +
            '.band{display:block; font-size:18pt; font-weight: bold; color:#184d47; }' +
            '.sub{font-size:11pt; margin:0; color:#184d47;}' +
            'tr:nth-child(odd){background:#eeeeee}' +
            '</style></head><body><p style="color:#222; margin:2pt;">{Name}</p></body></html>';

        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(before, after);
        Test.stopTest();

        System.assert(!hasRule(fs, 'Merge tags lost in the edit'), 'CSS declaration blocks are not merge tags: ' + fs);
    }

    @isTest
    static void aRealTagIsStillCaughtWhenCssIsPresent() {
        // The stripping must not blind the guard to a genuine loss.
        String before =
            '<html><head><style>.b{color:#0b4a6f; font-size:10pt;}</style></head>' +
            '<body><p>{Name}</p><p>{Amount:currency}</p></body></html>';
        String after =
            '<html><head><style>.b{color:#184d47; font-size:12pt;}</style></head>' +
            '<body><p>{Name}</p><p>&nbsp;</p></body></html>';

        Test.startTest();
        List<DocGenAiHtmlValidator.Finding> fs = DocGenAiEditGuard.compare(before, after);
        Test.stopTest();

        DocGenAiHtmlValidator.Finding f = get(fs, 'Merge tags lost in the edit');
        System.assertNotEquals(null, f, 'a real loss must still be caught: ' + fs);
        System.assertEquals(1, f.occurrences, 'exactly one, not the CSS too: ' + f.detail);
        System.assert(f.detail.contains('{Amount:currency}'), f.detail);
    }

    @isTest
    static void blankInputsAreSafe() {
        System.assertEquals(0, DocGenAiEditGuard.compare(null, '<p>x</p>').size());
        System.assertEquals(0, DocGenAiEditGuard.compare('<p>x</p>', null).size());
        System.assertEquals(0, DocGenAiEditGuard.compare('', '').size());
    }
}
