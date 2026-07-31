# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-31T16:14:23.636Z · **Duration** 401s

## Headline

|                       |            |
| --------------------- | ---------- |
| Checks evaluated      | 81         |
| Passed                | 78 (96.3%) |
| Failed                | 3          |
| Skipped (not counted) | 2          |
| Blockers              | 0          |
| Major                 | 2          |
| Minor                 | 1          |

## Coverage by area

| Suite       | Area        | Passed | Failed | Skipped |  Rate |
| ----------- | ----------- | -----: | -----: | ------: | ----: |
| `ui-runner` | End-user UI |     78 |      3 |       2 | 96.3% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity  | Suite       | Check                                                                          | Evidence                                                                                                                                                                                                                                                                                                       |
| --------- | ----------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **major** | `ui-runner` | picker hides a template that has no active version                             | "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObjectInternal filters on Is_Active**c/audience but never checks for an active DocGen_Template_Version**c.   |
| **major** | `ui-runner` | a record-filtered template is not silently applied to excluded records in bulk | "UIQA Filtered Out" carries a Record_Filter\_\_c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the per-record check. Documents can be generated for records the template excludes. Either the batch mu |
| **minor** | `ui-runner` | a filter that matches no records leaves Run disabled                           | Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns on a 0 count so no analysis blocks it (docGenBulkRunner.js isRunDisabled / runAnalysis).              |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `ui-runner` — a user without the DocGen permission set gets a clear message, not a broken UI: the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previously got reported as the component rendering nothing — a product defect that did not exist. Set the password once by hand and this check runs.
- `ui-runner` — a Document Packet contains every document it was built from: could not move templates into the packet: nothing reached the "In Packet" column — the move did not take

## Every check

### ui-runner — End-user UI

- ✅ runner template picker offers an active, usable template for the record — picker returned: UIQA Good PDF, UIQA Locked Format, UIQA No Version — DocGenController.getTemplatesForObjectAndRecord
- ✅ picker hides a template whose Record_Filter**c excludes this record — Record_Filter**c = Industry = 'Agriculture'; the record is Technology. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides a template requiring a permission set the user lacks — Required_Permission_Sets\_\_c = UIQA_No_Such_PermSet. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides an inactive template — Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ❌ picker hides a template that has no active version — "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObject
- ✅ generating from the picked template produces a real document — DocGenService.processDocument returned 66207 bytes
- ✅ the generated document's title resolves merge tokens against the record — Document_Title_Format\_\_c = "UIQA-ms957llt {Name}" → title was "UIQA-ms957llt UIQA Alpha", expected "UIQA-ms957llt UIQA Alpha"
- ✅ a locked output format cannot be overridden at run time — Lock_Output_Format\_\_c = true, override 'Word' → "This template locks its output format. Override not permitted."
- ✅ a template with no active version fails with a message, not a blank document — got: Error retrieving template data: No template file found (active or attached).
- ✅ bulk template picker excludes deactivated templates — matches the single-record runner
- ❌ a record-filtered template is not silently applied to excluded records in bulk — "UIQA Filtered Out" carries a Record_Filter\_\_c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the
- ✅ the runner shows an actionable empty state when no template matches the record — with every Account template inactive the runner rendered 581 chars; Create Document disabled=true. The user must be told WHY there is nothing to pick, and must not be able to press a button that canno
- ✅ docGenRunner renders on a record page — rendered 568 chars, 2 picker(s), 1 primary button(s)
- ✅ the runner shows neither an error nor an empty state on a record that has templates — component text starts: DocGen Create or combine documents for this record. Create Document Document Packet Combine PDFs Category All Categories Test UIQA (Uncategorized) Select Template Choose a templ
- ✅ docGenRunner boots without a console error
- ✅ the record-page template picker lists a template the user can actually run — picker showed: Choose a template... / Account / Certificate / [Test] E2E Test Template / ffff / PDFQA Giant Chrome / playa / test / Test2 / test3 / test345 / test99 / [UIQA] UIQA Good PDF / [UIQA] UIQ
- ✅ the record-page picker applies the active and audience rules — Inactive, Record_Filter\_\_c-excluded and permission-gated templates were all withheld
- ✅ the template picker is reachable by a mouse — found=true hit=ok
- ✅ choosing a category narrows the template list to that category — after picking category "UIQA" the picker showed: [UIQA] UIQA Good PDF / [UIQA] UIQA Locked Format / [UIQA] UIQA No Version
- ✅ the Save to Record output choice is reachable — found=true hit=ok
- ✅ choosing Save to Record is honoured by the UI — output pills after the click: download, save(active), both
- ✅ the Create Document button is reachable — found=true hit=ok
- ✅ pressing Create Document in Save to Record mode puts the document ON the record — ContentDocument "UIQA-ms957llt UIQA Alpha" linked to 001O50000432dmHIAQ
- ✅ the saved file is in the template's own output format — Output_Format\_\_c = PDF, file extension = .pdf
- ✅ choosing Download is honoured by the UI — output pills after the click: download(active), save, both
- ✅ pressing Create Document in Download mode downloads the document to the browser — the browser received "UIQA-ms957llt UIQA Alpha.pdf"
- ✅ Download does NOT also attach the document to the record — files linked to the record: 3 before the run, 3 after. Download and Save to Record are the two halves of one choice; honouring it means Download leaves the record untouched.
- ✅ choosing Save & Download is honoured by the UI — output pills after the click: download, save, both(active)
- ✅ Save & Download hands the file to the browser — the browser received "UIQA-ms957llt UIQA Alpha.pdf"
- ✅ Save & Download also attaches the document to the record — files linked to the record: 3 before the run, 4 after. A download alone would leave this unchanged — which is exactly the bug this mode exists to avoid.
- ✅ a template with Lock_Output_Format\_\_c exposes no runtime file-format control — with the locked template selected the runner offered 2 picker(s) (category + template) and the choice widgets [both, download, save], which are output DESTINATIONS, not formats. The server half of thi
- ✅ the Document Packet tab renders its template chooser and it is reachable — packet tab active=true, dual listboxes=1, source list hit=ok
- ✅ the packet chooser offers the record's PDF templates — chooser offered 17 template(s): Account / Certificate / E2E Test Template / ffff / PDFQA Giant Chrome / playa
- ✅ the Create Packet button is reachable and refuses to run with nothing chosen — button hit=ok, disabled=true
- ✅ the Combine PDFs tab lists the record's existing PDFs and they are reachable — tab active=true, source list hit=ok, it offered 2 file(s) of which 2 are the two PDFs this suite attached to the record
- ✅ the Combine PDFs button is reachable and refuses to run with fewer than two files chosen — button hit=ok, disabled=true with nothing moved into the Combine list
- ✅ docGenSignatureSender renders on a record page — rendered 321 chars with its template picker, signer table and send button
- ✅ docGenSignatureSender boots without a console error
- ✅ the send button refuses to send with no document and no signer details — found=true disabled=true
- ✅ the signature document picker is reachable — found=true hit=ok
- ✅ the signature document picker offers the record’s templates and they can be clicked — found=true hit=ok
- ✅ a document alone is not enough to send — the signer is still required — with a template chosen and the signer row blank, the send button is disabled=true
- ✅ every signer field is reachable by a mouse — role=ok name=ok email=ok
- ✅ a signer with no email address cannot be sent to — role and name filled, email blank → send button disabled=true
- ✅ a complete document + signer enables the send button — role, name and email all filled → send button disabled=false
- ✅ the send button is reachable by a mouse — found=true hit=ok
- ✅ sending a signature request tells the user it worked — component text: Signature Links Generated! Provide each signer with their unique secure link: UIQA-ms957llt Signer Signer https://<CONFIGURE_SITE_URL_IN_SETUP>/apex/portwoodglobal\_\_DocGenSignaturePdf?
- ✅ sending writes a DocGen_Signature_Request\_\_c tied to this record and template — request a08O5000014KMCrIAO: record=001O50000432dmHIAQ (expected 001O50000432dmHIAQ), status=Sent, order=Parallel, sourceDoc=068O500000MQWm2IAH
- ✅ sending writes exactly one DocGen_Signer\_\_c carrying what was typed — 1 signer row(s) (expected 1); first = name "UIQA-ms957llt Signer" (typed "UIQA-ms957llt Signer"), email "uiqa-ms957llt@example.com" (typed "uiqa-ms957llt@example.com"), role "Signer" (typed "Signer"),
- ✅ bulk generation UI renders on its tab — {"chars":251,"hasHeading":true,"hasStep1":true}
- ✅ bulk generation UI boots without a console error
- ✅ the screen stays usable while a job is still running — template search box is hittable with 1 non-terminal job(s) present
- ✅ focusing the template box lists the available templates — 20 options offered
- ✅ typing narrows the template list to the match — after typing "UIQA Good": UIQA Good PDF (Account • PDF)
- ✅ a search with no matches says so instead of showing an empty box — expected the "No templates found" empty state in the dropdown
- ✅ a template option can be clicked — found=true hit=ok
- ✅ selecting a template opens the filter and run steps — Step 2 (Record Filter) and Step 3 (Run Generation) must appear once a template is chosen
- ✅ the bulk screen offers no file-format override — format stays the template’s — Output Mode options: Individual Files / Print-Ready Packet / Combined + Individual
- ✅ choosing an output mode is honoured by the UI — after picking "Individual Files" the control reads "Individual Files"
- ✅ the Validate Filter button is clickable — found=true hit=ok
- ✅ Validate reports the true number of matching records — expected "2 Records Found" for Name LIKE 'UIQA%' (2 accounts seeded); component text did not contain it
- ✅ the Run button is clickable once the filter is validated — found=true hit=ok
- ✅ pressing Run creates a bulk job on the server — DocGen_Job\_\_c a03O500003ig5fGIAQ status Completed
- ✅ the job generates one document per matching record — status=Completed total=2 success=2 errors=0; error log:
- ✅ each generated document is attached to its own record — 6 pdf files across 2 records (expected 1 each on 2 records) — Output Mode was Individual Files
- ✅ the output honours the template's Output Format (PDF) — extensions produced: pdf
- ✅ a run where every record fails is reported as failed, not as success — status=Failed success=0 errors=2
- ✅ the failing job records WHY each record failed — Error_Log\_\_c = 001O50000432dmHIAQ — portwoodglobal.DocGenException: Error retrieving template data: No template file found (active or attached). 001O50000432dmIIAQ — portwoodglobal.DocGenException: Er
- ✅ the Recent Jobs list shows the error count to the user — Recent Jobs did not show "UIQA-ms957llt-err" with "2 errors" — a user would see the run as finished with no indication anything went wrong
- ❌ a filter that matches no records leaves Run disabled — Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns
- ✅ the DocGen Command Hub renders with its navigation — {"present":true,"navs":["My Templates","Bulk Generation","Signatures","Assets","Buttons","Email Templates","Learning Center","MoreTabs","API Name Help Info","Type Help Info","Word","PDF"]}
- ✅ Command Hub "Bulk Generation" mounts its component — rendered 372 chars of text; consoleErrors=none
- ✅ Command Hub "Signatures" mounts its component — rendered 1263 chars of text; consoleErrors=none
- ✅ Command Hub "Assets" mounts its component — rendered 489 chars of text; consoleErrors=none
- ✅ Command Hub "Email Templates" mounts its component — rendered 1534 chars of text; consoleErrors=none
- ✅ the document Button builder mounts from the Command Hub — rendered 994 chars of text
- ✅ the DocGen quick action is reachable by a mouse — clickable on the highlights panel
- ✅ a retired or wrong-object button configuration never appears — getButtons returned only QA_Account_Doc — the inactive fixture and the Contact fixture were both withheld, so the component takes its run-immediately branch
- ✅ pressing the record action does not error — the action screen had already closed itself, which it only does after a successful generate
- ✅ the record action delivers a document to the browser — downloaded "QA Button Document.pdf"
- ✅ Save To Record = false leaves the record untouched — 5 files before and after
- ⊘ a user without the DocGen permission set gets a clear message, not a broken UI — the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previousl
- ⊘ a Document Packet contains every document it was built from — could not move templates into the packet: nothing reached the "In Packet" column — the move did not take
