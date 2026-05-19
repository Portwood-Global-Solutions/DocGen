# Issue #105 — fresh-uploaded CV repro

End-to-end repro for the known [#105](https://github.com/Portwood-Global-Solutions/DocGen/issues/105) platform issue: a `ContentVersion` uploaded inside the same transaction that triggers a PDF render fails Flying Saucer's HTTP `<img src="/sfc/servlet.shepherd/version/download/...">` fetch, even when the `ContentDocumentLink` state is byte-identical to a CV uploaded ~30s earlier.

Symptom in a rendered PDF: a 48×48 broken-image placeholder where the real logo should be.

## How to run

```
scripts/issue-105-fresh-cv-repro/run.sh [target-org-alias] [path-to-source-docx]
# defaults: portwood-staging, Triage Docs/TEST (3).docx
```

The orchestrator splits the work across the production-style queueable boundary so the timing matches what customer orgs actually experience:

1. **`stage1-setup.apex`** — uploads the source DOCX, creates the template + version, enqueues the pre-decomposition queueable, then commits and exits. The queueable runs in a separate transaction, giving Salesforce's shepherd servlet time to publish the extracted image CVs across the cross-domain boundary Flying Saucer fetches from.
2. **Poll** — `run.sh` watches `Pre_Decomposition_Status__c = 'Complete'` on the version (up to 180s).
3. **Settle** — sleep an additional 30s (`SHEPHERD_SETTLE_S`) so shepherd finishes publishing the image CVs cross-domain. Calling stage 2 too soon is what reproduces the bug.
4. **`stage2-render.apex`** — runs the actual render via `generatePdfBlobFromData`, saves PDF + intermediate HTML.
5. **`stage3-rerender.apex`** — re-render against the _existing_ TEST3 template (no upload, no extraction, no version churn). If the broken logo is a fresh-CV timing issue, this run should render cleanly because the CVs have been committed long enough.
6. **Verify** — `run.sh` inspects the embedded image dimensions with `pdfimages`; 48×48 = still broken, anything else = real image rendered.

## What the scripts prove

Even with the queueable boundary AND a 30s settle, fresh-uploaded image CVs can still hit the broken-image path under load. `stage3-rerender.apex` (running against the _same_ template after the CVs have aged) renders cleanly — confirming the failure mode is CV freshness, not template content or template configuration.

## Why we keep these in tree

Diagnosing #105 took empirical iteration on the queueable timing, shepherd settle window, and Title-vs-Id download collisions. Future-us re-deriving the repro from scratch would be a waste; keep these as the canonical reproduction so any platform-side fix can be verified against a known-bad starting state.

See also: `memory/project_72_automated_process_soql_limit.md` and `memory/project_fresh_cv_fetch_fragility.md` for the wider context behind this and the (now-deprecated) Experience Cloud guest path.
