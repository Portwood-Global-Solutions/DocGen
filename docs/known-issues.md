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
