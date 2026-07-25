# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T15:21:59.246Z · **Duration** 0s

## Headline

|                       |             |
| --------------------- | ----------- |
| Checks evaluated      | 476         |
| Passed                | 318 (66.8%) |
| Failed                | 158         |
| Skipped (not counted) | 0           |
| Blockers              | 0           |
| Major                 | 34          |
| Minor                 | 124         |

## Coverage by area

| Suite            | Area     | Passed | Failed | Skipped |  Rate |
| ---------------- | -------- | -----: | -----: | ------: | ----: |
| `metadata-audit` | Metadata |    318 |    158 |       0 | 66.8% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity  | Suite            | Check                                                                                    | Evidence                                                                                                                                                                                 |
| --------- | ---------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **major** | `metadata-audit` | DocGen_Asset\_\_c has a page layout                                                      | no layout file references this object                                                                                                                                                    |
| **major** | `metadata-audit` | DocGen_Asset**c.Asset_Key**c is on the page layout                                       | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.               |
| **major** | `metadata-audit` | DocGen_Asset**c.Asset_Type**c is on the page layout                                      | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.               |
| **major** | `metadata-audit` | DocGen_Asset**c.Category**c is on the page layout                                        | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.               |
| **major** | `metadata-audit` | DocGen_Asset**c.Is_Active**c is on the page layout                                       | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.               |
| **major** | `metadata-audit` | DocGen_Email_Template\_\_c has a page layout                                             | no layout file references this object                                                                                                                                                    |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Body_Html**c is on the page layout                              | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Body_Plain**c is on the page layout                             | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Brand_Color**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Description**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Footer_Text**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Is_Active**c is on the page layout                              | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Layout_Mode**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Logo_Asset_Key**c is on the page layout                         | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Logo_Height**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Logo_Url_Extended**c is on the page layout                      | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Logo_Url**c is on the page layout                               | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Subject**c is on the page layout                                | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Email_Template**c.Type**c is on the page layout                                   | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.      |
| **major** | `metadata-audit` | DocGen_Job**c.Error_Log**c is on the page layout                                         | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.                 |
| **major** | `metadata-audit` | DocGen_Job**c.Merged_PDF_CV**c is on the page layout                                     | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.                 |
| **major** | `metadata-audit` | DocGen_Job**c.Parent_Record_Id**c is on the page layout                                  | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.                 |
| **major** | `metadata-audit` | DocGen_Signature_Placement**c.Render_Inline**c is on the page layout                     | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Placement\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason. |
| **major** | `metadata-audit` | DocGen_Signature_Request**c.Frozen_Document**c is on the page layout                     | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Request\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.   |
| **major** | `metadata-audit` | DocGen_Signature_Request**c.Snapshot_Taken_At**c is on the page layout                   | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Request\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.   |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Custom_Margins**c is on the page layout                       | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Document_Title_Format**c is on the page layout                | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Footer_Html**c is on the page layout                          | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Header_Html**c is on the page layout                          | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Output_Format**c is on the page layout                        | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Page_Margins**c is on the page layout                         | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Page_Orientation**c is on the page layout                     | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Page_Size**c is on the page layout                            | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **major** | `metadata-audit` | DocGen_Template_Version**c.Watermark_Image_CV_Id**c is on the page layout                | field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.    |
| **minor** | `metadata-audit` | DocGen_Asset**c.Asset_Key**c has a description or help text                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Asset**c.Asset_Type**c has a description or help text                             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Asset**c.Category**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Asset**c.Is_Active**c has a description or help text                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Object_API_Name**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Output_Format_Override**c has a description or help text              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Record_Type_Developer_Names**c has a description or help text         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Save_To_Record**c has a description or help text                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Template_API_Name**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Button**mdt.Template_Id**c has a description or help text                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Body_Html**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Body_Plain**c has a description or help text                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Brand_Color**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Footer_Text**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Is_Active**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Layout_Mode**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Logo_Asset_Key**c has a description or help text                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Logo_Height**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Logo_Url_Extended**c has a description or help text             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Logo_Url**c has a description or help text                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Subject**c has a description or help text                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Email_Template**c.Type**c has a description or help text                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Error_Log**c.Exception_Type**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Error_Log**c.Severity**c has a description or help text                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Guest_Render**e.Job_Id**c has a description or help text                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Error_Count**c has a description or help text                              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Error_Log**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Label**c has a description or help text                                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Merge_Only**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Parent_Record_Id**c has a description or help text                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Status**c has a description or help text                                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Success_Count**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Template**c has a description or help text                                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Job**c.Total_Records**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Company_Name**c has a description or help text                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Experience_Site_Url**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Email_Brand_Color**c has a description or help text         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Email_Footer_Text**c has a description or help text         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Email_Logo_Url**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Email_Message**c has a description or help text             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Email_Subject**c has a description or help text             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Expiration_Days**c has a description or help text           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_OWA_Id**c has a description or help text                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Prefill_Signer_Email**c has a description or help text      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Reminder_Enabled**c has a description or help text          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Reminder_Hours**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Reminder_Schedule**c has a description or help text         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Settings**c.Signature_Skip_Email_Verification**c has a description or help text   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Contact**c has a description or help text                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Document_Hash_SHA256**c has a description or help text         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.IP_Address**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Signature_Request**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Signed_Date**c has a description or help text                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Signer_Email**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Signer_Name**c has a description or help text                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Signer**c has a description or help text                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.User_Agent**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Audit**c.Verification_Method**c has a description or help text          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Document_Index**c has a description or help text           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Placement_Type**c has a description or help text           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Render_Inline**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Section_Context**c has a description or help text          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Sequence_Order**c has a description or help text           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Signature_Request**c has a description or help text        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Signed_At**c has a description or help text                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Signed_Value**c has a description or help text             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Signer**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Status**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Placement**c.Tag_Text**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Document_Title_Format**c has a description or help text      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Email_Status**c has a description or help text               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Expires_At**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Frozen_Document**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Prefill_Signer_Email**c has a description or help text       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Related_Record_Id**c has a description or help text          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Require_Email_Verification**c has a description or help text | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Signer_Email**c has a description or help text               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Signer_Name**c has a description or help text                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Signing_Order**c has a description or help text              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Snapshot_Taken_At**c has a description or help text          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Status**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Template_Ids**c has a description or help text               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signature_Request**c.Template**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Contact**c has a description or help text                               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Decline_Reason**c has a description or help text                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Reminder_Sent_At**c has a description or help text                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Reminders_Sent**c has a description or help text                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Signature_Request**c has a description or help text                     | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Signer_Email**c has a description or help text                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Signer_Name**c has a description or help text                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Sort_Order**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Signer**c.Status**c has a description or help text                                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Base_Object_API**c has a description or help text             | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Category**c has a description or help text                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Custom_Margins**c has a description or help text              | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Description**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Document_Title_Format**c has a description or help text       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Footer_Html**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Header_Html**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Output_Format**c has a description or help text               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Page_Orientation**c has a description or help text            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Page_Size**c has a description or help text                   | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Pre_Decomposition_Status**c has a description or help text    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Type**c has a description or help text                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template_Version**c.Watermark_Image_CV_Id**c has a description or help text       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.API_Name**c has a description or help text                            | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Custom_Margins**c has a description or help text                      | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Default_Email_Message**c has a description or help text               | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Footer_Html**c has a description or help text                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Form_Fields_Config**c has a description or help text                  | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Header_Html**c has a description or help text                         | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Is_Active**c has a description or help text                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Is_Default**c has a description or help text                          | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Page_Margins**c has a description or help text                        | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Page_Orientation**c has a description or help text                    | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Page_Size**c has a description or help text                           | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Prefill_Signer_Email**c has a description or help text                | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Record_Filter**c has a description or help text                       | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Signer_Verification**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | DocGen_Template**c.Specific_Record_Ids**c has a description or help text                 | no <description> or <inlineHelpText> — the admin has no idea what it does                                                                                                                |
| **minor** | `metadata-audit` | docGenAuthenticator (app page) is reachable from a tab                                   | no tab references it — reachable only via a hand-built Lightning page                                                                                                                    |
| **minor** | `metadata-audit` | docGenQueryBuilder (app page) is reachable from a tab                                    | no tab references it — reachable only via a hand-built Lightning page                                                                                                                    |
| **minor** | `metadata-audit` | docGenRunner (app page) is reachable from a tab                                          | no tab references it — reachable only via a hand-built Lightning page                                                                                                                    |
| **minor** | `metadata-audit` | docGenTreeBuilder (app page) is reachable from a tab                                     | no tab references it — reachable only via a hand-built Lightning page                                                                                                                    |

## Every check

### metadata-audit — Metadata

- ❌ DocGen_Asset\_\_c has a page layout — no layout file references this object
- ❌ DocGen_Asset**c.Asset_Key**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ❌ DocGen_Asset**c.Asset_Key**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Asset**c.Asset_Type**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Asset**c.Asset_Type**c is granted on DocGen_Admin
- ❌ DocGen_Asset**c.Asset_Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Asset**c.Category**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Asset**c.Category**c is granted on DocGen_Admin
- ❌ DocGen_Asset**c.Category**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Asset**c.Is_Active**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Asset\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ❌ DocGen_Email_Template\_\_c has a page layout — no layout file references this object
- ❌ DocGen_Email_Template**c.Body_Html**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Body_Html**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Body_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Body_Plain**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Body_Plain**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Body_Plain**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Brand_Color**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Brand_Color**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Brand_Color**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Description**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Description**c is granted on DocGen_Admin
- ✅ DocGen_Email_Template**c.Description**c has a description or help text
- ❌ DocGen_Email_Template**c.Footer_Text**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Footer_Text**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Footer_Text**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Is_Active**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Is_Active**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Is_Active**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Layout_Mode**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Layout_Mode**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Layout_Mode**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Logo_Asset_Key**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Logo_Asset_Key**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Asset_Key**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Logo_Height**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Logo_Height**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Height**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Logo_Url_Extended**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Logo_Url_Extended**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Url_Extended**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Logo_Url**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Logo_Url**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Logo_Url**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Subject**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Email_Template**c.Subject**c is granted on DocGen_Admin
- ❌ DocGen_Email_Template**c.Subject**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Email_Template**c.Type**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Email_Template\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ❌ DocGen_Job**c.Error_Log**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Job**c.Error_Log**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Error_Log**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Giant_Query_Config**c is kept OFF the page layout
- ✅ DocGen_Job**c.Label**c is on the page layout
- ✅ DocGen_Job**c.Label**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Label**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Job**c.Merge_Only**c is on the page layout
- ✅ DocGen_Job**c.Merge_Only**c is granted on DocGen_Admin
- ❌ DocGen_Job**c.Merge_Only**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Job**c.Merged_PDF_CV**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Job**c.Merged_PDF_CV**c is granted on DocGen_Admin
- ✅ DocGen_Job**c.Merged_PDF_CV**c has a description or help text
- ❌ DocGen_Job**c.Parent_Record_Id**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Job\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ❌ DocGen_Signature_Placement**c.Render_Inline**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Placement\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ❌ DocGen_Signature_Request**c.Frozen_Document**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Request\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ❌ DocGen_Signature_Request**c.Snapshot_Taken_At**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Signature_Request\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
- ✅ DocGen_Signer**c.Signature_Data**c is on the page layout
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
- ❌ DocGen_Template_Version**c.Custom_Margins**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Custom_Margins**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Custom_Margins**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Description**c is on the page layout
- ✅ DocGen_Template_Version**c.Description**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Description**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Document_Title_Format**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Document_Title_Format**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Document_Title_Format**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Footer_Html**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Footer_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Footer_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Header_Html**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Header_Html**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Header_Html**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Is_Active**c is on the page layout
- ✅ DocGen_Template_Version**c.Is_Active**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Is_Active**c has a description or help text
- ❌ DocGen_Template_Version**c.Output_Format**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Output_Format**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Output_Format**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Page_Margins**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Page_Margins**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Page_Margins**c has a description or help text
- ❌ DocGen_Template_Version**c.Page_Orientation**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Page_Orientation**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Page_Orientation**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Page_Size**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
- ✅ DocGen_Template_Version**c.Page_Size**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Page_Size**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Pre_Decomposition_Status**c is on the page layout
- ✅ DocGen_Template_Version**c.Pre_Decomposition_Status**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Pre_Decomposition_Status**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ✅ DocGen_Template_Version**c.Query_Config**c is on the page layout
- ✅ DocGen_Template_Version**c.Query_Config**c is granted on DocGen_Admin
- ✅ DocGen_Template_Version**c.Query_Config**c has a description or help text
- ✅ DocGen_Template_Version**c.Template**c is on the page layout
- ✅ DocGen_Template_Version**c.Template**c has a description or help text
- ✅ DocGen_Template_Version**c.Type**c is on the page layout
- ✅ DocGen_Template_Version**c.Type**c is granted on DocGen_Admin
- ❌ DocGen_Template_Version**c.Type**c has a description or help text — no <description> or <inlineHelpText> — the admin has no idea what it does
- ❌ DocGen_Template_Version**c.Watermark_Image_CV_Id**c is on the page layout — field exists but no layout shows it — an admin cannot see or set it. Add to layouts/DocGen_Template_Version\_\_c-\*.layout-meta.xml, or waive it in metadata-audit.mjs with a reason.
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
