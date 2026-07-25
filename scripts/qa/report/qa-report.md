# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T23:33:13.045Z · **Duration** 13s

## Headline

|                       |           |
| --------------------- | --------- |
| Checks evaluated      | 14        |
| Passed                | 14 (100%) |
| Failed                | 0         |
| Skipped (not counted) | 1         |
| Blockers              | 0         |
| Major                 | 0         |
| Minor                 | 0         |

## Coverage by area

| Suite         | Area        | Passed | Failed | Skipped | Rate |
| ------------- | ----------- | -----: | -----: | ------: | ---: |
| `pdf-content` | PDF content |     14 |      0 |       1 | 100% |

## What to fix

Nothing — every evaluated check passed.

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `pdf-content` — the table header repeats on later pages (giant path): this render took the ORDINARY path — no -fs-table-paginate in the output, 2101 rows in one table — so per-page headers were never promised for it, and the headings correctly appear on 1 of 59 pages. The giant branch is chosen on an estimated HEAP, not a row count, so slim rows never reach it however many there are. Covering the repeat needs a seed whose rows are fat enough to cross that estimate.

## Every check

### pdf-content — PDF content

- ✅ the dataset is large enough to exercise multi-page rendering — 2100 child rows across many pages (the giant branch is chosen on estimated heap, not on this count)
- ✅ the giant template generates — 442611 bytes in 5216ms (CPU 4666ms of 10000)
- ✅ the giant render leaves CPU headroom — 4666ms of the 10000ms synchronous limit (47%) at 2100 rows
- ✅ the giant document spans many pages — 59 pages from 2100 rows
- ✅ the document title survives the giant-query path — "PDFQA Master Roster" is on the page
- ✅ text above the table survives the giant-query path — intro paragraph present
- ✅ the column headers are rendered — "Contact Full Name" present
- ⊘ the table header repeats on later pages (giant path) — this render took the ORDINARY path — no -fs-table-paginate in the output, 2101 rows in one table — so per-page headers were never promised for it, and the headings correctly appear on 1 of 59 pages. T
- ✅ the footer appears on every page — footer on 59 of 59 pages
- ✅ the running header appears on every page — header on 59 of 59 pages
- ✅ page-number tags resolve rather than printing literally — counters resolved
- ✅ the footer reports the true page total — footer says "of 59", matching the actual page count
- ✅ merged child data is on the page — first seeded row and an email address both present
- ✅ no unresolved merge tag is printed — no raw tags on the page
- ✅ the last child row is present, not truncated — row 2100 of 2100 rendered
