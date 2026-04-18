# Template Partials (Clause Library) — Design

**Status:** Approved — ready for implementation plan
**Target release:** v1.50.0
**Date:** 2026-04-17

## Summary

Introduce reusable, data-aware template partials so admins can maintain a single canonical copy of a clause (NDA boilerplate, governing law, arbitration, payment terms) and include it across many host templates via `{>PartialName}`. Partials share the existing `DocGen_Template__c` object, use the same version history, the same pre-decomposed XML cache, and the same rendering pipeline as regular templates. Editing a partial fans out to every host that includes it at generation time.

## Scope

**In scope (v1):**
- New `{>PartialName}` merge tag
- Partials stored as `DocGen_Template__c` rows flagged `Is_Partial__c = true`
- Partials inherit the host's data context (merge fields, conditionals, loops, aggregates, image-field tags, barcodes work inside partials)
- Nested includes resolved recursively with max depth 5 (cycle protection)
- Active-version resolution at generation time — no pinning
- `docGenAdmin` list-view toggle (Templates / Partials / All), partial badge, "New Partial" creator
- Gates blocking standalone generation of partials (Generate button, Signature Sender, Flow Action, Bulk Runner)
- Save-time validation rejecting sig tags, embedded DOCX images, bad names, duplicate partial names

**Out of scope (v1):**
- Signature tags (`{@Signature_...}`) inside partials — coordinating roles/orders across multiple partials in one host is a rabbit hole
- Embedded DOCX images inside partials — requires style/relationship/rId merging across DOCX ZIPs
- Partial parameters (`{>Name(arg=val)}`) — revisit if demand emerges
- Pinned version resolution or drift-detection UI — revisit if legal/compliance customers push back
- Save-time cross-reference validation of `{>X}` tags in host templates — runtime error is clear enough

## Non-Goals

- Not a full module system with imports, parameters, and scope
- Not a mechanism for merging DOCX styles, numbering, or themes across files
- Not a replacement for the existing template versioning model

## User-Facing Behavior

### Syntax

```
{>PartialName}
```

- Matches the existing single-char prefix convention (`#` loop, `^` inverse, `*` barcode, `%` image, `@` signature, `>` include)
- `PartialName` resolves to the active version of the `DocGen_Template__c` row where `Name = 'PartialName'` AND `Is_Partial__c = true`
- Works anywhere a regular merge tag works: inline paragraphs, table cells, inside `{#Loop}...{/Loop}`, inside `{#IF ...}...{/IF}`

### Data context

Partials inherit whatever data map is active at the point of inclusion:

- At the top level of a host template, partials see the host's full record data
- Inside a `{#Contacts}...{>ContactBlock}...{/Contacts}` loop, the partial sees the iteration's Contact data and can use `{FirstName}`, `{Email}`, etc.
- Inside an `{#IF ...}` branch, the partial is only expanded when the branch fires

### Constraints

| Constraint | Behavior |
|---|---|
| No signature tags | Save-time rejection: `Partials cannot contain signature tags. Signatures live on the host template — remove {@Signature_...} tags from this partial.` |
| No embedded DOCX images | Save-time rejection: `Partials in v1 cannot contain embedded images. Delete the images from this DOCX, then re-insert as {%ImageField} merge tags referencing ContentVersion IDs.` |
| Max include depth 5 | Runtime rejection: `Partial include depth exceeded (max 5). Check for circular references starting at 'X'.` |
| Name charset: `^[A-Za-z0-9_][A-Za-z0-9_\-\.]{0,79}$` | Save-time + runtime rejection |
| Unique name among partials | Save-time rejection: `A partial named 'X' already exists. Partial names must be unique.` (Regular template can still share the name) |
| `Is_Partial__c` immutable after first save | Wizard disables the toggle on edit; admin must clone-and-recreate to switch modes |
| Style inheritance from host | Partial's `styles.xml`, `numbering.xml`, `theme.xml` are not merged. Use built-in Word styles (Heading 1, Normal, List Bullet, …) for portability. |

## Architecture

### Data model

**New field on `DocGen_Template__c`:**
- `Is_Partial__c` — Checkbox, default `false`, not null
- Granted read on `DocGen_Admin`, `DocGen_User`, `DocGen_Guest_Signature` permission sets; edit on Admin only

No new object. No dependency tracking table.

### Rendering pipeline (Approach A — parser-inline)

New prefix branch in `DocGenService.processXml()`, alongside existing `#`, `^`, `%`, `*`, `@`:

```apex
else if (tagContent.startsWith('>')) {
    String partialName = tagContent.substring(1).trim();
    output += expandPartial(partialName, data);
}
```

**`expandPartial(String name, Map<String, Object> data)`** — new private helper:

1. Depth guard: increment static `currentPartialDepth`; if `> MAX_PARTIAL_DEPTH` (5), throw
2. Validate name against regex; throw on fail
3. Fetch splice-ready body XML via `getPartialBodyXml(name)` (cached)
4. Recursively call `processXml(body, data)` — data context flows unchanged
5. Decrement depth, return result

**`getPartialBodyXml(String name)`:**

1. Check static `partialBodyCache` — return if hit
2. SOQL with bind variable (`WHERE Name = :name AND Is_Partial__c = true LIMIT 1`)
3. Resolve active version (existing template-version active-flag logic)
4. Load the active version's pre-decomposed `word/document.xml` via the same loader used by `tryMergeFromPreDecomposed`. Fall back to ZIP decomposition if pre-decomposed CVs don't exist.
5. Extract splice region: substring between `<w:body>` and `</w:body>`, stripping the trailing `<w:sectPr>` (partial must not override host page setup)
6. Cache and return

**Cache lifecycle:**
- `partialBodyCache` (Map<String, String>) — static, lazily initialized on first access. **Not reset** in `mergeTemplate()` or anywhere else. Apex transaction boundaries clear it naturally (test method end, Aura call end, batch `execute()` end). This is required: a bulk run of 50 records sharing one partial must issue **one** SOQL, not fifty — resetting mid-bulk would blow past the 100-query governor limit.
- `currentPartialDepth` (Integer) — static, balanced by the `try/finally` block in `expandPartial()`. Returns to 0 after every expansion (including on thrown exception). No explicit reset needed.
- This pattern matches the existing `cachedPreDecompTemplateId` / `cachedXmlParts` statics that `tryMergeFromPreDecomposed()` uses (DocGenService.cls:14-16) — populated lazily, survives the bulk loop, cleared by transaction boundary.

**Image-field tags (`{%ImageField}`) in partials:** work automatically — they resolve inside the recursive `processXml()` call, emit into the existing pending-images map, merge machinery handles them on the fully-expanded document.

**PDF / DOCX parity:** both output paths call `processXml()` server-side (PDF via `mergeTemplate()` → `DocGenHtmlRenderer`; DOCX via `generateDocumentParts()` → client-side ZIP assembly). Partial expansion happens before either path diverges, so the DOCX client receives fully-expanded XML with no `{>...}` tags surviving. No per-format logic needed.

### Save-time validation

New private helper `validatePartialConstraints(Blob docxZip, String partialName, Id existingId)` invoked from `DocGenController.saveTemplate()` only when `Is_Partial__c = true`. Three checks:

1. Extract `word/document.xml`, scan for `{@Signature_` → reject
2. Scan `word/_rels/document.xml.rels` for `<Relationship>` entries with `Type` containing `/image` → reject
3. Validate name regex + uniqueness among partials → reject on fail

Skip `extractAndSaveTemplateImages()` for partials — once Check 2 bans embedded images, there's nothing to extract.

### Standalone-generation gates

New shared helper `DocGenService.assertNotPartial(Id templateId)` — throws `DocGenException('This template is a partial — include it in a host template via {>Name}.')` if the target template has `Is_Partial__c = true`. Called from:

- `DocGenController.generate()`
- `DocGenController.generateDocumentParts()` (DOCX client-side assembly entry point)
- `DocGenSignatureSenderController.createTemplateSignerRequestWithOrder()`
- `DocGenSignatureSenderController.createTemplateSignatureRequestForFlow()`
- `DocGenFlowAction.invoke()`

Template-picker queries in `docGenBulkRunner` and `docGenSignatureSender` add `AND Is_Partial__c = false` to their WHERE clauses.

### Admin UX

**`docGenAdmin` template list:**
- Scope pill at top: `Templates | Partials | All`, default `Templates`
- Partial rows display a "Partial" badge
- "+ New" button splits into `New Template` and `New Partial`

**Template wizard — create flow:**
- Step 1 checkbox: "This is a reusable partial (can be included in other templates via `{>Name}`)"
- When checked: Query Config step skipped, Test Record Id step skipped, final-step preview disabled with note "Partials preview inside their host template"

**Template wizard — edit flow:**
- `Is_Partial__c` toggle disabled (immutable post-create)

**Partial detail view:**
- Prominent "Include tag" display with copy-to-clipboard: `{>PartialName}`

**Delete behavior:**
- No cross-reference scan in v1. Admins can delete freely; host templates referencing a deleted partial get the existing runtime "Unknown partial" error on next generation.

**Learning Center (`docGenCommandHub`):**
- New section "Partials & Clause Libraries" covering create flow, `{>Name}` syntax, v1 constraints, error-message cheat sheet

### Error handling

| # | Condition | Exception (`DocGenException`) |
|---|---|---|
| 1 | Unknown partial | `Unknown partial: 'X'. Verify a DocGen_Template__c with this name exists and has Is_Partial__c = true.` |
| 2 | No active version | `Partial 'X' has no active version. Open the template manager, select the partial, and activate a version.` |
| 3 | Depth > 5 | `Partial include depth exceeded (max 5). Check for circular references starting at 'X'.` |
| 4 | Invalid name chars | `Invalid partial name in tag {>...}: '<value>'. Names may contain letters, digits, underscore, dash, and dot only.` |
| 5 | Malformed DOCX | `Partial 'X' has malformed DOCX content (missing <w:body>). Re-upload the partial file.` |

All five propagate through `mergeTemplate()` → `DocGenController.generate()` → existing bulk per-record error handling (already records failures per record and continues). LWC surface uses the existing `AuraHandledException` wrapper that shows the current merge-failure toast.

### Governor-limit posture

- **SOQL:** one query per unique partial name per generation (cache dedups). 50 distinct partials = 50 queries, well under the 100 limit.
- **CPU:** each nested expansion re-invokes `processXml()`. Depth-5 nesting with complex partials is a real risk in large bulk jobs — documented in Learning Center with recommendation for flat partial graphs.
- **Heap:** pre-decomposed path reuses host-template caching strategy (XML-only, no blob). If a partial only has the ZIP fallback, log a warning and recommend re-save.

## Testing

### E2E scripts (mandatory per CLAUDE.md release checklist)

| Script | New assertions | Est. chars added |
|---|---|---|
| `e2e-01-permissions` | `Is_Partial__c` in all three permission sets | ~200 |
| `e2e-02-template-crud` | Create partial, all 4 save-time rejections, list scope toggle, `Is_Partial__c` immutability | ~1500 |
| `e2e-03-generate-pdf` | Generate PDF from host-with-partial, assert content | ~800 |
| `e2e-04-generate-docx` | Generate DOCX from host-with-partial, assert content | ~800 |
| `e2e-05-generate-bulk` | Bulk generate N records with partial-using template | ~400 |
| `e2e-07-syntax` | `processXmlForTest()` cases: simple, nested, cycle, unknown, invalid name, inside loop | ~1200 |
| `e2e-08-cleanup` | Delete test partial templates + versions + image CVs | ~300 |

Each script must stay under the 18,000-char Anonymous Apex limit.

### Apex tests — new `DocGenPartialTests.cls` (≥17 tests)

**Expansion:**
- `testPartialExpansion_SimpleField`
- `testPartialExpansion_InsideLoop`
- `testPartialExpansion_WithConditional`
- `testPartialExpansion_WithAggregate`
- `testPartialExpansion_Nested3Levels`
- `testPartialExpansion_WithImageField`

**Error paths:**
- `testPartialExpansion_UnknownName`
- `testPartialExpansion_NoActiveVersion`
- `testPartialExpansion_CycleDetected`
- `testPartialExpansion_InvalidNameChars`
- `testPartialExpansion_MalformedBody`

**Save validation:**
- `testValidatePartialConstraints_SigTag`
- `testValidatePartialConstraints_EmbeddedImage`
- `testValidatePartialConstraints_DuplicateName`
- `testValidatePartialConstraints_BadNameRegex`

**Gate helpers:**
- `testAssertNotPartial_FromGenerate`
- `testAssertNotPartial_FromSigSender`
- `testAssertNotPartial_FromFlowAction`

**Cache correctness:**
- `testPartialCacheDedup` — same partial used 10× = 1 SOQL (verify via `Limits.getQueries()`)
- `testPartialCacheReset` — two consecutive `mergeTemplate()` calls don't leak state

**Coverage target:** ≥ 85% on new code. No `Test.isRunningTest()` bypasses — if a path needs mocking, refactor for injection.

### Code Analyzer

- SOQL uses bind variable `:name`; name is regex-validated before reaching SOQL — two defenses against injection
- CRUD/FLS — reading `DocGen_Template__c` is admin-context only; partials are never invoked in guest flows
- SFGE taint analysis — clean (regex gate is a terminating node)

## Rollout

- Ship as **v1.50.0**
- README adds "Template Partials" subsection under Merge Tags (~30 lines)
- CHANGELOG entry: feature summary, v1 constraints (no sigs, no embedded images), note that `Is_Partial__c` is immutable post-create
- Manual validation in `docgen-demo-v2` scratch org: create a partial, include in a host, generate PDF + DOCX, verify visually
- No data migration required

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Admin edits a widely-used clause and breaks every host on next generation | Loud error messages + Learning Center guidance on treating clause updates as consequential changes. Drift-detection UI deferred to a future release. |
| Partial references to non-existent partials aren't caught at save time | Runtime error is clear and actionable. Admins discover on first generation of affected template. Revisit if real-world complaints. |
| DOCX style IDs in partials don't exist in host → Word falls back to Normal style | Documented constraint: use built-in styles in partials. Most clause libraries are paragraph-heavy content that works with Normal/Heading styles. |
| Depth-5 limit too restrictive for deeply-layered compositions | Configurable constant if anyone pushes back. 5 levels covers legal-clause use cases comfortably based on industry precedent. |
| Cache fails to dedup SOQL in bulk runs | Cache is lazily populated and survives the bulk loop within a single transaction. Apex transaction boundary (not mergeTemplate entry) is the reset point. Verified by `testPartialCache_SurvivesAcrossCalls` which asserts delta-SOQL = 0 on the second call. |

## Open Questions

None. All major choices locked during brainstorming (storage model, dynamism level, versioning strategy, syntax, v1 scope).
