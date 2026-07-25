# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T18:12:33.412Z · **Duration** 741s

## Headline

|                       |            |
| --------------------- | ---------- |
| Checks evaluated      | 58         |
| Passed                | 45 (77.6%) |
| Failed                | 13         |
| Skipped (not counted) | 0          |
| Blockers              | 0          |
| Major                 | 1          |
| Minor                 | 12         |

## Coverage by area

| Suite       | Area      | Passed | Failed | Skipped |  Rate |
| ----------- | --------- | -----: | -----: | ------: | ----: |
| `apex-unit` | Apex unit |     45 |     13 |       0 | 77.6% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity  | Suite       | Check                                                    | Evidence                                                               |
| --------- | ----------- | -------------------------------------------------------- | ---------------------------------------------------------------------- |
| **major** | `apex-unit` | DocGenPdfPreparedBodyQueueable is exercised by some test | 0% — 30 lines, none covered. Nothing would notice if this class broke. |
| **minor** | `apex-unit` | DocGenHtmlRenderer meets the 75% packaging bar           | 74% (2319/3150 lines)                                                  |
| **minor** | `apex-unit` | DocGenFlsGuard meets the 75% packaging bar               | 69% (118/172 lines)                                                    |
| **minor** | `apex-unit` | DocGenSvgChartSerializer meets the 75% packaging bar     | 43% (415/973 lines)                                                    |
| **minor** | `apex-unit` | DocGenSignatureGuestSecurity meets the 75% packaging bar | 63% (20/32 lines)                                                      |
| **minor** | `apex-unit` | DocGenApprovalHistory meets the 75% packaging bar        | 9% (4/44 lines)                                                        |
| **minor** | `apex-unit` | DocGenController meets the 75% packaging bar             | 71% (2609/3697 lines)                                                  |
| **minor** | `apex-unit` | DocGenAcroFormService meets the 75% packaging bar        | 65% (746/1154 lines)                                                   |
| **minor** | `apex-unit` | DocGenSignatureService meets the 75% packaging bar       | 54% (575/1065 lines)                                                   |
| **minor** | `apex-unit` | DocGenGiantQueryAssembler meets the 75% packaging bar    | 58% (562/962 lines)                                                    |
| **minor** | `apex-unit` | DocGenErrorLogger meets the 75% packaging bar            | 74% (52/70 lines)                                                      |
| **minor** | `apex-unit` | DocGenGiantQueryFlowAction meets the 75% packaging bar   | 47% (44/93 lines)                                                      |
| **minor** | `apex-unit` | DocGenFieldWritebackTrigger meets the 75% packaging bar  | 67% (4/6 lines)                                                        |

## Every check

### apex-unit — Apex unit

- ✅ the Apex test run passes — 1766 tests, 100%
- ✅ DocGenAuthenticatorController meets the 75% packaging bar — 100% (78/78 lines)
- ✅ DocGenSignatureExpiry meets the 75% packaging bar — 100% (28/28 lines)
- ❌ DocGenHtmlRenderer meets the 75% packaging bar — 74% (2319/3150 lines)
- ❌ DocGenFlsGuard meets the 75% packaging bar — 69% (118/172 lines)
- ✅ DocGenFieldWritebackService meets the 75% packaging bar — 90% (218/243 lines)
- ✅ DocGenGiantQueryBatch meets the 75% packaging bar — 85% (276/325 lines)
- ❌ DocGenSvgChartSerializer meets the 75% packaging bar — 43% (415/973 lines)
- ✅ DocGenSignatureEmailService meets the 75% packaging bar — 81% (195/242 lines)
- ✅ DocGenContentDocumentCleanupQueueable meets the 75% packaging bar — 92% (11/12 lines)
- ✅ DocGenBulkGiantFallbackJob meets the 75% packaging bar — 84% (37/44 lines)
- ❌ DocGenPdfPreparedBodyQueueable is exercised by some test — 0% — 30 lines, none covered. Nothing would notice if this class broke.
- ✅ DocGenSignatureSenderController meets the 75% packaging bar — 85% (1371/1604 lines)
- ✅ DocGenSigner meets the 75% packaging bar — 100% (1/1 lines)
- ✅ DocGenChartImageController meets the 75% packaging bar — 90% (266/297 lines)
- ✅ DocGenBatch meets the 75% packaging bar — 87% (233/269 lines)
- ❌ DocGenSignatureGuestSecurity meets the 75% packaging bar — 63% (20/32 lines)
- ✅ DocGenBulkFlowAction meets the 75% packaging bar — 100% (48/48 lines)
- ✅ DocGenSignatureReminderSchedulable meets the 75% packaging bar — 96% (89/93 lines)
- ✅ DocGenTemplateManager meets the 75% packaging bar — 91% (32/35 lines)
- ✅ DocGenChartFont meets the 75% packaging bar — 100% (1359/1361 lines)
- ✅ DocGenPngEncoder meets the 75% packaging bar — 95% (134/141 lines)
- ✅ BarcodeGenerator meets the 75% packaging bar — 99% (587/594 lines)
- ✅ DocGenButtonAdminController meets the 75% packaging bar — 80% (106/132 lines)
- ❌ DocGenApprovalHistory meets the 75% packaging bar — 9% (4/44 lines)
- ✅ DocGenSignatureController meets the 75% packaging bar — 84% (1222/1449 lines)
- ✅ DocGenSignatureFlowAction meets the 75% packaging bar — 97% (135/139 lines)
- ❌ DocGenController meets the 75% packaging bar — 71% (2609/3697 lines)
- ✅ DocGenSetupController meets the 75% packaging bar — 89% (211/236 lines)
- ❌ DocGenAcroFormService meets the 75% packaging bar — 65% (746/1154 lines)
- ✅ DocGenEmailTemplateInstall meets the 75% packaging bar — 100% (35/35 lines)
- ✅ DocGenChartBucketResolver meets the 75% packaging bar — 89% (661/742 lines)
- ✅ DocGenSignatureValidator meets the 75% packaging bar — 100% (12/12 lines)
- ✅ DocGenPdfSaveQueueable meets the 75% packaging bar — 100% (8/8 lines)
- ✅ DocGenDataRetriever meets the 75% packaging bar — 78% (987/1269 lines)
- ✅ DocGenChartRasterizer meets the 75% packaging bar — 91% (834/914 lines)
- ✅ DocGenEmailTemplateController meets the 75% packaging bar — 88% (262/299 lines)
- ✅ DocGenSignatureFinalizer meets the 75% packaging bar — 100% (3/3 lines)
- ✅ DocGenFlowAction meets the 75% packaging bar — 91% (97/107 lines)
- ✅ DocGenAssetKeyHandler meets the 75% packaging bar — 93% (38/41 lines)
- ✅ DocGenSignatureSubmitter meets the 75% packaging bar — 100% (12/12 lines)
- ❌ DocGenSignatureService meets the 75% packaging bar — 54% (575/1065 lines)
- ✅ DocGenChartTagExpander meets the 75% packaging bar — 95% (280/294 lines)
- ✅ DocGenEmailTemplateService meets the 75% packaging bar — 93% (358/383 lines)
- ❌ DocGenGiantQueryAssembler meets the 75% packaging bar — 58% (562/962 lines)
- ❌ DocGenErrorLogger meets the 75% packaging bar — 74% (52/70 lines)
- ✅ DocGenService meets the 75% packaging bar — 81% (4458/5505 lines)
- ✅ DocGenGiantQueryStitchJob meets the 75% packaging bar — 91% (156/171 lines)
- ✅ DocGenSignaturePdfFlowAction meets the 75% packaging bar — 87% (61/70 lines)
- ✅ DocGenMergeJob meets the 75% packaging bar — 90% (84/93 lines)
- ✅ DocGenButtonController meets the 75% packaging bar — 81% (135/167 lines)
- ✅ DocGenGuestRenderQueueable meets the 75% packaging bar — 100% (1/1 lines)
- ✅ DocGenBulkController meets the 75% packaging bar — 91% (392/433 lines)
- ❌ DocGenGiantQueryFlowAction meets the 75% packaging bar — 47% (44/93 lines)
- ✅ DocGenSignaturePdfTrigger meets the 75% packaging bar — 90% (74/82 lines)
- ❌ DocGenFieldWritebackTrigger meets the 75% packaging bar — 67% (4/6 lines)
- ✅ DocGenAssetKeyTrigger meets the 75% packaging bar — 100% (1/1 lines)
- ✅ org-wide coverage is at or above 75% — 78% (23054/29461 lines) — a 2GP build fails below 75%
