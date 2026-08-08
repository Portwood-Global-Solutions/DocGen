# DocGen QA report

**Org** `designer-ns` · **Run** 2026-08-08T10:59:51.831Z · **Duration** 1982s

## Headline

| | |
| --- | --- |
| Checks evaluated | 1491 |
| Passed | 1336 (89.6%) |
| Failed | 155 |
| Skipped (not counted) | 17 |
| Blockers | 1 |
| Major | 5 |
| Minor | 149 |

## Coverage by area

| Suite | Area | Passed | Failed | Skipped | Rate |
| --- | --- | ---: | ---: | ---: | ---: |
| `metadata-audit` | Metadata | 349 | 128 | 0 | 73.2% |
| `apex-e2e` | Apex end-to-end | 16 | 0 | 0 | 100% |
| `apex-unit` | Apex unit | 53 | 13 | 0 | 80.3% |
| `merge-tags` | Merge tags | 180 | 0 | 4 | 100% |
| `flow-actions` | Flow actions & endpoints | 176 | 10 | 1 | 94.6% |
| `output-formats` | Output formats | 75 | 0 | 2 | 100% |
| `ui-designer` | Designer UI | 103 | 0 | 2 | 100% |
| `ui-admin` | Admin UI | 64 | 0 | 4 | 100% |
| `ui-runner` | End-user UI | 68 | 4 | 3 | 94.4% |
| `record-pages` | Record pages | 250 | 0 | 0 | 100% |
| `pdf-content` | Crashed | — | — | — | _skipped: threw: Command failed: pdftotext -layout -enc UTF-8 /var/folders/pj/r60drhl55075qbd73_c6hyqh0000gn/T/dgqa-pdf-fiF2fZ/doc.pdf -
Syntax Warning: May not be a PDF file (continuing anyway)
Syntax Error (2): Ille_ |
| `template-integrity` | Template integrity | 2 | 0 | 1 | 100% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity | Suite | Check | Evidence |
| --- | --- | --- | --- |
| **blocker** | `ui-runner` | the signature document picker is reachable | found=false hit=missing |
| **major** | `flow-actions` | Create Signature Request: input validation reports through Success/Error Message rather than faulting the Flow | throws DocGenException instead of returning Result.success=false for: a null Template Id; a null Related Record Id; an empty Signers collection; a signer with no email. The Result class advertises "Success" and "Error Message" outputs that are unreachable on these paths — the Flow interview faults i |
| **major** | `flow-actions` | Validate Signature Token: survives a 60-request Flow batch | the action did not return — anonymous Apex died before it could report. System.LimitException: portwoodglobal:Too many SOQL queries: 101 |
| **major** | `flow-actions` | Finalize Signature Image: a bad token is handled, not thrown into the Flow | got: THREW~portwoodglobal.DocGenSignatureService.SignatureException~Invalid security token format. |
| **major** | `ui-runner` | picker hides a template that has no active version | "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObjectInternal filters on Is_Active__c/audience but never checks for an active DocGen_Template_Version__c. |
| **major** | `ui-runner` | a record-filtered template is not silently applied to excluded records in bulk | "UIQA Filtered Out" carries a Record_Filter__c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the per-record check. Documents can be generated for records the template excludes. Either the batch mu |
| **minor** | `metadata-audit` | DocGen_Asset__c.Asset_Key__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Asset__c.Asset_Type__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Asset__c.Category__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Asset__c.Is_Active__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Object_API_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Output_Format_Override__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Record_Type_Developer_Names__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Save_To_Record__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Template_API_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Button__mdt.Template_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Body_Html__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Body_Plain__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Brand_Color__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Footer_Text__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Is_Active__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Layout_Mode__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Logo_Asset_Key__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Logo_Height__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Logo_Url_Extended__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Logo_Url__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Subject__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Email_Template__c.Type__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Error_Log__c.Exception_Type__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Error_Log__c.Severity__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Guest_Render__e.Job_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Error_Count__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Error_Log__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Label__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Merge_Only__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Parent_Record_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Sort_Order__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Success_Count__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Template__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Job__c.Total_Records__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.AI_Prompt_Template__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.AI_Provider_Class__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Company_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Experience_Site_Url__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Email_Brand_Color__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Email_Footer_Text__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Email_Logo_Url__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Email_Message__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Email_Subject__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Expiration_Days__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_OWA_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Prefill_Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Reminder_Enabled__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Reminder_Hours__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Reminder_Schedule__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Settings__c.Signature_Skip_Email_Verification__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Contact__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Document_Hash_SHA256__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.IP_Address__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Signature_Request__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Signed_Date__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Signer_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Signer__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.User_Agent__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Audit__c.Verification_Method__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Document_Index__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Placement_Type__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Render_Inline__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Section_Context__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Sequence_Order__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Signature_Request__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Signed_At__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Signed_Value__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Signer__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Placement__c.Tag_Text__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Document_Title_Format__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Email_Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Expires_At__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Frozen_Document__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Prefill_Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Related_Record_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Require_Email_Verification__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Signer_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Signing_Order__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Snapshot_Taken_At__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Template_Ids__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signature_Request__c.Template__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Contact__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Decline_Reason__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Reminder_Sent_At__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Reminders_Sent__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Signature_Request__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Signer_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Sort_Order__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Signer__c.Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Base_Object_API__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Category__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Custom_Margins__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Description__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Document_Title_Format__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Footer_Html__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Header_Html__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Output_Format__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Page_Orientation__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Page_Size__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Pre_Decomposition_Status__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Type__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template_Version__c.Watermark_Image_CV_Id__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.API_Name__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Custom_Margins__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Default_Email_Message__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Draft_Body__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Footer_Html__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Form_Fields_Config__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Header_Html__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Is_Active__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Is_Default__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Page_Margins__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Page_Orientation__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Page_Size__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Prefill_Signer_Email__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Record_Filter__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Signer_Verification__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | DocGen_Template__c.Specific_Record_Ids__c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does |
| **minor** | `metadata-audit` | docGenAuthenticator (app page) is reachable from a tab | no tab references it — reachable only via a hand-built Lightning page |
| **minor** | `metadata-audit` | docGenQueryBuilder (app page) is reachable from a tab | no tab references it — reachable only via a hand-built Lightning page |
| **minor** | `metadata-audit` | docGenRunner (app page) is reachable from a tab | no tab references it — reachable only via a hand-built Lightning page |
| **minor** | `metadata-audit` | docGenTreeBuilder (app page) is reachable from a tab | no tab references it — reachable only via a hand-built Lightning page |
| **minor** | `apex-unit` | DocGenSignatureService meets the 75% packaging bar | 54% (575/1065 lines) |
| **minor** | `apex-unit` | DocGenSvgChartSerializer meets the 75% packaging bar | 43% (415/973 lines) |
| **minor** | `apex-unit` | DocGenAcroFormService meets the 75% packaging bar | 65% (746/1154 lines) |
| **minor** | `apex-unit` | DocGenSignatureGuestSecurity meets the 75% packaging bar | 63% (20/32 lines) |
| **minor** | `apex-unit` | DocGenFlsGuard meets the 75% packaging bar | 69% (118/172 lines) |
| **minor** | `apex-unit` | DocGenApprovalHistory meets the 75% packaging bar | 9% (4/44 lines) |
| **minor** | `apex-unit` | DocGenGiantQueryFlowAction meets the 75% packaging bar | 47% (44/93 lines) |
| **minor** | `apex-unit` | DocGenHtmlRenderer meets the 75% packaging bar | 74% (2319/3150 lines) |
| **minor** | `apex-unit` | DocGenAiProviderFactory meets the 75% packaging bar | 54% (29/54 lines) |
| **minor** | `apex-unit` | DocGenChartCvReaper meets the 75% packaging bar | 54% (13/24 lines) |
| **minor** | `apex-unit` | DocGenGiantQueryAssembler meets the 75% packaging bar | 53% (576/1077 lines) |
| **minor** | `apex-unit` | DocGenController meets the 75% packaging bar | 72% (2792/3879 lines) |
| **minor** | `apex-unit` | DocGenFieldWritebackTrigger meets the 75% packaging bar | 67% (4/6 lines) |
| **minor** | `flow-actions` | DocGenFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop | SOQL + DML inside a loop body — Flow can hand this action up to 200 requests in one transaction |
| **minor** | `flow-actions` | DocGenGiantQueryFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop | SOQL inside a loop body — Flow can hand this action up to 200 requests in one transaction |
| **minor** | `flow-actions` | DocGenSignatureFinalizer.FinalizeRequest: every input/output carries a label | no label= on: token, base64Image — Flow Builder shows the raw Apex field name to the admin |
| **minor** | `flow-actions` | DocGenSignatureFlowAction.Request.signers: Signer is a usable Apex-Defined Flow type (deprecated input) | not a top-level class (Flow never lists inner classes). All four are required — see DocGenSigner.cls for the reference implementation. |
| **minor** | `flow-actions` | DocGenSignatureSubmitter.submitSignature has a Flow description | no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs |
| **minor** | `flow-actions` | DocGenSignatureValidator.validateToken has a Flow description | no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs |
| **minor** | `flow-actions` | Generate Bulk Documents: a WHERE condition that cannot compile is reported to the Flow | got: true~null |
| **minor** | `ui-runner` | a filter that matches no records leaves Run disabled | Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns on a 0 count so no analysis blocks it (docGenBulkRunner.js isRunDisabled / runAnalysis). |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `merge-tags` — HTML-template escaping ({Field} newline → <br/>) behaves correctly: processXmlForTest(xml, data, templateType) is @TestVisible private and unreachable from anonymous Apex, so every check here runs the Word branch; HTML/Excel/PowerPoint escaping needs a unit test or a real HTML template render
- `merge-tags` — {PageNumber}/{TotalPages} render real page numbers in the PDF: processXml only preserves the tokens; the @page counter substitution happens in wrapHtmlForPdf and can only be verified on a rendered PDF (output-formats suite)
- `merge-tags` — {%ImageField} with a real ContentVersion renders an embedded image: needs an uploaded ContentVersion fixture and a real DOCX/PDF render; covered by scripts/e2e-09-images.apex, not by this parser-level probe
- `merge-tags` — The giant-query parent path resolves the same tag surface: DocGenGiantQueryAssembler.resolveParentMergeTags / resolveGiantChartBuckets do not go through processXmlForTest and need >2000 child rows to exercise
- `flow-actions` — Create Signature Request: the signing URL points at a real, reachable site: this org has no Experience Site URL in DocGen Settings, so the action returns the <CONFIGURE_SITE_URL_IN_SETUP> placeholder. The link shape is correct but end-to-end reachability is unproven here.
- `output-formats` — Record hidden by sharing/FLS from a low-privilege user: requires generating as a second, restricted user; System.runAs is test-context only and anonymous Apex cannot impersonate. Covered here only by the deleted-record analogue.
- `output-formats` — Giant-query PDF retains template chrome (title, column headers, footer): the giant path builds its HTML inside the assembler and does not set DocGenService.lastRenderedHtml, and Apex cannot extract text from a rendered PDF. This is the exact shape of the v2.5.0 regression, so it is a real gap — it needs a PDF text-extraction step outside Apex.
- `ui-designer` — header renders asset tags as images: skip: no assets in this org
- `ui-designer` — resizing a header image does not duplicate it: skip: no assets
- `ui-admin` — the floating panels open with their contents rendered: the designer never opened
- `ui-admin` — edit modal tab "Header / Footer" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — edit modal tab "Fillable Fields" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — closing the modal with unsaved edits warns or preserves them: could not re-open the modal: row "QAUI-ka5dmm-Starter": the menu never offered a visible "Edit" item
- `ui-runner` — docGenSignatureSender validates its fields and writes the signature rows: no template could be selected, so no request could be sent
- `ui-runner` — a user without the DocGen permission set gets a clear message, not a broken UI: the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previously got reported as the component rendering nothing — a product defect that did not exist. Set the password once by hand and this check runs.
- `ui-runner` — a Document Packet contains every document it was built from: could not move templates into the packet: nothing reached the "In Packet" column — the move did not take
- `template-integrity` — merge-tag pills stay inside their table cells: could not open a template in the Designer: no Designer tab

## Every check

### metadata-audit — Metadata

- ✅ DocGen_Asset__c has a page layout
- ✅ DocGen_Asset__c.Asset_Key__c is on the page layout
- ❌ DocGen_Asset__c.Asset_Key__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset__c.Asset_Type__c is on the page layout
- ✅ DocGen_Asset__c.Asset_Type__c is granted on DocGen_Admin
- ❌ DocGen_Asset__c.Asset_Type__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset__c.Category__c is on the page layout
- ✅ DocGen_Asset__c.Category__c is granted on DocGen_Admin
- ❌ DocGen_Asset__c.Category__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset__c.Is_Active__c is on the page layout
- ✅ DocGen_Asset__c.Is_Active__c is granted on DocGen_Admin
- ❌ DocGen_Asset__c.Is_Active__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Button__mdt.Active__c has a description or help text
- ✅ DocGen_Button__mdt.Document_Title__c has a description or help text
- ❌ DocGen_Button__mdt.Object_API_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button__mdt.Output_Format_Override__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button__mdt.Record_Type_Developer_Names__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button__mdt.Save_To_Record__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Button__mdt.Sort_Order__c has a description or help text
- ❌ DocGen_Button__mdt.Template_API_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button__mdt.Template_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c has a page layout
- ✅ DocGen_Email_Template__c.Body_Html__c is on the page layout
- ✅ DocGen_Email_Template__c.Body_Html__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Body_Html__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Body_Plain__c is on the page layout
- ✅ DocGen_Email_Template__c.Body_Plain__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Body_Plain__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Brand_Color__c is on the page layout
- ✅ DocGen_Email_Template__c.Brand_Color__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Brand_Color__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Description__c is on the page layout
- ✅ DocGen_Email_Template__c.Description__c is granted on DocGen_Admin
- ✅ DocGen_Email_Template__c.Description__c has a description or help text
- ✅ DocGen_Email_Template__c.Footer_Text__c is on the page layout
- ✅ DocGen_Email_Template__c.Footer_Text__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Footer_Text__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Is_Active__c is on the page layout
- ✅ DocGen_Email_Template__c.Is_Active__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Is_Active__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Layout_Mode__c is on the page layout
- ✅ DocGen_Email_Template__c.Layout_Mode__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Layout_Mode__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Logo_Asset_Key__c is on the page layout
- ✅ DocGen_Email_Template__c.Logo_Asset_Key__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Logo_Asset_Key__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Logo_Height__c is on the page layout
- ✅ DocGen_Email_Template__c.Logo_Height__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Logo_Height__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Logo_Url_Extended__c is on the page layout
- ✅ DocGen_Email_Template__c.Logo_Url_Extended__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Logo_Url_Extended__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Logo_Url__c is on the page layout
- ✅ DocGen_Email_Template__c.Logo_Url__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Logo_Url__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Subject__c is on the page layout
- ✅ DocGen_Email_Template__c.Subject__c is granted on DocGen_Admin
- ❌ DocGen_Email_Template__c.Subject__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template__c.Type__c is on the page layout
- ❌ DocGen_Email_Template__c.Type__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log__c has a page layout
- ✅ DocGen_Error_Log__c.Additional_Info__c is on the page layout
- ✅ DocGen_Error_Log__c.Additional_Info__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Additional_Info__c has a description or help text
- ✅ DocGen_Error_Log__c.Context__c is on the page layout
- ✅ DocGen_Error_Log__c.Context__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Context__c has a description or help text
- ✅ DocGen_Error_Log__c.Exception_Type__c is on the page layout
- ✅ DocGen_Error_Log__c.Exception_Type__c is granted on DocGen_Admin
- ❌ DocGen_Error_Log__c.Exception_Type__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log__c.Flow_Interview_Guid__c is on the page layout
- ✅ DocGen_Error_Log__c.Flow_Interview_Guid__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Flow_Interview_Guid__c has a description or help text
- ✅ DocGen_Error_Log__c.Job_Id__c is on the page layout
- ✅ DocGen_Error_Log__c.Job_Id__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Job_Id__c has a description or help text
- ✅ DocGen_Error_Log__c.Message__c is on the page layout
- ✅ DocGen_Error_Log__c.Message__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Message__c has a description or help text
- ✅ DocGen_Error_Log__c.Operation__c is on the page layout
- ✅ DocGen_Error_Log__c.Operation__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Operation__c has a description or help text
- ✅ DocGen_Error_Log__c.Record_Id__c is on the page layout
- ✅ DocGen_Error_Log__c.Record_Id__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Record_Id__c has a description or help text
- ✅ DocGen_Error_Log__c.Severity__c is on the page layout
- ✅ DocGen_Error_Log__c.Severity__c is granted on DocGen_Admin
- ❌ DocGen_Error_Log__c.Severity__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log__c.Stack_Trace__c is on the page layout
- ✅ DocGen_Error_Log__c.Stack_Trace__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Stack_Trace__c has a description or help text
- ✅ DocGen_Error_Log__c.Template_Id__c is on the page layout
- ✅ DocGen_Error_Log__c.Template_Id__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.Template_Id__c has a description or help text
- ✅ DocGen_Error_Log__c.User_Id__c is on the page layout
- ✅ DocGen_Error_Log__c.User_Id__c is granted on DocGen_Admin
- ✅ DocGen_Error_Log__c.User_Id__c has a description or help text
- ✅ DocGen_Field_Writeback__e.Request_Id__c has a description or help text
- ❌ DocGen_Guest_Render__e.Job_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Guest_Render__e.Record_Id__c has a description or help text
- ✅ DocGen_Guest_Render__e.Template_Id__c has a description or help text
- ✅ DocGen_Job__c has a page layout
- ✅ DocGen_Job__c.Data_Cache_CV__c is kept OFF the page layout
- ✅ DocGen_Job__c.Error_Count__c is on the page layout
- ✅ DocGen_Job__c.Error_Count__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Error_Count__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Error_Log__c is on the page layout
- ✅ DocGen_Job__c.Error_Log__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Error_Log__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Giant_Query_Config__c is kept OFF the page layout
- ✅ DocGen_Job__c.Label__c is on the page layout
- ✅ DocGen_Job__c.Label__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Label__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Merge_Only__c is on the page layout
- ✅ DocGen_Job__c.Merge_Only__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Merge_Only__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Merged_PDF_CV__c is on the page layout
- ✅ DocGen_Job__c.Merged_PDF_CV__c is granted on DocGen_Admin
- ✅ DocGen_Job__c.Merged_PDF_CV__c has a description or help text
- ✅ DocGen_Job__c.Parent_Record_Id__c is on the page layout
- ✅ DocGen_Job__c.Parent_Record_Id__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Parent_Record_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Query_Condition__c is on the page layout
- ✅ DocGen_Job__c.Query_Condition__c is granted on DocGen_Admin
- ✅ DocGen_Job__c.Query_Condition__c has a description or help text
- ✅ DocGen_Job__c.Sort_Order__c is on the page layout
- ✅ DocGen_Job__c.Sort_Order__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Sort_Order__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Status__c is on the page layout
- ✅ DocGen_Job__c.Status__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Success_Count__c is on the page layout
- ✅ DocGen_Job__c.Success_Count__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Success_Count__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Template__c is on the page layout
- ❌ DocGen_Job__c.Template__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job__c.Total_Records__c is on the page layout
- ✅ DocGen_Job__c.Total_Records__c is granted on DocGen_Admin
- ❌ DocGen_Job__c.Total_Records__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Saved_Query__c has a page layout
- ✅ DocGen_Saved_Query__c.Description__c is on the page layout
- ✅ DocGen_Saved_Query__c.Description__c is granted on DocGen_Admin
- ✅ DocGen_Saved_Query__c.Description__c has a description or help text
- ✅ DocGen_Saved_Query__c.DocGen_Template__c is on the page layout
- ✅ DocGen_Saved_Query__c.DocGen_Template__c has a description or help text
- ✅ DocGen_Saved_Query__c.Query_Condition__c is on the page layout
- ✅ DocGen_Saved_Query__c.Query_Condition__c is granted on DocGen_Admin
- ✅ DocGen_Saved_Query__c.Query_Condition__c has a description or help text
- ❌ DocGen_Settings__c.AI_Prompt_Template__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.AI_Provider_Class__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Company_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Experience_Site_Url__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Email_Brand_Color__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Email_Footer_Text__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Email_Logo_Url__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Email_Message__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Email_Subject__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Expiration_Days__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_OWA_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Prefill_Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Reminder_Enabled__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Reminder_Hours__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Reminder_Schedule__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings__c.Signature_Skip_Email_Verification__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c has a page layout
- ✅ DocGen_Signature_Audit__c.Consent_Captured__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Consent_Captured__c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit__c.Consent_Captured__c has a description or help text
- ✅ DocGen_Signature_Audit__c.Contact__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Contact__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Contact__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Document_Hash_SHA256__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Document_Hash_SHA256__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Document_Hash_SHA256__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Error_Message__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Error_Message__c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit__c.Error_Message__c has a description or help text
- ✅ DocGen_Signature_Audit__c.IP_Address__c is on the page layout
- ✅ DocGen_Signature_Audit__c.IP_Address__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.IP_Address__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.PIN_Verified_At__c is on the page layout
- ✅ DocGen_Signature_Audit__c.PIN_Verified_At__c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit__c.PIN_Verified_At__c has a description or help text
- ✅ DocGen_Signature_Audit__c.Signature_Request__c is on the page layout
- ❌ DocGen_Signature_Audit__c.Signature_Request__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Signed_Date__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Signed_Date__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Signed_Date__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Signer_Email__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Signer_Email__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Signer_Name__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Signer_Name__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Signer_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Signer__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Signer__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Signer__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.User_Agent__c is on the page layout
- ✅ DocGen_Signature_Audit__c.User_Agent__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.User_Agent__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit__c.Verification_Method__c is on the page layout
- ✅ DocGen_Signature_Audit__c.Verification_Method__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit__c.Verification_Method__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_PDF__e.Request_Id__c has a description or help text
- ✅ DocGen_Signature_Placement__c has a page layout
- ✅ DocGen_Signature_Placement__c.Document_Index__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Document_Index__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Document_Index__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Placement_Type__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Placement_Type__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Placement_Type__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Render_Inline__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Render_Inline__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Render_Inline__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Section_Context__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Section_Context__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Section_Context__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Sequence_Order__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Sequence_Order__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Sequence_Order__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Signature_Request__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Signature_Request__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Signature_Request__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Signed_At__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Signed_At__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Signed_At__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Signed_Value__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Signed_Value__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Signed_Value__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Signer__c is on the page layout
- ❌ DocGen_Signature_Placement__c.Signer__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Status__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Status__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement__c.Tag_Text__c is on the page layout
- ✅ DocGen_Signature_Placement__c.Tag_Text__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement__c.Tag_Text__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c has a page layout
- ✅ DocGen_Signature_Request__c.Document_Title_Format__c is on the page layout
- ✅ DocGen_Signature_Request__c.Document_Title_Format__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Document_Title_Format__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Email_Status__c is on the page layout
- ✅ DocGen_Signature_Request__c.Email_Status__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Email_Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Expires_At__c is on the page layout
- ✅ DocGen_Signature_Request__c.Expires_At__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Expires_At__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Frozen_Document_CV_Id__c is kept OFF the page layout
- ✅ DocGen_Signature_Request__c.Frozen_Document__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Frozen_Document__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Prefill_Signer_Email__c is on the page layout
- ✅ DocGen_Signature_Request__c.Prefill_Signer_Email__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Prefill_Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Related_Record_Id__c is on the page layout
- ✅ DocGen_Signature_Request__c.Related_Record_Id__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Related_Record_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Render_Data_Snapshot__c is kept OFF the page layout
- ✅ DocGen_Signature_Request__c.Require_Email_Verification__c is on the page layout
- ✅ DocGen_Signature_Request__c.Require_Email_Verification__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Require_Email_Verification__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Secure_Token__c is kept OFF the page layout
- ✅ DocGen_Signature_Request__c.Signature_Data__c is kept OFF the page layout
- ✅ DocGen_Signature_Request__c.Signer_Email__c is on the page layout
- ✅ DocGen_Signature_Request__c.Signer_Email__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Signer_Name__c is on the page layout
- ✅ DocGen_Signature_Request__c.Signer_Name__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Signer_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Signing_Order__c is on the page layout
- ✅ DocGen_Signature_Request__c.Signing_Order__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Signing_Order__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Snapshot_Hash__c is kept OFF the page layout
- ✅ DocGen_Signature_Request__c.Snapshot_Taken_At__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Snapshot_Taken_At__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Source_Document_Id__c is on the page layout
- ✅ DocGen_Signature_Request__c.Source_Document_Id__c is granted on DocGen_Admin
- ✅ DocGen_Signature_Request__c.Source_Document_Id__c has a description or help text
- ✅ DocGen_Signature_Request__c.Status__c is on the page layout
- ✅ DocGen_Signature_Request__c.Status__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Template_Ids__c is on the page layout
- ✅ DocGen_Signature_Request__c.Template_Ids__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Template_Ids__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request__c.Template__c is on the page layout
- ✅ DocGen_Signature_Request__c.Template__c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request__c.Template__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c has a page layout
- ✅ DocGen_Signer__c.Consent_Captured__c is on the page layout
- ✅ DocGen_Signer__c.Consent_Captured__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.Consent_Captured__c has a description or help text
- ✅ DocGen_Signer__c.Contact__c is on the page layout
- ✅ DocGen_Signer__c.Contact__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Contact__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Decline_Reason__c is on the page layout
- ✅ DocGen_Signer__c.Decline_Reason__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Decline_Reason__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Field_Data_Json__c is kept OFF the page layout
- ✅ DocGen_Signer__c.PIN_Attempts__c is on the page layout
- ✅ DocGen_Signer__c.PIN_Attempts__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.PIN_Attempts__c has a description or help text
- ✅ DocGen_Signer__c.PIN_Expires_At__c is on the page layout
- ✅ DocGen_Signer__c.PIN_Expires_At__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.PIN_Expires_At__c has a description or help text
- ✅ DocGen_Signer__c.PIN_Hash__c is kept OFF the page layout
- ✅ DocGen_Signer__c.PIN_Verified_At__c is on the page layout
- ✅ DocGen_Signer__c.PIN_Verified_At__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.PIN_Verified_At__c has a description or help text
- ✅ DocGen_Signer__c.Reminder_Sent_At__c is on the page layout
- ✅ DocGen_Signer__c.Reminder_Sent_At__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Reminder_Sent_At__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Reminders_Sent__c is on the page layout
- ✅ DocGen_Signer__c.Reminders_Sent__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Reminders_Sent__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Role_Name__c is on the page layout
- ✅ DocGen_Signer__c.Role_Name__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.Role_Name__c has a description or help text
- ✅ DocGen_Signer__c.Secure_Token__c is kept OFF the page layout
- ✅ DocGen_Signer__c.Signature_Data__c is granted on DocGen_Admin
- ✅ DocGen_Signer__c.Signature_Data__c has a description or help text
- ✅ DocGen_Signer__c.Signature_Request__c is on the page layout
- ❌ DocGen_Signer__c.Signature_Request__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Signer_Email__c is on the page layout
- ✅ DocGen_Signer__c.Signer_Email__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Signer_Name__c is on the page layout
- ✅ DocGen_Signer__c.Signer_Name__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Signer_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Sort_Order__c is on the page layout
- ✅ DocGen_Signer__c.Sort_Order__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Sort_Order__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer__c.Status__c is on the page layout
- ✅ DocGen_Signer__c.Status__c is granted on DocGen_Admin
- ❌ DocGen_Signer__c.Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c has a page layout
- ✅ DocGen_Template_Version__c.Base_Object_API__c is on the page layout
- ✅ DocGen_Template_Version__c.Base_Object_API__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Base_Object_API__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Category__c is on the page layout
- ✅ DocGen_Template_Version__c.Category__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Category__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Content_Version_Id__c is on the page layout
- ✅ DocGen_Template_Version__c.Content_Version_Id__c is granted on DocGen_Admin
- ✅ DocGen_Template_Version__c.Content_Version_Id__c has a description or help text
- ✅ DocGen_Template_Version__c.Custom_Margins__c is on the page layout
- ✅ DocGen_Template_Version__c.Custom_Margins__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Custom_Margins__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Description__c is on the page layout
- ✅ DocGen_Template_Version__c.Description__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Description__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Document_Title_Format__c is on the page layout
- ✅ DocGen_Template_Version__c.Document_Title_Format__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Document_Title_Format__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Footer_Html__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Footer_Html__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Header_Html__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Header_Html__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Is_Active__c is on the page layout
- ✅ DocGen_Template_Version__c.Is_Active__c is granted on DocGen_Admin
- ✅ DocGen_Template_Version__c.Is_Active__c has a description or help text
- ✅ DocGen_Template_Version__c.Output_Format__c is on the page layout
- ✅ DocGen_Template_Version__c.Output_Format__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Output_Format__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Page_Margins__c is on the page layout
- ✅ DocGen_Template_Version__c.Page_Margins__c is granted on DocGen_Admin
- ✅ DocGen_Template_Version__c.Page_Margins__c has a description or help text
- ✅ DocGen_Template_Version__c.Page_Orientation__c is on the page layout
- ✅ DocGen_Template_Version__c.Page_Orientation__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Page_Orientation__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Page_Size__c is on the page layout
- ✅ DocGen_Template_Version__c.Page_Size__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Page_Size__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Pre_Decomposition_Status__c is on the page layout
- ✅ DocGen_Template_Version__c.Pre_Decomposition_Status__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Pre_Decomposition_Status__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Query_Config__c is granted on DocGen_Admin
- ✅ DocGen_Template_Version__c.Query_Config__c has a description or help text
- ✅ DocGen_Template_Version__c.Template__c is on the page layout
- ✅ DocGen_Template_Version__c.Template__c has a description or help text
- ✅ DocGen_Template_Version__c.Type__c is on the page layout
- ✅ DocGen_Template_Version__c.Type__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Type__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version__c.Watermark_Image_CV_Id__c is granted on DocGen_Admin
- ❌ DocGen_Template_Version__c.Watermark_Image_CV_Id__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c has a page layout
- ✅ DocGen_Template__c.API_Name__c is on the page layout
- ✅ DocGen_Template__c.API_Name__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.API_Name__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Base_Object_API__c is on the page layout
- ✅ DocGen_Template__c.Base_Object_API__c has a description or help text
- ✅ DocGen_Template__c.Category__c is on the page layout
- ✅ DocGen_Template__c.Category__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Category__c has a description or help text
- ✅ DocGen_Template__c.Custom_Margins__c is on the page layout
- ✅ DocGen_Template__c.Custom_Margins__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Custom_Margins__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Default_Email_Message__c is on the page layout
- ✅ DocGen_Template__c.Default_Email_Message__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Default_Email_Message__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Description__c is on the page layout
- ✅ DocGen_Template__c.Description__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Description__c has a description or help text
- ✅ DocGen_Template__c.Document_Title_Format__c is on the page layout
- ✅ DocGen_Template__c.Document_Title_Format__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Document_Title_Format__c has a description or help text
- ✅ DocGen_Template__c.Draft_Body__c is on the page layout
- ✅ DocGen_Template__c.Draft_Body__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Draft_Body__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Footer_Html__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Footer_Html__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Form_Fields_Config__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Form_Fields_Config__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Header_Html__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Header_Html__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Is_Active__c is on the page layout
- ✅ DocGen_Template__c.Is_Active__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Is_Active__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Is_Default__c is on the page layout
- ✅ DocGen_Template__c.Is_Default__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Is_Default__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Lock_Output_Format__c is on the page layout
- ✅ DocGen_Template__c.Lock_Output_Format__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Lock_Output_Format__c has a description or help text
- ✅ DocGen_Template__c.Output_Format__c is on the page layout
- ✅ DocGen_Template__c.Output_Format__c has a description or help text
- ✅ DocGen_Template__c.Page_Margins__c is on the page layout
- ✅ DocGen_Template__c.Page_Margins__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Page_Margins__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Page_Orientation__c is on the page layout
- ✅ DocGen_Template__c.Page_Orientation__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Page_Orientation__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Page_Size__c is on the page layout
- ✅ DocGen_Template__c.Page_Size__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Page_Size__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Prefill_Signer_Email__c is on the page layout
- ✅ DocGen_Template__c.Prefill_Signer_Email__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Prefill_Signer_Email__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Query_Config__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Query_Config__c has a description or help text
- ✅ DocGen_Template__c.Record_Filter__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Record_Filter__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Required_Permission_Sets__c is on the page layout
- ✅ DocGen_Template__c.Required_Permission_Sets__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Required_Permission_Sets__c has a description or help text
- ✅ DocGen_Template__c.Signer_Verification__c is on the page layout
- ✅ DocGen_Template__c.Signer_Verification__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Signer_Verification__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Sort_Order__c is on the page layout
- ✅ DocGen_Template__c.Sort_Order__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Sort_Order__c has a description or help text
- ✅ DocGen_Template__c.Specific_Record_Ids__c is granted on DocGen_Admin
- ❌ DocGen_Template__c.Specific_Record_Ids__c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template__c.Test_Record_Id__c is on the page layout
- ✅ DocGen_Template__c.Test_Record_Id__c is granted on DocGen_Admin
- ✅ DocGen_Template__c.Test_Record_Id__c has a description or help text
- ✅ DocGen_Template__c.Type__c is on the page layout
- ✅ DocGen_Template__c.Type__c has a description or help text
- ✅ Product2.Product_Image__c has a description or help text
- ✅ docGenAdmin is exposed and declares at least one target — lightning__AppPage, lightning__HomePage, lightning__Tab
- ✅ docGenAdmin (app page) is reachable from a tab
- ✅ docGenAdminGuide is exposed and declares at least one target — lightning__AppPage, lightning__RecordPage, lightning__HomePage, lightning__Tab
- ✅ docGenAdminGuide (app page) is reachable from a tab
- ✅ docGenAuthenticator is exposed and declares at least one target — lightningCommunity__Page, lightning__AppPage
- ❌ docGenAuthenticator (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenBulkRunner is exposed and declares at least one target — lightning__AppPage, lightning__HomePage, lightning__Tab
- ✅ docGenBulkRunner (app page) is reachable from a tab
- ✅ docGenButton is exposed and declares at least one target — lightning__RecordAction
- ✅ docGenCommandHub is exposed and declares at least one target — lightning__AppPage, lightning__HomePage, lightning__Tab
- ✅ docGenCommandHub (app page) is reachable from a tab
- ✅ docGenQueryBuilder is exposed and declares at least one target — lightning__AppPage, lightning__RecordPage, lightning__HomePage
- ❌ docGenQueryBuilder (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenRunner is exposed and declares at least one target — lightning__RecordPage, lightning__AppPage, lightning__FlowScreen, lightning__UtilityBar, lightningCommunity__Page, lightningCommunity__Default
- ❌ docGenRunner (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenSetupWizard is exposed and declares at least one target — lightning__AppPage, lightning__HomePage, lightning__RecordPage, lightning__Tab
- ✅ docGenSetupWizard (app page) is reachable from a tab
- ✅ docGenSignatureSender is exposed and declares at least one target — lightning__RecordAction, lightning__RecordPage
- ✅ docGenTreeBuilder is exposed and declares at least one target — lightning__AppPage, lightning__RecordPage, lightning__HomePage
- ❌ docGenTreeBuilder (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page

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

### apex-unit — Apex unit

- ✅ the Apex test run passes — 1954 tests, 100%
- ✅ DocGenDataRetriever meets the 75% packaging bar — 78% (1013/1298 lines)
- ✅ DocGenEmailTemplateService meets the 75% packaging bar — 93% (358/383 lines)
- ✅ DocGenSignatureFinalizer meets the 75% packaging bar — 100% (3/3 lines)
- ✅ DocGenChartRasterizer meets the 75% packaging bar — 91% (836/914 lines)
- ✅ DocGenMergeJob meets the 75% packaging bar — 90% (84/93 lines)
- ❌ DocGenSignatureService meets the 75% packaging bar — 54% (575/1065 lines)
- ❌ DocGenSvgChartSerializer meets the 75% packaging bar — 43% (415/973 lines)
- ✅ DocGenBulkFlowAction meets the 75% packaging bar — 100% (53/53 lines)
- ✅ DocGenChartTagExpander meets the 75% packaging bar — 95% (280/294 lines)
- ✅ DocGenService meets the 75% packaging bar — 81% (4607/5679 lines)
- ✅ DocGenBulkController meets the 75% packaging bar — 91% (565/624 lines)
- ✅ DocGenAiEditGuard meets the 75% packaging bar — 98% (86/88 lines)
- ✅ DocGenSignatureValidator meets the 75% packaging bar — 100% (12/12 lines)
- ✅ DocGenPdfSaveQueueable meets the 75% packaging bar — 100% (8/8 lines)
- ✅ DocGenErrorLogger meets the 75% packaging bar — 81% (90/111 lines)
- ✅ DocGenButtonController meets the 75% packaging bar — 81% (136/168 lines)
- ✅ DocGenGiantQueryStitchJob meets the 75% packaging bar — 91% (156/171 lines)
- ✅ DocGenAiTemplateController meets the 75% packaging bar — 91% (118/129 lines)
- ❌ DocGenAcroFormService meets the 75% packaging bar — 65% (746/1154 lines)
- ✅ DocGenAiStubProvider meets the 75% packaging bar — 100% (12/12 lines)
- ✅ DocGenEmailTemplateController meets the 75% packaging bar — 88% (262/299 lines)
- ✅ DocGenButtonAdminController meets the 75% packaging bar — 90% (119/132 lines)
- ✅ DocGenAssetKeyHandler meets the 75% packaging bar — 93% (38/41 lines)
- ✅ DocGenSignatureFlowAction meets the 75% packaging bar — 97% (135/139 lines)
- ✅ DocGenSignatureSenderController meets the 75% packaging bar — 85% (1371/1604 lines)
- ✅ DocGenTemplateManager meets the 75% packaging bar — 91% (32/35 lines)
- ✅ DocGenSignatureExpiry meets the 75% packaging bar — 100% (28/28 lines)
- ✅ DocGenAiHtmlValidator meets the 75% packaging bar — 92% (505/546 lines)
- ✅ DocGenChartBucketResolver meets the 75% packaging bar — 88% (717/818 lines)
- ✅ DocGenChartFont meets the 75% packaging bar — 100% (1359/1361 lines)
- ✅ DocGenSignaturePdfFlowAction meets the 75% packaging bar — 87% (61/70 lines)
- ✅ DocGenChartImageController meets the 75% packaging bar — 91% (348/382 lines)
- ❌ DocGenSignatureGuestSecurity meets the 75% packaging bar — 63% (20/32 lines)
- ✅ DocGenContentDocumentCleanupQueueable meets the 75% packaging bar — 92% (11/12 lines)
- ❌ DocGenFlsGuard meets the 75% packaging bar — 69% (118/172 lines)
- ❌ DocGenApprovalHistory meets the 75% packaging bar — 9% (4/44 lines)
- ❌ DocGenGiantQueryFlowAction meets the 75% packaging bar — 47% (44/93 lines)
- ✅ DocGenFlowAction meets the 75% packaging bar — 91% (97/107 lines)
- ✅ DocGenGiantQueryBatch meets the 75% packaging bar — 85% (279/328 lines)
- ❌ DocGenHtmlRenderer meets the 75% packaging bar — 74% (2319/3150 lines)
- ❌ DocGenAiProviderFactory meets the 75% packaging bar — 54% (29/54 lines)
- ❌ DocGenChartCvReaper meets the 75% packaging bar — 54% (13/24 lines)
- ✅ DocGenSignatureEmailService meets the 75% packaging bar — 81% (195/242 lines)
- ❌ DocGenGiantQueryAssembler meets the 75% packaging bar — 53% (576/1077 lines)
- ✅ DocGenPdfPreparedBodyQueueable meets the 75% packaging bar — 100% (30/30 lines)
- ✅ DocGenFieldWritebackService meets the 75% packaging bar — 90% (225/250 lines)
- ✅ DocGenEmailTemplateInstall meets the 75% packaging bar — 100% (35/35 lines)
- ✅ DocGenSignatureSubmitter meets the 75% packaging bar — 100% (12/12 lines)
- ✅ DocGenPngEncoder meets the 75% packaging bar — 95% (134/141 lines)
- ✅ DocGenBatch meets the 75% packaging bar — 82% (262/318 lines)
- ✅ DocGenSetupController meets the 75% packaging bar — 89% (211/236 lines)
- ✅ DocGenAuthenticatorController meets the 75% packaging bar — 100% (78/78 lines)
- ✅ DocGenCurrency meets the 75% packaging bar — 79% (75/95 lines)
- ✅ DocGenBulkGiantFallbackJob meets the 75% packaging bar — 84% (37/44 lines)
- ✅ BarcodeGenerator meets the 75% packaging bar — 99% (587/594 lines)
- ✅ DocGenSignatureReminderSchedulable meets the 75% packaging bar — 96% (89/93 lines)
- ✅ DocGenSignatureController meets the 75% packaging bar — 84% (1222/1449 lines)
- ❌ DocGenController meets the 75% packaging bar — 72% (2792/3879 lines)
- ✅ DocGenSigner meets the 75% packaging bar — 100% (1/1 lines)
- ✅ DocGenGuestRenderQueueable meets the 75% packaging bar — 100% (1/1 lines)
- ✅ DocGenSignaturePdfTrigger meets the 75% packaging bar — 90% (74/82 lines)
- ✅ DocGenAssetKeyTrigger meets the 75% packaging bar — 100% (1/1 lines)
- ❌ DocGenFieldWritebackTrigger meets the 75% packaging bar — 67% (4/6 lines)
- ✅ DocGenTemplateLinter meets the 75% packaging bar — 94% (310/329 lines)
- ✅ org-wide coverage is at or above 75% — 79% (25013/31696 lines) — a 2GP build fails below 75%

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
- ✅ Text around an unresolved tag survives intact — actual: before  after
- ✅ Two tags in one text node both resolve — actual: Acme Corp/Won
- ✅ {Today:yyyy-MM-dd} equals the org calendar date — actual: 2026-08-08
- ✅ {Today:MMMM d, yyyy} formats the date — actual: August 8, 2026
- ✅ {Today} renders a date containing the current year — actual: 2026-08-08 07:00:00
- ✅ {Now:yyyy-MM-dd HH:mm} formats a timestamp — actual: 2026-08-08 04:13
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
- ✅ {*Field} defaults to a code128 barcode marker — actual: ##BARCODE:code128::ABC-123&amp;X##
- ✅ {*Field:qr} emits a QR marker — actual: ##BARCODE:qr::ABC-123&amp;X##
- ✅ {*Field:qr:200} carries the size through — actual: ##BARCODE:qr:200:ABC-123&amp;X##
- ✅ {*Field:code128:300x80} carries a WxH size through — actual: ##BARCODE:code128:300x80:ABC-123&amp;X##
- ✅ {*Field:code39} emits a code39 marker — actual: ##BARCODE:code39::ABC-123&amp;X##
- ✅ {*Field} XML-escapes the barcode value — actual: ##BARCODE:qr::ABC-123&amp;X##
- ✅ {*NullF:qr} on a null value emits nothing — actual: <empty>
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
- ✅ {?key} resolves from __formFields at finalize — actual: CTO
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
- ✅ {key} for a null value is empty, not the "__null__" sentinel — actual: [Bus][Car][Ash][Bike][]
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

### flow-actions — Flow actions & endpoints

- ✅ DocGenFlowAction still declares an @InvocableMethod
- ✅ DocGenBulkFlowAction still declares an @InvocableMethod
- ✅ DocGenGiantQueryFlowAction still declares an @InvocableMethod
- ✅ DocGenSignaturePdfFlowAction still declares an @InvocableMethod
- ✅ DocGenSignatureFlowAction still declares an @InvocableMethod
- ✅ DocGenSignatureValidator still declares an @InvocableMethod
- ✅ DocGenSignatureSubmitter still declares an @InvocableMethod
- ✅ DocGenSignatureFinalizer still declares an @InvocableMethod
- ✅ DocGenFieldWritebackService still declares an @InvocableMethod
- ✅ DocGenBulkFlowAction class is global (subscriber-visible)
- ✅ DocGenBulkFlowAction.generateBulkDocuments is global static
- ✅ DocGenBulkFlowAction.generateBulkDocuments has a Flow label — Generate Bulk Documents
- ✅ DocGenBulkFlowAction.generateBulkDocuments has a Flow description
- ✅ DocGenBulkFlowAction.Request (request type) is global
- ✅ DocGenBulkFlowAction.Request: all 9 @InvocableVariable fields are global
- ✅ DocGenBulkFlowAction.Request: every input/output carries a label
- ✅ DocGenBulkFlowAction.Response (response type) is global
- ✅ DocGenBulkFlowAction.Response: all 3 @InvocableVariable fields are global
- ✅ DocGenBulkFlowAction.Response: every input/output carries a label
- ✅ DocGenBulkFlowAction.generateBulkDocuments has no literal SOQL/DML inside the per-request loop
- ✅ DocGenFieldWritebackService class is global (subscriber-visible)
- ✅ DocGenFieldWritebackService.writeBackFields is global static
- ✅ DocGenFieldWritebackService.writeBackFields has a Flow label — Portwood: Write Back Signer Form Fields
- ✅ DocGenFieldWritebackService.writeBackFields has a Flow description
- ✅ DocGenFieldWritebackService.WritebackRequest (request type) is global
- ✅ DocGenFieldWritebackService.WritebackRequest: all 1 @InvocableVariable fields are global
- ✅ DocGenFieldWritebackService.WritebackRequest: every input/output carries a label
- ✅ DocGenFieldWritebackService.writeBackFields has no literal SOQL/DML inside the per-request loop
- ✅ DocGenFlowAction class is global (subscriber-visible)
- ✅ DocGenFlowAction.generateDocument is global static
- ✅ DocGenFlowAction.generateDocument has a Flow label — Generate Document
- ✅ DocGenFlowAction.generateDocument has a Flow description
- ✅ DocGenFlowAction.Request (request type) is global
- ✅ DocGenFlowAction.Request: all 7 @InvocableVariable fields are global
- ✅ DocGenFlowAction.Request: every input/output carries a label
- ✅ DocGenFlowAction.Response (response type) is global
- ✅ DocGenFlowAction.Response: all 4 @InvocableVariable fields are global
- ✅ DocGenFlowAction.Response: every input/output carries a label
- ❌ DocGenFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop — SOQL + DML inside a loop body — Flow can hand this action up to 200 requests in one transaction
- ✅ DocGenGiantQueryFlowAction class is global (subscriber-visible)
- ✅ DocGenGiantQueryFlowAction.generateDocument is global static
- ✅ DocGenGiantQueryFlowAction.generateDocument has a Flow label — Generate Document (Auto Giant Query)
- ✅ DocGenGiantQueryFlowAction.generateDocument has a Flow description
- ✅ DocGenGiantQueryFlowAction.Request (request type) is global
- ✅ DocGenGiantQueryFlowAction.Request: all 3 @InvocableVariable fields are global
- ✅ DocGenGiantQueryFlowAction.Request: every input/output carries a label
- ✅ DocGenGiantQueryFlowAction.Response (response type) is global
- ✅ DocGenGiantQueryFlowAction.Response: all 6 @InvocableVariable fields are global
- ✅ DocGenGiantQueryFlowAction.Response: every input/output carries a label
- ❌ DocGenGiantQueryFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop — SOQL inside a loop body — Flow can hand this action up to 200 requests in one transaction
- ✅ DocGenSignatureFinalizer class is global (subscriber-visible)
- ✅ DocGenSignatureFinalizer.finalizeSignature is global static
- ✅ DocGenSignatureFinalizer.finalizeSignature has a Flow label — Finalize Signature Image
- ✅ DocGenSignatureFinalizer.finalizeSignature has a Flow description
- ✅ DocGenSignatureFinalizer.FinalizeRequest (request type) is global
- ✅ DocGenSignatureFinalizer.FinalizeRequest: all 2 @InvocableVariable fields are global
- ❌ DocGenSignatureFinalizer.FinalizeRequest: every input/output carries a label — no label= on: token, base64Image — Flow Builder shows the raw Apex field name to the admin
- ✅ DocGenSignatureFinalizer.finalizeSignature has no literal SOQL/DML inside the per-request loop
- ✅ DocGenSignatureFlowAction class is global (subscriber-visible)
- ✅ DocGenSignatureFlowAction.generate is global static
- ✅ DocGenSignatureFlowAction.generate has a Flow label — Portwood: Create Signature Request
- ✅ DocGenSignatureFlowAction.generate has a Flow description
- ✅ DocGenSignatureFlowAction.Request (request type) is global
- ✅ DocGenSignatureFlowAction.Request: all 16 @InvocableVariable fields are global
- ✅ DocGenSignatureFlowAction.Request: every input/output carries a label
- ❌ DocGenSignatureFlowAction.Request.signers: Signer is a usable Apex-Defined Flow type (deprecated input) — not a top-level class (Flow never lists inner classes). All four are required — see DocGenSigner.cls for the reference implementation.
- ✅ DocGenSignatureFlowAction.Request.signerRecords: DocGenSigner is a usable Apex-Defined Flow type
- ✅ DocGenSignatureFlowAction.Result (response type) is global
- ✅ DocGenSignatureFlowAction.Result: all 8 @InvocableVariable fields are global
- ✅ DocGenSignatureFlowAction.Result: every input/output carries a label
- ✅ DocGenSignatureFlowAction.generate has no literal SOQL/DML inside the per-request loop
- ✅ DocGenSignaturePdfFlowAction class is global (subscriber-visible)
- ✅ DocGenSignaturePdfFlowAction.send is global static
- ✅ DocGenSignaturePdfFlowAction.send has a Flow label — Portwood: Send Existing Document for Signature (Deprecated — use "Portwood: Create Signature Request")
- ✅ DocGenSignaturePdfFlowAction.send has a Flow description
- ✅ DocGenSignaturePdfFlowAction.Request (request type) is global
- ✅ DocGenSignaturePdfFlowAction.Request: all 6 @InvocableVariable fields are global
- ✅ DocGenSignaturePdfFlowAction.Request: every input/output carries a label
- ✅ DocGenSignaturePdfFlowAction.Request.signerRecords: DocGenSigner is a usable Apex-Defined Flow type
- ✅ DocGenSignaturePdfFlowAction.Result (response type) is global
- ✅ DocGenSignaturePdfFlowAction.Result: all 7 @InvocableVariable fields are global
- ✅ DocGenSignaturePdfFlowAction.Result: every input/output carries a label
- ✅ DocGenSignaturePdfFlowAction.send has no literal SOQL/DML inside the per-request loop
- ✅ DocGenSignatureSubmitter class is global (subscriber-visible)
- ✅ DocGenSignatureSubmitter.submitSignature is global static
- ✅ DocGenSignatureSubmitter.submitSignature has a Flow label — Submit Signed Signature
- ❌ DocGenSignatureSubmitter.submitSignature has a Flow description — no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs
- ✅ DocGenSignatureSubmitter.FlowInput (request type) is global
- ✅ DocGenSignatureSubmitter.FlowInput: all 2 @InvocableVariable fields are global
- ✅ DocGenSignatureSubmitter.FlowInput: every input/output carries a label
- ✅ DocGenSignatureSubmitter.FlowOutput (response type) is global
- ✅ DocGenSignatureSubmitter.FlowOutput: all 2 @InvocableVariable fields are global
- ✅ DocGenSignatureSubmitter.FlowOutput: every input/output carries a label
- ✅ DocGenSignatureSubmitter.submitSignature has no literal SOQL/DML inside the per-request loop
- ✅ DocGenSignatureValidator class is global (subscriber-visible)
- ✅ DocGenSignatureValidator.validateToken is global static
- ✅ DocGenSignatureValidator.validateToken has a Flow label — Validate Signature Token
- ❌ DocGenSignatureValidator.validateToken has a Flow description — no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs
- ✅ DocGenSignatureValidator.FlowInput (request type) is global
- ✅ DocGenSignatureValidator.FlowInput: all 1 @InvocableVariable fields are global
- ✅ DocGenSignatureValidator.FlowInput: every input/output carries a label
- ✅ DocGenSignatureValidator.FlowOutput (response type) is global
- ✅ DocGenSignatureValidator.FlowOutput: all 5 @InvocableVariable fields are global
- ✅ DocGenSignatureValidator.FlowOutput: every input/output carries a label
- ✅ DocGenSignatureValidator.validateToken has no literal SOQL/DML inside the per-request loop
- ✅ Generate Document: returns one response per request (Flow batches)
- ✅ Generate Document: request 1 (by Template Id) returns a file
- ✅ Generate Document: request 2 (by Template API Name) returns a file
- ✅ Generate Document: the two requests produce two different documents
- ✅ Generate Document: Save to Record = false leaves the record's Files untouched (#90)
- ✅ Generate Document: a Flow batch of at least 10 requests fits in one transaction — 8 SOQL per request → about 12 requests per transaction (Flow can hand an invocable up to 200)
- ✅ Generate Document: no Template Id and no Template API Name → graceful failure with a useful message
- ✅ Generate Document: a template but no Record Id and no JSON Data → graceful failure with a useful message
- ✅ Generate Document: a Record Id that does not exist → graceful failure with a useful message
- ✅ Generate Document: a Template Id that does not exist → graceful failure with a useful message
- ✅ Generate Document: a template whose only version is inactive → graceful failure with a useful message
- ✅ Generate Document: JSON Data that is an array, not an object → graceful failure with a useful message
- ✅ Generate Document: a Template API Name that matches nothing → graceful failure with a useful message
- ✅ Generate Document (Auto Giant Query): returns one response per request
- ✅ Generate Document (Auto Giant Query): a small dataset renders synchronously and returns a file
- ✅ Generate Document (Auto Giant Query): Save to Record = true does attach the file
- ✅ Generate Document (Auto Giant Query): a Flow batch of at least 10 requests fits in one transaction — 9 SOQL per request → about 11 requests per transaction (Flow can hand an invocable up to 200)
- ✅ Generate Document (Auto Giant Query): a null Template Id → graceful failure with a useful message
- ✅ Generate Document (Auto Giant Query): a null Record Id → graceful failure with a useful message
- ✅ Generate Document (Auto Giant Query): a Template Id that does not exist → graceful failure with a useful message
- ✅ Generate Bulk Documents: returns one response per request
- ✅ Generate Bulk Documents: request 1 (explicit Record Ids) queues a job
- ✅ Generate Bulk Documents: request 2 (WHERE condition) queues a job
- ✅ Generate Bulk Documents: the two requests queue two different jobs
- ✅ Generate Bulk Documents: a malformed Record Id is rejected, not concatenated into SOQL
- ❌ Generate Bulk Documents: a WHERE condition that cannot compile is reported to the Flow — got: true~null
- ✅ Generate Bulk Documents: a null Template Id → graceful failure, not an unhandled Flow fault
- ✅ Create Signature Request: returns one result per request
- ✅ Create Signature Request: request 1 creates a request and one signing URL
- ✅ Create Signature Request: request 2 also succeeds (not poisoned by request 1)
- ✅ Create Signature Request: the two requests are distinct records
- ✅ Create Signature Request: a DocGen_Signer__c row is actually written
- ✅ Create Signature Request: the signing URL carries a 64-char token and targets the guided page
- ✅ Create Signature Request: Signer Names/Emails/Roles outputs echo the input (role defaults to "Signer")
- ⊘ Create Signature Request: the signing URL points at a real, reachable site — this org has no Experience Site URL in DocGen Settings, so the action returns the <CONFIGURE_SITE_URL_IN_SETUP> placeholder. The link shape is correct but end-to-end reachability is unproven here.
- ✅ Create Signature Request: a null Template Id → the Flow author gets an actionable message
- ✅ Create Signature Request: a null Related Record Id → the Flow author gets an actionable message
- ✅ Create Signature Request: an empty Signers collection → the Flow author gets an actionable message
- ✅ Create Signature Request: a signer with no email → the Flow author gets an actionable message
- ❌ Create Signature Request: input validation reports through Success/Error Message rather than faulting the Flow — throws DocGenException instead of returning Result.success=false for: a null Template Id; a null Related Record Id; an empty Signers collection; a signer with no email. The Result class advertises "Su
- ✅ Create Signature Request: a Template Id that does not exist fails with a catchable, readable error
- ✅ Send Existing Document for Signature (deprecated): returns one result per request
- ✅ Send Existing Document for Signature (deprecated): still creates a working request (existing Flows must not break)
- ✅ Send Existing Document for Signature (deprecated): second request also succeeds
- ✅ Send Existing Document for Signature (deprecated): the two requests are distinct records
- ✅ Send Existing Document for Signature (deprecated): a null request list returns empty, not an exception
- ✅ Send Existing Document for Signature (deprecated): the removed Content Version Id path explains what to use instead
- ✅ Validate Signature Token: returns one output per input
- ✅ Validate Signature Token: a live token validates and returns the signer + document title
- ✅ Validate Signature Token: a malformed token returns isValid=false with a reason
- ✅ Validate Signature Token: a null token returns isValid=false with a reason
- ❌ Validate Signature Token: survives a 60-request Flow batch — the action did not return — anonymous Apex died before it could report. System.LimitException: portwoodglobal:Too many SOQL queries: 101
- ✅ Submit Signed Signature: returns one output per input
- ✅ Submit Signed Signature: a bad token returns isSuccess=false with a reason
- ✅ Submit Signed Signature: null inputs return isSuccess=false with a reason
- ❌ Finalize Signature Image: a bad token is handled, not thrown into the Flow — got: THREW~portwoodglobal.DocGenSignatureService.SignatureException~Invalid security token format.
- ✅ Write Back Signer Form Fields: a mixed list (valid, null, malformed, missing) never throws
- ✅ Write Back Signer Form Fields: a null request list is a no-op
- ✅ Write Back Signer Form Fields: survives a 60-request Flow batch — note: the fixture request carries no form-field config, so this exercises the guard path, not a 60-record write
- ✅ docGenAdmin: getTemplateList returns templates
- ✅ docGenAdmin: getAllTemplates returns templates
- ✅ docGenRunner: getTemplatesForObject("Account") finds the fixture template
- ✅ docGenRunner: getTemplatesForObjectAndRecord respects record filters
- ✅ docGenAdmin: getTemplateById returns the right record
- ✅ Query builder: getObjectOptions is populated
- ✅ Query builder: getObjectFields("Account") is populated
- ✅ Query builder: getUpdateableObjectFields("Account") is populated
- ✅ Query builder: getChildRelationships("Account") is populated
- ✅ Preview: previewRecordData returns the requested fields
- ✅ Runner: generateDocumentData returns merge data
- ✅ docGenBulkRunner: getBulkTemplates returns templates
- ✅ docGenBulkRunner: validateFilter counts matching records
- ✅ docGenBulkRunner: getRecentJobs responds
- ✅ docGenBulkRunner: getSavedQueries responds
- ✅ Setup: getOrgUrl returns a URL
- ✅ Setup: getSettings responds
- ✅ Setup: getSettingsFresh responds
- ✅ Setup: getOrgWideEmailAddresses responds
- ✅ Setup: validateSignatureSetup returns its checklist
- ✅ Record page: getButtons responds for a record with no configured buttons
- ✅ Signing page: validateToken accepts a live token
- ✅ Test fixtures were cleaned up — 21 records removed

### output-formats — Output formats

- ✅ HTML→PDF: generation returned bytes — 75226 bytes
- ✅ HTML→PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ HTML→PDF: size above 800 bytes — 75226 bytes
- ✅ HTML→PDF: DocGenService.lastRenderedHtml captured for inspection — 675 chars
- ✅ HTML→PDF: merged parent field appears in the rendered document — both {Name} and {Industry} resolved in the rendered HTML
- ✅ HTML→PDF: every child-loop row rendered — ROW-Alpha, ROW-Bravo and ROW-Charlie all present
- ✅ HTML→PDF: non-Latin / unicode merge values survive the round trip — expected "Kabushiki 日本語 Ünïcødé Ω €" to appear; rendered slice was "UNI:Kabushiki <span style=\"font-family:'Arial Unicode MS', s"
- ✅ HTML→PDF: no unresolved merge tags leak into the output — no {Tag} or {#Loop} survived into the rendered HTML
- ✅ Document_Title_Format__c produces the document title — expected "QAOF187688249-QAOF187688249 Corp-Technology", got "QAOF187688249-QAOF187688249 Corp-Technology"
- ✅ HTML→PDF: result is labelled PDF — outputFormat=PDF templateType=HTML
- ✅ Word→DOCX: generation returned bytes — 1285 bytes
- ✅ Word→DOCX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ Word→DOCX: size above 400 bytes — 1285 bytes
- ✅ Word→DOCX: output opens as a ZIP archive — entries: word/document.xml&#124;word/_rels/document.xml.rels&#124;[Content_Types].xml&#124;_rels/.rels
- ✅ Word→DOCX: contains word/document.xml, [Content_Types].xml and _rels/.rels — document.xml=true content-types=true rels=true; parts: word/document.xml&#124;word/_rels/document.xml.rels&#124;[Content_Types].xml&#124;_rels/.rels
- ✅ Word→DOCX: merged data is inside the produced document.xml — {Name}=true {Industry}=true
- ✅ Word→DOCX: every child-loop row rendered — all three rows present in the produced word/document.xml
- ✅ Word→DOCX: no unresolved merge tags leak into the output — no {Tag} survived into word/document.xml
- ✅ Word→DOCX: Document_Title_Format__c applied — expected "QAOF187688249-QAOF187688249 Corp", got "QAOF187688249-QAOF187688249 Corp"
- ✅ Word→PDF: generation returned bytes — 1053 bytes
- ✅ Word→PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Word→PDF: size above 800 bytes — 1053 bytes
- ✅ Word→PDF: merged data survives the DOCX→HTML conversion — name=true rows=true
- ✅ Word→PDF: no raw OOXML reaches the PDF renderer — the converter emitted clean HTML — no <w:t>/<w:p> left
- ✅ Word→PDF: no unresolved merge tags leak into the output — no {Tag} survived the converter path
- ✅ PowerPoint→PPTX: generation returned bytes — 1226 bytes
- ✅ PowerPoint→PPTX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ PowerPoint→PPTX: size above 400 bytes — 1226 bytes
- ✅ PowerPoint→PPTX: ppt/slides/slide1.xml survives the repack — parts: ppt/_rels/presentation.xml.rels&#124;[Content_Types].xml&#124;_rels/.rels&#124;ppt/slides/slide1.xml
- ✅ PowerPoint→PPTX: merged data is inside the produced slide — merged=true leakedTags=false
- ✅ Excel→XLSX: generation returned bytes — 1436 bytes
- ✅ Excel→XLSX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ Excel→XLSX: size above 400 bytes — 1436 bytes
- ✅ Excel→XLSX: xl/worksheets/sheet1.xml survives the repack — parts: xl/_rels/workbook.xml.rels&#124;[Content_Types].xml&#124;xl/sharedStrings.xml&#124;xl/worksheets/sheet1.xml&#124;_rels/.rels
- ✅ Excel→XLSX: merged data is inside the produced sheet — merged=true leakedTags=false
- ✅ PDF AcroForm: generation returned bytes — 795 bytes
- ✅ PDF AcroForm: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ PDF AcroForm: size above 300 bytes — 795 bytes
- ✅ PDF AcroForm: merged value is written into the PDF — expected "QAOF187688249 Corp" in the filled PDF bytes; A_MERGED=true
- ✅ PDF AcroForm: incremental update appended (output larger than template) — template 513 bytes → output 795 bytes; equal size means no field was filled
- ✅ Template with no active version and no file fails instead of returning bytes — raised: Error retrieving template data: No template file found (active or attached).
- ✅ No-version failure message points at the template configuration — message was: Error retrieving template data: No template file found (active or attached). — an admin has to be able to tell what to fix
- ✅ Deactivated version with an attached file yields a valid PDF or a clean error, never a corrupt one — size=66799 hex=255044462D312E34 threw=false
- ✅ Zero-row child loop: generation returned bytes — 68011 bytes
- ✅ Zero-row child loop: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Zero-row child loop: size above 800 bytes — 68011 bytes
- ✅ Zero-row child collection: loop tags do not leak into the output — the loop collapsed cleanly with nothing to iterate
- ✅ Zero-row child collection: content around the loop is preserved — the heading before the loop and the paragraph after it both survived
- ✅ Zero-row child collection: no phantom row rendered — zero rows in, zero rows out
- ✅ Source HTML's own @page rule wins over the engine's page fields — sourceSizePresent=true engineSizeAlsoEmitted=false — two competing @page size declarations make Flying Saucer pick one silently
- ✅ Header image: generation returned bytes — 91123 bytes
- ✅ Header image: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Header image: size above 800 bytes — 91123 bytes
- ✅ Running header is wired into the @page margin box — running(dgheader)=true @top-center=true
- ✅ Tall header image grows the top margin instead of overflowing onto the body — margin-top raised to 1.65in for the 1.5in header image
- ✅ Missing image CV: generation returned bytes — 68244 bytes
- ✅ Missing image CV: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Missing image CV: size above 800 bytes — 68244 bytes
- ✅ Image field pointing at a missing ContentVersion does not abort generation — generation completed
- ✅ Missing image degrades without dropping the rest of the document — content before and after the image tag both survived
- ✅ Missing image does not leak the raw ContentVersion Id onto the page — no internal Id and no dangling <img src> in the output
- ✅ Very large document body: valid PDF or a clean, catchable error — size=505824 hex=255044462D312E34 at body length 1152000
- ✅ Very large document body: PDF is complete, not truncated — %%EOF trailer present in 505824 bytes
- ✅ Very large document body: output size reflects the content — 1152000-char body → 505824 bytes of PDF
- ✅ Generating against a record the user cannot read returns no document — raised: Error retrieving template data: Record data not found.
- ⊘ Record hidden by sharing/FLS from a low-privilege user — requires generating as a second, restricted user; System.runAs is test-context only and anonymous Apex cannot impersonate. Covered here only by the deleted-record analogue.
- ✅ Giant-query fixture actually crosses the 2000-row threshold — 2100 child rows — over the hard-coded 2000 threshold
- ✅ Over-threshold child collection routes to the giant-query path — isGiantQuery=true relationship=Contacts
- ✅ Giant-query job reaches Completed — status=Completed label=Giant Query totalRecords=2100
- ✅ Giant-query job harvested every child row — Total_Records__c=2100 of 2100 inserted
- ✅ Giant-query PDF: generation returned bytes — 109331 bytes
- ✅ Giant-query PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Giant-query PDF: size above 30000 bytes — 109331 bytes
- ✅ Giant-query PDF is complete, not truncated — %%EOF trailer present in 109331 bytes
- ✅ Giant-query output is named from Document_Title_Format__c — ContentVersion.Title was "QAOF187688249-giant-QAOF187688249 Giant", expected it to start with "QAOF187688249-giant-"
- ⊘ Giant-query PDF retains template chrome (title, column headers, footer) — the giant path builds its HTML inside the assembler and does not set DocGenService.lastRenderedHtml, and Apex cannot extract text from a rendered PDF. This is the exact shape of the v2.5.0 regression,
- ✅ Suite fixtures cleaned up — removed 14 templates, 3 accounts, 14 files, 1 jobs

### ui-designer — Designer UI

- ✅ designer opens (toolbar + canvas present) — {"bar":true,"pv":true}
- ✅ toolbar: B
- ✅ toolbar: I
- ✅ toolbar: U
- ✅ toolbar: S
- ✅ toolbar: x²
- ✅ toolbar: x₂
- ✅ toolbar: • List
- ✅ toolbar: 1. List
- ✅ toolbar: Left
- ✅ toolbar: Center
- ✅ toolbar: Right
- ✅ toolbar: Clear
- ✅ surface parity: bold works in header
- ✅ surface parity: bold works in footer
- ✅ zoom: body scales — {"pv":816,"hdr":816} -> {"pv":1224,"hdr":1224}
- ✅ zoom: header scales with the sheet — header must scale with the page
- ✅ table tools hidden outside a table — 24 table buttons visible
- ✅ table tools appear inside a table
- ✅ table tools work when shown (+ Row)
- ✅ table seams: render, no ghost targets, insert a column
- ✅ block handle: appears and reorders blocks — AAA,BBB -> BBB,AAA
- ✅ insert-table grid: 4x3 picker inserts and fits the page — cols=4 rows=4 overhang=false
- ✅ table never extends past the canvas after adding columns — table 1008px vs content 1080px
- ✅ cell selection highlight does not hang — 0 cells still marked selected
- ✅ bubble: appears on text selection
- ✅ bubble: position fixed (uncippable) — must be fixed, got true
- ✅ bubble: on screen with real size
- ✅ bubble: no clipping ancestor
- ✅ bubble: centre is hit-testable
- ✅ bubble: does not cover the selection
- ✅ bubble: bold actually formats
- ✅ popover textColor: opens, unclipped, hit-testable, formats
- ✅ popover highlight: opens, unclipped, hit-testable, formats
- ✅ popover font: opens, unclipped, hit-testable, formats
- ✅ header/footer are part of the sheet (width, alignment, flush) — w 1224/1224 left 108/108 gaps 0,0
- ✅ table +/- shows a ghost of what it will add/remove — ok
- ✅ zoom: Fit width fills the column — ok
- ✅ focus mode hides the setup chrome — ok
- ✅ only one region highlighted after moving block->block->cell->cell — 1 regions painted
- ✅ backtick opens the insert menu
- ✅ no invisible chrome intercepts clicks
- ✅ canvas click points reach the page
- ✅ undo: table row insert restores the document exactly — ok
- ✅ undo: table row delete restores the document exactly — ok
- ✅ undo: block move restores block order — ok
- ✅ undo: redo re-applies the undone edit — ok
- ✅ undo: one step covers the header band too — ok
- ✅ undo: toolbar button enables once there is history — ok
- ✅ regions: Source view shows the header as a marked region — header region + content must appear in the one source document
- ✅ regions: Source view shows the body as a marked region
- ✅ regions: Source view shows the footer as a marked region
- ✅ regions: round-trip preserves the header
- ✅ regions: round-trip preserves the body
- ✅ regions: round-trip preserves the footer
- ✅ regions: header does not leak into the body canvas — chrome in the body would print twice
- ✅ regions: no data-dg-region marker reaches the renderer — same discipline as .dg-drop-marker / data-dg-paint
- ✅ regions: a legacy template with no markers still loads and keeps its header — ok
- ✅ model: chrome is read from the live surfaces, not the last synced field
- ✅ header tools appear in the toolbar when the caret is in a band — page counters must be contextual, not in a separate panel
- ✅ insert lands in the header band, not the bottom of the body — ok
- ✅ header tools hide again when the caret returns to the body — page counters are meaningless in the body
- ✅ table seams survive the pointer leaving the table — ok
- ⊘ header renders asset tags as images — skip: no assets in this org
- ✅ a tall header at zoom does not overlap the page — ok
- ⊘ resizing a header image does not duplicate it — skip: no assets
- ✅ Enter inserts a line break, staying in the paragraph — {"blocks":1,"brInP":true}
- ✅ Shift+Enter starts a new paragraph — {"blocks":2,"brInP":true}
- ✅ Enter in a list makes the next item, not a line break — {"items":2,"brs":1}
- ✅ backtick opens the insert menu in the running header
- ✅ right-click opens the context menu in the header
- ✅ table tools appear for a table in the header
- ✅ table tools operate on the header table — 1 -> 2
- ✅ table handles track the pointer over a header table
- ✅ Tab moves to the next cell — landed in {"cell":"a2","rows":2}
- ✅ Shift+Tab moves back a cell — landed in {"cell":"a1","rows":2}
- ✅ Tab in the last cell adds a row and lands in it — rows 2 -> 3 (from cell b2)
- ✅ toolbar creates no fixed-positioning containing block — backdrop=none filter=none transform=none
- ✅ every insert-table grid cell is clickable — ok
- ✅ table handles are visible and clickable over a header table — 8/8 interactive
- ✅ the fill swatch applies a fill — ok
- ✅ fill applies to every cell in a multi-cell selection — ok
- ✅ the fill STAYS through hover, typing and caret moves — ok
- ✅ the fill survives into the serialized body — ok
- ✅ no editor chrome leaks into the serialized body — ok
- ✅ Designer tab offers templates to open when none is loaded — {"list":true,"count":7,"first":"Verify — Designer (pill-dense)AccountDesign →"}
- ✅ template list stays bounded regardless of org size — 7 rendered · 7 templates
- ✅ template search filters the list — ok
- ✅ clearing the search restores the list
- ✅ clicking a template on the Designer tab opens it for editing — {"pv":true,"bar":true}
- ✅ chip drag: a draggable tag chip is present — {Name}
- ✅ chip drag: a ghost follows the cursor mid-drag
- ✅ chip drag: an insertion caret tracks the pointer
- ✅ chip drag: a landing box outlines the receiving block — {"ghost":true,"caret":true,"zoneShown":true,"zoneHasArea":true,"zoneStripsAsChrome":true}
- ✅ chip drag: the landing box is strippable as editor chrome — must carry dg-drop-marker or it leaks into the saved template
- ✅ chip drag: the snippet lands in the page — {"landed":true,"ghostLeft":false,"markerLeft":false,"zoneLeft":false}
- ✅ chip drag: the ghost is cleaned up
- ✅ chip drag: no drop marker is left behind
- ✅ chip drag: no landing box is left behind
- ✅ chip click (no drag) still inserts — {"landed":true,"ghostLeft":false,"markerLeft":false,"zoneLeft":false}
- ✅ insert: caret lands after the tag, not before it — {"tagAt":1283,"typedAt":1288,"text":".dg-pv { background: #fff; max-width: 850px; margin: 0 auto; padding: 48px 56px;"}
- ✅ insert: two inserts keep their order — {"first":"{Name}","second":"{Industry}","a":1283,"b":1289}
- ✅ "/" reaches the canvas instead of global search — {"text":".dg-pv { background: #fff; max-width: 85","focusInSearch":false}
- ✅ "/" does not leave focus in global search
- ✅ no console errors during interaction

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
- ✅ wizard Back returns to step 1 and keeps what was typed — onStep1=true name="QAUI-ka5dmm-File" (expected "QAUI-ka5dmm-File")
- ✅ wizard step 2 refuses an empty query — Error notification. Error Please add at least one field to the query. Press Command + F6 to navigate to the next toast n
- ✅ wizard step 3 reviews the name, object and query it will save — reviewScreen=true nameEchoed=true queryEchoed=true
- ✅ the wizard creates a template record end to end — a0BRK00000gu3fl2AA, base object Account
- ✅ the created template keeps the query the wizard collected — Query_Config__c = Name, Industry, Phone
- ✅ the canvas path creates the template record — a0BRK00000gu3hN2AQ, Canvas/PDF
- ✅ and it is typed Canvas, which is what decides which editor opens — Type__c=Canvas
- ✅ the canvas path lands on the artboard
- ⊘ the floating panels open with their contents rendered — the designer never opened
- ✅ the template list renders rows — 10 rows; count label "10 templates"
- ✅ search narrows the list to matching rows only — 10 -> 2 rows for "ka5dmm"; every remaining row matches = true
- ✅ the row-count label reports the filtered subset — label reads "2 of 10 templates"
- ✅ a search with no matches empties the list instead of ignoring the query — 0 rows survived a nonsense query
- ✅ clearing the search restores the full list — 10 rows (expected 10)
- ✅ clicking a column header re-orders the rows both ways — clicked=true; first row "QAUI-ka5dmm-Starter Canvas P" -> asc "QA Fixtures Anchor Demo Canv" -> desc "Verify — Designer (pill-dens"
- ✅ Refresh reloads the list without emptying it — hit-test=ok; 10 rows after refresh (expected 10)
- ✅ "New Template" switches to the Create New wizard
- ✅ the row-action menu button is reachable by a mouse
- ✅ row action View opens the template on its Copy-Paste Tags tab — modalOpen=true, selected tabs: Your Templates, Copy-Paste Tags
- ✅ row action Export downloads a valid .docgen.json bundle — QAUI-ka5dmm-Starter.docgen.json — export version 1, template "QAUI-ka5dmm-Starter"
- ✅ Import Template restores an exported bundle as a new template — "QAUI-ka5dmm-Imported" exists after import
- ✅ row action Clone creates a copy and opens it for editing — created "QAUI-ka5dmm-File (Copy)" (a0BRK00000gtspL2AQ); the edit modal opened = true
- ✅ row action Delete removes the template — "QAUI-ka5dmm-File (Copy)" is gone from the org
- ✅ deleting a template asks for confirmation first — a confirmation step was shown
- ✅ row action Design opens that template in an editor — opened the canvas artboard
- ✅ row action Edit opens the edit modal
- ✅ the modal Save button is reachable (nothing covers the footer)
- ✅ edit modal tab "Settings" renders its panel — selected=Settings, controls=30, expected content present=true, text=1599 chars
- ⊘ edit modal tab "Header / Footer" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Watermark" renders its panel — selected=Watermark / Background, controls=2, expected content present=true, text=569 chars
- ✅ edit modal tab "Query Configuration" renders its panel — selected=Query Configuration, controls=7, expected content present=true, text=1265 chars
- ✅ edit modal tab "Signer Inputs" renders its panel — selected=Signer Inputs, controls=3, expected content present=true, text=485 chars
- ✅ edit modal tab "Copy-Paste Tags" renders its panel — selected=Copy-Paste Tags, controls=80, expected content present=true, text=1230 chars
- ⊘ edit modal tab "Fillable Fields" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Document & History" renders its panel — selected=Document & History, controls=2, expected content present=true, text=561 chars
- ✅ a tag chip copies its merge tag to the clipboard — clicked "{Name}"; the clipboard now holds "{Name}"
- ✅ Signer Inputs: "Add Field" adds a field row — signer field rows 0 -> 1
- ✅ Signer Inputs: a field row is editable — label was "New Field"
- ✅ Signer Inputs: removing a field takes it off the list — signer field rows 1 -> 0
- ✅ edit modal inputs accept real typing — description="edited by ui-admin ka5dmm" category="QAka5dmm"
- ✅ the Active toggle flips when clicked — checked true -> false
- ✅ Save as New Version persists the edited fields — stored description="edited by ui-admin ka5dmm", category="QAka5dmm" (expected "edited by ui-admin ka5dmm" / "QAka5dmm")
- ✅ Save as New Version really creates a new version record — template versions 0 -> 1
- ⊘ closing the modal with unsaved edits warns or preserves them — could not re-open the modal: row "QAUI-ka5dmm-Starter": the menu never offered a visible "Edit" item
- ✅ Command Hub: "My Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Template Library Manage your document designs and create new"; body 1565 chars
- ✅ Command Hub: "Bulk Generation" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Bulk Generation Create documents for hundreds of records at "; body 167 chars
- ✅ Command Hub: "Signatures" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Signature Settings Configure email branding, site URL, and s"; body 1264 chars
- ✅ Command Hub: "Assets" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Shared Assets Manage reusable images like logos and footers "; body 179 chars
- ✅ Command Hub: "Email Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Email Templates Brand and edit every signature email — reque"; body 1536 chars
- ✅ Command Hub: "Learning Center" opens its panel — panel header "Template Library Manage your document designs and create new" -> "User Guide The full Portwood User Guide lives on the web — a"; body 319 chars
- ✅ the Command Hub sidebar stays usable after opening Bulk Generation — 7 nav items reachable throughout
- ✅ no unexpected console errors while driving the admin UI
- ✅ the suite cleans up the templates it created — 3 QAUI- templates deleted

### ui-runner — End-user UI

- ✅ runner template picker offers an active, usable template for the record — picker returned: UIQA Good PDF, UIQA Locked Format, UIQA No Version — DocGenController.getTemplatesForObjectAndRecord
- ✅ picker hides a template whose Record_Filter__c excludes this record — Record_Filter__c = Industry = 'Agriculture'; the record is Technology. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides a template requiring a permission set the user lacks — Required_Permission_Sets__c = UIQA_No_Such_PermSet. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides an inactive template — Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ❌ picker hides a template that has no active version — "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObject
- ✅ generating from the picked template produces a real document — DocGenService.processDocument returned 66207 bytes
- ✅ the generated document's title resolves merge tokens against the record — Document_Title_Format__c = "UIQA-mskad8m4 {Name}" → title was "UIQA-mskad8m4 UIQA Alpha", expected "UIQA-mskad8m4 UIQA Alpha"
- ✅ a locked output format cannot be overridden at run time — Lock_Output_Format__c = true, override 'Word' → "This template locks its output format. Override not permitted."
- ✅ a template with no active version fails with a message, not a blank document — got: Error retrieving template data: No template file found (active or attached).
- ✅ bulk template picker excludes deactivated templates — matches the single-record runner
- ❌ a record-filtered template is not silently applied to excluded records in bulk — "UIQA Filtered Out" carries a Record_Filter__c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the
- ✅ the runner shows an actionable empty state when no template matches the record — with every Account template inactive the runner rendered 769 chars; Create Document disabled=true. The user must be told WHY there is nothing to pick, and must not be able to press a button that canno
- ✅ docGenRunner renders on a record page — rendered 570 chars, 2 picker(s), 1 primary button(s)
- ✅ the runner shows neither an error nor an empty state on a record that has templates — component text starts: Portwood Create or combine documents for this record. Create Document Document Packet Combine PDFs Category All Categories QA Fixtures UIQA (Uncategorized) Select Template Choos
- ✅ docGenRunner boots without a console error
- ✅ the record-page template picker lists a template the user can actually run — picker showed: Choose a template... / [QA Fixtures] Anchor Demo / [QA Fixtures] Anchor E2E / [QA Fixtures] Canvas Export Test / canvs / [QA Fixtures] Chart Scale Test (PowerPoint) / PDFQA Giant Chrome
- ✅ the record-page picker applies the active and audience rules — Inactive, Record_Filter__c-excluded and permission-gated templates were all withheld
- ✅ the template picker is reachable by a mouse — found=true hit=ok
- ✅ choosing a category narrows the template list to that category — after picking category "UIQA" the picker showed: [UIQA] UIQA Good PDF / [UIQA] UIQA Locked Format / [UIQA] UIQA No Version
- ✅ the Save to Record output choice is reachable — found=true hit=ok
- ✅ choosing Save to Record is honoured by the UI — output pills after the click: both, download, save(active)
- ✅ the Create Document button is reachable — found=true hit=ok
- ✅ pressing Create Document in Save to Record mode puts the document ON the record — ContentDocument "UIQA-mskad8m4 UIQA Alpha" linked to 001RK00002RDdO1YAL
- ✅ the saved file is in the template's own output format — Output_Format__c = PDF, file extension = .pdf
- ✅ choosing Download is honoured by the UI — output pills after the click: both, download(active), save
- ✅ pressing Create Document in Download mode downloads the document to the browser — the browser received "UIQA-mskad8m4 UIQA Alpha.pdf"
- ✅ Download does NOT also attach the document to the record — files linked to the record: 3 before the run, 3 after. Download and Save to Record are the two halves of one choice; honouring it means Download leaves the record untouched.
- ✅ choosing Save & Download is honoured by the UI — output pills after the click: both(active), download, save
- ✅ Save & Download hands the file to the browser — the browser received "UIQA-mskad8m4 UIQA Alpha.pdf"
- ✅ Save & Download also attaches the document to the record — files linked to the record: 3 before the run, 4 after. A download alone would leave this unchanged — which is exactly the bug this mode exists to avoid.
- ✅ a template with Lock_Output_Format__c exposes no runtime file-format control — with the locked template selected the runner offered 2 picker(s) (category + template) and the choice widgets [both, download, save], which are output DESTINATIONS, not formats. The server half of thi
- ✅ the Document Packet tab renders its template chooser and it is reachable — packet tab active=true, dual listboxes=1, source list hit=ok
- ✅ the packet chooser offers the record's PDF templates — chooser offered 10 template(s): Anchor Demo / Anchor E2E / Canvas Export Test / canvs / PDFQA Giant Chrome / Test
- ✅ the Create Packet button is reachable and refuses to run with nothing chosen — button hit=ok, disabled=true
- ✅ the Combine PDFs tab lists the record's existing PDFs and they are reachable — tab active=true, source list hit=ok, it offered 2 file(s) of which 2 are the two PDFs this suite attached to the record
- ✅ the Combine PDFs button is reachable and refuses to run with fewer than two files chosen — button hit=ok, disabled=true with nothing moved into the Combine list
- ✅ docGenSignatureSender renders on a record page — rendered 323 chars with its template picker, signer table and send button
- ✅ docGenSignatureSender boots without a console error
- ✅ the send button refuses to send with no document and no signer details — found=true disabled=true
- ❌ the signature document picker is reachable — found=false hit=missing
- ⊘ docGenSignatureSender validates its fields and writes the signature rows — no template could be selected, so no request could be sent
- ✅ bulk generation UI renders on its tab — {"chars":250,"hasHeading":true,"hasStep1":true}
- ✅ bulk generation UI boots without a console error
- ✅ the screen stays usable while a job is still running — template search box is hittable with 1 non-terminal job(s) present
- ✅ focusing the template box lists the available templates — 12 options offered
- ✅ typing narrows the template list to the match — after typing "UIQA Good": UIQA Good PDF (Account • PDF)
- ✅ a search with no matches says so instead of showing an empty box — expected the "No templates found" empty state in the dropdown
- ✅ a template option can be clicked — found=true hit=ok
- ✅ selecting a template opens the filter and run steps — Step 2 (Record Filter) and Step 3 (Run Generation) must appear once a template is chosen
- ✅ the bulk screen offers no file-format override — format stays the template’s — Output Mode options: Individual Files / Print-Ready Packet / Combined + Individual
- ✅ choosing an output mode is honoured by the UI — after picking "Individual Files" the control reads "Individual Files"
- ✅ the Validate Filter button is clickable — found=true hit=ok
- ✅ Validate reports the true number of matching records — expected "2 Records Found" for Name LIKE 'UIQA%' (2 accounts seeded); component text did not contain it
- ✅ the Run button is clickable once the filter is validated — found=true hit=ok
- ✅ pressing Run creates a bulk job on the server — DocGen_Job__c a03RK00001uHuwQYAS status Completed
- ✅ the job generates one document per matching record — status=Completed total=2 success=2 errors=0; error log: 
- ✅ each generated document is attached to its own record — 6 pdf files across 2 records (expected 1 each on 2 records) — Output Mode was Individual Files
- ✅ the output honours the template's Output Format (PDF) — extensions produced: pdf
- ✅ a run where every record fails is reported as failed, not as success — status=Failed success=0 errors=2
- ✅ the failing job records WHY each record failed — Error_Log__c = 001RK00002RDdO1YAL — portwoodglobal.DocGenException: Error retrieving template data: No template file found (active or attached). 001RK00002RDdO2YAL — portwoodglobal.DocGenException: Er
- ✅ the Recent Jobs list shows the error count to the user — Recent Jobs did not show "UIQA-mskad8m4-err" with "2 errors" — a user would see the run as finished with no indication anything went wrong
- ❌ a filter that matches no records leaves Run disabled — Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns
- ✅ the DocGen Command Hub renders with its navigation — {"present":true,"navs":["My Templates","Bulk Generation","Signatures","Assets","Buttons","Email Templates","Learning Center","MoreTabs","API Name Help Info","Type Help Info","Word","PDF"]}
- ✅ Command Hub "Bulk Generation" mounts its component — rendered 369 chars of text; consoleErrors=none
- ✅ Command Hub "Signatures" mounts its component — rendered 1265 chars of text; consoleErrors=none
- ✅ Command Hub "Assets" mounts its component — rendered 179 chars of text; consoleErrors=none
- ✅ Command Hub "Email Templates" mounts its component — rendered 1539 chars of text; consoleErrors=none
- ✅ the document Button builder mounts from the Command Hub — rendered 994 chars of text
- ✅ the DocGen quick action is reachable by a mouse — clickable on the highlights panel
- ✅ a retired or wrong-object button configuration never appears — getButtons returned only QA_Account_Doc — the inactive fixture and the Contact fixture were both withheld, so the component takes its run-immediately branch
- ✅ pressing the record action does not error — the action screen had already closed itself, which it only does after a successful generate
- ✅ the record action delivers a document to the browser — downloaded "QA Button Document.pdf"
- ✅ Save To Record = false leaves the record untouched — 5 files before and after
- ⊘ a user without the DocGen permission set gets a clear message, not a broken UI — the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previousl
- ⊘ a Document Packet contains every document it was built from — could not move templates into the packet: nothing reached the "In Packet" column — the move did not take

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

- ✅ every HTML template returns a body to the visual Designer — all 2 HTML templates return a non-empty body from getHtmlTemplateBody
- ✅ each template agrees with its active version about its own type — no template/version type disagreements
- ⊘ merge-tag pills stay inside their table cells — could not open a template in the Designer: no Designer tab
