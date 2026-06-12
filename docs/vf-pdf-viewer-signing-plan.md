# VF PDF-Viewer Signing — Implementation Plan & Agent Runbook

> **Branch:** `feat/vf-pdf-viewer` (off tag `v3.08.0`)
> **Milestone 1 goal:** A new guest signing page that renders the **real generated PDF** and captures a guided, modal-based signature (name + consent → audit + `Status='Signed'`). No in-document stamping/positioning yet.
> **How to use this doc:** Each task has a checkbox. Work top-to-bottom within a workstream; respect the cross-workstream dependencies in §6. Tick boxes as you go and leave a one-line note on anything you changed from this plan.

---

## 1. Context — why we're building this

The current signing page (`DocGenSignature.page`) never shows a real PDF: it renders a lossy DOCX→HTML snapshot (`fetchDocumentData` → `templateBase64`) and stamps signatures into **DOCX XML** (`DocGenSignatureService.stampSignaturesInXml`). We want a different flow:

1. **Generate a real document first** (existing `DocGenFlowAction.generateDocument`) → get `ContentDocumentId` + `ContentVersionId`.
2. **Send that already-generated file** for signature via a **new "send existing ContentVersion" entry point** that stores the CV id on the envelope.
3. **Render the actual PDF** to the signer in a new VF page.
4. Guide signing in a **button-launched modal** instead of inline. Templates carry **no `{@Signature_...}` tags** for now (positioning is a later milestone).

## 2. Locked design decisions

| #   | Decision          | Choice                                                                                                                             |
| --- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Signed output     | **Append a certificate/audit page** to the original PDF (pages otherwise untouched). **Deferred to Milestone 2.**                  |
| 2   | Wiring            | **Two-step.** Generate → then a **new** "send existing CV" entry point creates the envelope with `Source_Document_Id__c = <cvId>`. |
| 3   | Milestone 1 scope | **Skeleton:** render real PDF + modal capture (name/consent) → audit + `Status='Signed'`. No stamping/positioning.                 |
| 4   | Render tech       | **Hybrid** — native `<iframe>` blob render now, behind a thin **swappable viewer module** so PDF.js drops in later untouched.      |

## 3. Key facts that ground the design (read before coding)

- **Envelope already supports this.** `DocGen_Signature_Request__c.Source_Document_Id__c` (Text 18) holds a `ContentVersion.Id` of a pre-generated doc; it's the path used when `Template__c` is null. **No new field needed.**
- **Guest PDF serving has a proven pattern.** Guests can't hit file URLs; the page already serves images as base64 via token-gated `@RemoteAction` (`getImageBase64`, ~`DocGenSignatureController.cls:1939`) with IDOR protection (`isAuthorizedSignatureImage`) that **already allowlists the request's `Source_Document_Id__c`**.
- **No-tags is safe.** With `Template__c` null / no tags, `createPlacementsForSigners` early-returns (no placements); the page tolerates zero placements. Nothing breaks.
- **Do NOT reuse `saveSignature` for the PDF path.** It publishes `DocGen_Signature_PDF__e`, which kicks the **DOCX-XML** stamping queueable — wrong for a flat PDF. Milestone 1 uses a dedicated save that records audit + status only.
- **Reuse the security plumbing.** `validateToken`, `DocGenSignatureGuestSecurity.assertSignerReadable`, `DocGenFlsGuard.guestAssert*`, `WITH SYSTEM_MODE`, the IDOR allowlist. This is an AppExchange-reviewed package — match existing patterns exactly.

## 4. Files

**Create**

- `force-app/main/default/pages/DocGenSignaturePdf.page` (+ `.page-meta.xml`, apiVersion 66.0)
- `force-app/main/default/classes/DocGenSignaturePdfFlowAction.cls` (+ meta) — `global` invocable wrapper

**Modify**

- `force-app/main/default/classes/DocGenSignatureController.cls` — add 2 remote actions
- `force-app/main/default/classes/DocGenSignatureSenderController.cls` — add `createRequestFromContentVersion`

**Config (org, may be UI not source)**

- Site enabled-pages + path alias (e.g. `/signaturepdf`); guest profile / permission set VF access

---

## 5. Task checklist

### Workstream A — Apex backend (controller + sender + invocable)

- [ ] **A1.** `DocGenSignatureController.getSourcePdfBase64(String token)` — `@AuraEnabled @RemoteAction`. Validate token via existing path; resolve signer→request; read `ContentVersion.VersionData` for the request's `Source_Document_Id__c` **only** (no CV param → no IDOR surface); return `{ base64, fileName, mimeType:'application/pdf' }`. Use `DocGenSignatureGuestSecurity.assertSignerReadable` + `DocGenFlsGuard.guestAssertAccessible(ContentVersion, {'VersionData','Title'})` + `WITH SYSTEM_MODE`.
- [ ] **A2.** `DocGenSignatureController.savePdfSignature(String token, String typedName, Boolean consentGiven, String ip, String ua)` — `@AuraEnabled @RemoteAction`. Validate token; insert `DocGen_Signature_Audit__c` (reuse the audit-insert block from `saveSignature` ~`:951`); set signer `Status='Signed'` + `Consent_Captured__c`; if all signers signed, set request `Status='Signed'`. **No platform event, no stamping.** Return `{ success, isComplete, remaining }`.
- [ ] **A3.** `DocGenSignatureSenderController.createRequestFromContentVersion(Id contentVersionId, String relatedRecordId, String signersJson, String signingOrder, String documentTitleFormat)` — `@AuraEnabled`. Insert `DocGen_Signature_Request__c` (`Source_Document_Id__c=contentVersionId`, `Template__c=null`, `Status='Sent'`, related record, signing order, title format) SYSTEM_MODE; call existing `createSignersAndNotify(...)`; build signer URLs to the **new page path** (see C-config), not `/signature`.
- [ ] **A4.** `DocGenSignaturePdfFlowAction.cls` — `global` class, `@InvocableMethod` label **"DocGen: Send Existing Document for Signature"**, wrapping A3. Inputs: ContentVersion Id, Related Record Id, `List<DocGenSigner>` (reuse existing Apex-Defined type), signing order. Outputs: request Id, signer URLs, success/error. Remember: **`global` + `@InvocableMethod`** for subscriber visibility.
- [ ] **A5.** Confirm `createSignersAndNotify` / `createPlacementsForSigners` behave correctly with `Template__c=null` (placements skip cleanly). Add a guard/comment if needed.

### Workstream B — Visualforce page + JS (viewer + modal UX)

- [ ] **B1.** Scaffold `DocGenSignaturePdf.page` from `DocGenSignature.page`: keep token read, IP capture (`~:944-957`), and the show/hide state machine; **remove** the HTML-snapshot preview and the guided/legacy full-screen states. `controller="DocGenSignatureController"`.
- [ ] **B2.** **Viewer abstraction** — single JS module `DocGenPdfViewer.render(base64, containerEl)`. Impl A (now): base64 → `Uint8Array` → `Blob([bytes],{type:'application/pdf'})` → `URL.createObjectURL` → `<iframe>` src. **This module is the only place that knows the render engine.** Document the contract in a header comment so the PDF.js swap is mechanical.
- [ ] **B3.** On load: `validateToken` → if `requiresPin`, reuse existing `sendPin`/`verifyPin` flow; then call `getSourcePdfBase64` → `DocGenPdfViewer.render(...)`.
- [ ] **B4.** Main layout: PDF viewer area + a prominent **"Sign" button**.
- [ ] **B5.** **Signing modal** (SLDS modal markup): confirm name (prefill `signerName`), consent checkbox (required), **Sign** button disabled until consent checked. On submit → capture IP → `savePdfSignature` → success state (and `waiting` state if `isComplete=false` for multi-signer).
- [ ] **B6.** Error/declined/expired states reuse existing copy/markup patterns.

### Workstream C — Config & deploy enablement

- [~] **C1.** URL builder DONE in source (`DocGenSignatureSenderController.getSigningPdfPagePath()` → `/apex/[ns__]DocGenSignaturePdf`, wired into `createRequestFromContentVersion`). **ORG-UI-ONLY, NOT in source / NOT done:** registering the page on the Site's Enabled Visualforce Pages + setting a path alias must be done in Setup → Sites (or by adding the page to the Site's `.site-meta.xml` — note: there is **no `sites/` or `network/` metadata in this repo at all**, so this is entirely manual org config on `portwood-staging`). Note: the URL builder emits `/apex/DocGenSignaturePdf`, NOT the `/signaturepdf` alias from the plan — if you want the friendly alias the builder must change OR rely on the raw `/apex/` path (which works without an alias).
- [x] **C2.** DONE in source: added `DocGenSignaturePdf` to `pageAccesses` in `force-app/main/default/permissionsets/DocGen_Guest_Signature.permissionset-meta.xml`. Deploys with the package; assign that permset to the Site guest user (org step) and guest VF access is granted.
- [ ] **C3.** **ORG-UI-ONLY, NOT verified here:** Site CSP / Trusted URLs for the blob iframe. No `cspTrustedSites/` metadata in this repo. For M1 the render uses `URL.createObjectURL` (a `blob:` same-origin URL in a same-origin `<iframe>`), which is generally allowed by default Salesforce Site CSP — but this MUST be confirmed on `portwood-staging` during the C6/D6 manual walkthrough. It will definitely matter when the PDF.js worker (separate script/worker origin) arrives in M3.

### Workstream D — Tests & validation

- [x] **D1.** DONE: `DocGenSignaturePdfTests.testGetSourcePdf_success / _invalidTokenShape / _foreignTokenServesOnlyOwnDoc / _expiredToken`. IDOR test asserts the foreign token resolves ONLY its own bound doc (server resolves CV from the token's request — no client CV id), and the expired-token test backdates `CreatedDate` past the 48h window. Delivered by Workstream A.
- [x] **D2.** DONE: `testSavePdfSignature_success` (audit row + signer `Signed` + request `Signed`, no `Document_Hash_SHA256__c`) and `testSavePdfSignature_noStampingEvent` (asserts `Limits.getAsyncCalls() == 0` — proves no `DocGen_Signature_PDF__e` publish / no stamping queueable).
- [x] **D3.** DONE: `testCreateRequestFromContentVersion` asserts `Template__c == null`, `Source_Document_Id__c == cv.Id`, `Status == 'Sent'`, a 64-char token issued, and the signer URL targets `DocGenSignaturePdf`.
- [x] **D4.** DONE: added "Send Existing ContentVersion" block to `scripts/e2e-06-signatures.apex` — `createRequestFromContentVersion` → asserts PDF-page signer URL + Template-null request + `getSourcePdfBase64` round-trips the bound bytes; cleans up after itself. File is 17,957 chars (< 18,000 limit). prettier-clean.
- [~] **D5.** Release gate — **CANNOT be fully run in QA's current environment; MUST be run on `portwood-staging` before merge.** Status per check: (a) `npm run format:check` — **PASS, clean** (prettier installed via `npm install`; ran `npm run format`). (b) `e2e-06` + `RunLocalTests` — **NOT RUN**: no authenticated org has the DocGen package — `docgen-test` returns `Invalid type: Schema.DocGen_Signer__c` even on untouched lines (confirmed); no `portwood-staging` org is authenticated here. (c) `sf code-analyzer` Security+AppExchange — **NOT RUN**: no Java runtime installed (`spawn java ENOENT`) so PMD/CPD/sfge engines can't start; only the Java-free regex/retire-js engines ran → 0 violations on the 4 new files, but that does NOT cover the PMD Security rules or the sfge AppExchange data-flow rules. Also the installed plugin (5.2.2) predates the `rules.*.disabled` schema in `code-analyzer.yml` (needs ≥5.13.0). **Gate is NOT green — do not merge on this run.**
- [ ] **D6.** Manual guest walkthrough on staging (see §7) — blocked on C1 org config + a staging deploy.

### Workstream E — Security review (gate before merge)

- [ ] **E1.** Audit both new remote actions for guest/IDOR: token format check, token→CV binding, no CV id accepted from the client, FLS guards present, SYSTEM_MODE justified inline.
- [ ] **E2.** Confirm no new `WITH USER_MODE` gaps and no `VersionData` leak beyond the authorized source doc.
- [ ] **E3.** Sign off that the new invocable is `global` and exposes no sensitive internals.

---

## 6. Sequencing & dependencies

```
A3 ─┬─> A4            (invocable wraps creation)
A1,A2 ──> B3,B5       (page calls the remote actions)
B2 ──> B3             (viewer before wiring render)
C1 ──> A3 URL builder + D6
A* + B* ──> D1..D4 ──> D5 ──> E1..E3 ──> merge
```

- Backend (A1–A3) and the viewer module (B2) can start **in parallel** day one.
- Page wiring (B3–B6) needs A1/A2 signatures finalized.
- Config (C1) unblocks the URL builder and end-to-end test.
- Security (E) is the final gate; D5 must be green first.

## 7. End-to-end verification (manual)

1. Deploy to the `--no-namespace` staging org; assign `DocGen_Admin`; enable the new page on the Site + guest access (C1/C2).
2. Generate a PDF via `DocGenFlowAction.generateDocument` → capture `contentVersionId`.
3. Call `createRequestFromContentVersion(cvId, recordId, signersJson, 'Parallel', null)` → get a signer URL.
4. Open `/signaturepdf?token=...` as a guest → **the real PDF renders** in the iframe.
5. Click **Sign** → complete the modal (name + consent) → submit → confirm `DocGen_Signature_Audit__c` created, signer + request `Status='Signed'`, and **no** stamping/PDF event fired.

## 8. Out of scope (later milestones)

- **M2 — Signed-output certificate page:** append an audit page (name, timestamp, IP, consent, SHA-256) to the PDF.
- **M3 — Sign-spot positioning:** visible in-page anchors + coordinate capture. **This is the trigger to swap the viewer module's internals from native iframe to PDF.js** (also fixes mobile-inline rendering).

---

## 9. Open risks / watch-list

- **iOS Safari** may not render a blob PDF inline in an iframe — acceptable for M1 (desktop-first), resolved by the PDF.js swap in M3.
- **Site/guest config** is the fiddly part and may be UI-only — budget time, don't assume it's pure source.
- **Managed-package visibility** — new subscriber-facing Apex must be `global`; verify in a real subscriber/scratch, not just the no-namespace staging org.
