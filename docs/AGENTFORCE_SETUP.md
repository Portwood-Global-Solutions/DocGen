# Generate templates with Agentforce — setup

DocGen's Designer can write and revise HTML templates by prompting Salesforce AI
inside your own org, instead of copying a prompt out to ChatGPT and pasting HTML
back. This page is the whole setup: four steps, about ten minutes.

**You do not need any of this to use DocGen.** Without it the Designer simply
hides the Agentforce button and the existing **Copy AI Prompt** workflow is
unchanged. Nothing else is affected.

## Why there is a setup step at all

Two pieces cannot ship inside the DocGen package, for reasons that are technical
rather than commercial:

- **The Apex class that calls Einstein.** It references `ConnectApi.EinsteinLLM`,
  which is not a visible Apex type in an org without the Einstein entitlement —
  including the temporary org Salesforce uses to build the package. A package
  containing it fails to compile at build time, before anyone could install it.
- **The prompt template.** Prompt Builder generates its own version identifier,
  so a template cannot be authored into package metadata at all.

Both therefore live in your org, where your entitlement applies.

## What you need first

- Einstein Generative AI / Prompt Builder enabled.
- The **Einstein GPT Prompt Template Manager** permission set (or equivalent) on
  whoever will create the prompt template.
- The DocGen **DocGen Admin** permission set on whoever will use the Designer.

If you are not sure whether Einstein is on, run this in Developer Console →
Anonymous Apex. If it fails to compile, Einstein is not enabled yet:

```apex
ConnectApi.EinsteinPromptTemplateGenerationsInput probe = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
System.debug('Einstein Apex types are visible');
```

## Step 1 — Create the prompt template

**Setup → Einstein → Prompt Builder → New Prompt Template.**
(The Setup node is _Prompt Builder_; a direct link to `EinsteinGPTPromptTemplates`
returns "Page not found" — use the tree or Quick Find.)

| Field                | Value                                             |
| -------------------- | ------------------------------------------------- |
| Prompt Template Type | **Flex**                                          |
| Prompt Template Name | DocGen HTML Body                                  |
| API Name             | `DocGen_HTML_Body`                                |
| Input                | Type **Free Text**, name `Instructions`, required |

For the prompt body, enter a line of framing and then insert the input resource:

```
You generate HTML document templates for Portwood DocGen, which renders HTML to
PDF with Flying Saucer (CSS 2.1 only). Follow the instructions below exactly.
Return only a complete, self-contained HTML document. Do not wrap it in markdown
code fences and do not add commentary. Instructions: {{Input.Instructions}}
```

Insert `{{Input.Instructions}}` using **Insert Resource → Inputs → Instructions**
rather than typing it, so it binds properly.

Then **Save**, and **Activate**. An inactive template returns no content.

> This template is deliberately thin. DocGen assembles the real prompt — your
> object's fields and relationships, the merge-tag syntax, the PDF engine's CSS
> constraints, and what the author asked for — and passes the whole thing in as
> `Instructions`. That accumulated constraint set is what makes the output
> render correctly, so there is no need to elaborate here.

## Step 2 — Deploy the provider class

Take `force-app/main/default/classes/DocGenEinsteinProvider.cls` from the
[DocGen repository](https://github.com/Portwood-Global-Solutions/DocGen) and
deploy it to your org:

```bash
sf project deploy start -o <your-org> \
  -d force-app/main/default/classes/DocGenEinsteinProvider.cls
```

Or paste it into a new Apex class in Setup → Apex Classes.

**If DocGen is installed as a managed package**, add the namespace prefix in two
places (both are marked with a comment in the file):

```apex
public with sharing class DocGenEinsteinProvider implements portwoodglobal.DocGenAiProvider {
    ...
    String configured = portwoodglobal.DocGenAiProviderFactory.configuredPromptTemplate();
```

## Step 3 — Point DocGen at it (optional)

**Setup → Custom Settings → DocGen Settings → Manage → New / Edit.**

| Setting            | Leave blank to use       |
| ------------------ | ------------------------ |
| AI Provider Class  | `DocGenEinsteinProvider` |
| AI Prompt Template | `DocGen_HTML_Body`       |

Only fill these in if you named your class or template something else. The
provider class is resolved in your namespace first, then in `portwoodglobal`.

## Step 4 — Check it

Open any HTML template in the Designer. **Generate with Agentforce** should
appear in the toolbar next to Copy AI Prompt. If it does not, see Troubleshooting.

Or verify from Anonymous Apex:

```apex
System.debug(DocGenAiTemplateController.isAiAvailable());   // expect true
System.debug(DocGenAiProviderFactory.get().getName());      // expect 'Einstein'
```

## Using it

**From the wizard.** Choose **Generate with AI**, describe your document, and
click **Generate it here with Agentforce**. The HTML is checked and dropped in;
continue to Review & Create and the Designer opens on it.

**From the Designer.** **Generate with Agentforce** offers two modes:

- **Edit what is on the canvas** (the default) — your instruction is sent with
  the current template, unsaved edits included, and Agentforce revises it.
  Nothing is discarded.
- **Start over from scratch** — writes a new document. This replaces what is on
  the canvas, so it asks you to confirm first.

Two things that make results markedly better:

1. **Name concrete values.** "Change the header band to `#184d47`" is applied far
   more reliably than "make it dark green".
2. **Be explicit about each change.** Multi-part instructions are honoured, but
   spell them out: "change X, add Y, and make Z bold".

### What the report is telling you

Every generation is checked against the PDF engine's real capabilities before
anything is saved, and you get a list of what changed:

- **Repaired** — rewritten into something the engine understands. `rgba()` tints
  become flat hex, gradients become their first colour, `{!Field}` becomes
  `{Field}`. Your design intent survives.
- **Removed** — the engine ignores it entirely, so leaving it in the source would
  be misleading. `border-radius`, `box-shadow`, `opacity`, `@media`.
- **Check this** — we cannot fix it and you may need to. Most importantly, on an
  edit, **merge tags that were in the template before and are not in the result**.
  A lost tag renders as nothing, which is invisible on screen. If it was not
  something you asked for, click **Reload** to get the previous body back.

Previous bodies are never destroyed: every save writes a new file version, so
earlier ones remain in the template's file history.

## Troubleshooting

**The button does not appear.**
`isAiAvailable()` returned false. Check the class name matches AI Provider Class
(or is `DocGenEinsteinProvider`), that it compiled, and that it implements the
interface — with the `portwoodglobal.` prefix on a managed install.

**"Failed to generate Einstein LLM generations response"**, with no more detail.
Almost always `additionalConfig.applicationName` missing from the ConnectApi
call. The shipped provider sets it; if you wrote your own, set it too.

**"...does not implement the DocGenAiProvider interface"**
The class was found but the `implements` clause is missing or unprefixed.

**"Einstein returned no content"**
The prompt template exists but has no **active** version. Open it and Activate.

**The model returns "I do not know."**
It received an instruction with no template attached. Report it — DocGen should
be sending the current body, and refusing to call at all when it cannot read it.

## What this costs and where data goes

Generation runs through `ConnectApi`, not an HTTP callout — `Limits.getCallouts()`
stays at zero. Your template content and schema are handled by Salesforce's own
Einstein trust layer and never leave the platform. This is the reason the feature
exists at all: DocGen is a 100% native package, and a provider that made an
external callout would break that guarantee for the whole product.

Expect 10–25 seconds per generation, and Einstein usage consumed against your
org's entitlement.
