# Document Markup — M2 remainder: agent-team work plan

> Branch: `exp/document-markup`. M2-1 (markup interaction layer) + the per-template
> `Allow_Markup__c` toggle are **already built, deployed to `docgen-test`, and compile clean**.
> This plan breaks the REMAINDER of M2 into agent-sized chunks. **Review before spinning up agents.**

## What already exists (do not rebuild — call into it)

In `force-app/main/default/pages/DocGenSignaturePdf.page`:

- **`MarkupLayer`** (IIFE) — per-page overlay capture. API: `init(viewerPages)`, `setActive(on)`, `setTool(t)`, `setColor(c)`, `undo()`, `clear()`, `hasMarks()`, **`pageImage(pageIndex)` → transparent PNG dataURL of that page's marks (or null)**, `palette()`.
- **`DocGenPdfViewer.getPages()`** → `[{ pageIndex, pageNum, wrapEl, cssW, cssH, scale, widthPts, heightPts }]` (PDF points per page = the flatten target size).
- **`markupAllowed`** (JS var) — set from `validateToken` response `allowMarkup` (per-template toggle).
- **`markupMode`**, `enterMarkup()`, `exitMarkup()`, `initMarkupLayer()` — mode plumbing; button wired.
- Existing helpers reused by the flatten work: **`sourcePdfBase64`** (served source PDF), **`b64ToBytes` / `bytesToB64`**, **`compositeAndFinalize(...)`** (approve path → `saveCompositedSignedPdf`), **`handleDecline()`** (→ `declineSignature` RemoteAction), `PDFLib` global.

Backend already shipped: `DocGenSignatureController.validateToken` returns `allowMarkup`; `saveCompositedSignedPdf` (approve) and `declineSignature` (reject) RemoteActions exist.

## The shared seam (built in Chunk A, consumed by C & D)

One JS function both the approve and reject paths call:

```
// markupFlattenMode: 'raster' (v1) | 'vector' (future). Returns a Promise.
function flattenMarkupInto(doc /* PDFLib doc */, pdfLibPages /* doc.getPages() */) { ... }
```

- For each `DocGenPdfViewer.getPages()` entry where `MarkupLayer.pageImage(pageIndex)` is non-null:
  raster → `doc.embedPng(pngBytes)` then `pdfLibPages[pageIndex].drawImage(png, {x:0, y:0, width: widthPts, height: heightPts})` (full-bleed; PNG is transparent so it overlays cleanly).
- `markupFlattenMode === 'vector'` → **stub**: `console.warn` + fall back to the raster branch until vector is implemented.
- Module var `var markupFlattenMode = 'raster';` declared alongside `markupAllowed`.

---

## Chunks

### Chunk A — Frontend: raster flatten + approve path · agent: `docgen-vf-frontend`

File: `pages/DocGenSignaturePdf.page` only.

1. Add `var markupFlattenMode = 'raster';` next to `markupAllowed`.
2. Implement `flattenMarkupInto(doc, pdfLibPages)` per the seam above (raster + vector stub).
3. In `compositeAndFinalize`, after `doc.getPages()` + font embed and **before** the signature-spot
   draw loop, chain `flattenMarkupInto(doc, pages)` when `markupAllowed && MarkupLayer.hasMarks()`
   (so signatures render on top of markup). `embedPng` is async — fold into the existing promise chain.
   **Acceptance:** approving with marks → composited PDF (saved by existing `saveCompositedSignedPdf`)
   shows markup beneath the signature; **no-markup path is byte-for-byte unchanged**.

### Chunk B — Backend: `saveMarkupDocument` · agent: `docgen-apex-backend`

File: `classes/DocGenSignatureController.cls`.

- Add `@AuraEnabled @RemoteAction public static SavePdfSignatureResult saveMarkupDocument(String token, String base64Pdf, String ipAddress, String userAgent)`.
- Mirror `saveCompositedSignedPdf` security exactly: 64-hex token check; `DocGenSignatureGuestSecurity.assertSignerWritableFields(token)` + `assertAuditCreateable(token)`; resolve signer→request→`Related_Record_Id__c` + template name via the SAME `WITH SYSTEM_MODE` token-bound query (record id comes from the token, **never** from the client); expiry check.
- Insert `ContentVersion` (Title `<templateName> - Markup`, `VersionData = base64Decode`, `FirstPublishLocationId = Related_Record_Id__c`) + `ContentDocumentLink` to the related record (ShareType `V`) — mirror how `saveCompositedSignedPdf` lands the final doc on the record. Create a `DocGen_Signature_Audit__c` row (hash the bytes into `Document_Hash_SHA256__c`).
- **Do NOT** set signer `Status='Signed'`, set request status, or publish any platform event.
- Return `SavePdfSignatureResult{ success = true }`.
  **Acceptance:** a valid guest token saves the PDF to its OWN related record + audit, with signer/request status untouched; a foreign token can only ever reach its own bound record (IDOR-safe).

### Chunk C — Frontend: reject-with-markup wire · agent: `docgen-vf-frontend` · depends A + B

File: `pages/DocGenSignaturePdf.page`.

- In `handleDecline`: when `markupAllowed && MarkupLayer.hasMarks()`, load `sourcePdfBase64` into pdf-lib, `await flattenMarkupInto(doc, doc.getPages())`, `doc.save()` → `bytesToB64`, invoke `saveMarkupDocument(token, b64, ip, ua)`; then proceed to the existing `declineSignature` call. Show progress; if the markup save fails, surface a warning but still allow the decline to complete.
  **Acceptance:** rejecting with marks → marked-up PDF on the record AND signer `Declined` + reason; rejecting without marks → unchanged.

### Chunk D — Vector-flatten org-setting seam · agent: `docgen-apex-backend` (+ 2-line frontend) · depends A

- Field `DocGen_Settings__c.Markup_Vector_Flatten__c` (Checkbox, default false) + permset reads (Admin/User edit, Guest read), mirroring an existing `DocGen_Settings__c` field.
- Read the setting where DocGen settings are already read; add `markupVectorFlatten` (Boolean) to `SignatureInitResponse`; set it in `validateSignerToken`.
- Frontend (2 lines): in the `validateToken` callback set `markupFlattenMode = result.markupVectorFlatten ? 'vector' : 'raster';`.
  **Acceptance:** setting flows to the page; flatten stays raster (vector still stubbed). Pure seam — lowest priority, can ship last.

### Chunk E — Tests + deploy + smoke · agent: `docgen-qa-release` · depends A,B,C,D

- Apex tests in `DocGenSignaturePdfTests.cls` for `saveMarkupDocument`: happy path (CV linked to related record + audit row; signer NOT Signed; request NOT Signed); invalid token; expired token; **IDOR** (foreign token saves only to its own bound record).
- prettier; deploy all M2 to `docgen-test`; run `DocGenSignaturePdfTests` + `RunLocalTests` (100% / ≥75%).
- Document the manual front-end walkthrough (Apex can't unit-test pdf-lib): mint token → draw → approve → confirm marked-up + signed PDF on the record; draw → reject → confirm marked-up PDF on the record.

### Chunk F — Security review (merge gate) · agent: `docgen-security-reviewer` · depends B

- Read-only audit of `saveMarkupDocument`: token format + binding; record id resolved server-side only; FLS guards present; `SYSTEM_MODE` justified inline; no `VersionData`/foreign-doc leak; `base64Pdf` size/DoS consideration; ContentDocumentLink visibility correct. Produces findings; does not edit.

---

## Sequencing & conflict control

`DocGenSignaturePdf.page` is a single large file edited by A, C, and D-frontend → **one frontend
agent owns it serially** to avoid conflicts.

- **Wave 1 (parallel):** A (frontend) ‖ B (backend).
- **Wave 2:** same frontend agent does C, then D's 2-line frontend bit; `docgen-apex-backend` does D's field/controller/permset (parallel with the frontend, different files).
- **Wave 3:** E (QA, after all) ‖ F (security, after B).

Net: **2 builder agents** (1 frontend serial: A→C→D-fe; 1 backend: B + D-be) + **QA** + **security**.

## Out of scope for M2 (note, don't build)

- Implementing the actual vector flatten (D only builds the seam/switch).
- Editing/moving marks after placement (capture model supports undo/clear only in v1).
- Mobile-Safari inline-PDF edge cases (desktop-first, as elsewhere).
