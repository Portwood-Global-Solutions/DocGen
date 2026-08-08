# DocGen QA report

**Org** `designer-ns` · **Run** 2026-08-08T10:27:53.858Z · **Duration** 652s

## Headline

| | |
| --- | --- |
| Checks evaluated | 313 |
| Passed | 308 (98.4%) |
| Failed | 5 |
| Skipped (not counted) | 9 |
| Blockers | 5 |
| Major | 0 |
| Minor | 0 |

## Coverage by area

| Suite | Area | Passed | Failed | Skipped | Rate |
| --- | --- | ---: | ---: | ---: | ---: |
| `apex-e2e` | Apex end-to-end | 16 | 0 | 0 | 100% |
| `ui-admin` | Admin UI | 41 | 4 | 8 | 91.1% |
| `record-pages` | Record pages | 250 | 0 | 0 | 100% |
| `template-integrity` | Template integrity | 1 | 1 | 1 | 50% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity | Suite | Check | Evidence |
| --- | --- | --- | --- |
| **blocker** | `ui-admin` | the canvas path creates the template record | no record was created by "Create & Open Canvas" |
| **blocker** | `ui-admin` | and it is typed Canvas, which is what decides which editor opens | no record |
| **blocker** | `ui-admin` | the canvas path lands on the artboard | the artboard (.dg-board) never appeared |
| **blocker** | `ui-admin` | row action Edit opens the edit modal | the modal never opened, so nothing inside it could be tested |
| **blocker** | `template-integrity` | every HTML template returns a body to the visual Designer | 3 of 6 return NOTHING — those open to an empty canvas however well they generate. The Designer reads a ContentVersion titled docgen_html_body_<templateId>, not the version's Content_Version_Id__c: Chart Scale Demo (client-side) &#124; Flow Spike &#124; Flow Spike 3 |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `ui-admin` — the floating panels open with their contents rendered: the designer never opened
- `ui-admin` — row action View opens the template on its Copy-Paste Tags tab: could not drive the row menu: row "QAUI-k8e3j7-Starter": no row
- `ui-admin` — row action Export downloads a valid .docgen.json bundle: no download event fired: row "QAUI-k8e3j7-Starter": no row
- `ui-admin` — Import Template restores an exported bundle as a new template: nothing was exported to import
- `ui-admin` — row action Design opens that template in the designer: could not drive the row menu: row "QAUI-k8e3j7-Starter": no row
- `ui-admin` — the edit modal tabs render their panels: the edit modal never opened
- `ui-admin` — Save as New Version persists the edited fields: the edit modal never opened
- `ui-admin` — closing the modal with unsaved edits warns or preserves them: the edit modal never opened
- `template-integrity` — merge-tag pills stay inside their table cells: could not open a template in the Designer: no Designer tab

## Every check

### apex-e2e — Apex end-to-end

- ✅ Permissions: e2e-01-permissions.apex — 49 assertions
- ✅ Template CRUD: e2e-02-template-crud.apex — 10 assertions
- ✅ PDF generation: e2e-03-generate-pdf.apex — 14 assertions
- ✅ Page setup: e2e-03b-page-setup.apex — 3 assertions
- ✅ DOCX generation: e2e-04-generate-docx.apex — 15 assertions
- ✅ Bulk generation: e2e-05-generate-bulk.apex — 18 assertions
- ✅ Signatures: e2e-06-signatures.apex — 25 assertions
- ✅ Signature lifecycle: e2e-06b-signature-lifecycle.apex — 8 assertions
- ✅ Signature redemption: e2e-06c-signing.apex — 13 assertions
- ✅ PIN gate + decline: e2e-06d-pin-and-decline.apex — 12 assertions
- ✅ Merge-tag syntax: e2e-07-syntax1.apex — 35 assertions
- ✅ Merge-tag syntax: e2e-07-syntax2.apex — 31 assertions
- ✅ Merge-tag syntax: e2e-07-syntax3.apex — 18 assertions
- ✅ Merge-tag syntax: e2e-07-syntax4.apex — 20 assertions
- ✅ Images: e2e-09-images.apex — 8 assertions
- ✅ Cleanup: e2e-08-cleanup.apex — 13 assertions

### ui-admin — Admin UI

- ✅ admin app mounts with its three main tabs — Create New \| Your Templates \| Designer (Beta) \| More Tabs
- ✅ main tab "Create New" is reachable by a mouse
- ✅ main tab "Your Templates" is reachable by a mouse
- ✅ main tab "Designer" is reachable by a mouse
- ✅ main tab "Your Templates" swaps in its own content
- ✅ main tab "Create New" swaps in its own content
- ✅ authoring card "file" is reachable by a mouse
- ✅ authoring card "file" selects and reveals the Type / Output Format pickers — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "canvas" is reachable by a mouse
- ✅ authoring card "canvas" selects and reveals the Canvas setup fields — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ Advanced options discloses the power-user fields — Data Source radio group visible before=false after=true
- ✅ creating with an empty name is refused with a visible error — Error notification. Name it first Give the template a name, then create. Press Command + F6 to navigate to the next toas
- ✅ a refused create writes no template record
- ✅ wizard Next refuses to advance without a name — error shown; still on step 1 = true
- ✅ wizard Next advances to step 2 (Pick Your Data)
- ✅ wizard Back returns to step 1 and keeps what was typed — onStep1=true name="QAUI-k8e3j7-File" (expected "QAUI-k8e3j7-File")
- ✅ wizard step 2 refuses an empty query — Error notification. Error Please add at least one field to the query. Press Command + F6 to navigate to the next toast n
- ✅ wizard step 3 reviews the name, object and query it will save — reviewScreen=true nameEchoed=true queryEchoed=true
- ✅ the wizard creates a template record end to end — a0BRK00000gtDmJ2AU, base object Account
- ✅ the created template keeps the query the wizard collected — Query_Config__c = Name, Industry, Phone
- ❌ the canvas path creates the template record — no record was created by "Create & Open Canvas"
- ❌ and it is typed Canvas, which is what decides which editor opens — no record
- ❌ the canvas path lands on the artboard — the artboard (.dg-board) never appeared
- ⊘ the floating panels open with their contents rendered — the designer never opened
- ✅ the template list renders rows — 13 rows; count label "13 templates"
- ✅ search narrows the list to matching rows only — 13 -> 1 rows for "k8e3j7"; every remaining row matches = true
- ✅ the row-count label reports the filtered subset — label reads "1 of 13 templates"
- ✅ a search with no matches empties the list instead of ignoring the query — 0 rows survived a nonsense query
- ✅ clearing the search restores the full list — 13 rows (expected 13)
- ✅ clicking a column header re-orders the rows both ways — clicked=true; first row "QAUI-k8e3j7-File Word PDF Ac" -> asc "QA Fixtures Anchor Demo Canv" -> desc "Verify — Designer (pill-dens"
- ✅ Refresh reloads the list without emptying it — hit-test=ok; 13 rows after refresh (expected 13)
- ✅ "New Template" switches to the Create New wizard
- ✅ the row-action menu button is reachable by a mouse
- ⊘ row action View opens the template on its Copy-Paste Tags tab — could not drive the row menu: row "QAUI-k8e3j7-Starter": no row
- ⊘ row action Export downloads a valid .docgen.json bundle — no download event fired: row "QAUI-k8e3j7-Starter": no row
- ⊘ Import Template restores an exported bundle as a new template — nothing was exported to import
- ✅ row action Clone creates a copy and opens it for editing — created "QAUI-k8e3j7-File (Copy)" (a0BRK00000gu17h2AA); the edit modal opened = true
- ✅ row action Delete removes the template — "QAUI-k8e3j7-File (Copy)" is gone from the org
- ✅ deleting a template asks for confirmation first — a confirmation step was shown
- ⊘ row action Design opens that template in the designer — could not drive the row menu: row "QAUI-k8e3j7-Starter": no row
- ❌ row action Edit opens the edit modal — the modal never opened, so nothing inside it could be tested
- ⊘ the edit modal tabs render their panels — the edit modal never opened
- ⊘ Save as New Version persists the edited fields — the edit modal never opened
- ⊘ closing the modal with unsaved edits warns or preserves them — the edit modal never opened
- ✅ Command Hub: "My Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Template Library Manage your document designs and create new"; body 1565 chars
- ✅ Command Hub: "Bulk Generation" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Bulk Generation Create documents for hundreds of records at "; body 167 chars
- ✅ Command Hub: "Signatures" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Signature Settings Configure email branding, site URL, and s"; body 1264 chars
- ✅ Command Hub: "Assets" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Shared Assets Manage reusable images like logos and footers "; body 179 chars
- ✅ Command Hub: "Email Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Email Templates Brand and edit every signature email — reque"; body 1536 chars
- ✅ Command Hub: "Learning Center" opens its panel — panel header "Template Library Manage your document designs and create new" -> "User Guide The full Portwood User Guide lives on the web — a"; body 319 chars
- ✅ the Command Hub sidebar stays usable after opening Bulk Generation — 7 nav items reachable throughout
- ✅ no unexpected console errors while driving the admin UI
- ✅ the suite cleans up the templates it created — 1 QAUI- templates deleted

### record-pages — Record pages

- ✅ DocGen_Template__c record page renders — 57 field slots rendered
- ✅ DocGen_Template__c detail fields are genuinely visible (hit test) — first field "Template Name" is hittable
- ✅ DocGen_Template__c.Name renders on the record page
- ✅ DocGen_Template__c.API_Name__c renders on the record page
- ✅ DocGen_Template__c.Type__c renders on the record page
- ✅ DocGen_Template__c.Output_Format__c renders on the record page
- ✅ DocGen_Template__c.Is_Active__c renders on the record page
- ✅ DocGen_Template__c.Is_Default__c renders on the record page
- ✅ DocGen_Template__c.Category__c renders on the record page
- ✅ DocGen_Template__c.Base_Object_API__c renders on the record page
- ✅ DocGen_Template__c.Document_Title_Format__c renders on the record page
- ✅ DocGen_Template__c.Test_Record_Id__c renders on the record page
- ✅ DocGen_Template__c.Sort_Order__c renders on the record page
- ✅ DocGen_Template__c.Lock_Output_Format__c renders on the record page
- ✅ DocGen_Template__c.Specific_Record_Ids__c renders on the record page
- ✅ DocGen_Template__c.Required_Permission_Sets__c renders on the record page
- ✅ DocGen_Template__c.Signer_Verification__c renders on the record page
- ✅ DocGen_Template__c.Prefill_Signer_Email__c renders on the record page
- ✅ DocGen_Template__c.Page_Size__c renders on the record page
- ✅ DocGen_Template__c.Page_Orientation__c renders on the record page
- ✅ DocGen_Template__c.Page_Margins__c renders on the record page
- ✅ DocGen_Template__c.Custom_Margins__c renders on the record page
- ✅ DocGen_Template__c.Default_Email_Message__c renders on the record page
- ✅ DocGen_Template__c.Record_Filter__c renders on the record page
- ✅ DocGen_Template__c.Description__c renders on the record page
- ✅ DocGen_Template__c.Query_Config__c renders on the record page
- ✅ DocGen_Template__c.CreatedById renders on the record page
- ✅ DocGen_Template__c.LastModifiedById renders on the record page
- ✅ DocGen_Template__c.Draft_Body__c renders on the record page
- ✅ DocGen_Template__c exposes every one of its fields somewhere on the record page — all reachable; 3 field(s) intentionally edited elsewhere
- ✅ DocGen_Template__c fields edited outside the record page are accounted for — Footer_Html__c (edited in the Designer footer band), Form_Fields_Config__c (edited on the Signer Inputs tab), Header_Html__c (edited in the Designer header band)
- ✅ DocGen_Template__c related lists load without error — 7 related list container(s) rendered
- ✅ DocGen_Template__c shows its "Versions" related list
- ✅ DocGen_Template__c shows its "Files" related list
- ✅ DocGen_Template__c related lists are genuinely visible (hit test)
- ✅ DocGen_Template__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Template__c record page logs no console errors
- ✅ DocGen_Template_Version__c record page renders — 36 field slots rendered
- ✅ DocGen_Template_Version__c detail fields are genuinely visible (hit test) — first field "Version Name" is hittable
- ✅ DocGen_Template_Version__c.Name renders on the record page
- ✅ DocGen_Template_Version__c.Template__c renders on the record page
- ✅ DocGen_Template_Version__c.Is_Active__c renders on the record page
- ✅ DocGen_Template_Version__c.Type__c renders on the record page
- ✅ DocGen_Template_Version__c.Category__c renders on the record page
- ✅ DocGen_Template_Version__c.Base_Object_API__c renders on the record page
- ✅ DocGen_Template_Version__c.Content_Version_Id__c renders on the record page
- ✅ DocGen_Template_Version__c.Pre_Decomposition_Status__c renders on the record page
- ✅ DocGen_Template_Version__c.Description__c renders on the record page
- ✅ DocGen_Template_Version__c.Query_Config__c renders on the record page
- ✅ DocGen_Template_Version__c.CreatedById renders on the record page
- ✅ DocGen_Template_Version__c.LastModifiedById renders on the record page
- ✅ DocGen_Template_Version__c.Output_Format__c renders on the record page
- ✅ DocGen_Template_Version__c.Document_Title_Format__c renders on the record page
- ✅ DocGen_Template_Version__c.Page_Size__c renders on the record page
- ✅ DocGen_Template_Version__c.Page_Orientation__c renders on the record page
- ✅ DocGen_Template_Version__c.Page_Margins__c renders on the record page
- ✅ DocGen_Template_Version__c.Custom_Margins__c renders on the record page
- ✅ DocGen_Template_Version__c exposes every one of its fields somewhere on the record page — all reachable; 3 field(s) intentionally edited elsewhere
- ✅ DocGen_Template_Version__c fields edited outside the record page are accounted for — Footer_Html__c (edited in the Designer footer band), Header_Html__c (edited in the Designer header band), Watermark_Image_CV_Id__c (set when a watermark is uploaded)
- ✅ DocGen_Template_Version__c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Template_Version__c shows its "Files" related list
- ✅ DocGen_Template_Version__c related lists are genuinely visible (hit test)
- ✅ DocGen_Template_Version__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Template_Version__c record page logs no console errors
- ✅ DocGen_Job__c record page renders — 30 field slots rendered
- ✅ DocGen_Job__c detail fields are genuinely visible (hit test) — first field "Job Number" is hittable
- ✅ DocGen_Job__c.Name renders on the record page
- ✅ DocGen_Job__c.Template__c renders on the record page
- ✅ DocGen_Job__c.Status__c renders on the record page
- ✅ DocGen_Job__c.Label__c renders on the record page
- ✅ DocGen_Job__c.Total_Records__c renders on the record page
- ✅ DocGen_Job__c.Success_Count__c renders on the record page
- ✅ DocGen_Job__c.Error_Count__c renders on the record page
- ✅ DocGen_Job__c.Merge_Only__c renders on the record page
- ✅ DocGen_Job__c.Query_Condition__c renders on the record page
- ✅ DocGen_Job__c.CreatedById renders on the record page
- ✅ DocGen_Job__c.LastModifiedById renders on the record page
- ✅ DocGen_Job__c.Error_Log__c renders on the record page
- ✅ DocGen_Job__c.Merged_PDF_CV__c renders on the record page
- ✅ DocGen_Job__c.Parent_Record_Id__c renders on the record page
- ✅ DocGen_Job__c.Sort_Order__c renders on the record page
- ✅ DocGen_Job__c exposes every one of its fields somewhere on the record page — all reachable; 2 field(s) intentionally edited elsewhere
- ✅ DocGen_Job__c fields edited outside the record page are accounted for — Data_Cache_CV__c (internal cache pointer written by the batch), Giant_Query_Config__c (internal config written by the giant-query path)
- ✅ DocGen_Job__c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Job__c shows its "Files" related list
- ✅ DocGen_Job__c related lists are genuinely visible (hit test)
- ✅ DocGen_Job__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Job__c record page logs no console errors
- ✅ DocGen_Saved_Query__c record page renders — 15 field slots rendered
- ✅ DocGen_Saved_Query__c detail fields are genuinely visible (hit test) — first field "Query Label" is hittable
- ✅ DocGen_Saved_Query__c.Name renders on the record page
- ✅ DocGen_Saved_Query__c.DocGen_Template__c renders on the record page
- ✅ DocGen_Saved_Query__c.Description__c renders on the record page
- ✅ DocGen_Saved_Query__c.Query_Condition__c renders on the record page
- ✅ DocGen_Saved_Query__c.CreatedById renders on the record page
- ✅ DocGen_Saved_Query__c.LastModifiedById renders on the record page
- ✅ DocGen_Saved_Query__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Saved_Query__c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Saved_Query__c shows its "Files" related list
- ✅ DocGen_Saved_Query__c related lists are genuinely visible (hit test)
- ✅ DocGen_Saved_Query__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Saved_Query__c record page logs no console errors
- ✅ DocGen_Error_Log__c record page renders — 32 field slots rendered
- ✅ DocGen_Error_Log__c detail fields are genuinely visible (hit test) — first field "Error Number" is hittable
- ✅ DocGen_Error_Log__c.Name renders on the record page
- ✅ DocGen_Error_Log__c.Severity__c renders on the record page
- ✅ DocGen_Error_Log__c.Context__c renders on the record page
- ✅ DocGen_Error_Log__c.Operation__c renders on the record page
- ✅ DocGen_Error_Log__c.Exception_Type__c renders on the record page
- ✅ DocGen_Error_Log__c.Message__c renders on the record page
- ✅ DocGen_Error_Log__c.Stack_Trace__c renders on the record page
- ✅ DocGen_Error_Log__c.Additional_Info__c renders on the record page
- ✅ DocGen_Error_Log__c.Record_Id__c renders on the record page
- ✅ DocGen_Error_Log__c.Template_Id__c renders on the record page
- ✅ DocGen_Error_Log__c.Job_Id__c renders on the record page
- ✅ DocGen_Error_Log__c.User_Id__c renders on the record page
- ✅ DocGen_Error_Log__c.Flow_Interview_Guid__c renders on the record page
- ✅ DocGen_Error_Log__c.CreatedById renders on the record page
- ✅ DocGen_Error_Log__c.LastModifiedById renders on the record page
- ✅ DocGen_Error_Log__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Error_Log__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Error_Log__c record page logs no console errors
- ✅ DocGen_Asset__c record page renders — 15 field slots rendered
- ✅ DocGen_Asset__c detail fields are genuinely visible (hit test) — first field "Asset Name" is hittable
- ✅ DocGen_Asset__c.Name renders on the record page
- ✅ DocGen_Asset__c.Asset_Key__c renders on the record page
- ✅ DocGen_Asset__c.Asset_Type__c renders on the record page
- ✅ DocGen_Asset__c.Category__c renders on the record page
- ✅ DocGen_Asset__c.Is_Active__c renders on the record page
- ✅ DocGen_Asset__c.CreatedById renders on the record page
- ✅ DocGen_Asset__c.LastModifiedById renders on the record page
- ✅ DocGen_Asset__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Asset__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Asset__c record page logs no console errors
- ✅ DocGen_Email_Template__c record page renders — 32 field slots rendered
- ✅ DocGen_Email_Template__c detail fields are genuinely visible (hit test) — first field "Email Template Name" is hittable
- ✅ DocGen_Email_Template__c.Name renders on the record page
- ✅ DocGen_Email_Template__c.Type__c renders on the record page
- ✅ DocGen_Email_Template__c.Subject__c renders on the record page
- ✅ DocGen_Email_Template__c.Is_Active__c renders on the record page
- ✅ DocGen_Email_Template__c.Description__c renders on the record page
- ✅ DocGen_Email_Template__c.Layout_Mode__c renders on the record page
- ✅ DocGen_Email_Template__c.Body_Html__c renders on the record page
- ✅ DocGen_Email_Template__c.Body_Plain__c renders on the record page
- ✅ DocGen_Email_Template__c.Logo_Url__c renders on the record page
- ✅ DocGen_Email_Template__c.Logo_Url_Extended__c renders on the record page
- ✅ DocGen_Email_Template__c.Logo_Asset_Key__c renders on the record page
- ✅ DocGen_Email_Template__c.Logo_Height__c renders on the record page
- ✅ DocGen_Email_Template__c.Brand_Color__c renders on the record page
- ✅ DocGen_Email_Template__c.Footer_Text__c renders on the record page
- ✅ DocGen_Email_Template__c.CreatedById renders on the record page
- ✅ DocGen_Email_Template__c.LastModifiedById renders on the record page
- ✅ DocGen_Email_Template__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Email_Template__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Email_Template__c record page logs no console errors
- ✅ DocGen_Signature_Request__c record page renders — 34 field slots rendered
- ✅ DocGen_Signature_Request__c detail fields are genuinely visible (hit test) — first field "Request Number" is hittable
- ✅ DocGen_Signature_Request__c.Name renders on the record page
- ✅ DocGen_Signature_Request__c.Status__c renders on the record page
- ✅ DocGen_Signature_Request__c.Template__c renders on the record page
- ✅ DocGen_Signature_Request__c.Template_Ids__c renders on the record page
- ✅ DocGen_Signature_Request__c.Document_Title_Format__c renders on the record page
- ✅ DocGen_Signature_Request__c.Related_Record_Id__c renders on the record page
- ✅ DocGen_Signature_Request__c.Source_Document_Id__c renders on the record page
- ✅ DocGen_Signature_Request__c.Signing_Order__c renders on the record page
- ✅ DocGen_Signature_Request__c.Expires_At__c renders on the record page
- ✅ DocGen_Signature_Request__c.Email_Status__c renders on the record page
- ✅ DocGen_Signature_Request__c.Prefill_Signer_Email__c renders on the record page
- ✅ DocGen_Signature_Request__c.Require_Email_Verification__c renders on the record page
- ✅ DocGen_Signature_Request__c.Signer_Name__c renders on the record page
- ✅ DocGen_Signature_Request__c.Signer_Email__c renders on the record page
- ✅ DocGen_Signature_Request__c.CreatedById renders on the record page
- ✅ DocGen_Signature_Request__c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Request__c exposes every one of its fields somewhere on the record page — all reachable; 4 field(s) intentionally edited elsewhere
- ✅ DocGen_Signature_Request__c fields edited outside the record page are accounted for — Frozen_Document__c (snapshot blob written by the signing engine), Render_Data_Snapshot__c (snapshot blob written by the signing engine), Signature_Data__c (written by the signing engine), Snapshot_Tak
- ✅ DocGen_Signature_Request__c related lists load without error — 8 related list container(s) rendered
- ✅ DocGen_Signature_Request__c shows its "Signers" related list
- ✅ DocGen_Signature_Request__c shows its "Audits" related list
- ✅ DocGen_Signature_Request__c shows its "Files" related list
- ✅ DocGen_Signature_Request__c related lists are genuinely visible (hit test)
- ✅ DocGen_Signature_Request__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Request__c record page logs no console errors
- ✅ DocGen_Signer__c record page renders — 38 field slots rendered
- ✅ DocGen_Signer__c detail fields are genuinely visible (hit test) — first field "Signer Number" is hittable
- ✅ DocGen_Signer__c.Name renders on the record page
- ✅ DocGen_Signer__c.Signature_Request__c renders on the record page
- ✅ DocGen_Signer__c.Signer_Name__c renders on the record page
- ✅ DocGen_Signer__c.Signer_Email__c renders on the record page
- ✅ DocGen_Signer__c.Status__c renders on the record page
- ✅ DocGen_Signer__c.Role_Name__c renders on the record page
- ✅ DocGen_Signer__c.Sort_Order__c renders on the record page
- ✅ DocGen_Signer__c.Contact__c renders on the record page
- ✅ DocGen_Signer__c.Signature_Data__c renders on the record page
- ✅ DocGen_Signer__c.Consent_Captured__c renders on the record page
- ✅ DocGen_Signer__c.Decline_Reason__c renders on the record page
- ✅ DocGen_Signer__c.PIN_Verified_At__c renders on the record page
- ✅ DocGen_Signer__c.PIN_Attempts__c renders on the record page
- ✅ DocGen_Signer__c.PIN_Expires_At__c renders on the record page
- ✅ DocGen_Signer__c.Reminders_Sent__c renders on the record page
- ✅ DocGen_Signer__c.Reminder_Sent_At__c renders on the record page
- ✅ DocGen_Signer__c.CreatedById renders on the record page
- ✅ DocGen_Signer__c.LastModifiedById renders on the record page
- ✅ DocGen_Signer__c exposes every one of its fields somewhere on the record page — all reachable; 1 field(s) intentionally edited elsewhere
- ✅ DocGen_Signer__c fields edited outside the record page are accounted for — Field_Data_Json__c (written by the signing engine)
- ✅ DocGen_Signer__c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Signer__c shows its "Files" related list
- ✅ DocGen_Signer__c related lists are genuinely visible (hit test)
- ✅ DocGen_Signer__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signer__c record page logs no console errors
- ✅ DocGen_Signature_Placement__c record page renders — 31 field slots rendered
- ✅ DocGen_Signature_Placement__c detail fields are genuinely visible (hit test) — first field "Placement Number" is hittable
- ✅ DocGen_Signature_Placement__c.Name renders on the record page
- ✅ DocGen_Signature_Placement__c.Signer__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Signature_Request__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Placement_Type__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Sequence_Order__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Status__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Signed_Value__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Signed_At__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Document_Index__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Section_Context__c renders on the record page
- ✅ DocGen_Signature_Placement__c.Tag_Text__c renders on the record page
- ✅ DocGen_Signature_Placement__c.CreatedById renders on the record page
- ✅ DocGen_Signature_Placement__c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Placement__c.Render_Inline__c renders on the record page
- ✅ DocGen_Signature_Placement__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Signature_Placement__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Placement__c record page logs no console errors
- ✅ DocGen_Signature_Audit__c record page renders — 34 field slots rendered
- ✅ DocGen_Signature_Audit__c detail fields are genuinely visible (hit test) — first field "Audit Number" is hittable
- ✅ DocGen_Signature_Audit__c.Name renders on the record page
- ✅ DocGen_Signature_Audit__c.Signature_Request__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Signer__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Contact__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Signer_Name__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Signer_Email__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Signed_Date__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Consent_Captured__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Verification_Method__c renders on the record page
- ✅ DocGen_Signature_Audit__c.PIN_Verified_At__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Document_Hash_SHA256__c renders on the record page
- ✅ DocGen_Signature_Audit__c.IP_Address__c renders on the record page
- ✅ DocGen_Signature_Audit__c.User_Agent__c renders on the record page
- ✅ DocGen_Signature_Audit__c.Error_Message__c renders on the record page
- ✅ DocGen_Signature_Audit__c.CreatedById renders on the record page
- ✅ DocGen_Signature_Audit__c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Audit__c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Signature_Audit__c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Audit__c record page logs no console errors
- ✅ every seeded QA record is deleted again — 11 record(s) removed

### template-integrity — Template integrity

- ❌ every HTML template returns a body to the visual Designer — 3 of 6 return NOTHING — those open to an empty canvas however well they generate. The Designer reads a ContentVersion titled docgen_html_body_<templateId>, not the version's Content_Version_Id__c: Cha
- ✅ each template agrees with its active version about its own type — no template/version type disagreements
- ⊘ merge-tag pills stay inside their table cells — could not open a template in the Designer: no Designer tab
