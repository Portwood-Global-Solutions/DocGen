# DocGen QA report

**Org** `docgen-demo` · **Run** 2026-07-26T01:59:18.086Z · **Duration** 75s

## Headline

|                       |          |
| --------------------- | -------- |
| Checks evaluated      | 3        |
| Passed                | 3 (100%) |
| Failed                | 0        |
| Skipped (not counted) | 0        |
| Blockers              | 0        |
| Major                 | 0        |
| Minor                 | 0        |

## Coverage by area

| Suite                | Area               | Passed | Failed | Skipped | Rate |
| -------------------- | ------------------ | -----: | -----: | ------: | ---: |
| `template-integrity` | Template integrity |      3 |      0 |       0 | 100% |

## What to fix

Nothing — every evaluated check passed.

## Every check

### template-integrity — Template integrity

- ✅ every HTML template returns a body to the visual Designer — all 24 HTML templates return a non-empty body from getHtmlTemplateBody
- ✅ each template agrees with its active version about its own type — no template/version type disagreements
- ✅ merge-tag pills stay inside their table cells and none is covered — 2 pills in cells of "Skip to NavigationSkip to Main ContentMenuScratch OrgShow me": none overflowing, none covered
