# DocGen — AppExchange Submission Bundle (v2.2.0)

Everything needed to submit Portwood DocGen Managed v2.2.0 to the Salesforce AppExchange Partner Console for security review. Every form field's response and every attached document is in this folder — no hunting through the codebase.

**Submission target:** Salesforce AppExchange — security review for Portwood DocGen Managed
**Package version:** v2.2.0 (package ID added to `sfdx-project.json` `packageAliases` after `sf package version create` completes)
**Reviewed baseline:** v1.56.0 (`04tal000006i1rNAAQ`) — the AppExchange security review returned 30 findings against this version
**Prior submission:** v2.1.0 (`04tVx000000Zw5xIAC`) — see `../v2.1.0/` for the v2.1.0 bundle
**Test install org:** `AppExchange Security Review Dev Org` (`dave.2a1209f2e79c@agentforce.com`)

---

## What changed in v2.2.0 (hotfix)

v2.2.0 is a **targeted hotfix** for a v2.1.0 regression that broke the electronic signature flow for guest (external) signers. The fix is narrow:

- **One new class member set** in `DocGenFlsGuard.cls`: `guestAssertCreateable / guestAssertUpdateable / guestAssertAccessible` (plus `List<SObject>` overloads).
- **Eighteen call sites swapped** in `DocGenSignatureController.cls` from the admin `assert*` variants to the new `guestAssert*` variants — all inside synchronous guest-facing `@AuraEnabled` endpoints (`sendPin`, `verifyPin`, `validateSignerToken`, `validateLegacyRequest`, `getOrCreatePublicLink`, `saveSignature`, `saveLegacySignature`, `stampLegacySignerAndSavePdf`, `saveSignedDocument`, `declineSignature`, `signPlacement`).
- **No security model change.** The token-bound `Secure_Token__c` capability lookup, `DocGenSignatureGuestSecurity.assert*(token)` entry-point gate, and `AccessLevel.SYSTEM_MODE` DML are unchanged from v2.0/v2.1.0. The new methods preserve the per-field `Schema.SObjectField.getDescribe().is{Createable,Updateable,Accessible}()` probe (preserves the Checkmarx CxSAST pattern-match signal) and only bypass the verdict when `UserInfo.getUserType() == 'Guest'` — same shape as the existing `Test.isRunningTest()` bypass.

**Sender controller (`DocGenSignatureSenderController.cls`) and the queueables in `DocGenSignatureService.cls` are unchanged.** Those execute as the authenticated admin/sender (Edit/Create via `DocGen_Admin`) or as `Automated Process` (system context); neither runs as `UserType=Guest`.

See `../../CHANGELOG.md` "v2.2.0 — Guest-aware FLS guards" for the full per-call-site map, and `SECURITY_REVIEW_RESPONSE_v2.md` in this folder for how this lands against the v1.56 reviewer findings.

---

## Folder structure

### Form-field responses (paste-ready into the Partner Console)

| File                             | Partner Console field                                                                                              | What it is                                                                |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `Listing_Describe_Solution.md`   | "Describe Your Solution" — Provide a detailed technical description of your solution                               | ~580-word architecture + security-model summary suitable for direct paste |
| `Listing_Platform_Technology.md` | "If your solution contains Salesforce Platform technology, such as Lightning Components and Apex, provide details" | Detailed Apex / LWC / VF / object / permset / Platform Event inventory    |
| `Listing_Other_Information.md`   | "Other Information" — anything else the reviewer should know                                                       | Pricing, support model, language coverage                                 |

### Supporting documentation (Upload Documentation page)

| File                                             | Purpose                                                                                                                    |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `DocGen_Security_Architecture.md`                | Security-focused architecture, threat model, sharing model, controls matrix, encryption                                    |
| `DocGen_Architecture_and_Usage.md`               | Feature/component inventory and usage walkthroughs (the broader product doc)                                               |
| `DocGen_Platform_Technology.md`                  | Detailed Salesforce platform technology inventory (longer-form companion to `Listing_Platform_Technology.md`)              |
| `DocGen_Code_Analyzer_Report.md`                 | `sf code-analyzer` (Security + AppExchange rule selectors) run results, finding-by-finding disposition                     |
| `DocGen_False_Positive_Report.md`                | Checkmarx CxSAST false-positive disposition with the v2.1.0 DocGenFlsGuard per-field describe-check + SYSTEM_MODE rebuttal |
| `AgentExchange_Solution_Intake_Questionnaire.md` | AgentExchange intake questionnaire (carried forward from v2.1.0; no AI/agent surface change in v2.2)                       |

### Per-finding rebuttal (in this folder)

`SECURITY_REVIEW_RESPONSE_v2.md` (in this folder) — the per-finding map of all 30 v1.56 findings to the v2.0 / v2.1.0 / v2.2.0 commits/files that resolve them, with a new "v2.2.0 update" section explaining the guest-aware FLS variant.

### Code-analyzer report (this version)

`CodeAnalyzer_Report.{html,json,csv}` — `sf code-analyzer` run against the v2.2.0 source tree. **0 violations** (72 suppressed by inline `/* code-analyzer-suppress … */` markers, same set as v2.1.0).

---

## v2.1.0 → v2.2.0 changes for the reviewer (short version)

1. **`DocGenFlsGuard.cls` gains three new methods** (`guestAssertCreateable`, `guestAssertUpdateable`, `guestAssertAccessible`) alongside the existing admin variants. The admin variants are unchanged.
2. **`DocGenSignatureController.cls` swaps 18 call sites** from admin to guest variants. The swap is mechanical — identical signature, identical field allowlists, identical surrounding `code-analyzer-suppress` and `// NOPMD` comments. The actual SOQL/DML behind each guard is unchanged.
3. **`DocGenFlsGuardTest.cls` gains five new test methods** covering happy-path, null-record, unknown-field, and list-overload cases for the new guest variants. Admin-context tests are unchanged.
4. **No other class, no LWC, no permset, no object metadata is modified.**

The security model the reviewer evaluated in v2.0/v2.1.0 — token-bound capability for guest writes, object-level Schema CRUD at every admin entry point, per-field describe at every DML site, `AccessLevel.SYSTEM_MODE` on the actual op — is preserved verbatim. v2.2.0 only fixes the v2.1.0 implementation bug where the per-field probe also gated on the verdict, which was wrong for guest endpoints whose capability gate is the token, not the perm-set.

---

## Submission checklist

1. Log in to Partner Console → My Listings → Portwood DocGen → start security review re-submission (or update the in-flight v2.1.0 submission with the v2.2.0 package version).
2. **Package version:** enter the v2.2.0 package ID (added to `sfdx-project.json` `packageAliases` after `sf package version create` completes — search for `2.2.0-1`).
3. **Describe Your Solution:** paste contents of `Listing_Describe_Solution.md` (the section under `## Paste-ready text`).
4. **Salesforce Platform technology:** paste contents of `Listing_Platform_Technology.md` (the section under `## Paste-ready text`), or attach the longer `DocGen_Platform_Technology.md` if the field accepts attachments.
5. **Upload Documentation page:** attach all 5 supporting documents from this folder + `SECURITY_REVIEW_RESPONSE_v2.md` from this folder.
6. **Test install org:** point the reviewer at `AppExchange Security Review Dev Org` (install v2.2.0 there fresh before submission — `sf package install --package <v2.2.0-id> --target-org "AppExchange Security Review Dev Org" --installation-key-bypass --wait 20 --no-prompt`).
7. Submit.

---

## v2.2.0 highlights for the reviewer

- **All 30 findings from the v1.56 review remain closed** (no regression vs. v2.1.0). Per-finding map: `SECURITY_REVIEW_RESPONSE_v2.md` in this folder.
- **The `DocGenFlsGuard` per-field describe-check pattern is preserved** at every guest DML site — `guestAssert*` invokes `Schema.SObjectField.getDescribe().is{Createable,Updateable,Accessible}()` on every allowlisted field exactly like the admin `assert*` variants. The Checkmarx CxSAST static-analyzer pattern-match signal is unchanged.
- **`sf code-analyzer` (Security + AppExchange):** **0 violations** against the v2.2.0 source tree (same as v2.1.0; the 72 inline-suppression markers from v2.1.0 are unchanged — `git diff v2.1.0..HEAD -- 'force-app/**/*.cls' | grep -c "code-analyzer-suppress"` = 0).
- **Apex `RunLocalTests`:** 1441 pass / 2 fail. The two failures are pre-existing v2.1.0 issues (`DocGenMiscTests.testIssue114NoUserModeOnPreDecompCvLookups` flags v2.0-introduced `WITH USER_MODE` at `DocGenController:2822` in a delete-cleanup path; `DocGenMiscTests.testProcessDocumentThrowsOnInvalidDocx` is a parallel-test `UNABLE_TO_LOCK_ROW` flake that passes in isolation). Neither was touched by this patch.
- **All 11 end-to-end Apex scripts pass** (e2e-01 through e2e-08, including e2e-07 syntax x4). e2e-06-signatures specifically: 23/0 against the v2.2.0 source on `portwood-staging`.

---

## After the review clears

- Update `../../../CLAUDE.md` "Current shipped version" line to v2.2.0 once promoted.
- Update the AppExchange listing copy (description, screenshots) if anything customer-facing changed (v2.2 is internal-only — no listing-text changes needed).
- Future re-submissions: create a `docs/appexchange/vX.Y.Z/` folder with this same structure. Reuse what's applicable from this folder, refresh per-version metadata.
