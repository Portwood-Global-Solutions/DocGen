# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-26T12:26:13.940Z · **Duration** 2066s

## Headline

|                       |            |
| --------------------- | ---------- |
| Checks evaluated      | 1525       |
| Passed                | 1373 (90%) |
| Failed                | 152        |
| Skipped (not counted) | 13         |
| Blockers              | 4          |
| Major                 | 5          |
| Minor                 | 143        |

## Coverage by area

| Suite                | Area                     | Passed | Failed | Skipped |  Rate |
| -------------------- | ------------------------ | -----: | -----: | ------: | ----: |
| `metadata-audit`     | Metadata                 |    345 |    124 |       0 | 73.6% |
| `apex-e2e`           | Apex end-to-end          |     16 |      0 |       0 |  100% |
| `apex-unit`          | Apex unit                |     46 |     13 |       0 |   78% |
| `merge-tags`         | Merge tags               |    180 |      0 |       4 |  100% |
| `flow-actions`       | Flow actions & endpoints |    176 |     10 |       1 | 94.6% |
| `output-formats`     | Output formats           |     75 |      0 |       2 |  100% |
| `ui-designer`        | Designer UI              |     91 |      0 |       0 |  100% |
| `ui-admin`           | Admin UI                 |    107 |      0 |       2 |  100% |
| `ui-runner`          | End-user UI              |     75 |      3 |       2 | 96.2% |
| `record-pages`       | Record pages             |    248 |      0 |       0 |  100% |
| `pdf-content`        | PDF content              |     14 |      0 |       1 |  100% |
| `template-integrity` | Template integrity       |      0 |      2 |       1 |    0% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity    | Suite                | Check                                                                                                          | Evidence                                                                                                                                                                                                                                                                                                       |
| ----------- | -------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **blocker** | `apex-unit`          | the Apex test run passes                                                                                       | 1 failing: portwoodglobal.DocGenTests.testVersioning                                                                                                                                                                                                                                                           |
| **blocker** | `apex-unit`          | portwoodglobal.DocGenTests.testVersioning passes                                                               | System.AssertException: Assertion Failed: Should return V2 content: Expected: VjIgQ29udGVudA==, Actual: VGVzdCBDb250ZW50                                                                                                                                                                                       |
| **blocker** | `template-integrity` | every HTML template returns a body to the visual Designer                                                      | 4 of 7 return NOTHING — those open to an empty canvas however well they generate. The Designer reads a ContentVersion titled docgen*html_body*<templateId>, not the version's Content_Version_Id\_\_c: Verify — Cell Wrap + VAlign &#124; Verify — Landscape Precedence &#124; ZZ Warn Probe &#124; PDFQA Gian |
| **blocker** | `template-integrity` | each template agrees with its active version about its own type                                                | 4 disagree. Type\_\_c on the VERSION has Word as its picklist default, so any programmatic creation that omits it silently mistypes an HTML template — and the template derives its behaviour from the version: Verify — Cell Wrap + VAlign (tpl=HTML ver=Word) &#124; Verify — Landscape Precedence (tpl=HTML |
| **major**   | `flow-actions`       | Create Signature Request: input validation reports through Success/Error Message rather than faulting the Flow | throws DocGenException instead of returning Result.success=false for: a null Template Id; a null Related Record Id; an empty Signers collection; a signer with no email. The Result class advertises "Success" and "Error Message" outputs that are unreachable on these paths — the Flow interview faults i   |
| **major**   | `flow-actions`       | Validate Signature Token: survives a 60-request Flow batch                                                     | the action did not return — anonymous Apex died before it could report. System.LimitException: portwoodglobal:Too many SOQL queries: 101                                                                                                                                                                       |
| **major**   | `flow-actions`       | Finalize Signature Image: a bad token is handled, not thrown into the Flow                                     | got: THREW~portwoodglobal.DocGenSignatureService.SignatureException~Invalid security token format.                                                                                                                                                                                                             |
| **major**   | `ui-runner`          | picker hides a template that has no active version                                                             | "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObjectInternal filters on Is_Active**c/audience but never checks for an active DocGen_Template_Version**c.   |
| **major**   | `ui-runner`          | a record-filtered template is not silently applied to excluded records in bulk                                 | "UIQA Filtered Out" carries a Record_Filter\_\_c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the per-record check. Documents can be generated for records the template excludes. Either the batch mu |
| **minor**   | `metadata-audit`     | DocGen_Asset**c.Asset_Key**c has a description or help text                                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Asset**c.Asset_Type**c has a description or help text                                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Asset**c.Category**c has a description or help text                                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Asset**c.Is_Active**c has a description or help text                                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Object_API_Name**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Output_Format_Override**c has a description or help text                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Record_Type_Developer_Names**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Save_To_Record**c has a description or help text                                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Template_API_Name**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Button**mdt.Template_Id**c has a description or help text                                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Body_Html**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Body_Plain**c has a description or help text                                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Brand_Color**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Footer_Text**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Is_Active**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Layout_Mode**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Logo_Asset_Key**c has a description or help text                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Logo_Height**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Logo_Url_Extended**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Logo_Url**c has a description or help text                                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Subject**c has a description or help text                                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Email_Template**c.Type**c has a description or help text                                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Error_Log**c.Exception_Type**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Error_Log**c.Severity**c has a description or help text                                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Guest_Render**e.Job_Id**c has a description or help text                                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Error_Count**c has a description or help text                                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Error_Log**c has a description or help text                                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Label**c has a description or help text                                                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Merge_Only**c has a description or help text                                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Parent_Record_Id**c has a description or help text                                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Status**c has a description or help text                                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Success_Count**c has a description or help text                                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Template**c has a description or help text                                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Job**c.Total_Records**c has a description or help text                                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Company_Name**c has a description or help text                                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Experience_Site_Url**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Email_Brand_Color**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Email_Footer_Text**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Email_Logo_Url**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Email_Message**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Email_Subject**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Expiration_Days**c has a description or help text                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_OWA_Id**c has a description or help text                                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Prefill_Signer_Email**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Reminder_Enabled**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Reminder_Hours**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Reminder_Schedule**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Settings**c.Signature_Skip_Email_Verification**c has a description or help text                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Contact**c has a description or help text                                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Document_Hash_SHA256**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.IP_Address**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Signature_Request**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Signed_Date**c has a description or help text                                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Signer_Email**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Signer_Name**c has a description or help text                                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Signer**c has a description or help text                                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.User_Agent**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Audit**c.Verification_Method**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Document_Index**c has a description or help text                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Placement_Type**c has a description or help text                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Render_Inline**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Section_Context**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Sequence_Order**c has a description or help text                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Signature_Request**c has a description or help text                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Signed_At**c has a description or help text                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Signed_Value**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Signer**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Status**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Placement**c.Tag_Text**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Document_Title_Format**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Email_Status**c has a description or help text                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Expires_At**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Frozen_Document**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Prefill_Signer_Email**c has a description or help text                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Related_Record_Id**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Require_Email_Verification**c has a description or help text                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Signer_Email**c has a description or help text                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Signer_Name**c has a description or help text                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Signing_Order**c has a description or help text                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Snapshot_Taken_At**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Status**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Template_Ids**c has a description or help text                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signature_Request**c.Template**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Contact**c has a description or help text                                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Decline_Reason**c has a description or help text                                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Reminder_Sent_At**c has a description or help text                                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Reminders_Sent**c has a description or help text                                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Signature_Request**c has a description or help text                                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Signer_Email**c has a description or help text                                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Signer_Name**c has a description or help text                                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Sort_Order**c has a description or help text                                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Signer**c.Status**c has a description or help text                                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Base_Object_API**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Category**c has a description or help text                                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Custom_Margins**c has a description or help text                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Description**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Document_Title_Format**c has a description or help text                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Footer_Html**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Header_Html**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Output_Format**c has a description or help text                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Page_Orientation**c has a description or help text                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Page_Size**c has a description or help text                                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Pre_Decomposition_Status**c has a description or help text                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Type**c has a description or help text                                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template_Version**c.Watermark_Image_CV_Id**c has a description or help text                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.API_Name**c has a description or help text                                                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Custom_Margins**c has a description or help text                                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Default_Email_Message**c has a description or help text                                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Footer_Html**c has a description or help text                                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Form_Fields_Config**c has a description or help text                                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Header_Html**c has a description or help text                                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Is_Active**c has a description or help text                                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Is_Default**c has a description or help text                                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Page_Margins**c has a description or help text                                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Page_Orientation**c has a description or help text                                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Page_Size**c has a description or help text                                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Prefill_Signer_Email**c has a description or help text                                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Record_Filter**c has a description or help text                                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Signer_Verification**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | DocGen_Template**c.Specific_Record_Ids**c has a description or help text                                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                                                                                                                                      |
| **minor**   | `metadata-audit`     | docGenAuthenticator (app page) is reachable from a tab                                                         | no tab references it — reachable only via a hand-built Lightning page                                                                                                                                                                                                                                          |
| **minor**   | `metadata-audit`     | docGenQueryBuilder (app page) is reachable from a tab                                                          | no tab references it — reachable only via a hand-built Lightning page                                                                                                                                                                                                                                          |
| **minor**   | `metadata-audit`     | docGenRunner (app page) is reachable from a tab                                                                | no tab references it — reachable only via a hand-built Lightning page                                                                                                                                                                                                                                          |
| **minor**   | `metadata-audit`     | docGenTreeBuilder (app page) is reachable from a tab                                                           | no tab references it — reachable only via a hand-built Lightning page                                                                                                                                                                                                                                          |
| **minor**   | `apex-unit`          | DocGenHtmlRenderer meets the 75% packaging bar                                                                 | 74% (2319/3150 lines)                                                                                                                                                                                                                                                                                          |
| **minor**   | `apex-unit`          | DocGenFlsGuard meets the 75% packaging bar                                                                     | 69% (118/172 lines)                                                                                                                                                                                                                                                                                            |
| **minor**   | `apex-unit`          | DocGenSvgChartSerializer meets the 75% packaging bar                                                           | 43% (415/973 lines)                                                                                                                                                                                                                                                                                            |
| **minor**   | `apex-unit`          | DocGenSignatureGuestSecurity meets the 75% packaging bar                                                       | 63% (20/32 lines)                                                                                                                                                                                                                                                                                              |
| **minor**   | `apex-unit`          | DocGenApprovalHistory meets the 75% packaging bar                                                              | 9% (4/44 lines)                                                                                                                                                                                                                                                                                                |
| **minor**   | `apex-unit`          | DocGenController meets the 75% packaging bar                                                                   | 71% (2609/3697 lines)                                                                                                                                                                                                                                                                                          |
| **minor**   | `apex-unit`          | DocGenAcroFormService meets the 75% packaging bar                                                              | 65% (746/1154 lines)                                                                                                                                                                                                                                                                                           |
| **minor**   | `apex-unit`          | DocGenSignatureService meets the 75% packaging bar                                                             | 54% (575/1065 lines)                                                                                                                                                                                                                                                                                           |
| **minor**   | `apex-unit`          | DocGenGiantQueryAssembler meets the 75% packaging bar                                                          | 58% (562/962 lines)                                                                                                                                                                                                                                                                                            |
| **minor**   | `apex-unit`          | DocGenGiantQueryFlowAction meets the 75% packaging bar                                                         | 47% (44/93 lines)                                                                                                                                                                                                                                                                                              |
| **minor**   | `apex-unit`          | DocGenFieldWritebackTrigger meets the 75% packaging bar                                                        | 67% (4/6 lines)                                                                                                                                                                                                                                                                                                |
| **minor**   | `flow-actions`       | DocGenFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop                          | SOQL + DML inside a loop body — Flow can hand this action up to 200 requests in one transaction                                                                                                                                                                                                                |
| **minor**   | `flow-actions`       | DocGenGiantQueryFlowAction.generateDocument has no literal SOQL/DML inside the per-request loop                | SOQL inside a loop body — Flow can hand this action up to 200 requests in one transaction                                                                                                                                                                                                                      |
| **minor**   | `flow-actions`       | DocGenSignatureFinalizer.FinalizeRequest: every input/output carries a label                                   | no label= on: token, base64Image — Flow Builder shows the raw Apex field name to the admin                                                                                                                                                                                                                     |
| **minor**   | `flow-actions`       | DocGenSignatureFlowAction.Request.signers: Signer is a usable Apex-Defined Flow type (deprecated input)        | not a top-level class (Flow never lists inner classes). All four are required — see DocGenSigner.cls for the reference implementation.                                                                                                                                                                         |
| **minor**   | `flow-actions`       | DocGenSignatureSubmitter.submitSignature has a Flow description                                                | no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs                                                                                                                                                                                             |
| **minor**   | `flow-actions`       | DocGenSignatureValidator.validateToken has a Flow description                                                  | no description= on @InvocableMethod — the admin gets no help text explaining what the action does or what it needs                                                                                                                                                                                             |
| **minor**   | `flow-actions`       | Generate Bulk Documents: a WHERE condition that cannot compile is reported to the Flow                         | got: true~null                                                                                                                                                                                                                                                                                                 |
| **minor**   | `ui-runner`          | a filter that matches no records leaves Run disabled                                                           | Validate returned 0 records but Run Bulk Generation is still enabled — the user can submit a job that will produce nothing. isRunDisabled only requires filterValidated, and runAnalysis() early-returns on a 0 count so no analysis blocks it (docGenBulkRunner.js isRunDisabled / runAnalysis).              |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `merge-tags` — HTML-template escaping ({Field} newline → <br/>) behaves correctly: processXmlForTest(xml, data, templateType) is @TestVisible private and unreachable from anonymous Apex, so every check here runs the Word branch; HTML/Excel/PowerPoint escaping needs a unit test or a real HTML template render
- `merge-tags` — {PageNumber}/{TotalPages} render real page numbers in the PDF: processXml only preserves the tokens; the @page counter substitution happens in wrapHtmlForPdf and can only be verified on a rendered PDF (output-formats suite)
- `merge-tags` — {%ImageField} with a real ContentVersion renders an embedded image: needs an uploaded ContentVersion fixture and a real DOCX/PDF render; covered by scripts/e2e-09-images.apex, not by this parser-level probe
- `merge-tags` — The giant-query parent path resolves the same tag surface: DocGenGiantQueryAssembler.resolveParentMergeTags / resolveGiantChartBuckets do not go through processXmlForTest and need >2000 child rows to exercise
- `flow-actions` — Create Signature Request: the signing URL points at a real, reachable site: this org has no Experience Site URL in DocGen Settings, so the action returns the <CONFIGURE_SITE_URL_IN_SETUP> placeholder. The link shape is correct but end-to-end reachability is unproven here.
- `output-formats` — Record hidden by sharing/FLS from a low-privilege user: requires generating as a second, restricted user; System.runAs is test-context only and anonymous Apex cannot impersonate. Covered here only by the deleted-record analogue.
- `output-formats` — Giant-query PDF retains template chrome (title, column headers, footer): the giant path builds its HTML inside the assembler and does not set DocGenService.lastRenderedHtml, and Apex cannot extract text from a rendered PDF. This is the exact shape of the v2.5.0 regression, so it is a real gap — it needs a PDF text-extraction step outside Apex.
- `ui-admin` — edit modal tab "Fillable Fields" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — closing the modal with unsaved edits warns or preserves them: could not re-open the modal: row "QAUI-1sipiw-Starter": the menu never offered a visible "Edit" item
- `ui-runner` — a user without the DocGen permission set gets a clear message, not a broken UI: the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previously got reported as the component rendering nothing — a product defect that did not exist. Set the password once by hand and this check runs.
- `ui-runner` — a Document Packet contains every document it was built from: could not move templates into the packet: nothing reached the "In Packet" column — the move did not take
- `pdf-content` — the table header repeats on later pages (giant path): this render took the ORDINARY path — no -fs-table-paginate in the output, 2101 rows in one table — so per-page headers were never promised for it, and the headings correctly appear on 1 of 59 pages. The giant branch is chosen on an estimated HEAP, not a row count, so slim rows never reach it however many there are. Covering the repeat needs a seed whose rows are fat enough to cross that estimate.
- `template-integrity` — merge-tag pills stay inside their table cells: could not open a template in the Designer: no Designer tab

## Every check

### metadata-audit — Metadata

- ✅ DocGen_Asset\_\_c has a page layout
- ✅ DocGen_Asset**c.Asset_Key**c is on the page layout
- ❌ DocGen_Asset**c.Asset_Key**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset**c.Asset_Type**c is on the page layout
- ✅ DocGen_Asset**c.Asset_Type**c is granted on DocGen_Admin
- ❌ DocGen_Asset**c.Asset_Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset**c.Category**c is on the page layout
- ✅ DocGen_Asset**c.Category**c is granted on DocGen_Admin
- ❌ DocGen_Asset**c.Category**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Asset**c.Is_Active**c is on the page layout
- ✅ DocGen_Asset**c.Is_Active**c is granted on DocGen_Admin
- ❌ DocGen_Asset**c.Is_Active**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Button**mdt.Active**c has a description or help text
- ✅ DocGen_Button**mdt.Document_Title**c has a description or help text
- ❌ DocGen_Button**mdt.Object_API_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button**mdt.Output_Format_Override**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button**mdt.Record_Type_Developer_Names**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button**mdt.Save_To_Record**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Button**mdt.Sort_Order**c has a description or help text
- ❌ DocGen_Button**mdt.Template_API_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Button**mdt.Template_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template\_\_c has a page layout
- ✅ DocGen_Email_Template**c.Body_Html**c is on the page layout
- ✅ DocGen_Email_Template**c.Body_Html**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Body_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Body_Plain**c is on the page layout
- ✅ DocGen_Email_Template**c.Body_Plain**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Body_Plain**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Brand_Color**c is on the page layout
- ✅ DocGen_Email_Template**c.Brand_Color**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Brand_Color**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Description**c is on the page layout
- ✅ DocGen_Email_Template**c.Description**c is granted on DocGen_Admin
- ✅ DocGen_Email_Template**c.Description**c has a description or help text
- ✅ DocGen_Email_Template**c.Footer_Text**c is on the page layout
- ✅ DocGen_Email_Template**c.Footer_Text**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Footer_Text**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Is_Active**c is on the page layout
- ✅ DocGen_Email_Template**c.Is_Active**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Is_Active**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Layout_Mode**c is on the page layout
- ✅ DocGen_Email_Template**c.Layout_Mode**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Layout_Mode**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Logo_Asset_Key**c is on the page layout
- ✅ DocGen_Email_Template**c.Logo_Asset_Key**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Asset_Key**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Logo_Height**c is on the page layout
- ✅ DocGen_Email_Template**c.Logo_Height**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Height**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Logo_Url_Extended**c is on the page layout
- ✅ DocGen_Email_Template**c.Logo_Url_Extended**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Url_Extended**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Logo_Url**c is on the page layout
- ✅ DocGen_Email_Template**c.Logo_Url**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Url**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Subject**c is on the page layout
- ✅ DocGen_Email_Template**c.Subject**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Subject**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Email_Template**c.Type**c is on the page layout
- ❌ DocGen_Email_Template**c.Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log\_\_c has a page layout
- ✅ DocGen_Error_Log**c.Additional_Info**c is on the page layout
- ✅ DocGen_Error_Log**c.Additional_Info**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Additional_Info**c has a description or help text
- ✅ DocGen_Error_Log**c.Context**c is on the page layout
- ✅ DocGen_Error_Log**c.Context**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Context**c has a description or help text
- ✅ DocGen_Error_Log**c.Exception_Type**c is on the page layout
- ✅ DocGen_Error_Log**c.Exception_Type**c is granted on DocGen_Admin
- ❌ DocGen_Error_Log**c.Exception_Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log**c.Flow_Interview_Guid**c is on the page layout
- ✅ DocGen_Error_Log**c.Flow_Interview_Guid**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Flow_Interview_Guid**c has a description or help text
- ✅ DocGen_Error_Log**c.Job_Id**c is on the page layout
- ✅ DocGen_Error_Log**c.Job_Id**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Job_Id**c has a description or help text
- ✅ DocGen_Error_Log**c.Message**c is on the page layout
- ✅ DocGen_Error_Log**c.Message**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Message**c has a description or help text
- ✅ DocGen_Error_Log**c.Operation**c is on the page layout
- ✅ DocGen_Error_Log**c.Operation**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Operation**c has a description or help text
- ✅ DocGen_Error_Log**c.Record_Id**c is on the page layout
- ✅ DocGen_Error_Log**c.Record_Id**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Record_Id**c has a description or help text
- ✅ DocGen_Error_Log**c.Severity**c is on the page layout
- ✅ DocGen_Error_Log**c.Severity**c is granted on DocGen_Admin
- ❌ DocGen_Error_Log**c.Severity**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Error_Log**c.Stack_Trace**c is on the page layout
- ✅ DocGen_Error_Log**c.Stack_Trace**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Stack_Trace**c has a description or help text
- ✅ DocGen_Error_Log**c.Template_Id**c is on the page layout
- ✅ DocGen_Error_Log**c.Template_Id**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.Template_Id**c has a description or help text
- ✅ DocGen_Error_Log**c.User_Id**c is on the page layout
- ✅ DocGen_Error_Log**c.User_Id**c is granted on DocGen_Admin
- ✅ DocGen_Error_Log**c.User_Id**c has a description or help text
- ✅ DocGen_Field_Writeback**e.Request_Id**c has a description or help text
- ❌ DocGen_Guest_Render**e.Job_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Guest_Render**e.Record_Id**c has a description or help text
- ✅ DocGen_Guest_Render**e.Template_Id**c has a description or help text
- ✅ DocGen_Job\_\_c has a page layout
- ✅ DocGen_Job**c.Data_Cache_CV**c is kept OFF the page layout
- ✅ DocGen_Job**c.Error_Count**c is on the page layout
- ✅ DocGen_Job**c.Error_Count**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Error_Count**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Error_Log**c is on the page layout
- ✅ DocGen_Job**c.Error_Log**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Error_Log**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Giant_Query_Config**c is kept OFF the page layout
- ✅ DocGen_Job**c.Label**c is on the page layout
- ✅ DocGen_Job**c.Label**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Label**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Merge_Only**c is on the page layout
- ✅ DocGen_Job**c.Merge_Only**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Merge_Only**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Merged_PDF_CV**c is on the page layout
- ✅ DocGen_Job**c.Merged_PDF_CV**c is granted on DocGen_Admin
- ✅ DocGen_Job**c.Merged_PDF_CV**c has a description or help text
- ✅ DocGen_Job**c.Parent_Record_Id**c is on the page layout
- ✅ DocGen_Job**c.Parent_Record_Id**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Parent_Record_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Query_Condition**c is on the page layout
- ✅ DocGen_Job**c.Query_Condition**c is granted on DocGen_Admin
- ✅ DocGen_Job**c.Query_Condition**c has a description or help text
- ✅ DocGen_Job**c.Status**c is on the page layout
- ✅ DocGen_Job**c.Status**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Success_Count**c is on the page layout
- ✅ DocGen_Job**c.Success_Count**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Success_Count**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Template**c is on the page layout
- ❌ DocGen_Job**c.Template**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Total_Records**c is on the page layout
- ✅ DocGen_Job**c.Total_Records**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Total_Records**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Saved_Query\_\_c has a page layout
- ✅ DocGen_Saved_Query**c.Description**c is on the page layout
- ✅ DocGen_Saved_Query**c.Description**c is granted on DocGen_Admin
- ✅ DocGen_Saved_Query**c.Description**c has a description or help text
- ✅ DocGen_Saved_Query**c.DocGen_Template**c is on the page layout
- ✅ DocGen_Saved_Query**c.DocGen_Template**c has a description or help text
- ✅ DocGen_Saved_Query**c.Query_Condition**c is on the page layout
- ✅ DocGen_Saved_Query**c.Query_Condition**c is granted on DocGen_Admin
- ✅ DocGen_Saved_Query**c.Query_Condition**c has a description or help text
- ❌ DocGen_Settings**c.Company_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Experience_Site_Url**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Email_Brand_Color**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Email_Footer_Text**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Email_Logo_Url**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Email_Message**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Email_Subject**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Expiration_Days**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_OWA_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Prefill_Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Reminder_Enabled**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Reminder_Hours**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Reminder_Schedule**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Settings**c.Signature_Skip_Email_Verification**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit\_\_c has a page layout
- ✅ DocGen_Signature_Audit**c.Consent_Captured**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Consent_Captured**c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit**c.Consent_Captured**c has a description or help text
- ✅ DocGen_Signature_Audit**c.Contact**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Contact**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Contact**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Document_Hash_SHA256**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Document_Hash_SHA256**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Document_Hash_SHA256**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Error_Message**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Error_Message**c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit**c.Error_Message**c has a description or help text
- ✅ DocGen_Signature_Audit**c.IP_Address**c is on the page layout
- ✅ DocGen_Signature_Audit**c.IP_Address**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.IP_Address**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.PIN_Verified_At**c is on the page layout
- ✅ DocGen_Signature_Audit**c.PIN_Verified_At**c is granted on DocGen_Admin
- ✅ DocGen_Signature_Audit**c.PIN_Verified_At**c has a description or help text
- ✅ DocGen_Signature_Audit**c.Signature_Request**c is on the page layout
- ❌ DocGen_Signature_Audit**c.Signature_Request**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Signed_Date**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Signed_Date**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Signed_Date**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Signer_Email**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Signer_Email**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Signer_Name**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Signer_Name**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Signer_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Signer**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Signer**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Signer**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.User_Agent**c is on the page layout
- ✅ DocGen_Signature_Audit**c.User_Agent**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.User_Agent**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Audit**c.Verification_Method**c is on the page layout
- ✅ DocGen_Signature_Audit**c.Verification_Method**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Audit**c.Verification_Method**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_PDF**e.Request_Id**c has a description or help text
- ✅ DocGen_Signature_Placement\_\_c has a page layout
- ✅ DocGen_Signature_Placement**c.Document_Index**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Document_Index**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Document_Index**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Placement_Type**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Placement_Type**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Placement_Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Render_Inline**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Render_Inline**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Render_Inline**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Section_Context**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Section_Context**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Section_Context**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Sequence_Order**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Sequence_Order**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Sequence_Order**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Signature_Request**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Signature_Request**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Signature_Request**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Signed_At**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Signed_At**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Signed_At**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Signed_Value**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Signed_Value**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Signed_Value**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Signer**c is on the page layout
- ❌ DocGen_Signature_Placement**c.Signer**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Status**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Status**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Placement**c.Tag_Text**c is on the page layout
- ✅ DocGen_Signature_Placement**c.Tag_Text**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Placement**c.Tag_Text**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request\_\_c has a page layout
- ✅ DocGen_Signature_Request**c.Document_Title_Format**c is on the page layout
- ✅ DocGen_Signature_Request**c.Document_Title_Format**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Document_Title_Format**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Email_Status**c is on the page layout
- ✅ DocGen_Signature_Request**c.Email_Status**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Email_Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Expires_At**c is on the page layout
- ✅ DocGen_Signature_Request**c.Expires_At**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Expires_At**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Frozen_Document_CV_Id**c is kept OFF the page layout
- ✅ DocGen_Signature_Request**c.Frozen_Document**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Frozen_Document**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Prefill_Signer_Email**c is on the page layout
- ✅ DocGen_Signature_Request**c.Prefill_Signer_Email**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Prefill_Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Related_Record_Id**c is on the page layout
- ✅ DocGen_Signature_Request**c.Related_Record_Id**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Related_Record_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Render_Data_Snapshot**c is kept OFF the page layout
- ✅ DocGen_Signature_Request**c.Require_Email_Verification**c is on the page layout
- ✅ DocGen_Signature_Request**c.Require_Email_Verification**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Require_Email_Verification**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Secure_Token**c is kept OFF the page layout
- ✅ DocGen_Signature_Request**c.Signature_Data**c is kept OFF the page layout
- ✅ DocGen_Signature_Request**c.Signer_Email**c is on the page layout
- ✅ DocGen_Signature_Request**c.Signer_Email**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Signer_Name**c is on the page layout
- ✅ DocGen_Signature_Request**c.Signer_Name**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Signer_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Signing_Order**c is on the page layout
- ✅ DocGen_Signature_Request**c.Signing_Order**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Signing_Order**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Snapshot_Hash**c is kept OFF the page layout
- ✅ DocGen_Signature_Request**c.Snapshot_Taken_At**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Snapshot_Taken_At**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Source_Document_Id**c is on the page layout
- ✅ DocGen_Signature_Request**c.Source_Document_Id**c is granted on DocGen_Admin
- ✅ DocGen_Signature_Request**c.Source_Document_Id**c has a description or help text
- ✅ DocGen_Signature_Request**c.Status**c is on the page layout
- ✅ DocGen_Signature_Request**c.Status**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Template_Ids**c is on the page layout
- ✅ DocGen_Signature_Request**c.Template_Ids**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Template_Ids**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signature_Request**c.Template**c is on the page layout
- ✅ DocGen_Signature_Request**c.Template**c is granted on DocGen_Admin
- ❌ DocGen_Signature_Request**c.Template**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer\_\_c has a page layout
- ✅ DocGen_Signer**c.Consent_Captured**c is on the page layout
- ✅ DocGen_Signer**c.Consent_Captured**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.Consent_Captured**c has a description or help text
- ✅ DocGen_Signer**c.Contact**c is on the page layout
- ✅ DocGen_Signer**c.Contact**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Contact**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Decline_Reason**c is on the page layout
- ✅ DocGen_Signer**c.Decline_Reason**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Decline_Reason**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Field_Data_Json**c is kept OFF the page layout
- ✅ DocGen_Signer**c.PIN_Attempts**c is on the page layout
- ✅ DocGen_Signer**c.PIN_Attempts**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.PIN_Attempts**c has a description or help text
- ✅ DocGen_Signer**c.PIN_Expires_At**c is on the page layout
- ✅ DocGen_Signer**c.PIN_Expires_At**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.PIN_Expires_At**c has a description or help text
- ✅ DocGen_Signer**c.PIN_Hash**c is kept OFF the page layout
- ✅ DocGen_Signer**c.PIN_Verified_At**c is on the page layout
- ✅ DocGen_Signer**c.PIN_Verified_At**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.PIN_Verified_At**c has a description or help text
- ✅ DocGen_Signer**c.Reminder_Sent_At**c is on the page layout
- ✅ DocGen_Signer**c.Reminder_Sent_At**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Reminder_Sent_At**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Reminders_Sent**c is on the page layout
- ✅ DocGen_Signer**c.Reminders_Sent**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Reminders_Sent**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Role_Name**c is on the page layout
- ✅ DocGen_Signer**c.Role_Name**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.Role_Name**c has a description or help text
- ✅ DocGen_Signer**c.Secure_Token**c is kept OFF the page layout
- ✅ DocGen_Signer**c.Signature_Data**c is granted on DocGen_Admin
- ✅ DocGen_Signer**c.Signature_Data**c has a description or help text
- ✅ DocGen_Signer**c.Signature_Request**c is on the page layout
- ❌ DocGen_Signer**c.Signature_Request**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Signer_Email**c is on the page layout
- ✅ DocGen_Signer**c.Signer_Email**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Signer_Name**c is on the page layout
- ✅ DocGen_Signer**c.Signer_Name**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Signer_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Sort_Order**c is on the page layout
- ✅ DocGen_Signer**c.Sort_Order**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Sort_Order**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Signer**c.Status**c is on the page layout
- ✅ DocGen_Signer**c.Status**c is granted on DocGen_Admin
- ❌ DocGen_Signer**c.Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version\_\_c has a page layout
- ✅ DocGen_Template_Version**c.Base_Object_API**c is on the page layout
- ✅ DocGen_Template_Version**c.Base_Object_API**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Base_Object_API**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Category**c is on the page layout
- ✅ DocGen_Template_Version**c.Category**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Category**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Content_Version_Id**c is on the page layout
- ✅ DocGen_Template_Version**c.Content_Version_Id**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Content_Version_Id**c has a description or help text
- ✅ DocGen_Template_Version**c.Custom_Margins**c is on the page layout
- ✅ DocGen_Template_Version**c.Custom_Margins**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Custom_Margins**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Description**c is on the page layout
- ✅ DocGen_Template_Version**c.Description**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Description**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Document_Title_Format**c is on the page layout
- ✅ DocGen_Template_Version**c.Document_Title_Format**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Document_Title_Format**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Footer_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Footer_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Header_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Header_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Is_Active**c is on the page layout
- ✅ DocGen_Template_Version**c.Is_Active**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Is_Active**c has a description or help text
- ✅ DocGen_Template_Version**c.Output_Format**c is on the page layout
- ✅ DocGen_Template_Version**c.Output_Format**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Output_Format**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Page_Margins**c is on the page layout
- ✅ DocGen_Template_Version**c.Page_Margins**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Page_Margins**c has a description or help text
- ✅ DocGen_Template_Version**c.Page_Orientation**c is on the page layout
- ✅ DocGen_Template_Version**c.Page_Orientation**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Page_Orientation**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Page_Size**c is on the page layout
- ✅ DocGen_Template_Version**c.Page_Size**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Page_Size**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Pre_Decomposition_Status**c is on the page layout
- ✅ DocGen_Template_Version**c.Pre_Decomposition_Status**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Pre_Decomposition_Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Query_Config**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Query_Config**c has a description or help text
- ✅ DocGen_Template_Version**c.Template**c is on the page layout
- ✅ DocGen_Template_Version**c.Template**c has a description or help text
- ✅ DocGen_Template_Version**c.Type**c is on the page layout
- ✅ DocGen_Template_Version**c.Type**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Watermark_Image_CV_Id**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Watermark_Image_CV_Id**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template\_\_c has a page layout
- ✅ DocGen_Template**c.API_Name**c is on the page layout
- ✅ DocGen_Template**c.API_Name**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.API_Name**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Base_Object_API**c is on the page layout
- ✅ DocGen_Template**c.Base_Object_API**c has a description or help text
- ✅ DocGen_Template**c.Category**c is on the page layout
- ✅ DocGen_Template**c.Category**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Category**c has a description or help text
- ✅ DocGen_Template**c.Custom_Margins**c is on the page layout
- ✅ DocGen_Template**c.Custom_Margins**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Custom_Margins**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Default_Email_Message**c is on the page layout
- ✅ DocGen_Template**c.Default_Email_Message**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Default_Email_Message**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Description**c is on the page layout
- ✅ DocGen_Template**c.Description**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Description**c has a description or help text
- ✅ DocGen_Template**c.Document_Title_Format**c is on the page layout
- ✅ DocGen_Template**c.Document_Title_Format**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Document_Title_Format**c has a description or help text
- ✅ DocGen_Template**c.Footer_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Footer_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Form_Fields_Config**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Form_Fields_Config**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Header_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Header_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Is_Active**c is on the page layout
- ✅ DocGen_Template**c.Is_Active**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Is_Active**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Is_Default**c is on the page layout
- ✅ DocGen_Template**c.Is_Default**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Is_Default**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Lock_Output_Format**c is on the page layout
- ✅ DocGen_Template**c.Lock_Output_Format**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Lock_Output_Format**c has a description or help text
- ✅ DocGen_Template**c.Output_Format**c is on the page layout
- ✅ DocGen_Template**c.Output_Format**c has a description or help text
- ✅ DocGen_Template**c.Page_Margins**c is on the page layout
- ✅ DocGen_Template**c.Page_Margins**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Page_Margins**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Page_Orientation**c is on the page layout
- ✅ DocGen_Template**c.Page_Orientation**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Page_Orientation**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Page_Size**c is on the page layout
- ✅ DocGen_Template**c.Page_Size**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Page_Size**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Prefill_Signer_Email**c is on the page layout
- ✅ DocGen_Template**c.Prefill_Signer_Email**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Prefill_Signer_Email**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Query_Config**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Query_Config**c has a description or help text
- ✅ DocGen_Template**c.Record_Filter**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Record_Filter**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Required_Permission_Sets**c is on the page layout
- ✅ DocGen_Template**c.Required_Permission_Sets**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Required_Permission_Sets**c has a description or help text
- ✅ DocGen_Template**c.Signer_Verification**c is on the page layout
- ✅ DocGen_Template**c.Signer_Verification**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Signer_Verification**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Sort_Order**c is on the page layout
- ✅ DocGen_Template**c.Sort_Order**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Sort_Order**c has a description or help text
- ✅ DocGen_Template**c.Specific_Record_Ids**c is granted on DocGen_Admin
- ❌ DocGen_Template**c.Specific_Record_Ids**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template**c.Test_Record_Id**c is on the page layout
- ✅ DocGen_Template**c.Test_Record_Id**c is granted on DocGen_Admin
- ✅ DocGen_Template**c.Test_Record_Id**c has a description or help text
- ✅ DocGen_Template**c.Type**c is on the page layout
- ✅ DocGen_Template**c.Type**c has a description or help text
- ✅ Product2.Product_Image\_\_c has a description or help text
- ✅ docGenAdmin is exposed and declares at least one target — lightning**AppPage, lightning**HomePage, lightning\_\_Tab
- ✅ docGenAdmin (app page) is reachable from a tab
- ✅ docGenAdminGuide is exposed and declares at least one target — lightning**AppPage, lightning**RecordPage, lightning**HomePage, lightning**Tab
- ✅ docGenAdminGuide (app page) is reachable from a tab
- ✅ docGenAuthenticator is exposed and declares at least one target — lightningCommunity**Page, lightning**AppPage
- ❌ docGenAuthenticator (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenBulkRunner is exposed and declares at least one target — lightning**AppPage, lightning**HomePage, lightning\_\_Tab
- ✅ docGenBulkRunner (app page) is reachable from a tab
- ✅ docGenButton is exposed and declares at least one target — lightning\_\_RecordAction
- ✅ docGenCommandHub is exposed and declares at least one target — lightning**AppPage, lightning**HomePage, lightning\_\_Tab
- ✅ docGenCommandHub (app page) is reachable from a tab
- ✅ docGenQueryBuilder is exposed and declares at least one target — lightning**AppPage, lightning**RecordPage, lightning\_\_HomePage
- ❌ docGenQueryBuilder (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenRunner is exposed and declares at least one target — lightning**RecordPage, lightning**AppPage, lightning**FlowScreen, lightning**UtilityBar, lightningCommunity**Page, lightningCommunity**Default
- ❌ docGenRunner (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page
- ✅ docGenSetupWizard is exposed and declares at least one target — lightning**AppPage, lightning**HomePage, lightning**RecordPage, lightning**Tab
- ✅ docGenSetupWizard (app page) is reachable from a tab
- ✅ docGenSignatureSender is exposed and declares at least one target — lightning**RecordAction, lightning**RecordPage
- ✅ docGenTreeBuilder is exposed and declares at least one target — lightning**AppPage, lightning**RecordPage, lightning\_\_HomePage
- ❌ docGenTreeBuilder (app page) is reachable from a tab — no tab references it — reachable only via a hand-built Lightning page

### apex-e2e — Apex end-to-end

- ✅ Permissions: e2e-01-permissions.apex — 48 assertions
- ✅ Template CRUD: e2e-02-template-crud.apex — 10 assertions
- ✅ PDF generation: e2e-03-generate-pdf.apex — 14 assertions
- ✅ Page setup: e2e-03b-page-setup.apex — 3 assertions
- ✅ DOCX generation: e2e-04-generate-docx.apex — 15 assertions
- ✅ Bulk generation: e2e-05-generate-bulk.apex — 13 assertions
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

- ❌ the Apex test run passes — 1 failing: portwoodglobal.DocGenTests.testVersioning
- ❌ portwoodglobal.DocGenTests.testVersioning passes — System.AssertException: Assertion Failed: Should return V2 content: Expected: VjIgQ29udGVudA==, Actual: VGVzdCBDb250ZW50
- ✅ DocGenAuthenticatorController meets the 75% packaging bar — 100% (78/78 lines)
- ✅ DocGenSignatureExpiry meets the 75% packaging bar — 100% (28/28 lines)
- ❌ DocGenHtmlRenderer meets the 75% packaging bar — 74% (2319/3150 lines)
- ❌ DocGenFlsGuard meets the 75% packaging bar — 69% (118/172 lines)
- ✅ DocGenFieldWritebackService meets the 75% packaging bar — 90% (225/250 lines)
- ✅ DocGenGiantQueryBatch meets the 75% packaging bar — 85% (276/325 lines)
- ❌ DocGenSvgChartSerializer meets the 75% packaging bar — 43% (415/973 lines)
- ✅ DocGenSignatureEmailService meets the 75% packaging bar — 81% (195/242 lines)
- ✅ DocGenContentDocumentCleanupQueueable meets the 75% packaging bar — 92% (11/12 lines)
- ✅ DocGenBulkGiantFallbackJob meets the 75% packaging bar — 84% (37/44 lines)
- ✅ DocGenPdfPreparedBodyQueueable meets the 75% packaging bar — 100% (30/30 lines)
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
- ✅ DocGenButtonAdminController meets the 75% packaging bar — 90% (119/132 lines)
- ❌ DocGenApprovalHistory meets the 75% packaging bar — 9% (4/44 lines)
- ✅ DocGenSignatureController meets the 75% packaging bar — 84% (1222/1449 lines)
- ✅ DocGenSignatureFlowAction meets the 75% packaging bar — 97% (135/139 lines)
- ❌ DocGenController meets the 75% packaging bar — 71% (2609/3697 lines)
- ✅ DocGenSetupController meets the 75% packaging bar — 89% (211/236 lines)
- ❌ DocGenAcroFormService meets the 75% packaging bar — 65% (746/1154 lines)
- ✅ DocGenEmailTemplateInstall meets the 75% packaging bar — 100% (35/35 lines)
- ✅ DocGenChartBucketResolver meets the 75% packaging bar — 88% (661/752 lines)
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
- ✅ DocGenErrorLogger meets the 75% packaging bar — 81% (90/111 lines)
- ✅ DocGenService meets the 75% packaging bar — 81% (4459/5513 lines)
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
- ✅ org-wide coverage is at or above 75% — 78% (23143/29527 lines) — a 2GP build fails below 75%

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
- ✅ {Today:yyyy-MM-dd} equals the org calendar date — actual: 2026-07-26
- ✅ {Today:MMMM d, yyyy} formats the date — actual: July 26, 2026
- ✅ {Today} renders a date containing the current year — actual: 2026-07-26 07:00:00
- ✅ {Now:yyyy-MM-dd HH:mm} formats a timestamp — actual: 2026-07-26 05:40
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
- ✅ DocGenBulkFlowAction.Request: all 7 @InvocableVariable fields are global
- ✅ DocGenBulkFlowAction.Request: every input/output carries a label
- ✅ DocGenBulkFlowAction.Response (response type) is global
- ✅ DocGenBulkFlowAction.Response: all 3 @InvocableVariable fields are global
- ✅ DocGenBulkFlowAction.Response: every input/output carries a label
- ✅ DocGenBulkFlowAction.generateBulkDocuments has no literal SOQL/DML inside the per-request loop
- ✅ DocGenFieldWritebackService class is global (subscriber-visible)
- ✅ DocGenFieldWritebackService.writeBackFields is global static
- ✅ DocGenFieldWritebackService.writeBackFields has a Flow label — DocGen: Write Back Signer Form Fields
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
- ✅ DocGenSignatureFlowAction.generate has a Flow label — DocGen: Create Signature Request
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
- ✅ DocGenSignaturePdfFlowAction.send has a Flow label — DocGen: Send Existing Document for Signature (Deprecated — use "DocGen: Create Signature Request")
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
- ✅ Create Signature Request: a DocGen_Signer\_\_c row is actually written
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

- ✅ HTML→PDF: generation returned bytes — 75178 bytes
- ✅ HTML→PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ HTML→PDF: size above 800 bytes — 75178 bytes
- ✅ HTML→PDF: DocGenService.lastRenderedHtml captured for inspection — 675 chars
- ✅ HTML→PDF: merged parent field appears in the rendered document — both {Name} and {Industry} resolved in the rendered HTML
- ✅ HTML→PDF: every child-loop row rendered — ROW-Alpha, ROW-Bravo and ROW-Charlie all present
- ✅ HTML→PDF: non-Latin / unicode merge values survive the round trip — expected "Kabushiki 日本語 Ünïcødé Ω €" to appear; rendered slice was "UNI:Kabushiki <span style=\"font-family:'Arial Unicode MS', s"
- ✅ HTML→PDF: no unresolved merge tags leak into the output — no {Tag} or {#Loop} survived into the rendered HTML
- ✅ Document_Title_Format\_\_c produces the document title — expected "QAOF069679286-QAOF069679286 Corp-Technology", got "QAOF069679286-QAOF069679286 Corp-Technology"
- ✅ HTML→PDF: result is labelled PDF — outputFormat=PDF templateType=HTML
- ✅ Word→DOCX: generation returned bytes — 1285 bytes
- ✅ Word→DOCX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ Word→DOCX: size above 400 bytes — 1285 bytes
- ✅ Word→DOCX: output opens as a ZIP archive — entries: word/document.xml&#124;word/\_rels/document.xml.rels&#124;[Content_Types].xml&#124;\_rels/.rels
- ✅ Word→DOCX: contains word/document.xml, [Content_Types].xml and \_rels/.rels — document.xml=true content-types=true rels=true; parts: word/document.xml&#124;word/\_rels/document.xml.rels&#124;[Content_Types].xml&#124;\_rels/.rels
- ✅ Word→DOCX: merged data is inside the produced document.xml — {Name}=true {Industry}=true
- ✅ Word→DOCX: every child-loop row rendered — all three rows present in the produced word/document.xml
- ✅ Word→DOCX: no unresolved merge tags leak into the output — no {Tag} survived into word/document.xml
- ✅ Word→DOCX: Document_Title_Format\_\_c applied — expected "QAOF069679286-QAOF069679286 Corp", got "QAOF069679286-QAOF069679286 Corp"
- ✅ Word→PDF: generation returned bytes — 1053 bytes
- ✅ Word→PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Word→PDF: size above 800 bytes — 1053 bytes
- ✅ Word→PDF: merged data survives the DOCX→HTML conversion — name=true rows=true
- ✅ Word→PDF: no raw OOXML reaches the PDF renderer — the converter emitted clean HTML — no <w:t>/<w:p> left
- ✅ Word→PDF: no unresolved merge tags leak into the output — no {Tag} survived the converter path
- ✅ PowerPoint→PPTX: generation returned bytes — 1226 bytes
- ✅ PowerPoint→PPTX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ PowerPoint→PPTX: size above 400 bytes — 1226 bytes
- ✅ PowerPoint→PPTX: ppt/slides/slide1.xml survives the repack — parts: ppt/\_rels/presentation.xml.rels&#124;[Content_Types].xml&#124;\_rels/.rels&#124;ppt/slides/slide1.xml
- ✅ PowerPoint→PPTX: merged data is inside the produced slide — merged=true leakedTags=false
- ✅ Excel→XLSX: generation returned bytes — 1435 bytes
- ✅ Excel→XLSX: magic bytes are PK (ZIP) — leading bytes 504B030414000808, expected 504B0304
- ✅ Excel→XLSX: size above 400 bytes — 1435 bytes
- ✅ Excel→XLSX: xl/worksheets/sheet1.xml survives the repack — parts: xl/\_rels/workbook.xml.rels&#124;[Content_Types].xml&#124;xl/sharedStrings.xml&#124;xl/worksheets/sheet1.xml&#124;\_rels/.rels
- ✅ Excel→XLSX: merged data is inside the produced sheet — merged=true leakedTags=false
- ✅ PDF AcroForm: generation returned bytes — 795 bytes
- ✅ PDF AcroForm: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ PDF AcroForm: size above 300 bytes — 795 bytes
- ✅ PDF AcroForm: merged value is written into the PDF — expected "QAOF069679286 Corp" in the filled PDF bytes; A_MERGED=true
- ✅ PDF AcroForm: incremental update appended (output larger than template) — template 513 bytes → output 795 bytes; equal size means no field was filled
- ✅ Template with no active version and no file fails instead of returning bytes — raised: Error retrieving template data: No template file found (active or attached).
- ✅ No-version failure message points at the template configuration — message was: Error retrieving template data: No template file found (active or attached). — an admin has to be able to tell what to fix
- ✅ Deactivated version with an attached file yields a valid PDF or a clean error, never a corrupt one — size=66739 hex=255044462D312E34 threw=false
- ✅ Zero-row child loop: generation returned bytes — 67907 bytes
- ✅ Zero-row child loop: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Zero-row child loop: size above 800 bytes — 67907 bytes
- ✅ Zero-row child collection: loop tags do not leak into the output — the loop collapsed cleanly with nothing to iterate
- ✅ Zero-row child collection: content around the loop is preserved — the heading before the loop and the paragraph after it both survived
- ✅ Zero-row child collection: no phantom row rendered — zero rows in, zero rows out
- ✅ Source HTML's own @page rule wins over the engine's page fields — sourceSizePresent=true engineSizeAlsoEmitted=false — two competing @page size declarations make Flying Saucer pick one silently
- ✅ Header image: generation returned bytes — 91019 bytes
- ✅ Header image: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Header image: size above 800 bytes — 91019 bytes
- ✅ Running header is wired into the @page margin box — running(dgheader)=true @top-center=true
- ✅ Tall header image grows the top margin instead of overflowing onto the body — margin-top raised to 1.65in for the 1.5in header image
- ✅ Missing image CV: generation returned bytes — 68146 bytes
- ✅ Missing image CV: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Missing image CV: size above 800 bytes — 68146 bytes
- ✅ Image field pointing at a missing ContentVersion does not abort generation — generation completed
- ✅ Missing image degrades without dropping the rest of the document — content before and after the image tag both survived
- ✅ Missing image does not leak the raw ContentVersion Id onto the page — no internal Id and no dangling <img src> in the output
- ✅ Very large document body: valid PDF or a clean, catchable error — size=505746 hex=255044462D312E34 at body length 1152000
- ✅ Very large document body: PDF is complete, not truncated — %%EOF trailer present in 505746 bytes
- ✅ Very large document body: output size reflects the content — 1152000-char body → 505746 bytes of PDF
- ✅ Generating against a record the user cannot read returns no document — raised: Error retrieving template data: Record data not found.
- ⊘ Record hidden by sharing/FLS from a low-privilege user — requires generating as a second, restricted user; System.runAs is test-context only and anonymous Apex cannot impersonate. Covered here only by the deleted-record analogue.
- ✅ Giant-query fixture actually crosses the 2000-row threshold — 2100 child rows — over the hard-coded 2000 threshold
- ✅ Over-threshold child collection routes to the giant-query path — isGiantQuery=true relationship=Contacts
- ✅ Giant-query job reaches Completed — status=Completed label=Giant Query totalRecords=2100
- ✅ Giant-query job harvested every child row — Total_Records\_\_c=2100 of 2100 inserted
- ✅ Giant-query PDF: generation returned bytes — 109335 bytes
- ✅ Giant-query PDF: magic bytes are %PDF — leading bytes 255044462D312E34, expected 25504446
- ✅ Giant-query PDF: size above 30000 bytes — 109335 bytes
- ✅ Giant-query PDF is complete, not truncated — %%EOF trailer present in 109335 bytes
- ✅ Giant-query output is named from Document_Title_Format\_\_c — ContentVersion.Title was "QAOF069679286-giant-QAOF069679286 Giant", expected it to start with "QAOF069679286-giant-"
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
- ✅ header renders asset tags as images, not text pills — ok
- ✅ a tall header at zoom does not overlap the page — ok
- ✅ resizing a header image does not duplicate it — resized to 270px, still 1 image
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
- ✅ Designer tab offers templates to open when none is loaded — {"list":true,"count":8,"first":"Verify — Designer (pill-dense)AccountDesign →"}
- ✅ template list stays bounded regardless of org size — 8 rendered · Showing 8 of 13 · 13 total
- ✅ template search filters the list — ok
- ✅ clearing the search restores the list
- ✅ clicking a template on the Designer tab opens it for editing — {"pv":true,"bar":true}
- ✅ no console errors during interaction

### ui-admin — Admin UI

- ✅ admin app mounts with its three main tabs — Create New \| Your Templates \| Designer (Beta) \| More Tabs
- ✅ main tab "Create New" is reachable by a mouse
- ✅ main tab "Your Templates" is reachable by a mouse
- ✅ main tab "Designer" is reachable by a mouse
- ✅ main tab "Your Templates" swaps in its own content
- ✅ main tab "Create New" swaps in its own content
- ✅ authoring card "starter" is reachable by a mouse
- ✅ authoring card "starter" selects and reveals the starter gallery — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "ai" is reachable by a mouse
- ✅ authoring card "ai" selects and reveals the AI intro and its Next button — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "scratch" is reachable by a mouse
- ✅ authoring card "scratch" selects and reveals the blank-page CTA — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "file" is reachable by a mouse
- ✅ authoring card "file" selects and reveals the Type / Output Format pickers — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ the starter gallery renders every predesigned starter — rendered 5: report, invoice, letter, agreement, certificate — expected report, invoice, letter, agreement, certificate
- ✅ every starter card takes selection when clicked — 5 starters each selected
- ✅ Advanced options discloses the power-user fields — Data Source radio group visible before=false after=true
- ✅ creating with an empty name is refused with a visible error — Error notification. Name it first Give the template a name, then create. Press Command + F6 to navigate to the next toas
- ✅ a refused create writes no template record
- ✅ wizard Next refuses to advance without a name — error shown; still on step 1 = true
- ✅ wizard Next advances to step 2 (Pick Your Data)
- ✅ wizard Back returns to step 1 and keeps what was typed — onStep1=true name="QAUI-1sipiw-File" (expected "QAUI-1sipiw-File")
- ✅ wizard step 2 refuses an empty query — Error notification. Error Please add at least one field to the query. Press Command + F6 to navigate to the next toast n
- ✅ wizard step 3 reviews the name, object and query it will save — reviewScreen=true nameEchoed=true queryEchoed=true
- ✅ the wizard creates a template record end to end — a0BO500000OsRdKMAV, base object Account
- ✅ the created template keeps the query the wizard collected — Query_Config\_\_c = Name, Industry, Phone
- ✅ the AI path reaches the prompt screen
- ✅ the AI prompt is assembled with merge-tag syntax and the template fields — 7495 chars; contains merge-tag braces = true
- ✅ the AI prompt rebuilds live from what the author describes — prompt 7296 chars; carries the typed description = true
- ✅ Copy Prompt puts the whole prompt on the clipboard — clipboard holds 7356 chars; includes the live description = true
- ✅ the AI paste-back box accepts the returned HTML — textarea holds "<html><body><p>pasted</p></body></html>"
- ✅ the starter path creates the template record — a0BO500000OsW1tMAF, HTML/PDF
- ✅ the starter path lands in the designer with the design loaded
- ✅ the starter body is real content, not an empty page — 14179 chars of HTML — ".dg-pv { background: #fff; max-width: 850px; margin: 0 auto; padding: 48px 56px; box-shadow: 0 2px 1"
- ✅ panel button "insert" is reachable by a mouse
- ✅ panel "insert" opens with its contents rendered — title="Insert blocks" (expected "Insert blocks"), interactive children=66, text=1245 chars
- ✅ panel "insert" is not clipped or covered once open — hit-test says: ok
- ✅ panel "insert" closes from its own X
- ✅ panel button "tags" is reachable by a mouse
- ✅ panel "tags" opens with its contents rendered — title="Merge tags" (expected "Merge tags"), interactive children=75, text=2312 chars
- ✅ panel "tags" is not clipped or covered once open — hit-test says: ok
- ✅ panel "tags" closes from its own X
- ✅ panel button "images" is reachable by a mouse
- ✅ panel "images" opens with its contents rendered — title="Image assets" (expected "Image assets"), interactive children=2, text=186 chars
- ✅ panel "images" is not clipped or covered once open — hit-test says: ok
- ✅ panel "images" closes from its own X
- ✅ panel button "query" is reachable by a mouse
- ✅ panel "query" opens with its contents rendered — title="Query fields" (expected "Query fields"), interactive children=37, text=915 chars
- ✅ panel "query" is not clipped or covered once open — hit-test says: ok
- ✅ panel "query" closes from its own X
- ✅ panel button "versions" is reachable by a mouse
- ✅ panel "versions" opens with its contents rendered — title="Version history" (expected "Version history"), interactive children=1, text=170 chars
- ✅ panel "versions" is not clipped or covered once open — hit-test says: ok
- ✅ panel "versions" closes from its own X
- ✅ panel button "hf" is reachable by a mouse
- ✅ panel "hf" opens with its contents rendered — title="Header & Footer" (expected "Header & Footer"), interactive children=3, text=502 chars
- ✅ panel "hf" is not clipped or covered once open — hit-test says: ok
- ✅ panel "hf" closes from its own X
- ✅ panel button "watermark" is reachable by a mouse
- ✅ panel "watermark" opens with its contents rendered — title="Watermark" (expected "Watermark"), interactive children=3, text=260 chars
- ✅ panel "watermark" is not clipped or covered once open — hit-test says: ok
- ✅ panel "watermark" closes from its own X
- ✅ Tags panel: clicking a tag puts it on the page — inserted "Name"
- ✅ the designer exposes its page size and orientation pickers — 2 page-setup selects found (expected at least size + orientation)
- ✅ changing page orientation resizes the sheet — sheet width 816 -> 1056 switching to landscape
- ✅ the template list renders rows — 15 rows; count label "15 templates"
- ✅ search narrows the list to matching rows only — 15 -> 2 rows for "1sipiw"; every remaining row matches = true
- ✅ the row-count label reports the filtered subset — label reads "2 of 15 templates"
- ✅ a search with no matches empties the list instead of ignoring the query — 0 rows survived a nonsense query
- ✅ clearing the search restores the full list — 15 rows (expected 15)
- ✅ clicking a column header re-orders the rows both ways — clicked=true; first row "QAUI-1sipiw-Starter HTML PDF" -> asc "Account HTML PDF Account Act" -> desc "ZZ Warn Probe HTML PDF Accou"
- ✅ Refresh reloads the list without emptying it — hit-test=ok; 15 rows after refresh (expected 15)
- ✅ "New Template" switches to the Create New wizard
- ✅ the row-action menu button is reachable by a mouse
- ✅ row action View opens the template on its Copy-Paste Tags tab — modalOpen=true, selected tabs: Your Templates, Copy-Paste Tags
- ✅ row action Export downloads a valid .docgen.json bundle — QAUI-1sipiw-Starter.docgen.json — export version 1, template "QAUI-1sipiw-Starter"
- ✅ Import Template restores an exported bundle as a new template — "QAUI-1sipiw-Imported" exists after import
- ✅ row action Clone creates a copy and opens it for editing — created "QAUI-1sipiw-File (Copy)" (a0BO500000OsWRhMAN); the edit modal opened = true
- ✅ row action Delete removes the template — "QAUI-1sipiw-File (Copy)" is gone from the org
- ✅ deleting a template asks for confirmation first — a confirmation step was shown
- ✅ row action Design opens that template in the designer
- ✅ row action Edit opens the edit modal
- ✅ the modal Save button is reachable (nothing covers the footer)
- ✅ edit modal tab "Settings" renders its panel — selected=Settings, controls=36, expected content present=true, text=1576 chars
- ✅ edit modal tab "Header / Footer" renders its panel — selected=Header / Footer, controls=38, expected content present=true, text=680 chars
- ✅ edit modal tab "Watermark" renders its panel — selected=Watermark / Background, controls=2, expected content present=true, text=569 chars
- ✅ edit modal tab "Query Configuration" renders its panel — selected=Query Configuration, controls=7, expected content present=true, text=521 chars
- ✅ edit modal tab "Signer Inputs" renders its panel — selected=Signer Inputs, controls=3, expected content present=true, text=485 chars
- ✅ edit modal tab "Copy-Paste Tags" renders its panel — selected=Copy-Paste Tags, controls=18, expected content present=true, text=326 chars
- ⊘ edit modal tab "Fillable Fields" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Document & History" renders its panel — selected=Document & History, controls=8, expected content present=true, text=405 chars
- ✅ a tag chip copies its merge tag to the clipboard — clicked "{Name}"; the clipboard now holds "{Name}"
- ✅ Signer Inputs: "Add Field" adds a field row — signer field rows 0 -> 1
- ✅ Signer Inputs: a field row is editable — label was "New Field"
- ✅ Signer Inputs: removing a field takes it off the list — signer field rows 1 -> 0
- ✅ edit modal inputs accept real typing — description="edited by ui-admin 1sipiw" category="QA1sipiw"
- ✅ the Active toggle flips when clicked — checked true -> false
- ✅ Save as New Version persists the edited fields — stored description="edited by ui-admin 1sipiw", category="QA1sipiw" (expected "edited by ui-admin 1sipiw" / "QA1sipiw")
- ✅ Save as New Version really creates a new version record — template versions 0 -> 1
- ⊘ closing the modal with unsaved edits warns or preserves them — could not re-open the modal: row "QAUI-1sipiw-Starter": the menu never offered a visible "Edit" item
- ✅ Command Hub: "My Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Template Library Manage your document designs and create new"; body 1842 chars
- ✅ Command Hub: "Bulk Generation" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Bulk Generation Create documents for hundreds of records at "; body 167 chars
- ✅ Command Hub: "Signatures" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Signature Settings Configure email branding, site URL, and s"; body 1262 chars
- ✅ Command Hub: "Assets" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Shared Assets Manage reusable images like logos and footers "; body 481 chars
- ✅ Command Hub: "Email Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Email Templates Brand and edit every signature email — reque"; body 1531 chars
- ✅ Command Hub: "Learning Center" opens its panel — panel header "Template Library Manage your document designs and create new" -> "User Guide The full DocGen User Guide lives on the web — alw"; body 317 chars
- ✅ the Command Hub sidebar stays usable after opening Bulk Generation — 7 nav items reachable throughout
- ✅ no unexpected console errors while driving the admin UI
- ✅ the suite cleans up the templates it created — 3 QAUI- templates deleted

### ui-runner — End-user UI

- ✅ runner template picker offers an active, usable template for the record — picker returned: UIQA Good PDF, UIQA Locked Format, UIQA No Version — DocGenController.getTemplatesForObjectAndRecord
- ✅ picker hides a template whose Record_Filter**c excludes this record — Record_Filter**c = Industry = 'Agriculture'; the record is Technology. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides a template requiring a permission set the user lacks — Required_Permission_Sets\_\_c = UIQA_No_Such_PermSet. Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ✅ picker hides an inactive template — Picker: UIQA Good PDF, UIQA Locked Format, UIQA No Version
- ❌ picker hides a template that has no active version — "UIQA No Version" is offered in the runner picker but cannot generate — the user gets "No template file found (active or attached)" only after pressing Generate. DocGenController.getTemplatesForObject
- ✅ generating from the picked template produces a real document — DocGenService.processDocument returned 66207 bytes
- ✅ the generated document's title resolves merge tokens against the record — Document_Title_Format\_\_c = "UIQA-ms1sro4v {Name}" → title was "UIQA-ms1sro4v UIQA Alpha", expected "UIQA-ms1sro4v UIQA Alpha"
- ✅ a locked output format cannot be overridden at run time — Lock_Output_Format\_\_c = true, override 'Word' → "This template locks its output format. Override not permitted."
- ✅ a template with no active version fails with a message, not a blank document — got: Error retrieving template data: No template file found (active or attached).
- ✅ bulk template picker excludes deactivated templates — matches the single-record runner
- ❌ a record-filtered template is not silently applied to excluded records in bulk — "UIQA Filtered Out" carries a Record_Filter\_\_c and is offered for bulk, where the filter is never evaluated — DocGenBulkController passes null to filterTemplatesForSender and the batch never calls the
- ✅ the runner shows an actionable empty state when no template matches the record — with every Account template inactive the runner rendered 565 chars; Create Document disabled=true. The user must be told WHY there is nothing to pick, and must not be able to press a button that canno
- ✅ docGenRunner renders on a record page — rendered 524 chars, 2 picker(s), 1 primary button(s)
- ✅ the runner shows neither an error nor an empty state on a record that has templates — component text starts: DocGen Create or combine documents for this record. Create Document Document Packet Combine PDFs Category All Categories UIQA (Uncategorized) Select Template Choose a template..
- ✅ docGenRunner boots without a console error
- ✅ the record-page template picker lists a template the user can actually run — picker showed: Choose a template... / Account / ffff / PDFQA Giant Chrome / playa / test / Test2 / test3 / test345 / test99 / [UIQA] UIQA Good PDF / [UIQA] UIQA Locked Format / [UIQA] UIQA No Version
- ✅ the record-page picker applies the active and audience rules — Inactive, Record_Filter\_\_c-excluded and permission-gated templates were all withheld
- ✅ the template picker is reachable by a mouse — found=true hit=ok
- ✅ choosing a category narrows the template list to that category — after picking category "UIQA" the picker showed: [UIQA] UIQA Good PDF / [UIQA] UIQA Locked Format / [UIQA] UIQA No Version
- ✅ the Save to Record output choice is reachable — found=true hit=ok
- ✅ choosing Save to Record is honoured by the UI — output pills after the click: download, save(active)
- ✅ the Create Document button is reachable — found=true hit=ok
- ✅ pressing Create Document in Save to Record mode puts the document ON the record — ContentDocument "UIQA-ms1sro4v UIQA Alpha" linked to 001O50000410qXFIAY
- ✅ the saved file is in the template's own output format — Output_Format\_\_c = PDF, file extension = .pdf
- ✅ choosing Download is honoured by the UI — output pills after the click: download(active), save
- ✅ pressing Create Document in Download mode downloads the document to the browser — the browser received "UIQA-ms1sro4v UIQA Alpha.pdf"
- ✅ Download does NOT also attach the document to the record — files linked to the record: 3 before the run, 3 after. Download and Save to Record are the two halves of one choice; honouring it means Download leaves the record untouched.
- ✅ a template with Lock_Output_Format\_\_c exposes no runtime file-format control — with the locked template selected the runner offered 2 picker(s) (category + template) and the choice widgets [download, save], which are output DESTINATIONS, not formats. The server half of this cont
- ✅ the Document Packet tab renders its template chooser and it is reachable — packet tab active=true, dual listboxes=1, source list hit=ok
- ✅ the packet chooser offers the record's PDF templates — chooser offered 16 template(s): Account / ffff / PDFQA Giant Chrome / playa / test / Test2
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
- ✅ sending a signature request tells the user it worked — component text: Signature Links Generated! Provide each signer with their unique secure link: UIQA-ms1sro4v Signer Signer https://<CONFIGURE_SITE_URL_IN_SETUP>/apex/portwoodglobal\_\_DocGenSignaturePdf?
- ✅ sending writes a DocGen_Signature_Request\_\_c tied to this record and template — request a08O50000140Y5LIAU: record=001O50000410qXFIAY (expected 001O50000410qXFIAY), status=Sent, order=Parallel, sourceDoc=068O500000MIdsfIAD
- ✅ sending writes exactly one DocGen_Signer\_\_c carrying what was typed — 1 signer row(s) (expected 1); first = name "UIQA-ms1sro4v Signer" (typed "UIQA-ms1sro4v Signer"), email "uiqa-ms1sro4v@example.com" (typed "uiqa-ms1sro4v@example.com"), role "Signer" (typed "Signer"),
- ✅ bulk generation UI renders on its tab — {"chars":251,"hasHeading":true,"hasStep1":true}
- ✅ bulk generation UI boots without a console error
- ✅ the screen stays usable while a job is still running — template search box is hittable with 1 non-terminal job(s) present
- ✅ focusing the template box lists the available templates — 17 options offered
- ✅ typing narrows the template list to the match — after typing "UIQA Good": UIQA Good PDF (Account • PDF)
- ✅ a search with no matches says so instead of showing an empty box — expected the "No templates found" empty state in the dropdown
- ✅ a template option can be clicked — found=true hit=ok
- ✅ selecting a template opens the filter and run steps — Step 2 (Record Filter) and Step 3 (Run Generation) must appear once a template is chosen
- ✅ the bulk screen offers no file-format override — format stays the template’s — Output Mode options: Individual Files / Print-Ready Packet / Combined + Individual
- ✅ choosing an output mode is honoured by the UI — after picking "Individual Files" the control reads "Individual Files"
- ✅ the Validate Filter button is clickable — found=true hit=ok
- ✅ Validate reports the true number of matching records — expected "2 Records Found" for Name LIKE 'UIQA%' (2 accounts seeded); component text did not contain it
- ✅ the Run button is clickable once the filter is validated — found=true hit=ok
- ✅ pressing Run creates a bulk job on the server — DocGen_Job\_\_c a03O500003hFckDIAS status Completed
- ✅ the job generates one document per matching record — status=Completed total=2 success=2 errors=0; error log:
- ✅ each generated document is attached to its own record — 5 pdf files across 2 records (expected 1 each on 2 records) — Output Mode was Individual Files
- ✅ the output honours the template's Output Format (PDF) — extensions produced: pdf
- ✅ a run where every record fails is reported as failed, not as success — status=Failed success=0 errors=2
- ✅ the failing job records WHY each record failed — Error_Log\_\_c = 001O50000410qXFIAY — portwoodglobal.DocGenException: Error retrieving template data: No template file found (active or attached). 001O50000410qXGIAY — portwoodglobal.DocGenException: Er
- ✅ the Recent Jobs list shows the error count to the user — Recent Jobs did not show "UIQA-ms1sro4v-err" with "2 errors" — a user would see the run as finished with no indication anything went wrong
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
- ✅ Save To Record = false leaves the record untouched — 4 files before and after
- ⊘ a user without the DocGen permission set gets a clear message, not a broken UI — the restricted user was sent to the first-login "Change Your Password" screen, so the record page was never reached. A session cookie IS set, which is why this slipped past the auth gate and previousl
- ⊘ a Document Packet contains every document it was built from — could not move templates into the packet: nothing reached the "In Packet" column — the move did not take

### record-pages — Record pages

- ✅ DocGen_Template\_\_c record page renders — 54 field slots rendered
- ✅ DocGen_Template\_\_c detail fields are genuinely visible (hit test) — first field "Template Name" is hittable
- ✅ DocGen_Template\_\_c.Name renders on the record page
- ✅ DocGen_Template**c.API_Name**c renders on the record page
- ✅ DocGen_Template**c.Type**c renders on the record page
- ✅ DocGen_Template**c.Output_Format**c renders on the record page
- ✅ DocGen_Template**c.Is_Active**c renders on the record page
- ✅ DocGen_Template**c.Is_Default**c renders on the record page
- ✅ DocGen_Template**c.Category**c renders on the record page
- ✅ DocGen_Template**c.Base_Object_API**c renders on the record page
- ✅ DocGen_Template**c.Document_Title_Format**c renders on the record page
- ✅ DocGen_Template**c.Test_Record_Id**c renders on the record page
- ✅ DocGen_Template**c.Sort_Order**c renders on the record page
- ✅ DocGen_Template**c.Lock_Output_Format**c renders on the record page
- ✅ DocGen_Template**c.Specific_Record_Ids**c renders on the record page
- ✅ DocGen_Template**c.Required_Permission_Sets**c renders on the record page
- ✅ DocGen_Template**c.Signer_Verification**c renders on the record page
- ✅ DocGen_Template**c.Prefill_Signer_Email**c renders on the record page
- ✅ DocGen_Template**c.Page_Size**c renders on the record page
- ✅ DocGen_Template**c.Page_Orientation**c renders on the record page
- ✅ DocGen_Template**c.Page_Margins**c renders on the record page
- ✅ DocGen_Template**c.Custom_Margins**c renders on the record page
- ✅ DocGen_Template**c.Default_Email_Message**c renders on the record page
- ✅ DocGen_Template**c.Record_Filter**c renders on the record page
- ✅ DocGen_Template**c.Description**c renders on the record page
- ✅ DocGen_Template**c.Query_Config**c renders on the record page
- ✅ DocGen_Template\_\_c.CreatedById renders on the record page
- ✅ DocGen_Template\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Template\_\_c exposes every one of its fields somewhere on the record page — all reachable; 3 field(s) intentionally edited elsewhere
- ✅ DocGen_Template**c fields edited outside the record page are accounted for — Footer_Html**c (edited in the Designer footer band), Form_Fields_Config**c (edited on the Signer Inputs tab), Header_Html**c (edited in the Designer header band)
- ✅ DocGen_Template\_\_c related lists load without error — 7 related list container(s) rendered
- ✅ DocGen_Template\_\_c shows its "Versions" related list
- ✅ DocGen_Template\_\_c shows its "Files" related list
- ✅ DocGen_Template\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Template\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Template\_\_c record page logs no console errors
- ✅ DocGen_Template_Version\_\_c record page renders — 36 field slots rendered
- ✅ DocGen_Template_Version\_\_c detail fields are genuinely visible (hit test) — first field "Version Name" is hittable
- ✅ DocGen_Template_Version\_\_c.Name renders on the record page
- ✅ DocGen_Template_Version**c.Template**c renders on the record page
- ✅ DocGen_Template_Version**c.Is_Active**c renders on the record page
- ✅ DocGen_Template_Version**c.Type**c renders on the record page
- ✅ DocGen_Template_Version**c.Category**c renders on the record page
- ✅ DocGen_Template_Version**c.Base_Object_API**c renders on the record page
- ✅ DocGen_Template_Version**c.Content_Version_Id**c renders on the record page
- ✅ DocGen_Template_Version**c.Pre_Decomposition_Status**c renders on the record page
- ✅ DocGen_Template_Version**c.Description**c renders on the record page
- ✅ DocGen_Template_Version**c.Query_Config**c renders on the record page
- ✅ DocGen_Template_Version\_\_c.CreatedById renders on the record page
- ✅ DocGen_Template_Version\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Template_Version**c.Output_Format**c renders on the record page
- ✅ DocGen_Template_Version**c.Document_Title_Format**c renders on the record page
- ✅ DocGen_Template_Version**c.Page_Size**c renders on the record page
- ✅ DocGen_Template_Version**c.Page_Orientation**c renders on the record page
- ✅ DocGen_Template_Version**c.Page_Margins**c renders on the record page
- ✅ DocGen_Template_Version**c.Custom_Margins**c renders on the record page
- ✅ DocGen_Template_Version\_\_c exposes every one of its fields somewhere on the record page — all reachable; 3 field(s) intentionally edited elsewhere
- ✅ DocGen_Template_Version**c fields edited outside the record page are accounted for — Footer_Html**c (edited in the Designer footer band), Header_Html**c (edited in the Designer header band), Watermark_Image_CV_Id**c (set when a watermark is uploaded)
- ✅ DocGen_Template_Version\_\_c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Template_Version\_\_c shows its "Files" related list
- ✅ DocGen_Template_Version\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Template_Version\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Template_Version\_\_c record page logs no console errors
- ✅ DocGen_Job\_\_c record page renders — 29 field slots rendered
- ✅ DocGen_Job\_\_c detail fields are genuinely visible (hit test) — first field "Job Number" is hittable
- ✅ DocGen_Job\_\_c.Name renders on the record page
- ✅ DocGen_Job**c.Template**c renders on the record page
- ✅ DocGen_Job**c.Status**c renders on the record page
- ✅ DocGen_Job**c.Label**c renders on the record page
- ✅ DocGen_Job**c.Total_Records**c renders on the record page
- ✅ DocGen_Job**c.Success_Count**c renders on the record page
- ✅ DocGen_Job**c.Error_Count**c renders on the record page
- ✅ DocGen_Job**c.Merge_Only**c renders on the record page
- ✅ DocGen_Job**c.Query_Condition**c renders on the record page
- ✅ DocGen_Job\_\_c.CreatedById renders on the record page
- ✅ DocGen_Job\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Job**c.Error_Log**c renders on the record page
- ✅ DocGen_Job**c.Merged_PDF_CV**c renders on the record page
- ✅ DocGen_Job**c.Parent_Record_Id**c renders on the record page
- ✅ DocGen_Job\_\_c exposes every one of its fields somewhere on the record page — all reachable; 2 field(s) intentionally edited elsewhere
- ✅ DocGen_Job**c fields edited outside the record page are accounted for — Data_Cache_CV**c (internal cache pointer written by the batch), Giant_Query_Config\_\_c (internal config written by the giant-query path)
- ✅ DocGen_Job\_\_c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Job\_\_c shows its "Files" related list
- ✅ DocGen_Job\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Job\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Job\_\_c record page logs no console errors
- ✅ DocGen_Saved_Query\_\_c record page renders — 15 field slots rendered
- ✅ DocGen_Saved_Query\_\_c detail fields are genuinely visible (hit test) — first field "Query Label" is hittable
- ✅ DocGen_Saved_Query\_\_c.Name renders on the record page
- ✅ DocGen_Saved_Query**c.DocGen_Template**c renders on the record page
- ✅ DocGen_Saved_Query**c.Description**c renders on the record page
- ✅ DocGen_Saved_Query**c.Query_Condition**c renders on the record page
- ✅ DocGen_Saved_Query\_\_c.CreatedById renders on the record page
- ✅ DocGen_Saved_Query\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Saved_Query\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Saved_Query\_\_c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Saved_Query\_\_c shows its "Files" related list
- ✅ DocGen_Saved_Query\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Saved_Query\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Saved_Query\_\_c record page logs no console errors
- ✅ DocGen_Error_Log\_\_c record page renders — 32 field slots rendered
- ✅ DocGen_Error_Log\_\_c detail fields are genuinely visible (hit test) — first field "Error Number" is hittable
- ✅ DocGen_Error_Log\_\_c.Name renders on the record page
- ✅ DocGen_Error_Log**c.Severity**c renders on the record page
- ✅ DocGen_Error_Log**c.Context**c renders on the record page
- ✅ DocGen_Error_Log**c.Operation**c renders on the record page
- ✅ DocGen_Error_Log**c.Exception_Type**c renders on the record page
- ✅ DocGen_Error_Log**c.Message**c renders on the record page
- ✅ DocGen_Error_Log**c.Stack_Trace**c renders on the record page
- ✅ DocGen_Error_Log**c.Additional_Info**c renders on the record page
- ✅ DocGen_Error_Log**c.Record_Id**c renders on the record page
- ✅ DocGen_Error_Log**c.Template_Id**c renders on the record page
- ✅ DocGen_Error_Log**c.Job_Id**c renders on the record page
- ✅ DocGen_Error_Log**c.User_Id**c renders on the record page
- ✅ DocGen_Error_Log**c.Flow_Interview_Guid**c renders on the record page
- ✅ DocGen_Error_Log\_\_c.CreatedById renders on the record page
- ✅ DocGen_Error_Log\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Error_Log\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Error_Log\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Error_Log\_\_c record page logs no console errors
- ✅ DocGen_Asset\_\_c record page renders — 15 field slots rendered
- ✅ DocGen_Asset\_\_c detail fields are genuinely visible (hit test) — first field "Asset Name" is hittable
- ✅ DocGen_Asset\_\_c.Name renders on the record page
- ✅ DocGen_Asset**c.Asset_Key**c renders on the record page
- ✅ DocGen_Asset**c.Asset_Type**c renders on the record page
- ✅ DocGen_Asset**c.Category**c renders on the record page
- ✅ DocGen_Asset**c.Is_Active**c renders on the record page
- ✅ DocGen_Asset\_\_c.CreatedById renders on the record page
- ✅ DocGen_Asset\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Asset\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Asset\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Asset\_\_c record page logs no console errors
- ✅ DocGen_Email_Template\_\_c record page renders — 32 field slots rendered
- ✅ DocGen_Email_Template\_\_c detail fields are genuinely visible (hit test) — first field "Email Template Name" is hittable
- ✅ DocGen_Email_Template\_\_c.Name renders on the record page
- ✅ DocGen_Email_Template**c.Type**c renders on the record page
- ✅ DocGen_Email_Template**c.Subject**c renders on the record page
- ✅ DocGen_Email_Template**c.Is_Active**c renders on the record page
- ✅ DocGen_Email_Template**c.Description**c renders on the record page
- ✅ DocGen_Email_Template**c.Layout_Mode**c renders on the record page
- ✅ DocGen_Email_Template**c.Body_Html**c renders on the record page
- ✅ DocGen_Email_Template**c.Body_Plain**c renders on the record page
- ✅ DocGen_Email_Template**c.Logo_Url**c renders on the record page
- ✅ DocGen_Email_Template**c.Logo_Url_Extended**c renders on the record page
- ✅ DocGen_Email_Template**c.Logo_Asset_Key**c renders on the record page
- ✅ DocGen_Email_Template**c.Logo_Height**c renders on the record page
- ✅ DocGen_Email_Template**c.Brand_Color**c renders on the record page
- ✅ DocGen_Email_Template**c.Footer_Text**c renders on the record page
- ✅ DocGen_Email_Template\_\_c.CreatedById renders on the record page
- ✅ DocGen_Email_Template\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Email_Template\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Email_Template\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Email_Template\_\_c record page logs no console errors
- ✅ DocGen_Signature_Request\_\_c record page renders — 34 field slots rendered
- ✅ DocGen_Signature_Request\_\_c detail fields are genuinely visible (hit test) — first field "Request Number" is hittable
- ✅ DocGen_Signature_Request\_\_c.Name renders on the record page
- ✅ DocGen_Signature_Request**c.Status**c renders on the record page
- ✅ DocGen_Signature_Request**c.Template**c renders on the record page
- ✅ DocGen_Signature_Request**c.Template_Ids**c renders on the record page
- ✅ DocGen_Signature_Request**c.Document_Title_Format**c renders on the record page
- ✅ DocGen_Signature_Request**c.Related_Record_Id**c renders on the record page
- ✅ DocGen_Signature_Request**c.Source_Document_Id**c renders on the record page
- ✅ DocGen_Signature_Request**c.Signing_Order**c renders on the record page
- ✅ DocGen_Signature_Request**c.Expires_At**c renders on the record page
- ✅ DocGen_Signature_Request**c.Email_Status**c renders on the record page
- ✅ DocGen_Signature_Request**c.Prefill_Signer_Email**c renders on the record page
- ✅ DocGen_Signature_Request**c.Require_Email_Verification**c renders on the record page
- ✅ DocGen_Signature_Request**c.Signer_Name**c renders on the record page
- ✅ DocGen_Signature_Request**c.Signer_Email**c renders on the record page
- ✅ DocGen_Signature_Request\_\_c.CreatedById renders on the record page
- ✅ DocGen_Signature_Request\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Request\_\_c exposes every one of its fields somewhere on the record page — all reachable; 4 field(s) intentionally edited elsewhere
- ✅ DocGen_Signature_Request**c fields edited outside the record page are accounted for — Frozen_Document**c (snapshot blob written by the signing engine), Render_Data_Snapshot**c (snapshot blob written by the signing engine), Signature_Data**c (written by the signing engine), Snapshot_Tak
- ✅ DocGen_Signature_Request\_\_c related lists load without error — 8 related list container(s) rendered
- ✅ DocGen_Signature_Request\_\_c shows its "Signers" related list
- ✅ DocGen_Signature_Request\_\_c shows its "Audits" related list
- ✅ DocGen_Signature_Request\_\_c shows its "Files" related list
- ✅ DocGen_Signature_Request\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Signature_Request\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Request\_\_c record page logs no console errors
- ✅ DocGen_Signer\_\_c record page renders — 38 field slots rendered
- ✅ DocGen_Signer\_\_c detail fields are genuinely visible (hit test) — first field "Signer Number" is hittable
- ✅ DocGen_Signer\_\_c.Name renders on the record page
- ✅ DocGen_Signer**c.Signature_Request**c renders on the record page
- ✅ DocGen_Signer**c.Signer_Name**c renders on the record page
- ✅ DocGen_Signer**c.Signer_Email**c renders on the record page
- ✅ DocGen_Signer**c.Status**c renders on the record page
- ✅ DocGen_Signer**c.Role_Name**c renders on the record page
- ✅ DocGen_Signer**c.Sort_Order**c renders on the record page
- ✅ DocGen_Signer**c.Contact**c renders on the record page
- ✅ DocGen_Signer**c.Signature_Data**c renders on the record page
- ✅ DocGen_Signer**c.Consent_Captured**c renders on the record page
- ✅ DocGen_Signer**c.Decline_Reason**c renders on the record page
- ✅ DocGen_Signer**c.PIN_Verified_At**c renders on the record page
- ✅ DocGen_Signer**c.PIN_Attempts**c renders on the record page
- ✅ DocGen_Signer**c.PIN_Expires_At**c renders on the record page
- ✅ DocGen_Signer**c.Reminders_Sent**c renders on the record page
- ✅ DocGen_Signer**c.Reminder_Sent_At**c renders on the record page
- ✅ DocGen_Signer\_\_c.CreatedById renders on the record page
- ✅ DocGen_Signer\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Signer\_\_c exposes every one of its fields somewhere on the record page — all reachable; 1 field(s) intentionally edited elsewhere
- ✅ DocGen_Signer**c fields edited outside the record page are accounted for — Field_Data_Json**c (written by the signing engine)
- ✅ DocGen_Signer\_\_c related lists load without error — 6 related list container(s) rendered
- ✅ DocGen_Signer\_\_c shows its "Files" related list
- ✅ DocGen_Signer\_\_c related lists are genuinely visible (hit test)
- ✅ DocGen_Signer\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signer\_\_c record page logs no console errors
- ✅ DocGen_Signature_Placement\_\_c record page renders — 31 field slots rendered
- ✅ DocGen_Signature_Placement\_\_c detail fields are genuinely visible (hit test) — first field "Placement Number" is hittable
- ✅ DocGen_Signature_Placement\_\_c.Name renders on the record page
- ✅ DocGen_Signature_Placement**c.Signer**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Signature_Request**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Placement_Type**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Sequence_Order**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Status**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Signed_Value**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Signed_At**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Document_Index**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Section_Context**c renders on the record page
- ✅ DocGen_Signature_Placement**c.Tag_Text**c renders on the record page
- ✅ DocGen_Signature_Placement\_\_c.CreatedById renders on the record page
- ✅ DocGen_Signature_Placement\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Placement**c.Render_Inline**c renders on the record page
- ✅ DocGen_Signature_Placement\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Signature_Placement\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Placement\_\_c record page logs no console errors
- ✅ DocGen_Signature_Audit\_\_c record page renders — 34 field slots rendered
- ✅ DocGen_Signature_Audit\_\_c detail fields are genuinely visible (hit test) — first field "Audit Number" is hittable
- ✅ DocGen_Signature_Audit\_\_c.Name renders on the record page
- ✅ DocGen_Signature_Audit**c.Signature_Request**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Signer**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Contact**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Signer_Name**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Signer_Email**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Signed_Date**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Consent_Captured**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Verification_Method**c renders on the record page
- ✅ DocGen_Signature_Audit**c.PIN_Verified_At**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Document_Hash_SHA256**c renders on the record page
- ✅ DocGen_Signature_Audit**c.IP_Address**c renders on the record page
- ✅ DocGen_Signature_Audit**c.User_Agent**c renders on the record page
- ✅ DocGen_Signature_Audit**c.Error_Message**c renders on the record page
- ✅ DocGen_Signature_Audit\_\_c.CreatedById renders on the record page
- ✅ DocGen_Signature_Audit\_\_c.LastModifiedById renders on the record page
- ✅ DocGen_Signature_Audit\_\_c exposes every one of its fields somewhere on the record page
- ✅ DocGen_Signature_Audit\_\_c page components report no error state — no custom component is placed on this record page
- ✅ DocGen_Signature_Audit\_\_c record page logs no console errors
- ✅ every seeded QA record is deleted again — 11 record(s) removed

### pdf-content — PDF content

- ✅ the dataset is large enough to exercise multi-page rendering — 2100 child rows across many pages (the giant branch is chosen on estimated heap, not on this count)
- ✅ the giant template generates — 442611 bytes in 6996ms (CPU 6419ms of 10000)
- ✅ the giant render leaves CPU headroom — 6419ms of the 10000ms synchronous limit (64%) at 2100 rows
- ✅ the giant document spans many pages — 59 pages from 2100 rows
- ✅ the document title survives the giant-query path — "PDFQA Master Roster" is on the page
- ✅ text above the table survives the giant-query path — intro paragraph present
- ✅ the column headers are rendered — "Contact Full Name" present
- ⊘ the table header repeats on later pages (giant path) — this render took the ORDINARY path — no -fs-table-paginate in the output, 2101 rows in one table — so per-page headers were never promised for it, and the headings correctly appear on 1 of 59 pages. T
- ✅ the footer appears on every page — footer on 59 of 59 pages
- ✅ the running header appears on every page — header on 59 of 59 pages
- ✅ page-number tags resolve rather than printing literally — counters resolved
- ✅ the footer reports the true page total — footer says "of 59", matching the actual page count
- ✅ merged child data is on the page — first seeded row and an email address both present
- ✅ no unresolved merge tag is printed — no raw tags on the page
- ✅ the last child row is present, not truncated — row 2100 of 2100 rendered

### template-integrity — Template integrity

- ❌ every HTML template returns a body to the visual Designer — 4 of 7 return NOTHING — those open to an empty canvas however well they generate. The Designer reads a ContentVersion titled docgen*html_body*<templateId>, not the version's Content_Version_Id\_\_c: Ver
- ❌ each template agrees with its active version about its own type — 4 disagree. Type\_\_c on the VERSION has Word as its picklist default, so any programmatic creation that omits it silently mistypes an HTML template — and the template derives its behaviour from the ver
- ⊘ merge-tag pills stay inside their table cells — could not open a template in the Designer: no Designer tab
