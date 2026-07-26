/**
 * Compares the template that went INTO an AI edit with the one that came back.
 *
 * Editing is riskier than generating. A fresh generation that goes wrong is
 * obviously wrong — you look at it and start again. An edit that goes wrong is
 * subtly wrong: the model returns a plausible document that quietly dropped
 * {Amount:currency} from the totals row, or truncated the second page, and the
 * loss is invisible in the canvas until a customer document renders blank where
 * a number should be.
 *
 * The prompt tells the model in the strongest terms to preserve everything it
 * was not asked to change. This class assumes it will sometimes do it anyway,
 * and says so. It never blocks or rewrites — the author decides. Losing a merge
 * tag can be exactly what was asked for.
 *
 * The previous body is always recoverable: every save writes a NEW
 * ContentVersion (docgen_html_body_<templateId>_<ts>) and the reader takes the
 * latest, so prior bodies remain in the file history.
 */
public with sharing class DocGenAiEditGuard {
    /** Below this ratio of surviving characters, the edit looks like a truncation. */
    private static final Decimal SHRINK_WARN_RATIO = 0.6;

    /**
     * @param before HTML sent to the model.
     * @param after  Validated HTML that came back.
     * @return Findings to append to the validator's own report. Empty when the
     *         edit looks faithful.
     */
    public static List<DocGenAiHtmlValidator.Finding> compare(String before, String after) {
        List<DocGenAiHtmlValidator.Finding> findings = new List<DocGenAiHtmlValidator.Finding>();
        if (String.isBlank(before) || String.isBlank(after)) {
            return findings;
        }

        // 1. Merge tags that existed before and are gone now. This is the one
        //    that silently ruins a document, so it is reported first and by name.
        Set<String> lostTags = missingTags(before, after);
        if (!lostTags.isEmpty()) {
            List<String> sorted = new List<String>(lostTags);
            sorted.sort();
            Integer shown = Math.min(sorted.size(), 8);
            List<String> head = new List<String>();
            for (Integer i = 0; i < shown; i++) {
                head.add(sorted[i]);
            }
            String sample = String.join(head, ', ');
            if (sorted.size() > shown) {
                sample += ' and ' + (sorted.size() - shown) + ' more';
            }
            findings.add(
                new DocGenAiHtmlValidator.Finding(
                    'warning',
                    'Merge tags lost in the edit',
                    sorted.size(),
                    'These tags were in the template before this edit and are not in the result: ' +
                        sample +
                        '. Each one is a live data binding — wherever it used to be, the document will now render nothing. If you did not ask for them to go, use Reload to get the previous body back, or re-run the edit with a narrower instruction.'
                )
            );
        }

        // 2. Wholesale shrinkage — the classic "model summarised instead of
        //    editing" or "ran out of output tokens mid-document" failure.
        Decimal ratio = Decimal.valueOf(after.length()) / Decimal.valueOf(before.length());
        if (ratio < SHRINK_WARN_RATIO) {
            findings.add(
                new DocGenAiHtmlValidator.Finding(
                    'warning',
                    'The edit came back much shorter',
                    1,
                    'The template went from ' +
                        before.length() +
                        ' characters to ' +
                        after.length() +
                        ' (' +
                        (ratio * 100).setScale(0) +
                        '%). A model asked to edit will sometimes summarise the document or stop early instead. Check the end of the template is still there before you save a new version.'
                )
            );
        }

        // 3. Structural landmarks that should survive an ordinary edit.
        if (before.containsIgnoreCase('@page') && !after.containsIgnoreCase('@page')) {
            findings.add(
                new DocGenAiHtmlValidator.Finding(
                    'warning',
                    'Page setup rule dropped',
                    1,
                    'The @page rule that sets page size and margins is gone. The PDF will fall back to the engine default.'
                )
            );
        }
        Integer tablesBefore = countOccurrences(before.toLowerCase(), '<table');
        Integer tablesAfter = countOccurrences(after.toLowerCase(), '<table');
        if (tablesAfter < tablesBefore) {
            findings.add(
                new DocGenAiHtmlValidator.Finding(
                    'warning',
                    'A table disappeared',
                    tablesBefore - tablesAfter,
                    'The template had ' +
                        tablesBefore +
                        ' tables and now has ' +
                        tablesAfter +
                        '. Tables carry the layout here, so check nothing you wanted is missing.'
                )
            );
        }
        return findings;
    }

    /** Merge tags present in `before` but absent from `after`. */
    @TestVisible
    private static Set<String> missingTags(String before, String after) {
        Set<String> lost = new Set<String>();
        for (String tag : extractTags(before)) {
            if (!after.contains(tag)) {
                lost.add(tag);
            }
        }
        return lost;
    }

    /**
     * Every {...} in the document. Closing loop tags are skipped: a loop whose
     * opener survived is intact, and reporting both halves doubles the noise.
     *
     * CSS is removed first, because a declaration block is also brace-wrapped
     * and looks exactly like a merge tag to a regex. Measured on a real edit:
     * without this, `{display:block; font-size:16pt; color:#0b4a6f; }` was
     * reported as a lost merge tag three times over, which is worse than no
     * guard at all — a warning nobody can act on trains people to ignore the
     * ones that matter.
     */
    @TestVisible
    private static Set<String> extractTags(String html) {
        Set<String> tags = new Set<String>();
        Matcher m = Pattern.compile('\\{[^{}\\n]{1,120}\\}').matcher(stripCss(html));
        while (m.find()) {
            String t = m.group(0);
            if (t.startsWith('{/') || t == '{:else}') {
                continue;
            }
            // A semicolon means a CSS declaration list, never a merge tag.
            if (t.contains(';')) {
                continue;
            }
            tags.add(t);
        }
        return tags;
    }

    /** <style> blocks and style="" attributes — the only places CSS braces live. */
    @TestVisible
    private static String stripCss(String html) {
        String s = html.replaceAll('(?is)<style\\b[^>]*>.*?</style\\s*>', ' ');
        s = s.replaceAll('(?is)\\sstyle\\s*=\\s*"[^"]*"', ' ');
        s = s.replaceAll('(?is)\\sstyle\\s*=\\s*\\\'[^\\\']*\\\'', ' ');
        return s;
    }

    private static Integer countOccurrences(String haystack, String needle) {
        Integer n = 0;
        Integer i = haystack.indexOf(needle);
        while (i != -1) {
            n++;
            i = haystack.indexOf(needle, i + needle.length());
        }
        return n;
    }
}
