# Agentforce template authoring — feasibility and plan

Goal: build and refine a DocGen HTML template by prompting Salesforce AI in-org,
instead of copying the Designer's AI prompt out to an external assistant and
pasting HTML back.

**Status 2026-07-26: Phase 1 built and proven end-to-end.** Einstein generated a
template through `ConnectApi` in `talentstacker-buildalong`, the validator
sanitized it, and the cleaned body was written where the Designer reads it.

## Where this can be developed

`talentstacker-buildalong` (`talentstacker@portwood.dev`, Developer Edition).
Prompt Builder is available and `EinsteinGPTPromptTemplateManager` is assigned.

**Scratch orgs are out, and must stay out.** The Dev Hub is not entitled —
creating an org from `Portwood Global - Production` fails at the settings deploy
with `EinsteinGpt : Not available for deploy for this organization`. Do **not**
add `EinsteinGPTForDevelopers` to `config/project-scratch-def.json`; it would
break every scratch org the QA harness and demo tooling create.

Agentforce agent **chat** is not available in that org. That turned out not to
matter — Phase 1 needs Prompt Builder only. (An earlier session left
`GenAiPlugin` / `GenAiFunction` / `GenAiPlannerBundle` metadata in the org for
the chat path; it is unused here.)

**One org cannot host all of it.** `talentstacker-buildalong` has Einstein but
also has DocGen v3.45.0 installed as a _managed_ package, so `docGenAdmin` and
`DocGenController` cannot be modified there. `Portwood Dev` has the unmanaged
source but no Einstein. So the work is verified in two halves, which is
precisely what the provider interface is for:

| Verified in                | What                                                                                                         |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `Portwood Dev`             | Full pipeline against the stub: validator, staging field, ContentVersion write, Designer load, 29 Apex tests |
| `talentstacker-buildalong` | The Einstein leg: real ConnectApi generation → validator                                                     |

## The ConnectApi surface — measured, not read

Verified against **API 66.0 classes in a 67.0 org**, which is what the package
targets:

```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
input.isPreview = false;
ConnectApi.EinsteinLlmAdditionalConfigInput cfg = new ConnectApi.EinsteinLlmAdditionalConfigInput();
cfg.applicationName = 'PromptBuilderPreview';          // REQUIRED
input.additionalConfig = cfg;
ConnectApi.WrappedValue v = new ConnectApi.WrappedValue();
v.value = prompt;
input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Instructions' => v };
ConnectApi.EinsteinPromptTemplateGenerationsRepresentation r =
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('DocGen_HTML_Body', input);
String html = r.generations[0].text;
```

Findings worth keeping:

- **`additionalConfig.applicationName` is required, and its absence is
  undiagnosable.** Omit `additionalConfig` and the call throws
  `ConnectApi.ConnectApiException: Failed to generate Einstein LLM generations
response` with a null cause and `(System Code)` as the entire stack. The real
  message — `Application Name is a required field providing existing registered
ai applicaton` — appears only when the name is non-empty but unrecognized.
  `'PromptBuilderPreview'` and `''` are accepted; `PromptTemplateGeneration`,
  `Copilot`, `EinsteinGPT`, `AgentforceForDevelopers` and `default` are not.
  `SELECT ... FROM AiApplication` returns zero rows.
- **Not a callout.** `Limits.getCallouts()` stays at 0, so the 100% native claim
  holds. This is the whole reason the feature is allowable here.
- **Slow.** 9–13s wall clock for a 4–5KB body; ~420ms Apex CPU. The UI has to be
  built for a long call.
- `inputParams` keys accept both `Input:Name` and `Input.Name`.
- Permissions: a System Administrator with `EinsteinGPTPromptTemplateManager`
  suffices. No extra permission set was needed.

### The prompt template is org-owned, not packaged

There is **no `GenAiPromptTemplate` SObject** — it is metadata-only, so
`Schema.getGlobalDescribe()` will never show it (`sf org list metadata -m
GenAiPromptTemplate` is the right probe). And it cannot be hand-authored into
the package: `versionIdentifier` is a platform-generated value
(`yvmKyDKd7FT3ZEaBcJ3xDc4/KiNH2FSWumeMrabd4ss=_1`), and a template with no
active version is refused outright while the "Deploy Active Prompt Template
Versions Only" preference is on. Both were measured by trying.

So **the subscriber creates the template**; DocGen ships the code that calls it.
That answers open question 3 below: this is documented setup, not shipped
metadata. Setup node is `EinsteinPromptStudio` (not `EinsteinGPTPromptTemplates`,
which 404s). The one created for this spike:

- API name `DocGen_HTML_Body`, type Flex, one required Free Text input
  `Instructions`, model `sfdc_ai__DefaultGPT5Mini`, Published + Activated.
- Its body is a thin **carrier** — a sentence of framing plus
  `{{Input.Instructions}}`. DocGen's own `buildAiPrompt()` assembles everything
  that matters and passes it as that one input.

### The Einstein class only compiles where Einstein exists

`ConnectApi.EinsteinLLM` is not a visible type in an org without the
entitlement — deploying `DocGenEinsteinProvider` to `Portwood Dev` fails with
`Type is not visible: ConnectApi.EinsteinLLM`. A compile-time reference to it
anywhere would make the validator, the controller and the Designer undeployable
in every org without Einstein. `DocGenAiProviderFactory` therefore resolves it
with `Type.forName('DocGenEinsteinProvider')` and falls back to an honest
`DocGenUnavailableProvider`. This is a packaging constraint, not a style choice.

## Why this fits DocGen specifically

- **No external callout.** Einstein is reached through `ConnectApi`, not `Http`.
- **The prompt already exists.** `buildAiPrompt()` in
  `lwc/docGenAdmin/docGenAuthoringKit.js` assembles a schema-aware prompt — the
  record's fields, relationships, tag syntax and the engine's CSS constraints.
  Today a human ferries it to ChatGPT. This closes that loop; it does not invent
  it, and both paths send the same text so they cannot drift.
- **The Designer already ingests HTML.** A body written to a ContentVersion
  titled `docgen_html_body_<templateId>_<ts>` is what
  `DocGenController.getHtmlTemplateBody` reads. Phase 1 reuses
  `saveHtmlTemplateBody` rather than hand-rolling a write.

## The prompt is the moat, not the model — now with evidence

A general model asked for "an invoice" returns flexbox, `border-radius`,
`rgba()` tints and gradient headers. Every one of those renders wrong in Flying
Saucer, and several fail **silently** — `rgba()` makes a panel invisible rather
than falling back.

Measured, not asserted. Asked for an invoice with "CSS 2.1 only" **stated in the
prompt**, GPT-5-mini through Prompt Builder still emitted:

| Emitted                                                                | Consequence in Flying Saucer                                 |
| ---------------------------------------------------------------------- | ------------------------------------------------------------ |
| `display:flex` ×3 + `justify-content`/`align-items`                    | ignored; header/panel/summary stack vertically               |
| `box-sizing: border-box`                                               | ignored; widths are content-box                              |
| `opacity: 0.95`                                                        | ignored                                                      |
| `font-weight: 600`                                                     | falls back to regular, not semibold                          |
| `@media print { ... }`                                                 | never matches; those rules never apply                       |
| `{#OpportunityLineItems}` on its own line between `<tbody>` and `<tr>` | foster-parented out of the table — **the row never repeats** |

That last one is issue #248, reproduced on the first real generation, and again
on the second run. It is a correctness bug, not a cosmetic one.

## What Phase 1 actually ships

```
buildAiPrompt() + the author's description      (LWC, unchanged prompt)
  -> DocGenAiProvider                            (interface; Einstein | Stub | Unavailable)
  -> DocGen_Template__c.Draft_Body__c            RAW model output, staged for diffing
  -> DocGenAiHtmlValidator                       strip / repair, and say what changed
  -> DocGenController.saveHtmlTemplateBody       ContentVersion the Designer already reads
  -> canvas
```

| File                             | Role                                                      |
| -------------------------------- | --------------------------------------------------------- |
| `DocGenAiProvider.cls`           | Interface. `isAvailable` / `getName` / `generateHtml`     |
| `DocGenAiStubProvider.cls`       | Canned DIRTY response reproducing real model output       |
| `DocGenEinsteinProvider.cls`     | ConnectApi call. Einstein-only compile                    |
| `DocGenAiProviderFactory.cls`    | `Type.forName` seam + `DocGenUnavailableProvider`         |
| `DocGenAiHtmlValidator.cls`      | The product                                               |
| `DocGenAiTemplateController.cls` | `generateTemplateBody` / `validateOnly` / `isAiAvailable` |
| `Draft_Body__c`                  | LongTextArea 131,072 on `DocGen_Template__c`              |
| `docGenAdmin` button + panel     | "Generate with Agentforce", hidden when unavailable       |

The button is **hidden**, not disabled, when AI is unavailable, so Copy AI Prompt
stays the visible answer rather than a dead end.

## Phase 2 — the validator is the product

Already implemented, since it is what makes the output trustworthy. Every rule is
measured against the engine (UserGuide 5.7.3 / 15.11 and
`scripts/css-capability-probe.apex`), and each reports as **repaired**,
**removed** or **warning** — the distinction the author needs:

- **Repaired** — `rgba()`/`hsla()` composited over white into a flat hex;
  gradients collapsed to their first stop; `var()` substituted; numeric
  `font-weight` mapped to normal/bold; markdown fences stripped; loop tags moved
  from between rows into the first and last cells.
- **Removed** — `border-radius` (every form, including `-fs-border-radius`),
  `box-shadow`, `text-shadow`, `outline`, `opacity`, `transform`, `transition`,
  `animation`, `box-sizing`, `overflow-wrap`, `word-break`, CSS columns,
  `filter`, `calc()` declarations, `@media` blocks, `<script>`, `<svg>`,
  external stylesheets, flex/grid alignment properties.
- **Warning** — `display:flex|grid` (needs a real table rebuild),
  `position:absolute|fixed|sticky`, ZapfDingbats/Symbol/Wingdings,
  `{PageNumber}` in the body, unbalanced merge braces, a loop wrapping a whole
  table.

Deliberately **not** stripped, because they are measured to work: `border:
dashed`/`dotted`, `:nth-child(even)`, `display: table|table-row|table-cell`,
`@page`.

## Phase 3 — conversational refinement

"Make the header darker", "add a totals row". Needs the current body as context,
which `Draft_Body__c` now provides. Still open.

## Open questions

1. ~~Exact `ConnectApi` surface~~ — answered above, measured at 66.0/67.0.
2. **What Agentforce licensing a SUBSCRIBER needs.** Still open. Confirmed only
   that a DE org with Prompt Builder + `EinsteinGPTPromptTemplateManager` works.
   Degradation is already built (hidden button), but the licensing floor is
   unknown.
3. ~~Whether the prompt template can be packaged~~ — it cannot. Subscriber
   creates it; ship the setup steps. They are in the `DocGenEinsteinProvider`
   header comment.
4. **New:** the carrier template's dev name is hardcoded to `DocGen_HTML_Body`.
   If this ships, it should be a `DocGen_Settings__c` field so a subscriber can
   point at their own template.
5. **New:** ~9–13s generation with no progress signal beyond a spinner. Fine for
   a spike; a queueable + platform event would be better if this ships.

## Design constraint (held)

Everything except the final ConnectApi hop is exercised by the stub, so the
validator, the staging field, the CV write and the Designer load are all covered
by 29 passing Apex tests in an org with **no** entitlement.
