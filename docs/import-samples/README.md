# HTML → Canvas import samples

Five real HTML template bodies, generated from the shipped starters
(`docGenAuthoringKit.buildStarterHtml`). They exist so the importer can be exercised by
hand against documents the product actually produces, rather than against something
written to make the importer look good.

Open a **Canvas** template in the Designer and use **Import HTML** in the toolbar.

| File               | What it exercises                                                     |
| ------------------ | --------------------------------------------------------------------- |
| `report.html`      | Title band, a details table, a table per child relationship           |
| `invoice.html`     | Billed-to block, line-item loop, totals row                           |
| `letter.html`      | Dense prose — the case where margin collapsing decides the page count |
| `agreement.html`   | Numbered terms and `{@Signature_*}` placement tags                    |
| `certificate.html` | Landscape, nested frame borders, centred layout                       |

## What "lossless" was measured against

`node scripts/qa/canvas-import-fidelity.mjs` converts all five and compares merge tags,
tables, rows, cells, images and words between the source and the converted body. All
five pass.

Three were also rendered through the engine and compared as PDFs:

| Starter     | Pages | Page size         | Rendered words |
| ----------- | ----- | ----------------- | -------------- |
| Report      | 1 → 1 | 612×792 → 612×792 | identical      |
| Certificate | 1 → 1 | 792×612 → 792×612 | identical      |
| Letter      | 1 → 1 | 612×792 → 612×792 | identical      |

## What import does NOT do

- It never changes an HTML template into a Canvas one. The file is read in the browser
  and written to whichever Canvas template is already open; the source template is not
  touched.
- It is one-way. Flowing content becomes discrete boxes, and there is no route back.
- It reports what it could not carry — running headers/footers, multi-column layout,
  scripts — rather than dropping them quietly.

Tables come across as markup so they render exactly as before, which means the table
tool cannot edit them. That is stated in the conversion report at import time.
