---
name: package-release
description: >-
    Review/bring in contributor PRs and cut a new Portwood DocGen managed-package
    version. Use when asked to "make a new package", "cut a release", "bring in /
    review / merge these PRs", bump the version, build/promote a package version,
    or when a `sf package version create` fails. Encodes the gotchas that pass a
    no-namespace scratch but fail the namespaced packaging build, the doc/picklist
    completeness checks, the three release-validation gates, and the
    bump→build→promote→alias→rollout steps.
---

# Packaging & release playbook (Portwood DocGen Managed, 2GP, ns `portwoodglobal`)

The goal: bring contributor work in and ship a managed-package version **without
burning a 20–40 min build on a failure that was findable up front**. Most failures
come from a small set of recurring traps that a no-namespace scratch org cannot
surface. This skill is the checklist for _what to look for and what to edit_.

Canonical gate commands + package IDs live in `CLAUDE.md` — don't duplicate them,
read them there. This skill is the _sequence + the traps_.

---

## Phase 0 — Intake (PRs are usually from a FORK)

```bash
gh pr list --state open --json number,title,headRefName,author,isCrossRepository
gh pr view <n> --json number,title,body,files,additions,mergeable,isCrossRepository,headRepositoryOwner
gh pr checks <n>
gh pr diff <n>
git fetch origin "refs/pull/<n>/head:pr-<n>"
```

- **Fork PRs (`isCrossRepository: true`)** — you can MERGE them via `gh pr merge <n> --merge --admin` (server-side; no fork access needed), but you **cannot push fixes to the fork's branch**. If a fork PR needs a fix, merge it, then land the fix as a **follow-up commit on `main`** (cherry-pick), or hand it back. Pushing `feat/x` to _origin_ just makes a parallel branch — it does **not** update the fork PR.
- Validate PRs **stacked on `main`** (merge them into one integration branch off `main`) so the gates exercise the combined result. They usually touch disjoint files and merge clean.
- Dave is sole reviewer → self-approve comment + `--admin` merge. Preserve per-issue history with `--merge` (not squash) when the author asks.

---

## Phase 1 — Pre-build review: what to look for (the high-value part)

These all **compile and pass a no-namespace scratch** but break the namespaced
packaging build or production. Grep for them in the PR diff _before_ validating.

### 1. Namespace traps (THE recurring build-killer)

The packaging build runs Apex tests in a **namespaced** org where every packaged
field/object is `portwoodglobal__X`. A no-namespace scratch never sees this.

- **`getPopulatedFieldsAsMap().get('Field__c')`** → returns null in the package
  (keys are namespace-prefixed). Use direct field access. `grep -rn getPopulatedFieldsAsMap`.
- **Dynamic SOQL** (`Database.query('… Field__c …')`) with bare field names →
  `QueryException: No such column 'Field__c' on entity 'portwoodglobal__Obj__c'`
  (namespaced object, bare column = the fingerprint). Build field lists from
  `Schema.describe`, not literals. `grep -rn "Database.query"`.
- **Brand-new picklist field referenced in static SOQL** can throw the same
  half-namespaced "No such column" in the build org even though static SOQL
  _should_ auto-namespace — often a **transient propagation flake** in the
  ephemeral build org. **Retry the build once.** If it fails identically it's
  deterministic → reproduce in a real namespace dev org (deploy the object, query
  the field) instead of guessing.
- **Rule of thumb:** scratch `RunLocalTests` passing is necessary but **NOT
  sufficient** — the namespaced `sf package version create --code-coverage` run is
  the real gate. Budget for one rebuild.

### 2. `@TestVisible private` ↔ anonymous Apex

`@TestVisible` grants access **only from `@IsTest` code**, NOT from anonymous Apex.
The `scripts/e2e-07-*.apex` gate scripts run as anonymous Apex, so any reference to
a `@TestVisible private` member (e.g. `DocGenService.assetCvCache`,
`imageCvCache`) is a **compile failure** that fails that whole e2e script.

- `grep -n "DocGenService\.\|DocGen[A-Za-z]*\." scripts/e2e-07-*.apex` for cross-class private refs.
- Per-transaction cache resets are pointless in anon Apex anyway (fresh transaction → static starts null). Drop them.
- **Prettier passing ≠ compiling.** Always actually RUN the e2e scripts.

### 3. Restricted picklist values on EXISTING objects → manual upgrade step

2GP does not reliably propagate **new values added to a restricted picklist on an
existing object** on upgrade (fresh installs are fine). If a PR adds one, it needs
a **§15 Troubleshooting** entry telling admins to add it by hand (mirrors the
`Type` HTML/Excel and `Signing_Order` `Single` entries).

- Check each changed `*/fields/*.field-meta.xml`: `<restricted>true</restricted>` + a _new_ `<value>` on a _pre-existing_ field → needs the entry.
- **Not** required for: unrestricted picklists (Apex writes off-list values, e.g. `Job.Status__c` `Recovering`/`Completed with Errors`), or values that ship _with a brand-new field/object_ (e.g. `Placement_Type__c` born with `Date`/`DatePick` in v1.43; `Asset_Type__c` on the new `DocGen_Asset__c`).

### 4. Other managed-package / FLS traps

- **Internal CV reads must be `WITH SYSTEM_MODE`** + FLS guard — the `docgen_tmpl_*`
  snapshot CVs have CDL `Visibility=InternalUsers`, so `WITH USER_MODE` silently
  returns empty. New unguarded `SELECT` in a trigger/handler → `code-analyzer` High
  (`pmd:ApexCRUDViolation`): add `WITH SYSTEM_MODE` + `// NOPMD ApexCRUDViolation — …` on the statement line.
- **Guest vs admin FLS guards** on signing paths — guest signers need
  `DocGenFlsGuard.guest*` variants; admin variants throw for guest/Automated-Process contexts.
- **Only `global` Apex is subscriber-visible.** A Flow `@InvocableMethod` must be
  `global`; a Flow Apex-Defined variable type needs ALL of: top-level class +
  `global` + `@AuraEnabled` members + `global` no-arg ctor.
- **`processXml` try/catch must rethrow `HeapPressureException`** before the generic
  catch (it's the giant-query control-flow signal). Run `RunLocalTests`, not just e2e-07.
- **Three merge-tag paths** — a parser fix in `processXml` may also need mirroring in
  `DocGenGiantQueryAssembler` (parent + giant-query paths). Add an e2e-07 assertion either way.

---

## Phase 2 — Documentation completeness

- **UserGuide.md** — every _user-facing_ change must be documented. Grep the
  UserGuide for the feature's tag/field/UI term; if absent, add it. (Internal
  refactors/bugfixes like a doc-title fix need no entry.)
- **Picklist troubleshooting (§15)** — confirm any _new restricted value on an
  existing object_ (Phase 1.3) has its manual-add note. New objects / unrestricted
  fields do **not** need one — say so explicitly when reporting.
- Run `npm run format` then `npm run format:check` after editing docs (CI gate).

---

## Phase 3 — Validate on a no-namespace staging scratch (3 gates)

Create with `--no-namespace` (bare class/field refs in e2e scripts must compile),
assign `DocGen_Admin`, deploy the integration branch, then run all three gates from
`CLAUDE.md`:

1. **e2e** — 11 scripts, each must print `FAIL: 0`. Capture the `USER_DEBUG` summary
   lines (not the echoed source). The script a PR _modified_ is the one to watch.
2. **RunLocalTests** — `Outcome: Passed`, 100% pass, org-wide ≥ 75%.
3. **`sf code-analyzer`** — **0 High**. (~30 Moderate false positives are fine.)

For front-end-only PRs (a VF page / LWC), the gates won't exercise the JS — do a
**browser walkthrough** (token-auth the signing page; set `PIN_Verified_At__c` via
Apex to skip the email gate) and confirm the real behavior + backend state.

---

## Phase 4 — Version bump (`sfdx-project.json`, `packageDirectories[0]`)

Patch versioning is **disabled** on the namespace → always bump the **minor**
(vX.Y.0 → vX.(Y+1).0). Edit:

- `versionName` — INTERNAL (engineering): `"v3.22.0 — <short feature list>"`.
- `versionNumber` — `"3.22.0.NEXT"`.
- `ancestorId` — the **last RELEASED** version's alias id (the most recent
  `Portwood DocGen Managed@X.Y.0-1` in `packageAliases`). NOT `ancestorVersion`.
- `versionDescription` — **CONSUMER-friendly** product copy (shows in the
  AppExchange install dialog). Marketing tone, not engineering notes. End with
  "100% native Salesforce — no external services or callouts. Free for all users."
  Engineering detail goes in `CHANGELOG.md`, never here.

Commit + push the bump to `main` before building.

---

## Phase 5 — Build (the namespaced packaging org = the real gate)

```bash
sf package version create --package "Portwood DocGen Managed" \
  --installation-key-bypass --code-coverage --wait 120 \
  --target-dev-hub dave@portwoodglobalsolutions.com --json
```

Run it **in the background** (~20–40 min; runs `RunLocalTests` in the namespaced
build org defined by `config/build-def.json`). On failure read the JSON `message`:

- `No such column 'Field__c'` on a new field → Phase 1.1 (retry once; then reproduce in a namespace org).
- Test failures → it's a namespace trap the scratch missed (Phase 1) — fix, re-push, rebuild.
- Translations / `edition cannot be specified` → `build-def.json` org-shape issue (see CLAUDE.md).

## Phase 6 — Promote + alias + commit

```bash
sf package version promote --package <04tVx…> --target-dev-hub dave@portwoodglobalsolutions.com
```

Then add the new alias to `packageAliases` (`"Portwood DocGen Managed@3.22.0-1": "04tVx…"`),
commit + push. Record the install URL:
`https://login.salesforce.com/packaging/installPackage.apexp?p0=<04tVx…>` (sandbox = test.salesforce.com).

## Phase 7 — Rollout (confirm scope with Dave — it varies per release)

- **README** version badge + release table; **GitHub release** (`gh release create`).
- **DemoBox** — upgrade via the **package** (`sf package install`).
- **Production (`portwood-prod`)** — **SOURCE deploy only, NEVER the package**
  (a managed package in prod locks components + breaks the sandbox-refresh→source-deploy
  workflow). **DevBox** — source deploy. (DevBox=source, DemoBox=package, Prod=source.)
- Demo kit stays on a local-only branch (templates-only to GitHub).

---

## Quick gotcha table

| Symptom                                                                    | Cause                                                    | Fix                                                              |
| -------------------------------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------- |
| `No such column 'X__c' on portwoodglobal__Obj__c` in build, passes scratch | dynamic SOQL bare field / new picklist propagation flake | Schema-derive field lists; retry build once; reproduce in ns org |
| `.get('Field__c')` null only in package                                    | `getPopulatedFieldsAsMap` ns keys                        | direct field access                                              |
| e2e-07 script won't compile                                                | `@TestVisible private` ref from anon Apex                | remove ref / use global API                                      |
| `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` after upgrade                    | new value on existing restricted picklist                | §15 manual-add note + admin step                                 |
| Giant-query output drops chrome / empty snapshot                           | internal CV read `WITH USER_MODE`                        | `WITH SYSTEM_MODE` + FLS guard                                   |
| `code-analyzer` High `ApexCRUDViolation`                                   | unguarded SOQL/DML                                       | `WITH SYSTEM_MODE` + `// NOPMD ApexCRUDViolation — …`            |
| Guest signer "insufficient access" write                                   | admin FLS guard on guest path                            | `DocGenFlsGuard.guest*` variant                                  |
| Flow can't see Apex action/type                                            | `public` not `global` / inner class                      | top-level + `global` + `@AuraEnabled` + `global` ctor            |

## Related memories

`feedback_getpopulatedfieldsasmap_namespace`, `feedback_testvisible_not_in_anon_apex`,
`feedback_internal_cv_reads_must_be_system_mode`, `feedback_flow_apexdefined_managed_pkg_recipe`,
`feedback_package_descriptions_consumer_friendly`, `project_patch_versioning_disabled`,
`feedback_processxml_heappressure_passthrough`, `feedback_dave_sole_coder_admin_bypass`.
