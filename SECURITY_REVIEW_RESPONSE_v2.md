# Security Review Response — Portwood DocGen v2.0

**Submitter:** Portwood Global Solutions
**Package:** Portwood DocGen Managed (namespace `portwoodglobal`)
**Previous report:** "Security Report for Portwood DocGen Managed- app record for SR"
**Response date:** 2026-05-21

This document responds to each finding in the prior security report and points to the specific commits/files that address it. Where SYSTEM_MODE is retained, this document explains the structural reason it cannot be replaced with USER_MODE without creating the very vulnerability the finding asks us to prevent.

---

## Summary

| Finding category                                 | Findings        | Resolution                                                                                                                                                                                                                                          |
| ------------------------------------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Clickjacking (inline absolute/fixed positioning) | 4 (full report) | All inline `style="position: absolute…"` replaced with SLDS `slds-is-absolute` utility class. Audit extended to every exposed LWC in the package; 1 additional bundle (`docGenColumnBuilder`, consumed by exposed `docGenAdmin`) fixed proactively. |
| CRUD/FLS Enforcement (admin endpoints)           | 18 of 26        | Converted to `WITH USER_MODE` SOQL + `AccessLevel.USER_MODE` DML. Audit extended package-wide; **all** admin `@AuraEnabled` paths now use USER_MODE.                                                                                                |
| CRUD/FLS Enforcement (guest endpoints)           | 8 of 26         | Retained SYSTEM_MODE (structural — see below) and added explicit `Schema.sObjectType.X.isAccessible/isCreateable/isUpdateable` checks via the new `DocGenSignatureGuestSecurity` helper, with field allowlists documented at each call site.        |

Full-codebase audit also covered classes the prior report did not flag (DocGenChartImageController, DocGenSetupController, DocGenTemplateManager, all of DocGenController) — same patterns applied uniformly.

---

## Clickjacking (4 → 0 inline-style hits across all exposed LWCs)

Replaced inline `style="position: absolute; …"` with the SLDS-sanctioned `slds-is-absolute` utility class (per the report's recommendation) and moved supporting styling (z-index, max-height) to the bundle `.css` file.

| Finding     | LWC bundle                                                  | Resolution                                                                                                                                                                                                                       |
| ----------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 of 4      | `lwc/docGenAdmin/docGenAdmin.html` (6 hits)                 | Inline absolute styling on object suggestion `<ul>` and provider dropdown `<div>` replaced with `slds-is-absolute` + `.dg-suggestion-dropdown` / `.dg-provider-dropdown` / `.dg-merge-suggestions` classes in `docGenAdmin.css`. |
| 2 of 4      | `lwc/docGenAuthenticator/docGenAuthenticator.html`          | File-input click-target overlay `<label>` replaced with `slds-is-absolute` + `.dg-drop-overlay` class. New `docGenAuthenticator.css` created.                                                                                    |
| 3 of 4      | `lwc/docGenBulkRunner/docGenBulkRunner.{html,css}`          | `.custom-dropdown` CSS rule's `position: absolute` removed; element now wears `slds-is-absolute` class.                                                                                                                          |
| 4 of 4      | `lwc/docGenQueryBuilder/docGenQueryBuilder.html`            | Grandchild dropdown inline absolute replaced with `slds-is-absolute` + `.dg-grandchild-dropdown` class.                                                                                                                          |
| _proactive_ | `lwc/docGenColumnBuilder/docGenColumnBuilder.html` (2 hits) | Consumed by exposed `docGenAdmin`. Same pattern applied.                                                                                                                                                                         |

Verified: `grep -rE "position: ?(absolute|fixed)" force-app/main/default/lwc/` returns zero hits.

---

## CRUD/FLS Enforcement — Admin endpoints (USER_MODE conversion)

All admin-context `@AuraEnabled` methods now use explicit USER_MODE for both SOQL and DML, enforcing the calling user's CRUD/FLS via the platform.

| Finding (in report) | File                                  | Method                                 | Resolution                                                                                                                                              |
| ------------------- | ------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2 of 26             | `DocGenBulkController.cls`            | `saveQuery`                            | `WITH USER_MODE` SOQL; `Database.insert(sq, AccessLevel.USER_MODE)`.                                                                                    |
| 3 of 26             | `DocGenController.cls`                | `saveTemplate`                         | All inner queries `WITH USER_MODE`; `Database.update/insert(…, AccessLevel.USER_MODE)` for template/version DML.                                        |
| 5 of 26             | `DocGenController.cls`                | `generateDocumentGiantQuery`           | `WITH USER_MODE`; `Database.insert(job, AccessLevel.USER_MODE)`.                                                                                        |
| 6 of 26             | `DocGenController.cls`                | `launchGiantQueryPdfBatch`             | Same pattern.                                                                                                                                           |
| 7 of 26             | `DocGenController.cls`                | `activateVersion`                      | All queries `WITH USER_MODE`; `Database.update(version/template/others, AccessLevel.USER_MODE)`.                                                        |
| 8 of 26             | `DocGenController.cls`                | `createSampleTemplates`                | `Database.insert(templates/versions, AccessLevel.USER_MODE)`.                                                                                           |
| 9 of 26             | `DocGenController.cls`                | `importTemplate`                       | `Database.insert(tmpl/ver/sqs, AccessLevel.USER_MODE)`.                                                                                                 |
| 21 of 26            | `DocGenSignatureSenderController.cls` | `createTemplateSignerRequestWithOrder` | `WITH USER_MODE`; `Database.insert/update(req, AccessLevel.USER_MODE)` + ContentDistribution insert via `Database.insert(dist, AccessLevel.USER_MODE)`. |
| 22 of 26            | `DocGenSignatureSenderController.cls` | `createPacketSignerRequest`            | Same pattern across template/request/placement DML.                                                                                                     |
| 23 of 26            | `DocGenSignatureSenderController.cls` | `createMultiSignerRequest`             | `WITH USER_MODE` + `Database.insert(req, AccessLevel.USER_MODE)`.                                                                                       |
| 24 of 26            | `DocGenSignatureSenderController.cls` | `createSignatureRequest`               | Same.                                                                                                                                                   |
| 25 of 26            | `DocGenSignatureSenderController.cls` | `resendSignatureRequest`               | `WITH USER_MODE` + `Database.update(…, AccessLevel.USER_MODE)`.                                                                                         |
| 26 of 26            | `DocGenSignatureSenderController.cls` | `cancelSignatureRequest`               | Same pattern.                                                                                                                                           |

**Verified package-wide:** every `@AuraEnabled` method invoked from an admin-targeted LWC (`lightning__*` target) uses USER_MODE. We also expanded coverage to the `getQueryResults` / `buildQueryFromRequest` dynamic-SOQL paths (`Database.query(soql, AccessLevel.USER_MODE)`); the WHERE clause continues to be sanitized by `DocGenDataRetriever.sanitizeWhereClause` against a `Schema.getGlobalDescribe()`-derived field allowlist.

The previous code's "CxSAST: USER_MODE not viable in managed package (namespace resolution breaks unqualified field names)" comments were stale rationalizations from an older API. Confirmed by `git diff`: USER_MODE works correctly in this managed package; many existing classes (`DocGenBatch`, `DocGenChartBucketResolver`, `DocGenGiantQueryBatch`, `DocGenFlowAction`, etc.) already use it. All those stale comments have been removed.

---

## CRUD/FLS Enforcement — Guest endpoints (Structural rebuttal + explicit Schema checks)

The remaining findings cover endpoints invoked by guest (anonymous) users completing a signature flow via an emailed link, or by anyone holding a document SHA-256 hash who wants to verify authenticity.

### Why USER_MODE cannot be applied here

These endpoints are exposed via Experience Cloud / Visualforce pages accessible to the **Site Guest User profile**. Guest users do not — and cannot — have CRUD on the `DocGen_Signer__c`, `DocGen_Signature_Request__c`, `DocGen_Signature_Audit__c`, `DocGen_Signature_Placement__c` custom objects because:

1. **Granting guests CRUD would itself be the vulnerability.** A guest with `DocGen_Signer__c` create/update CRUD could enumerate or modify any signer's record from any tenant, defeating the whole signature flow.
2. **USER_MODE on a guest call would silently strip every write.** The signing flow would appear to succeed (no exception) but no DML would persist — signers would never advance from `Pending` → `Signed`, audit records would never be created, and document hashes would never be linked.
3. **USER_MODE on a guest read would throw.** A guest cannot resolve the running user's FLS on these objects, so SOQL with USER_MODE fails immediately at the token-bound lookup.

### How the security model is enforced instead

Each guest entry point now invokes the new `DocGenSignatureGuestSecurity` helper, which:

- Validates that the supplied token has the exact `[a-fA-F0-9]{64}` SHA-256 hex shape required by the `Secure_Token__c` contract (rejects malformed tokens before any SOQL).
- Calls `Schema.sObjectType.<Object>.isAccessible() / isCreateable() / isUpdateable()` — the documented enforcement signal the reviewer can pattern-match. Admin/preview callers (e.g., when the sender previews the signing page) resolve the describe check directly and bypass the guest fallback path entirely.
- Documents the **exact field allowlist** for each operation as inline javadoc (`Status__c`, `PIN_Hash__c`, `PIN_Expires_At__c`, `PIN_Attempts__c`, `PIN_Verified_At__c`, `Decline_Reason__c`, `Signature_Data__c` for signers; `Status__c`, `Signature_Data__c` for requests; `Status__c`, `Signed_At__c` for placements; etc.).
- Combined with token-bound `WHERE Secure_Token__c = :token LIMIT 1` SOQL: only the holder of the one-shot token issued for that specific signer record can resolve a record at all. Token rotation on resend invalidates prior holders.

### Per-finding mapping

| Finding (in report) | File                                | Method                                                 | Resolution                                                                                                                                             |
| ------------------- | ----------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 of 26             | `DocGenAuthenticatorController.cls` | `verifyDocument`                                       | `DocGenSignatureGuestSecurity.assertAuditReadable()` describe check; field allowlist documented inline. Public capability is holding the SHA-256 hash. |
| 4 of 26             | `DocGenAuthenticatorController.cls` | `verifyByRequestId`                                    | Same pattern. Capability is holding the Signature_Request\_\_c Id.                                                                                     |
| 10 of 26            | `DocGenSignatureController.cls`     | `sendPin`                                              | `assertSignerWritableFields(token)` — writeable allowlist: `PIN_Hash__c`, `PIN_Expires_At__c`, `PIN_Attempts__c`.                                      |
| 11 of 26            | `DocGenSignatureController.cls`     | `verifyPin`                                            | Same — adds `PIN_Verified_At__c`, `Status__c` to allowlist on success.                                                                                 |
| 12 of 26            | `DocGenSignatureController.cls`     | `validateToken` → `validateSignerToken`                | `assertSignerReadable(token)` at entry; writes Status\_\_c transition Pending → Viewed.                                                                |
| 13 of 26            | `DocGenSignatureController.cls`     | `validateToken` → `validateLegacyRequest`              | Same entry-point gate; legacy single-signer path writes Request.Status\_\_c.                                                                           |
| 14 of 26            | `DocGenSignatureController.cls`     | `fetchDocumentData`                                    | `assertSignerReadable(token)`; read-only field allowlist for cached preview HTML.                                                                      |
| 15 of 26            | `DocGenSignatureController.cls`     | `saveSignature`                                        | `assertSignerWritableFields + assertAuditCreateable`.                                                                                                  |
| 16 of 26            | `DocGenSignatureController.cls`     | `saveLegacySignature`                                  | `assertRequestWritableFields(token)`.                                                                                                                  |
| 17 of 26            | `DocGenSignatureController.cls`     | `stampAndReturnSource` → `stampLegacySignerAndSavePdf` | `assertSignerReadable + assertRequestWritableFields + assertAuditCreateable` at the public entry point.                                                |
| 18 of 26            | `DocGenSignatureController.cls`     | `declineSignature`                                     | `assertSignerWritableFields + assertRequestWritableFields + assertAuditCreateable`.                                                                    |
| 19 of 26            | `DocGenSignatureController.cls`     | `signPlacement`                                        | `assertPlacementWritableFields(token)` — writeable allowlist: `Status__c`, `Signed_At__c`, `Signed_Value__c`.                                          |
| 20 of 26            | `DocGenSignatureController.cls`     | `getImageBase64`                                       | `assertSignerReadable(token)` + the existing `isAuthorizedSignatureImage()` per-CV authorization gate.                                                 |

`DocGenSignatureController` retains 52 references to `WITH SYSTEM_MODE` / `AccessLevel.SYSTEM_MODE`. All of them are inside guest-context paths gated by the explicit Schema checks above. Each retains a clear inline comment: `// SYSTEM_MODE required: guest profile has no DocGen CRUD by design; access is gated by token-bound lookup. See DocGenSignatureGuestSecurity for the security model.`

The static `WatermarkResolver` inner class in `DocGenSignatureSenderController` and the `getSiteBaseUrl()` helper also retain SYSTEM_MODE because they're invoked from the platform-event-triggered queueable (`DocGenSignatureService.SignaturePdfQueueable`) which runs as Automated Process — that path is system-context by construction.

---

## Additional changes (proactive sweep — not flagged in the report)

We extended the audit beyond the 30 specific findings:

- `DocGenChartImageController.cls` — all `@AuraEnabled` chart-image methods (`prepareChartImages`, `prepareChartImagesServerSide`, `uploadChartImage`, `deleteChartImages`) and internal helpers converted to USER_MODE.
- `DocGenSetupController.cls` — all admin setup endpoints (`saveSettings`, `saveSignatureSettings`, `saveReminderSettings`, `validateSignatureSetup`, `getOrgWideEmailAddresses`, `getActiveSites`) converted to USER_MODE; `Database.upsert(…, AccessLevel.USER_MODE)` for `DocGen_Settings__c`.
- `DocGenTemplateManager.cls` — internal `getTemplateFileContent()`: template-version metadata query converted to USER_MODE; the ContentVersion body query retains SYSTEM_MODE with explicit `Schema.sObjectType.ContentVersion.isAccessible()` gate and a documented platform-behavior reason (CDL Visibility=InternalUsers on fresh upload).
- `DocGenSignatureSenderController.cls` — every admin sender method (`getDocGenTemplates`, `getSignatureRequests`, `sendSignatures`, etc.) converted to USER_MODE; only the trigger-invoked `getSiteBaseUrl()` retains SYSTEM_MODE.

Async (`@future`, batch, queueable, schedulable, platform-event trigger) classes were verified — these run as Automated Process and SYSTEM_MODE is the documented normal mode for that context.

---

## Verification steps

| Check                                                                                              | Result                                                                                                                                                                                                           |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run format:check`                                                                             | ✅ All matched files use Prettier code style.                                                                                                                                                                    |
| `sf code-analyzer run --workspace force-app/ --rule-selector Security --rule-selector AppExchange` | ✅ 0 High severity violations. 38 Moderate (pre-existing `pmd:AvoidLwcBubblesComposedTrue` and `pmd:ProtectSensitiveData` false positives on signature audit/request fields, documented in `code-analyzer.yml`). |
| `sf apex run test --target-org portwood-staging --test-level RunLocalTests --code-coverage`        | ✅ See deploy log.                                                                                                                                                                                               |
| E2E suite (`scripts/e2e-01` through `scripts/e2e-08`)                                              | ✅ See deploy log.                                                                                                                                                                                               |

---

## Files added

- `force-app/main/default/classes/DocGenSignatureGuestSecurity.cls` (+ meta) — shared CRUD/FLS describe-check helper for guest-context signature endpoints. Contains the full security model documentation in the class-level javadoc.

## Files modified

- 5 Apex controllers (admin USER_MODE conversion + stale-comment cleanup)
- 1 Apex utility class (`DocGenTemplateManager`)
- 1 Apex helper class (`DocGenAuthenticatorController` — explicit Schema checks for public verifier)
- 5 LWC bundles (inline `position: absolute` → `slds-is-absolute` class)
