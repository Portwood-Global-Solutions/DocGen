# Certificate of Completion — Unification Plan & Spec

> **Status:** Proposal / not started. Research-only writeup — no code changed.
> **Problem in one line:** There are two different Certificate of Completion renderers that emit _different_ certificates, and neither one carries the full set of what a completion cert should carry.
> **Goal:** One canonical certificate — same fields, same legal attestation, same verification pointer — regardless of which signing path produced it.

---

## 1. Context — why we're doing this

DocGen produces the completion certificate in **two independent places**, using **two different rendering engines**, and they have drifted apart:

|                         | Renderer                          | Where                                                                                             | Title                              | ESIGN/UETA line      | Verify link              |
| ----------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------- | -------------------- | ------------------------ |
| **Typed / server path** | HTML → `Blob.toPdf`               | `DocGenSignatureService.buildVerificationBlockHtml` (footer `DocGenSignatureService.cls:364-386`) | "ELECTRONIC SIGNATURE CERTIFICATE" | ❌ absent            | ✅ present (conditional) |
| **Drawn / guided path** | pdf-lib `drawText` in the browser | `DocGenSignaturePdf.page` `addCertificatePage` (`:1922-2044`)                                     | "Certificate of Completion"        | ✅ present (`:2038`) | ❌ absent                |

So the same product emits two visually and substantively different certificates, and **neither cert has both** the ESIGN/UETA attestation and a verification pointer. This is a credibility problem in exactly the high-stakes "hand it to opposing counsel" scenario the platform is being evaluated for.

Secondary defect: **`UserGuide.md:2442` claims the guided-path cert includes "a link to the verify page." It does not** — the code doesn't draw one. Doc-vs-code discrepancy to close as part of this work.

## 2. The one hard decision — hash semantics ("you can't hash a file from inside itself")

The two paths diverged for a real reason, not by accident: **the moment you print a hash of the PDF onto a page inside that PDF, the file's bytes change and the printed value is stale for the delivered file.** The current behavior reflects this:

- **Drawn path** prints the SHA-256 of the content **before** the cert page is appended (`DocGenSignaturePdf.page:2387-2389`). Honest, but it is _not_ the hash of the delivered file.
- **Stored / authoritative hash** is `DocGen_Signature_Audit__c.Document_Hash_SHA256__c`, recomputed server-side over the **final** bytes including the cert page (`DocGenSignatureController.cls:2719`). This is the value the verify endpoint checks (`DocGenAuthenticatorController.verifyDocument` → lookup on `Document_Hash_SHA256__c`, `:69`).
- Net: **the number printed on the cert ≠ the number that actually verifies.** A recipient who hashes the delivered PDF and compares to the printed number will get a false mismatch.

There is no way to make a page inside a PDF print the whole file's own hash. So unification **must pick one integrity contract**. Three options:

| Option                                                               | What the cert says                                                                            | Verify story                                                                           | Tradeoff                                                                                                                        |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **A. Document-content hash** (recommended)                           | prints the hash of the signed agreement content (bytes before the cert page), labeled as such | verify page checks that **same** document-content hash — printed == stored == verified | one byte range everywhere; mirrors DocuSign/Adobe (attest the document, not the wrapper)                                        |
| **B. No inline verifiable hash; external stored hash authoritative** | prints roster + ESIGN/UETA + verify link only                                                 | recipient uses the verify link; stored hash is source of truth                         | self-consistent but hides the hash from the page — weaker than A for no real gain                                               |
| **C. Print the final-file hash on the cert**                         | prints the whole-file hash                                                                    | self-contained                                                                         | **not achievable** without fixing/excluding the cert page's bytes from the hash range across two renderers — fiddly and fragile |

**Recommendation: Option A — standardize everything on the document-content hash** (the bytes of the signed agreement, before the certificate page is appended). This is both the most maintainable and the most widely accepted choice:

- **Most maintainable:** one hash, one byte range, computed once, used for all three purposes (printed on the cert, stored in the audit record, checked by the verify page). The current defect is precisely that two byte ranges exist and drift; collapsing to one removes the whole class of mismatch.
- **Most widely accepted:** DocuSign and Adobe Sign attest the hash of the _document_, not the document-plus-certificate bundle. The certificate is _about_ the agreement; it isn't part of what's hashed. This is also the legally meaningful question ("did the agreement change"), and it sidesteps the self-reference paradox entirely.

This supersedes an earlier draft that recommended Option B. A is strictly better: the printed hash _becomes_ the authoritative one because it is the same value everywhere, so the cert can safely show it **and** link to the verify page that confirms it.

**End-state on every completed document:** the PDF ends with one Certificate of Completion page containing the signer roster + ESIGN/UETA attestation + the document-content hash + a link to the verify page. The recipient clicks the link → the verify page recomputes/looks up that same document-content hash → shows "matches, signed by X on Y." Printed hash and verified hash are identical by construction.

> Honest ceiling: the most widely accepted _tamper-evidence_ in this category is a cryptographic seal on the file itself (PAdES/PKI), which DocGen can't apply (no PKI in Apex/pdf-lib). The stored-hash + verify-portal model is the legitimate substitute smaller vendors use — the certificate is the readable audit, the portal is the integrity check.

## 3. Locked design decisions (proposed)

| #   | Decision               | Choice                                                                                                                                                                                                                                                          |
| --- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Single source of truth | **One canonical cert generator, server-side, after finalize.** Both paths route through it.                                                                                                                                                                     |
| 2   | Where                  | Server side — the drawn path already posts final bytes back to `saveCompositedSignedPdf` (`DocGenSignatureController.cls:2609`), so the server already holds the final PDF for both paths. Natural single home.                                                 |
| 3   | Integrity contract     | **Option A** (see §2). One value — the **document-content hash** (bytes before the cert page) — is printed on the cert, stored in the audit record, and checked by the verify page. Printed == stored == verified. Label it "hash of signed agreement content." |
| 4   | Legal attestation      | **Always** include the ESIGN/UETA sentence (currently drawn-path only).                                                                                                                                                                                         |
| 5   | Verification pointer   | **Always** include the verify pointer when a public Site URL is configured; degrade gracefully (omit link, keep instructions) when it isn't.                                                                                                                    |
| 6   | Canonical field set    | Title, Document title, Request ID, Completed timestamp, per-signer {name, role, email, signed timestamp, email-verified Y/N, IP, consent, device}, form-field responses, ESIGN/UETA attestation, verify pointer, labeled content hash.                          |

## 4. Open questions to resolve before building

- **Renderer convergence.** §3 routes both through one _content spec_, but the two engines (HTML→`Blob.toPdf` vs pdf-lib) still render differently. Decide: (a) one canonical renderer for the cert page for both paths, or (b) shared content model + two renderers held to a golden-file test. (a) is cleaner long-term; (b) is less churn now.
- **Verify page target.** The typed path links to the **token-based** `DocGenVerify` page (shows signer audit). The **hash-based** `verifyDocument` endpoint is a separate mechanism. Decide which the canonical cert points at (or both: "verify this document" via hash, "view signing record" via token).
- **AppExchange review.** This is a security-reviewed managed package. Any change to guest-facing cert/verify output should match existing security patterns and likely needs a re-review pass.

## 5. Acceptance criteria

- [ ] A cert produced via the typed path and a cert produced via the drawn path contain the **same field set, same section order, same ESIGN/UETA attestation, same verify pointer**.
- [ ] The document-content hash printed on the cert is the **same value** stored in the audit record and checked by the verify page (printed == stored == verified); it is labeled "hash of signed agreement content."
- [ ] From the delivered PDF, a recipient can reach the verify page via the on-cert link and see the document-content hash confirmed ("matches, signed by X on Y").
- [ ] `UserGuide.md:2442` matches actual behavior (either the link now exists, or the doc is corrected).
- [ ] No regression in guest security (token gating, FLS guards, `WITH SYSTEM_MODE`, IDOR allowlist).

## 6. Files likely in scope (for later — not touched yet)

- `force-app/main/default/classes/DocGenSignatureService.cls` — `buildVerificationBlockHtml` (typed-path cert)
- `force-app/main/default/pages/DocGenSignaturePdf.page` — `addCertificatePage` (drawn-path cert)
- `force-app/main/default/classes/DocGenSignatureController.cls` — `saveCompositedSignedPdf`, final-hash recompute
- `force-app/main/default/classes/DocGenAuthenticatorController.cls` — `verifyDocument` (hash lookup)
- `docs/UserGuide.md` — §2442 verify-link claim
