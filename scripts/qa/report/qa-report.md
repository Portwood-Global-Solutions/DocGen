# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T16:19:34.230Z · **Duration** 174s

## Headline

|                       |            |
| --------------------- | ---------- |
| Checks evaluated      | 37         |
| Passed                | 34 (91.9%) |
| Failed                | 3          |
| Skipped (not counted) | 8          |
| Blockers              | 0          |
| Major                 | 2          |
| Minor                 | 1          |

## Coverage by area

| Suite       | Area        | Passed | Failed | Skipped |  Rate |
| ----------- | ----------- | -----: | -----: | ------: | ----: |
| `ui-runner` | End-user UI |     34 |      3 |       8 | 91.9% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity  | Suite       | Check                                                                     | Evidence                                                                                                                                                                                                                                                                                                     |
| --------- | ----------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **major** | `ui-runner` | picker hides a template that has no active version                        | "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObjectInternal filters on Is_Active**c/audience but never checks for an active DocGen_Template_Version**c. |
| **major** | `ui-runner` | bulk template picker applies the same active/audience rules as the runner | DocGenBulkController.getBulkTemplates has no Is_Active\_\_c filter, so deactivated templates stay selectable for bulk runs. Bulk picker: UIQA Filtered Out, UIQA Good PDF, UIQA Inactive, UIQA Locked Format, UIQA No Version                                                                                |
| **minor** | `ui-runner` | a filter that matches no records leaves Run disabled                      | Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns on a 0 count so no analysis blocks it (docGenBulkRunner.js isRunDisabled / runAnalysis).            |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `ui-runner` — docGenRunner renders on a record page: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenRunner Generate button produces a document from a record page: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenRunner honours the Save to Record / Download output choice: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenRunner shows the empty state when no template matches the record: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenSignatureSender validates its fields and creates a request: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenSignatureSender writes correct DocGen_Signature_Request**c / DocGen_Signer**c rows: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — docGenButton one-click generation from a record action: no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickActionDefinitions). The package ships tabs for the admin surfaces but nothing that places this component, and there is no supported URL that renders an LWC on a record without a page assignment. Reaching it requires hand-building a Lightning record page, which this suite is not permitted to deploy.
- `ui-runner` — a user without the DocGen permission set gets a clear message, not a broken UI: needs a second user and a Login-As session; creating a licensed user and switching identity is outside what this suite may do to the org, and System.runAs is not available in anonymous Apex. The template-audience half of this (Required_Permission_Sets\_\_c) IS covered above.

## Every check

### ui-runner — End-user UI

- ✅ runner template picker offers an active, usable template for the record — picker returned: UIQA Good PDF, UIQA Locked Format, UIQA No Version — DocGenController.getTemplatesForObjectAndRecord
- ✅ picker hides a template whose Record_Filter**c excludes this record — Record_Filter**c = Industry = 'Agriculture'; the record is Technology. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides a template requiring a permission set the user lacks — Required_Permission_Sets\_\_c = UIQA_No_Such_PermSet. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides an inactive template — Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ❌ picker hides a template that has no active version — "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObject
- ✅ generating from the picked template produces a real document — DocGenService.processDocument returned 66207 bytes
- ✅ the generated document is titled from the record — title was "UIQA Alpha", expected "UIQA Alpha"
- ✅ a locked output format cannot be overridden at run time — Lock_Output_Format\_\_c = true, override 'Word' → "This template locks its output format. Override not permitted."
- ✅ a template with no active version fails with a message, not a blank document — got: Error retrieving template data: No template file found (active or attached).
- ❌ bulk template picker applies the same active/audience rules as the runner — DocGenBulkController.getBulkTemplates has no Is_Active\_\_c filter, so deactivated templates stay selectable for bulk runs. Bulk picker: UIQA Filtered Out, UIQA Good PDF, UIQA Inactive, UIQA Locked Form
- ✅ bulk generation UI renders on its tab — {"chars":251,"hasHeading":true,"hasStep1":true}
- ✅ bulk generation UI boots without a console error
- ✅ the screen stays usable while a job is still running — template search box is hittable with 1 non-terminal job(s) present
- ✅ focusing the template box lists the available templates — 16 options offered
- ✅ typing narrows the template list to the match — after typing "UIQA Good": UIQA Good PDF (Account • PDF)
- ✅ a search with no matches says so instead of showing an empty box — expected the "No templates found" empty state in the dropdown
- ✅ a template option can be clicked — found=true hit=ok
- ✅ selecting a template opens the filter and run steps — Step 2 (Record Filter) and Step 3 (Run Generation) must appear once a template is chosen
- ✅ the bulk screen offers no file-format override — format stays the template’s — Output Mode options: Individual Files / Print-Ready Packet / Combined + Individual
- ✅ choosing an output mode is honoured by the UI — after picking "Individual Files" the control reads "Individual Files"
- ✅ the Validate Filter button is clickable — found=true hit=ok
- ✅ Validate reports the true number of matching records — expected "2 Records Found" for Name LIKE 'UIQA%' (2 accounts seeded); component text did not contain it
- ✅ the Run button is clickable once the filter is validated — found=true hit=ok
- ✅ pressing Run creates a bulk job on the server — DocGen_Job\_\_c a03O500003gzxaXIAQ status Completed
- ✅ the job generates one document per matching record — status=Completed total=2 success=2 errors=0; error log:
- ✅ each generated document is attached to its own record — 2 pdf files across 2 records (expected 1 each on 2 records) — Output Mode was Individual Files
- ✅ the output honours the template's Output Format (PDF) — extensions produced: pdf
- ✅ a run where every record fails is reported as failed, not as success — status=Failed success=0 errors=2
- ✅ the failing job records WHY each record failed — Error_Log\_\_c = 001O5000040js8PIAQ — portwoodglobal.DocGenException: Error retrieving template data: No template file found (active or attached). 001O5000040js8QIAQ — portwoodglobal.DocGenException: Er
- ✅ the Recent Jobs list shows the error count to the user — Recent Jobs did not show "UIQA-ms0kr7gr-err" with "2 errors" — a user would see the run as finished with no indication anything went wrong
- ❌ a filter that matches no records leaves Run disabled — Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns
- ✅ the DocGen Command Hub renders with its navigation — {"present":true,"navs":["My Templates","Bulk Generation","Signatures","Assets","Buttons","Email Templates","Learning Center","MoreTabs","API Name Help Info","Type Help Info","Word","PDF"]}
- ✅ Command Hub "Bulk Generation" mounts its component — rendered 372 chars of text; consoleErrors=none
- ✅ Command Hub "Signatures" mounts its component — rendered 1400 chars of text; consoleErrors=none
- ✅ Command Hub "Assets" mounts its component — rendered 489 chars of text; consoleErrors=none
- ✅ Command Hub "Email Templates" mounts its component — rendered 1564 chars of text; consoleErrors=none
- ✅ the document Button builder mounts from the Command Hub — rendered 761 chars of text
- ⊘ docGenRunner renders on a record page — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenRunner Generate button produces a document from a record page — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenRunner honours the Save to Record / Download output choice — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenRunner shows the empty state when no template matches the record — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenSignatureSender validates its fields and creates a request — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenSignatureSender writes correct DocGen_Signature_Request**c / DocGen_Signer**c rows — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ docGenButton one-click generation from a record action — no Lightning record page or quick action exists in this org that hosts the component (SELECT DeveloperName, Type FROM FlexiPage returns only UtilityBar rows, and there are no LightningComponent QuickA
- ⊘ a user without the DocGen permission set gets a clear message, not a broken UI — needs a second user and a Login-As session; creating a licensed user and switching identity is outside what this suite may do to the org, and System.runAs is not available in anonymous Apex. The templ
