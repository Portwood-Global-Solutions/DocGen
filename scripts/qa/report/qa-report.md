# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-26T13:08:37.461Z · **Duration** 20s

## Headline

|                       |          |
| --------------------- | -------- |
| Checks evaluated      | 2        |
| Passed                | 2 (100%) |
| Failed                | 0        |
| Skipped (not counted) | 1        |
| Blockers              | 0        |
| Major                 | 0        |
| Minor                 | 0        |

## Coverage by area

| Suite                | Area               | Passed | Failed | Skipped | Rate |
| -------------------- | ------------------ | -----: | -----: | ------: | ---: |
| `template-integrity` | Template integrity |      2 |      0 |       1 | 100% |

## What to fix

Nothing — every evaluated check passed.

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `template-integrity` — merge-tag pills stay inside their table cells: could not open a template in the Designer: no Designer tab

## Every check

### template-integrity — Template integrity

- ✅ every HTML template returns a body to the visual Designer — all 6 HTML templates return a non-empty body from getHtmlTemplateBody
- ✅ each template agrees with its active version about its own type — no template/version type disagreements
- ⊘ merge-tag pills stay inside their table cells — could not open a template in the Designer: no Designer tab
