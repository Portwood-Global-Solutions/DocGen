# Generate templates with Agentforce — setup

**The setup and usage instructions live in the UserGuide, section 5.7.11.** That
is the version customers read at <https://portwood.dev/guide>, so it is the one
that gets kept current. This file exists only so links in the Apex source have
somewhere to land, and to hold the engineering notes that do not belong in a
customer document.

→ [UserGuide.md § 5.7.11 — Generate the template with Agentforce](../UserGuide.md#5711-generate-the-template-with-agentforce-v346)

## Engineering notes, not for the UserGuide

**Why the provider class cannot ship in the package.** It references
`ConnectApi.EinsteinLLM`, which is not a visible Apex type without the Einstein
entitlement. The package _builds_ fine — with the correct scratch-org recipe the
build org can have Einstein — but **install into a subscriber org without it is
refused**:

```
ApexClass Type is not visible: ConnectApi.EinsteinLLM
Details: DocGenEinsteinProvider: Type is not visible: ConnectApi.EinsteinLLM
```

Buildable is not installable. Both are measured; see
`docs/AGENTFORCE_TEMPLATE_PLAN.md` for the full record.

**Why the prompt template cannot ship either.** Including a
`GenAiPromptTemplate` makes the whole package declare a feature requirement, so
every subscriber without Einstein is refused at install:

```
Generative AI Prompt Templates(...) Missing feature — Installing this package
requires the following feature and its associated permissions: Generative AI
Prompt Templates
```

That is worse than the Apex case: it gates the entire product, not one class.

**Why there is no "install the prompt for me" button.** The mechanism exists —
`GenAiPromptTemplate` is absent from the Tooling API and from the Apex Metadata
API, but a self-callout to `/services/data/vXX/metadata/deployRequest` does
deploy it (proven end to end). It is unusable in practice because it requires
`UserInfo.getSessionId()`, which is an immediate AppExchange security-review
failure for a managed package.

**The route that remains open** is an extension package: a separate
Einstein-requiring package carrying the provider class and the prompt template.
The base package needs no change — `DocGenAiProviderFactory` already resolves
the provider in the subscriber namespace first, then in `portwoodglobal`.
