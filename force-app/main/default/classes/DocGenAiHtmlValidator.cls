/**
 * Makes AI-written HTML safe for the DocGen PDF engine, and SAYS what it changed.
 *
 * Flying Saucer (behind Blob.toPdf) is CSS 2.1 plus a small, undocumented CSS 3
 * subset. Modern CSS is not rejected — it is silently ignored, so the page still
 * renders and the layout quietly collapses. A general model asked for "an
 * invoice" returns flexbox, border-radius and rgba() tints every time, however
 * firmly the prompt says otherwise (measured 2026-07-26: GPT-5-mini emitted
 * display:flex three times in a template whose prompt said "CSS 2.1 only").
 *
 * So the constraint set is the asset, not the model access. Every rule below is
 * MEASURED, not inferred — see UserGuide 5.7.3 / 15.11 and the rendered proof in
 * docs/css-capability-probe.png produced by scripts/css-capability-probe.apex.
 *
 * Three kinds of change, and the difference matters to the author:
 *   REPAIRED — we computed the equivalent the engine understands. rgba(0,0,0,.1)
 *              becomes a flat hex; a gradient becomes its first stop. The design
 *              intent survives.
 *   REMOVED  — the engine ignores it, so deleting it changes nothing on the page
 *              and leaves the source honest about what will actually happen.
 *   WARNING  — we cannot fix it and the author must. Left in place.
 *
 * The one that earns this class its keep is rgba(). It does not degrade to a
 * solid colour — it resolves to nothing and the panel renders INVISIBLE. An
 * author looking at a blank box has no way to know why.
 */
public with sharing class DocGenAiHtmlValidator {
    public class Finding {
        @AuraEnabled
        public String action { get; set; } // 'repaired' | 'removed' | 'warning'
        @AuraEnabled
        public String rule { get; set; }
        @AuraEnabled
        public String detail { get; set; }
        @AuraEnabled
        public Integer occurrences { get; set; }

        public Finding(String action, String rule, Integer occurrences, String detail) {
            this.action = action;
            this.rule = rule;
            this.occurrences = occurrences;
            this.detail = detail;
        }
    }

    public class Result {
        @AuraEnabled
        public String html { get; set; }
        @AuraEnabled
        public List<Finding> findings { get; set; }
        @AuraEnabled
        public String summary { get; set; }
        @AuraEnabled
        public Integer repairedCount { get; set; }
        @AuraEnabled
        public Integer removedCount { get; set; }
        @AuraEnabled
        public Integer warningCount { get; set; }
    }

    private String work;
    private final List<Finding> findings = new List<Finding>();

    // -----------------------------------------------------------------------
    // Entry point
    // -----------------------------------------------------------------------

    public static Result sanitize(String rawHtml) {
        DocGenAiHtmlValidator v = new DocGenAiHtmlValidator();
        return v.run(rawHtml);
    }

    private Result run(String rawHtml) {
        Result r = new Result();
        r.findings = this.findings;
        r.html = '';
        r.repairedCount = 0;
        r.removedCount = 0;
        r.warningCount = 0;
        if (String.isBlank(rawHtml)) {
            r.summary = 'Nothing to check — the model returned an empty response.';
            return r;
        }
        this.work = rawHtml;

        stripMarkdownFences();
        stripUnsupportedElements();
        resolveCssVariables();
        repairColours();
        removeIgnoredDeclarations();
        removeModernLayout();
        normaliseFontWeight();
        guardMissingFonts();
        removeMediaQueries();
        repairLoopTagsBetweenRows();
        checkMergeTags();

        r.html = this.work;
        for (Finding f : this.findings) {
            if (f.action == 'repaired') {
                r.repairedCount += f.occurrences;
            } else if (f.action == 'removed') {
                r.removedCount += f.occurrences;
            } else {
                r.warningCount += f.occurrences;
            }
        }
        r.summary = buildSummary(r);
        return r;
    }

    private String buildSummary(Result r) {
        if (this.findings.isEmpty()) {
            return 'Clean — nothing in this template is ignored by the PDF engine.';
        }
        List<String> parts = new List<String>();
        if (r.repairedCount > 0) {
            parts.add(
                'repaired ' +
                    r.repairedCount +
                    (r.repairedCount == 1 ? ' thing' : ' things') +
                    ' the engine renders differently'
            );
        }
        if (r.removedCount > 0) {
            parts.add(
                'removed ' + r.removedCount + (r.removedCount == 1 ? ' thing' : ' things') + ' the engine ignores'
            );
        }
        if (r.warningCount > 0) {
            parts.add(r.warningCount + (r.warningCount == 1 ? ' issue needs' : ' issues need') + ' your attention');
        }
        String s = String.join(parts, ', ');
        return s.substring(0, 1).toUpperCase() + s.substring(1) + '.';
    }

    // -----------------------------------------------------------------------
    // 1. Models wrap output in markdown fences no matter how firmly you ask.
    // -----------------------------------------------------------------------

    private void stripMarkdownFences() {
        String before = this.work;
        this.work = this.work.trim();
        // ```html\n...\n``` or bare ```...```
        this.work = this.work.replaceAll('(?is)^```[a-z]*\\s*\\n', '').replaceAll('(?is)\\n?```\\s*$', '');
        if (before != this.work) {
            note(
                'repaired',
                'Markdown code fence',
                1,
                'Removed the ``` fence the model wrapped the file in — it would have printed as literal text.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 2. Elements the engine drops entirely.
    // -----------------------------------------------------------------------

    private void stripUnsupportedElements() {
        Integer n = countAndStrip('(?is)<script\\b[^>]*>.*?</script\\s*>', '');
        n += countAndStrip('(?is)<script\\b[^>]*/>', '');
        if (n > 0) {
            note('removed', '<script>', n, 'JavaScript never runs — the PDF is rendered server-side from static HTML.');
        }

        n = countAndStrip('(?is)<link\\b[^>]*rel\\s*=\\s*["\\\']?stylesheet["\\\']?[^>]*>', '');
        if (n > 0) {
            note(
                'removed',
                'External stylesheet',
                n,
                'The engine cannot fetch external CSS. Put the rules in the inline <style> block.'
            );
        }

        n = countAndStrip('(?im)^\\s*@import\\b[^;]*;', '');
        if (n > 0) {
            note(
                'removed',
                '@import',
                n,
                'The engine cannot fetch imported CSS. Put the rules in the inline <style> block.'
            );
        }

        n = countMatches('(?is)<svg\\b');
        if (n > 0) {
            countAndStrip('(?is)<svg\\b.*?</svg\\s*>', '');
            note(
                'removed',
                '<svg>',
                n,
                'Flying Saucer drops SVG. Use a raster image, a table-and-border drawing, or a Unicode glyph instead.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 3. CSS custom properties. var() resolves to nothing, so a colour written
    //    that way disappears. Substitute the real value where we can.
    // -----------------------------------------------------------------------

    private void resolveCssVariables() {
        Map<String, String> vars = new Map<String, String>();
        Matcher m = Pattern.compile('(?i)(--[A-Za-z0-9_-]+)\\s*:\\s*([^;}]+)[;}]').matcher(this.work);
        while (m.find()) {
            vars.put(m.group(1).trim(), m.group(2).trim());
        }
        if (vars.isEmpty() && countMatches('(?i)var\\s*\\(') == 0) {
            return;
        }

        Integer resolved = 0;
        Integer unresolved = 0;
        // Two passes so a variable defined in terms of another still lands.
        for (Integer pass = 0; pass < 2; pass++) {
            Matcher vm = Pattern.compile('(?i)var\\s*\\(\\s*(--[A-Za-z0-9_-]+)\\s*(?:,\\s*([^()]*?)\\s*)?\\)')
                .matcher(this.work);
            List<String> sb = new List<String>();
            Integer last = 0;
            Boolean matchedAny = false;
            while (vm.find()) {
                matchedAny = true;
                String name = vm.group(1);
                String fallback = vm.group(2);
                String value = vars.containsKey(name) ? vars.get(name) : fallback;
                if (String.isBlank(value)) {
                    value = 'inherit';
                    unresolved++;
                } else {
                    resolved++;
                }
                sb.add(this.work.substring(last, vm.start()));
                sb.add(value);
                last = vm.end();
            }
            if (!matchedAny) {
                break;
            }
            sb.add(this.work.substring(last));
            this.work = String.join(sb, '');
        }

        Integer declRemoved = countAndStrip('(?i)\\s*--[A-Za-z0-9_-]+\\s*:[^;}]*;', '');
        if (resolved > 0) {
            note(
                'repaired',
                'CSS variable',
                resolved,
                'var(...) resolves to nothing in this engine. Substituted the literal value so the colour/size survives.'
            );
        }
        if (unresolved > 0) {
            note(
                'warning',
                'Unresolved CSS variable',
                unresolved,
                'A var(...) had no definition and no fallback — it now reads "inherit". Set a literal value.'
            );
        }
        if (declRemoved > 0) {
            note(
                'removed',
                'Custom property declaration',
                declRemoved,
                'The --name: value declarations are inert once the values are substituted.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 4. Colour repairs. THE important one.
    // -----------------------------------------------------------------------

    private void repairColours() {
        Integer n = flattenAlphaColour(
            '(?i)rgba\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*([0-9.]+%?)\\s*\\)',
            false
        );
        n += flattenAlphaColour(
            '(?i)rgba?\\(\\s*(\\d{1,3})\\s+(\\d{1,3})\\s+(\\d{1,3})\\s*/\\s*([0-9.]+%?)\\s*\\)',
            false
        );
        if (n > 0) {
            note(
                'repaired',
                'rgba() colour',
                n,
                'rgba() does NOT fall back to a solid colour here — it resolves to nothing and the element renders invisible. Composited the tint over white and wrote it as a flat hex.'
            );
        }

        Integer h = flattenAlphaColour(
            '(?i)hsla\\(\\s*([0-9.]+)(?:deg)?\\s*,\\s*([0-9.]+)%\\s*,\\s*([0-9.]+)%\\s*,\\s*([0-9.]+%?)\\s*\\)',
            true
        );
        if (h > 0) {
            note(
                'repaired',
                'hsla() colour',
                h,
                'Same failure mode as rgba(). Converted to a flat hex composited over white.'
            );
        }

        Integer g = flattenGradients();
        if (g > 0) {
            note(
                'repaired',
                'Gradient',
                g,
                'Gradients are discarded when the stylesheet is parsed. Replaced each with its first colour stop as a solid fill.'
            );
        }
    }

    /** rgba()/hsla() → #rrggbb composited over a white page. */
    private Integer flattenAlphaColour(String regex, Boolean isHsl) {
        Matcher m = Pattern.compile(regex).matcher(this.work);
        List<String> sb = new List<String>();
        Integer last = 0;
        Integer count = 0;
        while (m.find()) {
            Decimal c1 = Decimal.valueOf(m.group(1));
            Decimal c2 = Decimal.valueOf(m.group(2));
            Decimal c3 = Decimal.valueOf(m.group(3));
            String alphaRaw = m.group(4);
            Decimal alpha = alphaRaw.endsWith('%')
                ? Decimal.valueOf(alphaRaw.removeEnd('%')) / 100
                : Decimal.valueOf(alphaRaw);
            List<Integer> rgb = isHsl
                ? hslToRgb(c1, c2, c3)
                : new List<Integer>{ c1.intValue(), c2.intValue(), c3.intValue() };
            sb.add(this.work.substring(last, m.start()));
            sb.add(compositeOverWhite(rgb, alpha));
            last = m.end();
            count++;
        }
        if (count > 0) {
            sb.add(this.work.substring(last));
            this.work = String.join(sb, '');
        }
        return count;
    }

    /** Alpha over a white page background, which is what a PDF page is. */
    private String compositeOverWhite(List<Integer> rgb, Decimal alpha) {
        if (alpha < 0) {
            alpha = 0;
        }
        if (alpha > 1) {
            alpha = 1;
        }
        String hex = '#';
        for (Integer c : rgb) {
            Decimal blended = 255 - ((255 - c) * alpha);
            Integer v = Math.max(0, Math.min(255, blended.round(System.RoundingMode.HALF_UP).intValue()));
            hex += toHex2(v);
        }
        return hex;
    }

    private String toHex2(Integer v) {
        final String DIGITS = '0123456789abcdef';
        return DIGITS.substring(v / 16, (v / 16) + 1) + DIGITS.substring(Math.mod(v, 16), Math.mod(v, 16) + 1);
    }

    private List<Integer> hslToRgb(Decimal hDeg, Decimal sPct, Decimal lPct) {
        // Standard HSL->RGB. h wraps to [0,360); s and l are percentages.
        Double h = hDeg.doubleValue() - (Math.floor(hDeg.doubleValue() / 360.0) * 360.0);
        Double s = sPct.doubleValue() / 100.0;
        Double l = lPct.doubleValue() / 100.0;
        Double c = (1 - Math.abs(2 * l - 1)) * s;
        Double sector = h / 60.0;
        Double x = c * (1 - Math.abs(sector - (Math.floor(sector / 2.0) * 2.0) - 1));
        Double mm = l - c / 2;
        Double r1 = 0;
        Double g1 = 0;
        Double b1 = 0;
        if (h < 60) {
            r1 = c;
            g1 = x;
        } else if (h < 120) {
            r1 = x;
            g1 = c;
        } else if (h < 180) {
            g1 = c;
            b1 = x;
        } else if (h < 240) {
            g1 = x;
            b1 = c;
        } else if (h < 300) {
            r1 = x;
            b1 = c;
        } else {
            r1 = c;
            b1 = x;
        }
        return new List<Integer>{
            Integer.valueOf(Math.round((r1 + mm) * 255)),
            Integer.valueOf(Math.round((g1 + mm) * 255)),
            Integer.valueOf(Math.round((b1 + mm) * 255))
        };
    }

    /** linear/radial/conic-gradient(...) → its first colour stop. */
    private Integer flattenGradients() {
        Matcher m = Pattern.compile('(?i)(?:repeating-)?(?:linear|radial|conic)-gradient\\(([^()]*)\\)')
            .matcher(this.work);
        List<String> sb = new List<String>();
        Integer last = 0;
        Integer count = 0;
        while (m.find()) {
            String stops = m.group(1);
            Matcher cm = Pattern.compile(
                    '(?i)(?:#[0-9a-f]{3,8}|rgb\\([^)]*\\)|\\b(?:white|black|red|blue|green|gray|grey|silver|navy|teal|olive|maroon|purple|orange|yellow)\\b)'
                )
                .matcher(stops);
            String colour = cm.find() ? cm.group(0) : 'transparent';
            sb.add(this.work.substring(last, m.start()));
            sb.add(colour);
            last = m.end();
            count++;
        }
        if (count > 0) {
            sb.add(this.work.substring(last));
            this.work = String.join(sb, '');
        }
        return count;
    }

    // -----------------------------------------------------------------------
    // 5. Declarations the engine silently ignores. Measured, not inferred.
    // -----------------------------------------------------------------------

    private void removeIgnoredDeclarations() {
        // property regex fragment => human explanation
        List<List<String>> rules = new List<List<String>>{
            new List<String>{
                '(?:-fs-)?border-radius(?:-[a-z-]+)?',
                'border-radius',
                'There are no rounded corners — measured on a div, a td, and a border-collapse:separate table, including the engine\'s own -fs-border-radius. Every box is square.'
            },
            new List<String>{ 'box-shadow', 'box-shadow', 'Ignored. Use a solid border for definition instead.' },
            new List<String>{ 'text-shadow', 'text-shadow', 'Ignored.' },
            new List<String>{
                'outline(?:-[a-z]+)?',
                'outline',
                'Ignored. Use border, which does render (including dashed and dotted).'
            },
            new List<String>{
                'opacity',
                'opacity',
                'Ignored — the element renders at full strength. Pick a lighter hex colour instead.'
            },
            new List<String>{ 'transform(?:-[a-z]+)?', 'transform', 'Ignored. There is no rotation or scaling.' },
            new List<String>{
                'transition(?:-[a-z]+)?',
                'transition',
                'Ignored — a PDF has no interaction to transition.'
            },
            new List<String>{ 'animation(?:-[a-z]+)?', 'animation', 'Ignored — a PDF has no animation.' },
            new List<String>{
                'box-sizing',
                'box-sizing',
                'Ignored. Widths are content-box; subtract padding and border yourself.'
            },
            new List<String>{
                'overflow-wrap',
                'overflow-wrap',
                'Ignored. The engine breaks at spaces and nowhere else — use <wbr/> for unbreakable values.'
            },
            new List<String>{ 'word-break', 'word-break', 'Ignored. Use <wbr/> at each allowed break point instead.' },
            new List<String>{
                'column-(?:count|gap|rule|width)|columns',
                'CSS columns',
                'Ignored. Use a table with one row and a cell per column.'
            },
            new List<String>{ 'filter|backdrop-filter', 'filter', 'Ignored.' }
        };
        for (List<String> rule : rules) {
            Integer n = countAndStrip('(?i)(?<![-\\w])(?:' + rule[0] + ')\\s*:[^;}"\\\']*;?', '');
            if (n > 0) {
                note('removed', rule[1], n, rule[2]);
            }
        }

        // calc() cannot be evaluated here — the whole declaration has to go.
        Integer c = countAndStrip('(?i)(?<![-\\w])[a-z-]+\\s*:[^;}"\\\']*\\bcalc\\([^;}"\\\']*;?', '');
        if (c > 0) {
            note(
                'removed',
                'calc()',
                c,
                'Ignored, which usually collapses the element to zero or auto. Work the literal value out and write it in pt or in.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 6. Flexbox and grid. This is the one that visibly wrecks a layout: the
    //    declaration is ignored, the children fall back to block flow, and a
    //    side-by-side header stacks vertically.
    // -----------------------------------------------------------------------

    private void removeModernLayout() {
        Integer displays = countAndStrip('(?i)(?<![-\\w])display\\s*:\\s*(?:inline-)?(?:flex|grid)\\s*;?', '');
        Integer companions = 0;
        List<String> props = new List<String>{
            'justify-content',
            'justify-items',
            'justify-self',
            'align-content',
            'align-items',
            'align-self',
            'place-content',
            'place-items',
            'place-self',
            'flex',
            'flex-grow',
            'flex-shrink',
            'flex-basis',
            'flex-direction',
            'flex-wrap',
            'flex-flow',
            'order',
            'gap',
            'row-gap',
            'column-gap',
            'grid',
            'grid-template',
            'grid-template-columns',
            'grid-template-rows',
            'grid-template-areas',
            'grid-area',
            'grid-column',
            'grid-row',
            'grid-auto-flow',
            'grid-auto-columns',
            'grid-auto-rows'
        };
        for (String p : props) {
            companions += countAndStrip('(?i)(?<![-\\w])' + p + '\\s*:[^;}"\\\']*;?', '');
        }
        if (displays > 0) {
            note(
                'warning',
                'display:flex / display:grid',
                displays,
                'The engine ignores flex and grid, so the children fall back to block flow and stack vertically. Rebuild each of these as a <table> with one <tr> and a <td> per column — that is the only side-by-side layout available.'
            );
        }
        if (companions > 0) {
            note(
                'removed',
                'Flex/grid alignment properties',
                companions,
                'Inert without flex or grid. Use text-align and vertical-align on the table cells instead.'
            );
        }

        Integer pos = countAndStrip('(?i)(?<![-\\w])position\\s*:\\s*(?:absolute|fixed|sticky)\\s*;?', '');
        if (pos > 0) {
            note(
                'warning',
                'position: absolute/fixed/sticky',
                pos,
                'Not honoured in the page flow. For content that repeats on every page use the template\'s Header HTML / Footer HTML fields.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 7. Numeric font-weight. The engine has regular and bold faces; 600 lands
    //    on whichever the face-matching picks, usually regular, so a heading
    //    the author expected to be semibold prints as body text.
    // -----------------------------------------------------------------------

    private void normaliseFontWeight() {
        Matcher m = Pattern.compile('(?i)(?<![-\\w])font-weight\\s*:\\s*([1-9]00)').matcher(this.work);
        List<String> sb = new List<String>();
        Integer last = 0;
        Integer count = 0;
        while (m.find()) {
            Integer w = Integer.valueOf(m.group(1));
            sb.add(this.work.substring(last, m.start()));
            sb.add('font-weight: ' + (w >= 600 ? 'bold' : 'normal'));
            last = m.end();
            count++;
        }
        if (count > 0) {
            sb.add(this.work.substring(last));
            this.work = String.join(sb, '');
            note(
                'repaired',
                'Numeric font-weight',
                count,
                'Only normal and bold exist here. Mapped 600 and above to bold, below to normal, so the emphasis is not lost.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 8. ZapfDingbats / Symbol. Worse than an ignored property: nothing fails,
    //    the font falls back to a serif face, and the letter "l" the author used
    //    to draw a filled circle is typeset literally into the document.
    // -----------------------------------------------------------------------

    private void guardMissingFonts() {
        Integer n = countMatches(
            '(?i)font-family\\s*:[^;}"\\\']*\\b(?:ZapfDingbats|Zapf Dingbats|Symbol|Wingdings|Webdings)\\b'
        );
        if (n > 0) {
            this.work = this.work.replaceAll(
                '(?i)\\s*,?\\s*["\\\']?\\b(?:ZapfDingbats|Zapf Dingbats|Symbol|Wingdings|Webdings)\\b["\\\']?',
                ''
            );
            note(
                'warning',
                'Dingbat font',
                n,
                'ZapfDingbats, Symbol and Wingdings are NOT installed in the render engine — the letter falls back to a serif face and prints a literal "l" or "m" where a shape was intended. Removed the font, but check the character: circles must be Unicode glyphs (&#9679; filled, &#9675; hollow, &#8226; bullet) sized with font-size.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 9. @media. Ignored wholesale, so anything styled only inside one never
    //    applies. Deleting it makes the source honest.
    // -----------------------------------------------------------------------

    private void removeMediaQueries() {
        Integer n = 0;
        // Nested braces mean one regex will not do it — walk the block instead.
        while (true) {
            Matcher m = Pattern.compile('(?i)@media\\b[^{]*\\{').matcher(this.work);
            if (!m.find()) {
                break;
            }
            Integer depth = 1;
            Integer i = m.end();
            while (i < this.work.length() && depth > 0) {
                String ch = this.work.substring(i, i + 1);
                if (ch == '{') {
                    depth++;
                } else if (ch == '}') {
                    depth--;
                }
                i++;
            }
            this.work = this.work.substring(0, m.start()) + this.work.substring(Math.min(i, this.work.length()));
            n++;
            if (n > 50) {
                break;
            }
        }
        if (n > 0) {
            note(
                'removed',
                '@media query',
                n,
                'Media queries never match — the engine has no viewport. Any rule that only lived inside one was never going to apply; move it to the main stylesheet if you meant it.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // 10. The single most common structural mistake a model makes with DocGen:
    //     putting the loop tags on their own lines around a <tr> instead of
    //     inside its cells. Text placed directly inside a <table> is
    //     foster-parented out by the HTML parser, so the loop never expands the
    //     row. Reproduced on the first real generation, 2026-07-26.
    // -----------------------------------------------------------------------

    private void repairLoopTagsBetweenRows() {
        Matcher m = Pattern.compile('(?is)\\{#([A-Za-z0-9_]+)\\}\\s*(<tr\\b.*?</tr\\s*>)\\s*\\{/\\1\\}')
            .matcher(this.work);
        List<String> sb = new List<String>();
        Integer last = 0;
        Integer fixed = 0;
        Integer couldNotFix = 0;
        while (m.find()) {
            String rel = m.group(1);
            String row = m.group(2);
            String rebuilt = injectLoopIntoRow(row, rel);
            sb.add(this.work.substring(last, m.start()));
            if (rebuilt == null) {
                sb.add(m.group(0));
                couldNotFix++;
            } else {
                sb.add(rebuilt);
                fixed++;
            }
            last = m.end();
        }
        if (fixed > 0 || couldNotFix > 0) {
            sb.add(this.work.substring(last));
            this.work = String.join(sb, '');
        }
        if (fixed > 0) {
            note(
                'repaired',
                'Loop tag placed between rows',
                fixed,
                'A {#Relationship} tag sitting between <tr> elements is foster-parented out of the table by the HTML parser, so the row never repeats. Moved the opening tag into the first cell and the closing tag into the last cell of the same row, which is what makes the engine expand it.'
            );
        }
        if (couldNotFix > 0) {
            note(
                'warning',
                'Loop tag outside a cell',
                couldNotFix,
                'A loop wraps a row that has no <td> or <th> to move the tags into. Put {#Rel} in the first cell and {/Rel} in the last cell of the repeating row.'
            );
        }

        // {#Rel}<table>...</table>{/Rel} repeats the ENTIRE table, headers and
        // all, once per child. Too ambiguous to auto-fix — say so plainly.
        Integer wholeTable = countMatches('(?is)\\{#([A-Za-z0-9_]+)\\}\\s*<table\\b');
        if (wholeTable > 0) {
            note(
                'warning',
                'Loop wraps the whole table',
                wholeTable,
                'This repeats the entire table — column headers and all — once per child record. Move {#Rel} into the first cell of the data row and {/Rel} into its last cell, and leave the <thead> outside the loop.'
            );
        }
    }

    /** Put {#rel} after the first cell's opening tag and {/rel} before the last cell's close. */
    private String injectLoopIntoRow(String row, String rel) {
        Matcher firstCell = Pattern.compile('(?is)<(td|th)\\b[^>]*>').matcher(row);
        if (!firstCell.find()) {
            return null;
        }
        Integer openEnd = firstCell.end();
        Integer lastClose = Math.max(row.toLowerCase().lastIndexOf('</td'), row.toLowerCase().lastIndexOf('</th'));
        if (lastClose < openEnd) {
            return null;
        }
        return row.substring(0, openEnd) +
            '{#' +
            rel +
            '}' +
            row.substring(openEnd, lastClose) +
            '{/' +
            rel +
            '}' +
            row.substring(lastClose);
    }

    // -----------------------------------------------------------------------
    // 11. Merge-tag sanity.
    // -----------------------------------------------------------------------

    private void checkMergeTags() {
        Integer page = countMatches('\\{(?:PageNumber|TotalPages)\\}');
        if (page > 0) {
            note(
                'warning',
                '{PageNumber} in the body',
                page,
                'Page counters only resolve inside the template\'s Header HTML / Footer HTML fields. In the body they render as empty text. Move them, or delete them.'
            );
        }

        Integer opens = countMatches('\\{');
        Integer closes = countMatches('\\}');
        if (opens != closes) {
            note(
                'warning',
                'Unbalanced merge braces',
                Math.abs(opens - closes),
                'The counts of { and } do not match (' +
                    opens +
                    ' vs ' +
                    closes +
                    '). An unclosed brace fails the whole merge. For a literal brace use &#123; and &#125;.'
            );
        }
    }

    // -----------------------------------------------------------------------
    // helpers
    // -----------------------------------------------------------------------

    private void note(String action, String rule, Integer occurrences, String detail) {
        this.findings.add(new Finding(action, rule, occurrences, detail));
    }

    private Integer countMatches(String regex) {
        Matcher m = Pattern.compile(regex).matcher(this.work);
        Integer n = 0;
        while (m.find()) {
            n++;
        }
        return n;
    }

    private Integer countAndStrip(String regex, String replacement) {
        Integer n = countMatches(regex);
        if (n > 0) {
            this.work = this.work.replaceAll(regex, replacement);
        }
        return n;
    }
}
