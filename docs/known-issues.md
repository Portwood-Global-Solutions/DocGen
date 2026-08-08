# Known issues

Findings the QA suite reports that are **real and unfixed**, as distinct from suite
staleness or org setup. Each one is reproducible, pre-dates the release it is listed
under, and is written down here so a run that reports it is not mistaken for a
regression.

Raised 2026-08-08 against v3.55.0. All three pre-date it — they are present in v3.54.0
and earlier — so none of them is a regression introduced by that release.

## 1. Bulk generation ignores a template's Record Filter

`DocGenBulkController.getTemplates` passes `null` as the related record id to
`DocGenController.filterTemplatesForSender`, which turns `applyRecordFilter` off. The
batch never evaluates `Record_Filter__c` per record either.

**Consequence:** a template carrying a Record Filter is offered for bulk generation, and
documents are produced for records the filter excludes. Single-record generation applies
the filter correctly; only bulk does not.

The current behaviour is deliberate as far as the code goes — there is a comment saying
"Bulk has no single record, so pass null to apply only sharing + audience filters" — but
the outcome is still a document generated against a record the author said to exclude.
Two honest fixes: evaluate the filter per record inside the batch, or exclude
filter-carrying templates from the bulk picker and say why.

Not changed for v3.55 because altering bulk filtering semantics is a behaviour change
for existing jobs and deserves its own decision, not a release-eve patch.

## 2. The runner offers templates that have no active version

`DocGenController.getTemplatesForObjectInternal` filters on `Is_Active__c` and audience,
but never checks that the template has an active `DocGen_Template_Version__c`.

**Consequence:** the template appears in the runner picker and fails only after the user
presses Generate, with "No template file found (active or attached)". The check belongs
in the query that builds the picker.

## 3. `DocGen_Template_Version__c.Type__c` defaults to Word

The picklist has `Word` marked as its default value. Any code path that creates a
version without setting `Type__c` therefore produces a Word version — and
`DocGenController.activateVersion` copies the version's type onto the template
(`template.Type__c = version.Type__c`), so the mistype propagates to the template and
changes how it generates.

**Consequence:** a programmatically created HTML or Canvas template can silently become
a Word one. `scripts/qa/suites/template-integrity.mjs` exists because of exactly this
and checks every template against its active version.

Removing the picklist default is not obviously the fix: an omitted type would then be
null, and a silent null is no better than a silent Word. The durable fix is for every
creation path to set the type explicitly and for the version to reject a blank one.

## 4. A template created outside the designer opens to an empty canvas

The visual Designer loads a template body from a ContentVersion titled
`docgen_html_body_<templateId>` (and, for pre-decomposed types,
`docgen_tmpl_xml_<templateId>`). It does **not** read the active version's
`Content_Version_Id__c`.

**Consequence:** a template whose body was written any other way — the API, a script, a
data load — generates perfectly but opens to a blank designer, with nothing to say why.
The fix from the author's side is to re-save once through the Template Manager UI, which
writes the CV the designer expects.

`scripts/qa/suites/template-integrity.mjs` checks this directly ("every HTML template
returns a body to the visual Designer") and will report any fixture created by script.
That is the check working, not a fixture problem: the same thing happens to a customer
who builds templates through the API.

The durable fix is for the designer to fall back to the active version's
`Content_Version_Id__c` when the well-known title is absent.

## 5. Signature Flow actions are not bulkified

`Validate Signature Token` queries per request. A Flow that hands the action a batch —
the suite uses 60, the platform allows up to 200 — hits `Too many SOQL queries: 101` and
the interview faults. `flow-actions` separately reports SOQL and DML inside the
per-request loop of `DocGenFlowAction.generateDocument`.

**Consequence:** any Flow that processes signature tokens in bulk fails partway with a
governor limit rather than returning results. Single-request Flows are unaffected, which
is why this has gone unnoticed.

## 6. Signature actions fault the Flow instead of returning an error

`Create Signature Request` throws `DocGenException` for a null Template Id, a null
Related Record Id, an empty Signers collection, or a signer with no email —
the four most common author mistakes. `Finalize Signature Image` throws
`SignatureException` on a malformed token.

Both actions publish `Success` and `Error Message` output variables. On these paths those
outputs are unreachable: the interview faults before it can read them, so a Flow author
who wired up error handling never sees it run.

Deliberate per the class comment, but it makes the two advertised outputs a lie for
exactly the cases they exist to report. Either validate into `Result.success = false`, or
drop the outputs and document that these actions fault.
