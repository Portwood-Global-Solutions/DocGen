# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T15:39:25.333Z · **Duration** 12s

## Headline

|                       |            |
| --------------------- | ---------- |
| Checks evaluated      | 180        |
| Passed                | 180 (100%) |
| Failed                | 0          |
| Skipped (not counted) | 4          |
| Blockers              | 0          |
| Major                 | 0          |
| Minor                 | 0          |

## Coverage by area

| Suite        | Area       | Passed | Failed | Skipped | Rate |
| ------------ | ---------- | -----: | -----: | ------: | ---: |
| `merge-tags` | Merge tags |    180 |      0 |       4 | 100% |

## What to fix

Nothing — every evaluated check passed.

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `merge-tags` — HTML-template escaping ({Field} newline → <br/>) behaves correctly: processXmlForTest(xml, data, templateType) is @TestVisible private and unreachable from anonymous Apex, so every check here runs the Word branch; HTML/Excel/PowerPoint escaping needs a unit test or a real HTML template render
- `merge-tags` — {PageNumber}/{TotalPages} render real page numbers in the PDF: processXml only preserves the tokens; the @page counter substitution happens in wrapHtmlForPdf and can only be verified on a rendered PDF (output-formats suite)
- `merge-tags` — {%ImageField} with a real ContentVersion renders an embedded image: needs an uploaded ContentVersion fixture and a real DOCX/PDF render; covered by scripts/e2e-09-images.apex, not by this parser-level probe
- `merge-tags` — The giant-query parent path resolves the same tag surface: DocGenGiantQueryAssembler.resolveParentMergeTags / resolveGiantChartBuckets do not go through processXmlForTest and need >2000 child rows to exercise

## Every check

### merge-tags — Merge tags

- ✅ probe "fields+built-ins" stays under the 20,000-char anonymous Apex limit — 5494 chars
- ✅ {Name} resolves a plain field — actual: Acme Corp
- ✅ {Account.Name} resolves a parent relationship field — actual: Parent Co
- ✅ {Account.Owner.Name} resolves two hops up — actual: Deep Owner
- ✅ {name} resolves case-insensitively — actual: Acme Corp
- ✅ {!Name} (Salesforce-style prefix) resolves like {Name} — actual: Acme Corp
- ✅ { Name } tolerates whitespace inside the braces — actual: Acme Corp
- ✅ {Missing} (no such key) renders empty, not the raw tag — actual: <empty>
- ✅ {NullF} (key present, value null) renders empty — actual: <empty>
- ✅ {Blank} (empty-string value) renders empty — actual: <empty>
- ✅ {Account.Missing} (missing subfield) renders empty — actual: <empty>
- ✅ {Nope.Sub} (missing relationship) renders empty, no throw — actual: <empty>
- ✅ {Nope.A.B.C} (deep missing path) renders empty, no throw — actual: <empty>
- ✅ Text around an unresolved tag survives intact — actual: before after
- ✅ Two tags in one text node both resolve — actual: Acme Corp/Won
- ✅ {Today:yyyy-MM-dd} equals the org calendar date — actual: 2026-07-25
- ✅ {Today:MMMM d, yyyy} formats the date — actual: July 25, 2026
- ✅ {Today} renders a date containing the current year — actual: 2026-07-25 07:00:00
- ✅ {Now:yyyy-MM-dd HH:mm} formats a timestamp — actual: 2026-07-25 08:39
- ✅ {RunningUser.Name} resolves the executing user — actual: User User
- ✅ {RunningUser.Email} resolves the executing user email — actual: dave@portwood.dev
- ✅ {runninguser.name} resolves case-insensitively — actual: User User
- ✅ {RunningUser.ProfileId} (outside the allowlist) renders empty — actual: <empty>
- ✅ {PageNumber} survives processXml verbatim for the PDF counter layer — actual: {PageNumber}
- ✅ {TotalPages} survives processXml verbatim — actual: {TotalPages}
- ✅ {pagenumber} is preserved case-insensitively — actual: {pagenumber}
- ✅ "Page {PageNumber} of {TotalPages}" passes through untouched — actual: Page {PageNumber} of {TotalPages}
- ✅ probe "formats" stays under the 20,000-char anonymous Apex limit — 5167 chars
- ✅ {Amt:currency} formats US dollars with separators — actual: $75,000.50
- ✅ {Amt:currency:EUR} uses the euro symbol — actual: €75,000.50
- ✅ {Amt:currency:EUR:de_DE} uses German separators — actual: 75.000,50 €
- ✅ {Amt:currency:JPY} rounds to zero decimals — actual: ¥75,001
- ✅ {Amt:currency:auto} falls back to $ when no ISO is on the record — actual: $75,000.50
- ✅ {Rate:percent} renders a percent sign — actual: 15.5%
- ✅ {Qty:number} groups thousands — actual: 1,234,567
- ✅ {Qty:#,##0} honours a custom numeric pattern — actual: 1,234,567
- ✅ {Amt:0.00} honours a two-decimal pattern — actual: 75,000.50
- ✅ {Text:currency} on non-numeric text degrades to the raw value — actual: not-a-number
- ✅ {Active:checkbox} renders [X] when true — actual: [X]
- ✅ {Inactive:checkbox} renders [ ] when false — actual: [ ]
- ✅ {D:MM/dd/yyyy} formats a DateTime — actual: 04/08/2026
- ✅ {D:MMMM d, yyyy} formats a DateTime long-form — actual: April 8, 2026
- ✅ {D:HH:mm} formats the time component — actual: 13:45
- ✅ {D:date:de_DE} uses the German date pattern — actual: 08.04.2026
- ✅ {D:date} renders a locale date, not an ISO timestamp — actual: 04/08/2026
- ✅ {DateStr:MM/dd/yyyy} re-types a "yyyy-MM-dd" string and formats it — actual: 04/08/2026
- ✅ {DateStr} on a date-string shows no 00:00:00 time tail — actual: 04/08/2026
- ✅ {DateStr} keeps the calendar day (no timezone shift) — actual: 04/08/2026
- ✅ {IsoStr:yyyy} re-types an ISO datetime string — actual: 2026
- ✅ {Stage:label} falls back to the raw value with no label map — actual: Won
- ✅ {Name:upper} (unsupported suffix) is ignored, not printed — actual: Acme Corp
- ✅ probe "sections+loops" stays under the 20,000-char anonymous Apex limit — 8152 chars
- ✅ {#Items}...{/Items} repeats the body once per row — actual: [Item A][Item B][Item C]
- ✅ {#Items} over an empty list renders nothing and leaks no tag — actual: <empty>
- ✅ {#Empty}...{:else}... renders the else branch for 0 rows — actual: none
- ✅ {#Rel} iterates a {totalSize, records} relationship wrapper — actual: [W1][W2]
- ✅ {#Rel} over non-record entries renders nothing rather than throwing — actual: <empty>
- ✅ {#Rows} over 60 rows emits every row (crosses the heap-check boundary) — actual: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,
- ✅ {#Rows} over 60 rows includes the last row — actual: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,
- ✅ Nested {#Orders}{#Lines} loops expand inner rows per outer row — actual: [O1(L1a)(L1b)][O2(L2a)]
- ✅ A parent field inside {#Items} is out of scope (renders empty) — actual: [][][]
- ✅ {index} inside a plain {#Items} loop leaks no literal tag — actual: [][][]
- ✅ {count} inside a plain {#Items} loop leaks no literal tag — actual: [][][]
- ✅ {#Flag} shows the body when the field is true — actual: Yes
- ✅ {#Flag} hides the body when the field is false — actual: <empty>
- ✅ {#Field} treats a non-blank string as truthy — actual: Y
- ✅ {#Field} treats an empty string as falsy — actual: <empty>
- ✅ {#Field} treats visually-blank rich text (<p><br></p>) as falsy — actual: <empty>
- ✅ {^Field} shows for visually-blank rich text (symmetric with {#}) — actual: N
- ✅ {^Flag} shows the body when the field is false — actual: No
- ✅ {^Flag} hides the body when the field is true — actual: <empty>
- ✅ {#Flag}Y{:else}N{/Flag} takes the true branch — actual: Y
- ✅ {#Flag}Y{:else}N{/Flag} takes the else branch — actual: N
- ✅ {^Flag}Y{:else}N{/Flag} takes the else branch when truthy — actual: N
- ✅ {#Parent}{Field}{/Parent} scopes into a related map — actual: Parent Co
- ✅ {#IF Amount > 10000} evaluates a numeric comparison — actual: Big
- ✅ {#IF Amount &gt; 10000} works with the OOXML-escaped operator — actual: Big
- ✅ {#IF Amount < 100} is false for a large value — actual: <empty>
- ✅ {#IF Stage = 'Won'} matches a single-quoted literal — actual: C
- ✅ {#IF Stage = "Won"} matches a double-quoted literal — actual: C
- ✅ {#IF Stage != 'Lost'} evaluates inequality — actual: A
- ✅ {#IF a AND b} evaluates a conjunction — actual: B
- ✅ {#IF a OR b} evaluates a disjunction — actual: B
- ✅ {#IF NOT(...)} negates a comparison — actual: B
- ✅ {#IF ...}{:else}... falls to the else branch on a missing field — actual: Y
- ✅ Nested {#IF} blocks pair with the right {/IF} — actual: D
- ✅ A conditional inside a loop evaluates per row — actual: [Item A][Item B]
- ✅ A loop inside <w:tr> clones the whole table row per record — actual: <w:tbl><w:tr><w:tc><w:t>Item A</w:t></w:tc></w:tr><w:tr><w:tc><w:t>Item B</w:t></w:tc></w:tr><w:tr><w:tc><w:t>Item C</w:t></w:tc></w:tr></w:tbl>
- ✅ A loop inside <w:tr> keeps every row value — actual: <w:tbl><w:tr><w:tc><w:t>Item A</w:t></w:tc></w:tr><w:tr><w:tc><w:t>Item B</w:t></w:tc></w:tr><w:tr><w:tc><w:t>Item C</w:t></w:tc></w:tr></w:tbl>
- ✅ probe "aggregates+media" stays under the 20,000-char anonymous Apex limit — 6193 chars
- ✅ {SUM:Items.Amount} totals a child collection — actual: 350
- ✅ {COUNT:Items} counts a child collection — actual: 3
- ✅ {AVG:Items.Amount} averages a child collection — actual: 116.67
- ✅ {MIN:Items.Amount} returns the smallest value — actual: 50
- ✅ {MAX:Items.Amount} returns the largest value — actual: 200
- ✅ {sum:Items.Amount} accepts a lower-case function name — actual: 350
- ✅ {SUM:Items.Amount:currency} applies a format suffix to the total — actual: $350.00
- ✅ {COUNT:Empty} over an empty collection renders 0 — actual: 0
- ✅ {SUM:Empty.Amount} over an empty collection renders 0 — actual: 0
- ✅ {COUNT:Nope} on a missing relationship renders 0, no throw — actual: 0
- ✅ {SUM:Items.Nope} on a missing field renders 0, no throw — actual: 0
- ✅ {Nope:bar} (colon tag, unknown function) renders empty, not an error — actual: <empty>
- ✅ {\*Field} defaults to a code128 barcode marker — actual: ##BARCODE:code128::ABC-123&amp;X##
- ✅ {\*Field:qr} emits a QR marker — actual: ##BARCODE:qr::ABC-123&amp;X##
- ✅ {\*Field:qr:200} carries the size through — actual: ##BARCODE:qr:200:ABC-123&amp;X##
- ✅ {\*Field:code128:300x80} carries a WxH size through — actual: ##BARCODE:code128:300x80:ABC-123&amp;X##
- ✅ {\*Field:code39} emits a code39 marker — actual: ##BARCODE:code39::ABC-123&amp;X##
- ✅ {\*Field} XML-escapes the barcode value — actual: ##BARCODE:qr::ABC-123&amp;X##
- ✅ {\*NullF:qr} on a null value emits nothing — actual: <empty>
- ✅ {%Field} on a null image field emits nothing (no broken markup) — actual: <empty>
- ✅ {%Field:200x100} on a null image field emits nothing — actual: <empty>
- ✅ {%Image:1} with no attached image emits nothing — actual: <empty>
- ✅ {%asset:key} for an unknown asset renders a visible placeholder — actual: [missing asset: dgqa_no_such_asset]
- ✅ {%asset:key} inside src="" emits a URL, not a nested <img> — actual: <img src="">
- ✅ probe "edge cases" stays under the 20,000-char anonymous Apex limit — 7195 chars
- ✅ A value containing "<" is XML-escaped — actual: R&amp;D &lt;Widgets&gt; &quot;Q1&quot; it&apos;s
- ✅ A value containing "<" leaves no raw markup in the output — actual: R&amp;D &lt;Widgets&gt; &quot;Q1&quot; it&apos;s
- ✅ A value containing "&" is XML-escaped — actual: R&amp;D &lt;Widgets&gt; &quot;Q1&quot; it&apos;s
- ✅ A value containing quotes is XML-escaped — actual: R&amp;D &lt;Widgets&gt; &quot;Q1&quot; it&apos;s
- ✅ A tag inside href="" escapes the query-string ampersand — actual: <a href="https://ex.test/a?b=1&amp;c=2">x</a>
- ✅ A tag inside href="" keeps the attribute well-formed — actual: <a href="https://ex.test/a?b=1&amp;c=2">x</a>
- ✅ A unicode + emoji value round-trips unchanged — actual: Zürich 東京 😀
- ✅ A 4,000-character value is not truncated — actual: 0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789<T
- ✅ A multi-line value becomes Word line breaks, not literal newlines — actual: <w:r><w:t>Line1</w:t></w:r><w:r><w:br/></w:r><w:r><w:t xml:space="preserve">Line2</w:t></w:r>
- ✅ A multi-line value keeps both lines — actual: <w:r><w:t>Line1</w:t></w:r><w:r><w:br/></w:r><w:r><w:t xml:space="preserve">Line2</w:t></w:r>
- ✅ A field value that looks like a merge tag is not re-parsed — actual: {Secret}
- ✅ A field value that looks like a merge tag renders literally — actual: {Secret}
- ✅ {unclosed (no closing brace) throws a named error — actual: THREW portwoodglobal.DocGenException: Malformed merge tag: missing closing "}" near "{unclosed b". Check for an unclosed tag in the template.
- ✅ {#Items} with no {/Items} throws a named error — actual: THREW portwoodglobal.DocGenException: Malformed loop tag: missing closing "{/Items}" for "{#Items}" opened near "{#Items}{Name}".
- ✅ {^Flag} with no {/Flag} throws a named error — actual: THREW portwoodglobal.DocGenException: Malformed inverse tag: missing closing "{/Active}" for "{^Active}" opened near "{^Active}x".
- ✅ A malformed-loop error names the offending tag — actual: THREW portwoodglobal.DocGenException: Malformed loop tag: missing closing "{/Items}" for "{#Items}" opened near "{#Items}{Name}".
- ✅ {} (empty tag) renders nothing and does not throw — actual: ab
- ✅ {/Orphan} with no opener is emitted literally so the author sees the typo — actual: a{/Orphan}b
- ✅ {{nested}} resolves the inner tag to empty and passes the trailing brace through — actual: }
- ✅ {{nested}} does not print the inner tag name — actual: }
- ✅ A tag split across <w:r> runs resolves after run de-fragmentation — actual: <w:r><w:t>Acme Corp</w:t></w:r><w:r><w:t></w:t></w:r>
- ✅ A tag with a format suffix split across runs resolves — actual: <w:r><w:t>$75,000.50</w:t></w:r><w:r><w:t></w:t></w:r>
- ✅ A split tag does NOT resolve without de-fragmentation (documents the dependency) — actual: <w:r><w:t></w:t></w:r>
- ✅ {RepeatHeader} injects <w:tblHeader/> into its table row — actual: <w:tbl><w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Head</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
- ✅ {RepeatHeader} text is stripped from the rendered row — actual: <w:tbl><w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Head</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
- ✅ {RepeatHeader} never renders as literal text even without a table row — actual: xy
- ✅ {@Signature_X} is stripped during normal generation — actual: ab
- ✅ {@Signature_X} is preserved when preserveSignatureTags is on — actual: {@Signature_Buyer}
- ✅ {?key} is preserved until the finalize re-render — actual: {?title}
- ✅ {?key} resolves from \_\_formFields at finalize — actual: CTO
- ✅ {?key\|fallback} uses the fallback when unanswered — actual: N/A
- ✅ {?key} XML-escapes the collected value — actual: &lt;b&gt;&amp;
- ✅ probe "chart buckets (in-memory)" stays under the 20,000-char anonymous Apex limit — 6157 chars
- ✅ {#ChartBucket:rel:field} buckets by value, sorted desc by count — actual: [Bus:3][Car:2][Ash:1][Bike:1][:1]
- ✅ {#ChartBucket} breaks count ties alphabetically by key — actual: Bus,Car,Ash,Bike,,
- ✅ {percent} is the share of all rows — actual: [37.5][25.0][12.5][12.5][12.5]
- ✅ {max_percent} is 100 for the largest bucket — actual: [100.0][66.7][33.3][33.3][33.3]
- ✅ {max_percent} scales the runner-up against the largest bucket — actual: [100.0][66.7][33.3][33.3][33.3]
- ✅ {index} is a 1-based bucket counter — actual: 1,2,3,4,5,
- ✅ {color} cycles the default palette starting at #3b82f6 — actual: [#3b82f6][#10b981][#f59e0b][#ef4444][#8b5cf6]
- ✅ {color_hex} emits raw hex with no leading # (for Word w:shd) — actual: [3b82f6][10b981][f59e0b][ef4444][8b5cf6]
- ✅ {key_label} labels a null/blank bucket "Not Specified" — actual: [Bus][Car][Ash][Bike][Not Specified]
- ✅ {key} for a null value is empty, not the "**null**" sentinel — actual: [Bus][Car][Ash][Bike][]
- ✅ colors= overrides the palette, cycling by row index — actual: [#111111][#222222][#111111][#222222][#111111]
- ✅ split=; splits multi-select values per respondent — actual: [Bus:2][Car:2][Bike:1]
- ✅ split=; counts every selection, not just the first — actual: [Bus:2][Car:2][Bike:1]
- ✅ split=; produces no combined "Bus;Car" bucket — actual: [Bus][Car][Bike]
- ✅ colors= and split= compose in one tag — actual: [Bus#111111][Car#111111][Bike#111111]
- ✅ {#ChartBucket} over an empty collection renders nothing, leaks no tag — actual: xy
- ✅ {#ChartBucket} nested inside a loop resolves against the iteration item — actual: [Inner]
- ✅ {#ChartBucket} on an unknown relationship renders nothing, no throw — actual: xy
- ✅ {#ChartBucket} on an unknown field buckets everything as blank, no throw — actual: [:8]
- ✅ {#ChartBucket:onlyOneArg} fails loudly instead of rendering garbage — actual: THREW portwoodglobal.DocGenException: Malformed loop tag: missing closing "{/ChartBucket:Answers}" for "{#ChartBucket:Answers}" opened near "{#ChartBucket:Answers}[{key}]{/ChartBuck".
- ✅ Two {#ChartBucket} tags on one page each get their own bucket list — actual: [Bus][Car][Ash][Bike][]&#124;[Bus][Bus;Car][Car;Bike]
- ✅ probe "chart buckets (SOQL modifiers)" stays under the 20,000-char anonymous Apex limit — 5068 chars
- ✅ {#ChartBucket} falls back to a SOQL aggregate when the relationship is not pre-loaded — actual: [Bus:3][Car:1][Bike:1]
- ✅ The SOQL fallback returns every bucket, not just the largest — actual: [Bus:3][Car:1][Bike:1]
- ✅ where= filters the aggregate server-side — actual: [Bus:2][Bike:1]
- ✅ where= excludes non-matching rows entirely — actual: [Bus][Bike]
- ✅ where= with an injection attempt renders nothing rather than running — actual: <empty>
- ✅ groupBy= builds a cross-tab with a {#cols} sub-list — actual: [Bus(Eng:2)(Sales:1)(Total:3)][Bike(Eng:1)(Sales:0)(Total:1)][Car(Eng:0)(Sales:1)(Total:1)]
- ✅ groupBy= counts the right cell (Bus x Eng = 2) — actual: [Bus(Eng:2)(Sales:1)(Total:3)][Bike(Eng:1)(Sales:0)(Total:1)][Car(Eng:0)(Sales:1)(Total:1)]
- ✅ groupBy= appends a synthetic Total column last — actual: [Bus(Eng:2)(Sales:1)(Total:3)][Bike(Eng:1)(Sales:0)(Total:1)][Car(Eng:0)(Sales:1)(Total:1)]
- ✅ colSort= orders the pivot columns as the author named them — actual: [(Sales)(Eng)(Total)][(Sales)(Eng)(Total)][(Sales)(Eng)(Total)]
- ✅ {#ChartBucket} on a field the child object lacks renders nothing, no throw — actual: xy
- ⊘ HTML-template escaping ({Field} newline → <br/>) behaves correctly — processXmlForTest(xml, data, templateType) is @TestVisible private and unreachable from anonymous Apex, so every check here runs the Word branch; HTML/Excel/PowerPoint escaping needs a unit test or a
- ⊘ {PageNumber}/{TotalPages} render real page numbers in the PDF — processXml only preserves the tokens; the @page counter substitution happens in wrapHtmlForPdf and can only be verified on a rendered PDF (output-formats suite)
- ⊘ {%ImageField} with a real ContentVersion renders an embedded image — needs an uploaded ContentVersion fixture and a real DOCX/PDF render; covered by scripts/e2e-09-images.apex, not by this parser-level probe
- ⊘ The giant-query parent path resolves the same tag surface — DocGenGiantQueryAssembler.resolveParentMergeTags / resolveGiantChartBuckets do not go through processXmlForTest and need >2000 child rows to exercise
