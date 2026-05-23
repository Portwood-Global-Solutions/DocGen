# DocGen — AppExchange Submission Bundle (v2.3.0)

Everything needed to submit Portwood DocGen Managed v2.3.0 to the Salesforce AppExchange Partner Console for security review.

**Submission target:** Salesforce AppExchange — security review for Portwood DocGen Managed
**Package version:** v2.3.0 (`04tVx000000ZxDJIA0`, build `2.3.0-1`), promoted 2026-05-23
**Install URL:** https://login.salesforce.com/packaging/installPackage.apexp?p0=04tVx000000ZxDJIA0
**Reviewed baseline:** v1.56.0 (`04tal000006i1rNAAQ`) — the AppExchange security review returned 30 findings against this version
**Prior submissions:** v2.1.0 (`04tVx000000Zw5xIAC`), v2.2.0 (`04tVx000000ZxBhIAK`)
**Test install org:** `AppExchange Security Review Dev Org` (`dave.2a1209f2e79c@agentforce.com`)

---

## What changed v2.2.0 → v2.3.0

v2.3.0 is a **completion patch** for the v2.2.0 hotfix. v2.2.0 added the guest-aware FLS helper variants (`guestAssertCreateable / guestAssertUpdateable / guestAssertAccessible`) and swapped the 18 admin **write** guard sites in `DocGenSignatureController.cls` to the guest variants — but left the 36 **read** guard sites (`DocGenFlsGuard.assertAccessible`) as admin variants. Those throw the same way on guest context, just with the per-field FLS describe verdict on the SOQL select-list. Customers running v2.2.0 hit:

`Save failed: Insufficient FLS to read portwoodglobal__DocGen_Signer__c.Contact__c. Verify DocGen permission set assignment.`

after clicking the signing link from email and reaching the saveSignature step. The `DocGen_Guest_Signature` permset DOES grant `<readable>true</readable>` on `Contact__c` (and on every field in the saveSignature read allowlist), but `Schema.SObjectField.getDescribe().isAccessible()` returns FALSE for guest profiles even when the permset grants it — same platform inconsistency that drove the v2.1 → v2.2 fix.

v2.3.0 swaps the 36 read-guard call sites:

- **`DocGenSignatureController.cls`** — 34 sites swapped from `DocGenFlsGuard.assertAccessible(` to `DocGenFlsGuard.guestAssertAccessible(`. Covers every SOQL read inside the guest-facing controller: signer/request/placement/audit reads, ContentVersion reads, ContentDistribution reads.
- **`DocGenAuthenticatorController.cls`** — 2 sites swapped (`verifyDocument(fileHash)`, `verifyByRequestId(requestId)`). Both are public verifier endpoints, guest-context, gated by `DocGenSignatureGuestSecurity.assertAuditReadable()` at entry, both reading `DocGen_Signature_Audit__c`.

No new methods, no new tests, no new files. `DocGenFlsGuard.guestAssertAccessible` was already shipped in v2.2.0 — v2.3.0 just calls it from 36 sites v2.2.0 missed. Sender controller and Service queueables unchanged (those run as authenticated admin / Automated Process, not as `UserType=Guest`).

See `../../CHANGELOG.md` "v2.3.0 — Guest-aware FLS reads" for the full per-call-site picture, and `SECURITY_REVIEW_RESPONSE_v2.md` in this folder for how this lands against the v1.56 reviewer findings.

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
| `AgentExchange_Solution_Intake_Questionnaire.md` | AgentExchange intake questionnaire (carried forward from v2.2.0; no AI/agent surface change in v2.3)                       |

### Per-finding rebuttal (in this folder)

`SECURITY_REVIEW_RESPONSE_v2.md` (in this folder) — the per-finding map of all 30 v1.56 findings to the v2.0 / v2.1.0 / v2.2.0 / v2.3.0 commits/files that resolve them, with a "v2.3.0 update" section explaining the read-path completion.

### Code-analyzer report (this version)

`CodeAnalyzer_Report.{html,json,csv}` — `sf code-analyzer` run against the v2.3.0 source tree (generated after the v2.3.0 build promotes; expected to match v2.2.0's **0 violations**).

---

## v2.2.0 → v2.3.0 changes for the reviewer (short version)

1. **`DocGenSignatureController.cls`** — 34 of the 35 `assertAccessible` calls swapped to `guestAssertAccessible`. The signature is identical (`(SObjectType, Set<String>)`); the only behavioral difference is the `UserInfo.getUserType() == 'Guest'` verdict bypass already shipped in v2.2.
2. **`DocGenAuthenticatorController.cls`** — 2 `assertAccessible` calls swapped to `guestAssertAccessible`. The 35th `assertAccessible` in DocGenSignatureController is in a `//` comment, not a call.
3. **No new classes, no new methods, no new tests, no metadata changes.** The fix is a 36-line mechanical call-site swap.

The security model the reviewer evaluated in v2.0/v2.1.0/v2.2.0 — token-bound capability for guest reads/writes, object-level Schema CRUD at every admin entry point, per-field describe at every SOQL/DML site, `AccessLevel.SYSTEM_MODE` on the actual op — is preserved verbatim.

---

## Submission checklist

1. Log in to Partner Console → My Listings → Portwood DocGen → start security review re-submission (or update the in-flight v2.2.0 submission with the v2.3.0 package version).
2. **Package version:** enter `04tVx000000ZxDJIA0` (`Portwood DocGen Managed@2.3.0-1`).
3. **Describe Your Solution:** paste contents of `Listing_Describe_Solution.md`.
4. **Salesforce Platform technology:** paste contents of `Listing_Platform_Technology.md`.
5. **Upload Documentation page:** attach all 5 supporting documents from this folder + `SECURITY_REVIEW_RESPONSE_v2.md`.
6. **Test install org:** point the reviewer at `AppExchange Security Review Dev Org` (install v2.3.0 there fresh before submission).
7. Submit.

---

## After the review clears

- Update `../../../CLAUDE.md` "Current shipped version" line to v2.3.0 once promoted.
- Future re-submissions: create a `docs/appexchange/vX.Y.Z/` folder with this same structure.
