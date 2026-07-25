# DocGen QA harness

One command runs every kind of test this package has and produces one report.

```bash
npm run qa                     # everything, against docgen-verify
npm run qa -- --org myorg
npm run qa -- --offline        # only suites that need no org (CI-safe)
npm run qa -- --fast           # skip the slow suites
npm run qa -- --suite merge-tags,metadata-audit
npm run qa -- --headed         # watch the browser suites
npm run qa -- --list
```

Output lands in `scripts/qa/report/`:

- `qa-report.md` — headline numbers, coverage by area, and an ordered **what to fix** list
- `qa-report.json` — the same data, for tracking the numbers over time

Exit code is `0` only when every evaluated check passed, so this drops straight
into CI.

## Why it exists

The evidence that this package worked used to live in three places nobody ran
together: an Apex unit run, a hand-run sequence of anonymous Apex scripts, and a
browser smoke test for one component. Everything else — page layouts, permission
sets, Flow actions, the runner UI, the merge-tag matrix, every output format —
was verified by a person clicking, or not at all.

## The result contract

Every suite returns the same shape, which is the only reason suites written
independently can aggregate into one number:

```js
import { check, skip, suiteResult, SEVERITY } from '../lib/report.mjs';

export async function run({ org, headed }) {
    return suiteResult('my-suite', 'My area', [
        check('the thing does the thing', ok, 'evidence either way', SEVERITY.MAJOR),
        skip('the thing I could not reach', 'why not') // NOT counted as a pass
    ]);
}
```

Three rules keep the report honest:

1. **A skipped check is never a pass.** Skips are counted and listed separately,
   so a suite that quietly stops testing cannot report 100%.
2. **Severity is a work queue, not decoration.** `blocker` = a customer cannot
   finish the job. `major` = broken with a workaround. `minor` = cosmetic.
3. **`detail` must say where to look.** On failure it is the only thing standing
   between a red line and an hour of hunting.

Suites must never throw. A suite that cannot run returns `suiteSkipped()` so the
report says so out loud.

## Suites

| Suite            | Needs an org | What it proves                                                                                                                               |
| ---------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `metadata-audit` | no           | Every field is on a layout and granted to admins; secrets are NOT on layouts; exposed LWCs are reachable                                     |
| `apex-unit`      | yes          | Per-class Apex results, plus which production classes have no test at all                                                                    |
| `apex-e2e`       | yes          | The `scripts/e2e-*.apex` release sequence, parsed — including the silent case where a governor limit kills a script and it prints no summary |
| `merge-tags`     | yes          | Every merge-tag syntax and modifier, and the edge cases around them                                                                          |
| `flow-actions`   | yes          | Every `@InvocableMethod` and the managed-package visibility rules Flow depends on                                                            |
| `output-formats` | yes          | PDF/DOCX/PPTX/XLSX generation produces genuinely valid files, including the giant-query path                                                 |
| `ui-designer`    | yes          | The existing `ui-smoke.mjs` behavioural assertions, folded in                                                                                |
| `ui-admin`       | yes          | Every button, tab and input in the admin UI outside the designer                                                                             |
| `ui-runner`      | yes          | The end-user components: runner, bulk runner, signature sender                                                                               |
| `record-pages`   | yes          | Every object's record page renders its fields in a real org                                                                                  |

## Writing browser checks — rules learned the hard way

These each cost a false result before they were understood. `lib/browser.mjs`
bakes in what it can; the rest is on you.

1. **Bust Lightning's IndexedDB cache** before believing anything. `login()`
   does it. Skipping it means testing a bundle that is no longer deployed.
2. **Pierce shadow roots.** Use `inPage()` / `__dgFind`; a plain
   `document.querySelector` finds nothing.
3. **Synthetic events are not real ones.** CSS `:hover` ignores a dispatched
   `mousemove`, and a dispatched `keydown` never triggers the browser's own
   editing. Use `page.mouse` / `page.keyboard` when the browser's reaction _is_
   the thing under test.
4. **`inPage()` bodies are template literals.** `\s` collapses to a literal
   `s` — write `\\s` or avoid escapes. This silently rewrote a regex once and
   produced a confident, wrong failure.
5. **Assert behaviour, not layout.** "The button exists" proves nothing; a
   toolbar rewrite once measured perfectly and was completely broken.
6. **Prove a control is reachable**, not just present, with `HIT_TEST` —
   `opacity: 0` does not remove an element from hit-testing.

## Measure, do not infer

Four of this harness's own early findings were bugs in the harness, not the
product. That is the failure mode to guard against hardest, because a report
that cries wolf gets switched off:

- Two "blockers" in the first full run were a namespace matcher that prefixed
  `Object.Field` once instead of both halves, and a CLI command line too long to
  execute.
- **32 classes were reported as "untested surface"** by a check that asked
  whether a \*Test class NAME contained the production class name. Classes
  covered by shared test files like `DocGenMiscTests` read as untested. That was
  a guess presented as a measurement; coverage now comes from
  `ApexCodeCoverageAggregate`.
- A delete check failed the moment a confirmation dialog was added, because
  detecting a dialog is not the same as answering one.

So: read the number from the system that owns it. If a check cannot measure the
thing it claims to measure, make it a `skip` with the reason — never a pass, and
never a proxy dressed up as the real thing.

Two suites also disagreed with each other about the same field, which is worse
than either being wrong. Shared policy lives in `lib/field-policy.mjs` for
exactly that reason.
