# CLAUDE.md — SalesforceDocGen

## Triage

See `TRIAGE.md` at the repo root for the priority rubric (P0/P1/P2/P3 + severity labels + milestone scheme). Apply it when classifying new issues or proposing what to work on next. Current milestones live on GitHub: `v1.89.0` (in flight — Template_Version Type picklist fix + CSS 2.1 guidance + #60/#72), `v1.90.0`, `Backlog`.

## Mission

Maintain Portwood DocGen — a native Salesforce 2GP package for generating Word and PDF documents from any Salesforce record. Work is roadmap-driven via the GitHub issue board; treat it as the source of truth for what's in flight.

When picking up work, prefer the highest open priority on the smallest milestone. P0 silent-corruption bugs jump the queue. Community-contributed fixes (the `community-contribution` label) are usually fast wins because the reporter has already done the diagnostic work.

## Critical: three merge-tag resolution paths

`DocGenGiantQueryAssembler` does **not** call `processXml()`. A fix to section-tag logic in `processXml` only covers row-level loop bodies. Parent-level tags outside the loop are resolved by `DocGenGiantQueryAssembler.resolveParentMergeTags()`, and grand-total aggregates by `resolveGiantAggregateTags()`. If a parser-level change needs to behave consistently for templates that fall into the giant-query path (>2000 child rows), the logic has to be mirrored in the assembler or routed through `processXmlForTest` the same way format-suffix tags already are. Always check whether your fix needs the same change in the giant-query parent path and add an e2e-07 assertion either way.

## Critical: {#ChartBucket} tag (v1.91+) — 4 resolution paths, 5 modifiers

`{#ChartBucket:relationship:field[:modifier1=value1&modifier2=value2&...]}body{/ChartBucket}` aggregates a child collection by `field`, exposing per-bucket data (`{key}`, `{count}`, `{percent}`, `{max_percent}`, `{color}`, `{index}`, `{key_label}`) inside the body. The bucket list is sorted desc by count, alpha by key for ties.

**Five modifiers** (composable; v1.91 surface):

| Modifier                                | Behavior                                                                                                                                                              |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `colors=#aaa,#bbb,#ccc`                 | Override default 8-color palette, cycles by row index                                                                                                                 |
| `where=Field='Value' AND Other != null` | Sanitized SOQL fragment appended to chart's WHERE. Forces SOQL fallback.                                                                                              |
| `split=;`                               | Multi-select delimiter. Splits combo values per respondent, percentages sum >100% expected.                                                                           |
| `groupBy=Field__c`                      | Cross-tab pivot. Each row gets `cols` sub-list with `{#cols}{key}{count}{percent}{/cols}` body iteration. Synthetic Total column appended last. Forces SOQL fallback. |
| `colSort=val1,val2,...`                 | Author-controlled column ordering (for `groupBy=`). Named values appear first in order; remaining values alpha-sorted; Total always last.                             |

**Four resolution paths** (chart resolver mirrors what merge-tags already do — all four must stay consistent):

1. **In-memory** — `DocGenChartBucketResolver.preprocessInline` against pre-loaded relationship records. Used when child count <2000 AND no `where=`/`groupBy=`. Single SOQL-free path, fastest.
2. **SOQL fallback** — `tryFallbackSoqlAggregateAdvanced` when relationship isn't on the data map OR `where=`/`groupBy=` force it. Schema-auto-discovers child object + FK via `ChildRelationship`. Issues a `GROUP BY` aggregate, constant-cost regardless of row count. **This is how 30K-scale templates work** — Query_Config\_\_c omits the chart-target relationship, retriever doesn't eager-load, chart aggregates server-side.
3. **Parent-level** — `DocGenGiantQueryAssembler.resolveParentMergeTags()` regex skips `{#…}` prefixes, so charts pass through. Then `processXmlForTest` routes through the inline path.
4. **Giant-query parent** — `DocGenGiantQueryAssembler.resolveGiantChartBuckets` for charts targeting the giant relationship in giant-query templates. Same modifiers, same shape.

**SOQL budget**: 50 chart aggregates per transaction (static `DocGenChartBucketResolver.chartSoqlBudget`). When exhausted, charts render a sentinel "Chart limit reached" bucket — never silently empty. Tune in resolver if templates pathologically stack >50 charts.

**Layout gotcha for `groupBy=` pivot**: HTML container auto-expansion at `DocGenService.processXml:2708` looks for the nearest open `<tr>` when processing nested `{#…}` loops — placing `{#cols}` directly inside `<tr>` causes each col to duplicate the whole row. Use `<div class="row">` + `display: table-row` instead (CSS 2.1 safe in Flying Saucer). See `docs/CommuteSurveyExample.html` for the canonical pattern.

**Reference templates**:

- `docs/SurveyChartExample.html` — single-dimension chart per question + cross-tab spread (rich pivot + vertical clustered bars + stacked composition) using Department dimension. Canonical chart template.
- `docs/CommuteSurveyExample.html` — pivot + filter + multi-select + colSort all composed
- `docs/SurveyChartExample.docx` — Word-authored variant. Supports simple bars only; pivot/stacked/vertical-clustered styles require `<div>` table-cell layout which Word lacks. Steer chart customers to HTML.

**HTML is the recommended chart source format.** Word `.docx` chart templates work but are constrained — Word's row auto-expansion (`{#Lines}` semantics) conflicts with the inner `{#cols}` loop when both want to drive cell placement in the same `<w:tr>`. `<div>` + `display:table-cell` in HTML dodges this entirely; Word has no `<div>` equivalent. The `{color_hex}` chart field exists specifically so Word's `w:shd w:fill` attributes can use cycled palette colors (raw hex, no `#`).

## Critical: zero-heap PDF image rendering (don't accidentally regress)

For PDF output, `{%ImageField}` tags with ContentVersion IDs skip blob loading. `currentOutputFormat` is set to `'PDF'` before `processXml()` calls; in `buildImageXml()`, when `currentOutputFormat == 'PDF'` and value is `068xxx`, query only `Id, FileExtension` (NOT `VersionData`) and store the relative URL `/sfc/servlet.shepherd/version/download/<cvId>`. Image URLs in HTML for `Blob.toPdf()` MUST be relative — absolute URLs and data URIs render broken.

If your fix touches `processXml`, do not add `VersionData` to the PDF-path SOQL and do not prepend `URL.getOrgDomainUrl()` anywhere in the image pipeline.

## Package info

- Package: Portwood DocGen, Unlocked 2GP, namespace `portwoodglobal`
- Current shipped version: **v2.3.0** (`04tVx000000ZxDJIA0`, build `2.3.0-1`) — Guest-Aware FLS Reads (completion patch for v2.2). v2.2 swapped the 18 admin write-guards (`DocGenFlsGuard.assertUpdateable / assertCreateable`) to guest variants but left the 36 read-guards (`DocGenFlsGuard.assertAccessible`) as admin. Customers running v2.2.0 hit `Save failed: Insufficient FLS to read portwoodglobal__DocGen_Signer__c.Contact__c. Verify DocGen permission set assignment.` on the saveSignature step — the per-field FLS describe verdict throws for guest profiles on the SOQL select-list even though the permset grants read. v2.3.0 swaps 34 sites in `DocGenSignatureController.cls` + 2 sites in `DocGenAuthenticatorController.cls` (verifyDocument, verifyByRequestId) to `DocGenFlsGuard.guestAssertAccessible`. No new methods/classes/tests — reuses v2.2's helper. AppExchange impact: still v1.56 listed at the time of release; v2.x bundles are forward-prep per [[project_appexchange_voucher_pending]].
- Previous shipped version: **v2.2.0** (`04tVx000000ZxBhIAK`, build `2.2.0-2`) — Guest-Aware FLS Guards (signature flow hotfix). Adds `DocGenFlsGuard.guestAssertCreateable/guestAssertUpdateable/guestAssertAccessible` mirroring the v2.1.0 admin variants but bypassing the object-level + per-field FLS _verdict_ when `UserInfo.getUserType() == 'Guest'` (same shape as the existing `Test.isRunningTest()` bypass; the per-field `Schema.SObjectField.getDescribe().is*()` probe still fires for the Checkmarx pattern-match signal). 18 call sites in `DocGenSignatureController.cls` swapped from admin to guest variants (sendPin, verifyPin, validateSignerToken→Viewed, validateLegacyRequest, getOrCreatePublicLink, saveSignature, saveLegacySignature, stampLegacySignerAndSavePdf, saveSignedDocument, declineSignature, signPlacement). Fixes v2.1.0 regression where guest signers got `Failed to save: Insufficient access to update portwoodglobal__DocGen_Signature_Placement__c` on every write — DocGen_Guest_Signature permset grants allowRead-only by design (token-bound `Secure_Token__c` is the capability for guest writes, not perm-set Edit). Sender controller and Service queueables unchanged. v2.2.0-1 was built first but contained the pre-fix `DocGenMiscTests.testIssue114NoUserModeOnPreDecompCvLookups` over-broad assertion; v2.2.0-2 is the promoted build with the narrowed test (skips the admin delete-cleanup block at `DocGenController.cls:2822` where `WITH USER_MODE` is structurally correct). Test now passes. `sf code-analyzer`: 0 violations.
- Previous shipped version: **v2.1.0** (`04tVx000000Zw5xIAC`) — Per-Field FLS Guards release. Adds `DocGenFlsGuard.cls` with `assertCreateable/assertUpdateable/assertAccessible(SObject|SObjectType, Set<String> fieldAllowlist)` — calls `Schema.SObjectField.getDescribe().is{Createable,Updateable,Accessible}()` per field before every admin DML / `WITH SYSTEM_MODE` SOQL. 243 guard call sites across 19 controllers. Implements the second half of the v1.56 review's finding-resolution language ("enforce CRUD checks on the object AND FLS checks on the fields"). `Test.isRunningTest()` bypass on the per-field verdict (object-level CRUD and field-existence check still fire) — matches platform behavior where USER_MODE is lenient in test contexts; documented inline at each bypass. Closes the 222 FLS Create/Update + 340 USER_MODE Missing Checkmarx findings. `sf code-analyzer`: 0 Critical / 0 High / 0 Moderate after disabling pmd:ProtectSensitiveData + pmd:AvoidLwcBubblesComposedTrue (documented false positives in code-analyzer.yml). Packaged as v2.1.0 because patch versioning is disabled on the namespace (see [[project_patch_versioning_disabled]]). Build attempts: 3 (attempts 1 + 2 failed on the namespaced-field-map and FLS-propagation issues respectively, both fixed and documented in DocGenFlsGuard.cls).
- Previous shipped version: **v2.0.0** (`04tVx000000ZqBpIAK`) — Security Hardening for AppExchange resubmission. 4 clickjacking LWC fixes; CRUD/FLS hybrid pattern (Schema CRUD gate + SYSTEM_MODE); new `DocGenSignatureGuestSecurity.cls`; verifyDocument returns ALL signers for multi-signer docs. See `CHANGELOG.md` for per-finding mapping (the standalone `SECURITY_REVIEW_RESPONSE_v2.md` now lives only in the local-only `docs/appexchange/` bundle).
- DevHub: `Portwood Global - Production` (dave@portwoodglobalsolutions.com)
- Staging org for release validation: `portwood-staging` — must be created with `--no-namespace` so source-deploy lands in the default namespace and the e2e scripts' bare class/field references compile. Assign `DocGen_Admin` permset to the running user immediately after deploy or field-level security blocks the e2e scripts.
- Dev scratch: `docgen-designer`

### Package version descriptions must be CONSUMER-friendly

The `versionDescription` field in `sfdx-project.json` (and what shows up in the AppExchange listing + install dialog) is read by **end users / customers** evaluating the package, not by engineers. Write it like marketing copy, not engineering notes. The `versionName` ("v2.1.0 — Per-Field FLS Guards (DocGenFlsGuard)") is internal-facing; the `versionDescription` is customer-facing.

**Bad** (engineering jargon — what shipped in v2.1.0-1):

> v2.1.0 adds DocGenFlsGuard — per-field Schema.SObjectField.getDescribe().isAccessible/isCreateable/isUpdateable() checks at every admin DML and WITH SYSTEM_MODE SOQL site (243 guard call sites across 19 controllers). Implements the AppExchange v1.56 review's stated finding-resolution: 'enforce CRUD checks on the object and FLS checks on the fields...'

**Good** (consumer-friendly):

> Portwood DocGen generates PDFs and Word documents from any Salesforce record. v2.1 strengthens permission enforcement so users only see and modify the fields their permission set grants. 100% native Salesforce — no external services or callouts. Free for all users.

The detailed engineering-language belongs in `CHANGELOG.md` (and the local-only `docs/appexchange/` bundle), not in the package metadata customers see at install time.

## Release validation checklist

All three checks MUST pass before release. No exceptions.

### 1. E2E test suite

```bash
sf apex run --target-org <org> -f scripts/e2e-01-permissions.apex
sf apex run --target-org <org> -f scripts/e2e-02-template-crud.apex
sf apex run --target-org <org> -f scripts/e2e-03-generate-pdf.apex
sf apex run --target-org <org> -f scripts/e2e-04-generate-docx.apex
sf apex run --target-org <org> -f scripts/e2e-05-generate-bulk.apex
sf apex run --target-org <org> -f scripts/e2e-06-signatures.apex
sf apex run --target-org <org> -f scripts/e2e-07-syntax1.apex
sf apex run --target-org <org> -f scripts/e2e-07-syntax2.apex
sf apex run --target-org <org> -f scripts/e2e-07-syntax3.apex
sf apex run --target-org <org> -f scripts/e2e-07-syntax4.apex
sf apex run --target-org <org> -f scripts/e2e-08-cleanup.apex
```

Each script must print `PASS: N  FAIL: 0  ALL TESTS PASSED`. Sequence: 01 standalone, 02 creates test data, 03–06 depend on 02, 07-syntax1/2/3/4 standalone (use `processXmlForTest`), 08 cleans up.

When fixing a parser-level bug, add a regression assertion in `e2e-07-syntax1` or `e2e-07-syntax2` that exercises the offending pattern via `processXmlForTest`. Each script must stay under 18,000 chars (Anonymous Apex limit is 20,000).

### 2. Apex test suite

```bash
sf apex run test --target-org <org> --test-level RunLocalTests --wait 15 --code-coverage
```

Expected: `Outcome: Passed`, `Pass Rate: 100%`, org-wide coverage ≥ 75%.

### 3. Code Analyzer

```bash
sf code-analyzer run --workspace "force-app/" --rule-selector "Security" --rule-selector "AppExchange" --view table
```

Expected: `0 High severity violation(s) found`. ~30 Moderate false positives are acceptable (see `code-analyzer.yml`).

## Pre-commit: prettier (CI gate)

CI runs `npm run format:check` (prettier) on every PR; a failure blocks merge. Run before pushing:

```bash
npm install   # one-time, adds prettier to node_modules/.bin
npm run format        # auto-fix
npm run format:check  # verify clean
```

Covers `force-app/**/*.{cls,trigger,page,component,cmp,html,js,xml}`, `scripts/**/*.apex`, and root `*.{json,md,yml,yaml}`. Apex scripts under `/scripts/` are formatted too — long string concatenations get reflowed, so don't fight the wrap.

## Subsystem caution

Several subsystems are tightly coupled and easy to break with surgical fixes — reach for `git log -- CLAUDE.md` and `git show 6a2deff^:CLAUDE.md` to recover the deeper historical notes if you're touching:

- **Signatures (especially v3 packets / multi-template)** — three hand-rolled loops, no content-correctness tests, two divergent creation paths. Read the `project_signature_v3_fragility.md` memory before changing anything here.
- **Client-side DOCX assembly** (`docGenZipWriter.js`) — splits work between server (XML merge) and browser (ZIP repack). The boundary is load-bearing; don't move work across it lightly.
- **HTML templates and `Blob.toPdf` rendering** — Flying Saucer is essentially **CSS 2.1** plus a small CSS 3 subset. `display: flex`/`grid`, `gap`, `linear-gradient(...)`, `calc(...)`, CSS variables, and most CSS 3 layout features are silently ignored — the page renders but layout collapses to default block flow. When troubleshooting "the PDF looks wrong," first check whether the source HTML uses any of these and rewrite to `<table>`-based layout + solid colors. Also: when both the engine `<style>` (built from `Page_Size__c`/`Page_Orientation__c`/`Custom_Margins__c` template fields) and the source HTML's own `<style>` declare `@page`, you get a conflict — recommend authors clear the template page fields when their source CSS already specifies `@page`. Issues #60 and #71 both live here.
- **Query Config formats** (V1 flat string, V3 node tree) — V3's `processChildNodes` and V1's `stitchGrandchildren` reproduce similar patterns; bug fixes often need to land in both (see #67).
- **Watermarks, font handling, command hub** — light traffic, but the test coverage is sparse, so verify visually after edits.
