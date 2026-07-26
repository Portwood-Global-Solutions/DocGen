# Agentforce template authoring — feasibility and plan

Goal: build and refine a DocGen HTML template by chatting in-org, instead of
copying the Designer's AI prompt out to an external assistant and pasting HTML
back.

## Blocker: the Dev Hub is not entitled to Einstein GPT

Measured 2026-07-26. `EinsteinGPTForDevelopers` is a **valid** scratch-org
feature, but creating an org from `Portwood Global - Production` fails at the
settings deploy:

```
EinsteinGpt : Not available for deploy for this organization
```

So this cannot be developed against a scratch org today. Resolve the entitlement
first (Partner Community request, or a Developer Edition / trial org with
Einstein enabled). Everything below is designed so the work is useful before
that lands.

## Why this fits DocGen specifically

- **No external callout.** Einstein/Agentforce is reached through `ConnectApi`,
  not `Http`, so it does not break the 100% native constraint that would
  normally rule an AI feature out here.
- **The prompt already exists.** The Designer's "Copy AI Prompt" assembles a
  schema-aware prompt — the record's fields, relationships, tag syntax and the
  engine's CSS constraints. Today a human ferries it to ChatGPT and pastes the
  result back. This closes that loop; it does not invent it.
- **The Designer already ingests HTML.** A body written to a ContentVersion
  titled `docgen_html_body_<templateId>` opens in the canvas. That hop is built
  and tested.

## The prompt is the moat, not the model

A general model asked for "an invoice template" returns flexbox, `border-radius`,
`rgba()` tints and gradient headers. Every one of those renders wrong in Flying
Saucer, and several fail **silently** — `rgba()` makes a panel invisible rather
than falling back. The value here is the accumulated constraint set (UserGuide
§5.7.3, §15.11, §15.12 and `scripts/css-capability-probe.apex`), not access to an
LLM.

## Flow

```
Prompt Builder (Field Generation)
  → DocGen_Template__c.Draft_Body__c   (Long Text Area, 131,072 — a real body is 5–70KB)
  → validator
  → ContentVersion 'docgen_html_body_<templateId>'
  → Designer canvas
```

## Phase 1 — smallest slice that proves the pipeline

One field, one button, one validator. **Generate with Agentforce** in the
Designer: in-org call with the existing prompt, validate, load into the canvas.
No chat UI, no round-trip. If this works, the rest is incremental.

## Phase 2 — the validator is the product

Reject or repair what the engine cannot render, and SAY what was changed:
`display:flex|grid`, `border-radius`, `box-shadow`, `opacity`, `transform`,
`calc()`, `rgba()`/`hsla()`, `font-family: ZapfDingbats|Symbol`, loop tags placed
between rows rather than inside cells, `{PageNumber}` in the body. "Removed 3
things the PDF engine ignores" is the difference between a demo and a tool
someone trusts with a customer document.

## Phase 3 — conversational refinement

"Make the header darker", "add a totals row". Needs the current body as context,
which the staging field already provides. This is the actually-useful
interaction; phase 1 exists to earn the right to build it.

## Open questions to answer first

1. Exact `ConnectApi` surface for the target API version — it has moved between
   releases. Verify against the version the package targets, not the docs' latest.
2. What Agentforce licensing a SUBSCRIBER needs. The feature must degrade
   gracefully to today's copy-paste prompt when absent, never error.
3. Whether Prompt Builder's Field Generation can be packaged, or whether the org
   must own the prompt template. This decides if it ships or is documented setup.

## Design constraint

Build behind a provider interface with a stub implementation. The validator,
the staging field, the CV write and the Designer load can all be built and
tested with a canned response — no entitlement required — so the blocker above
only gates the final wiring.
