# Portwood DocGen — Example Template Library

A set of **ready-to-adapt HTML document templates** for **Portwood DocGen**,
spanning 9 industries. Use them as starting points for your own templates: copy a
body, point it at your own object/fields, and load it into the DocGen Template
Builder.

> These are **example template bodies**, not an installer. They show real-world
> layouts (line-item loops, signatures, charts, QR/barcodes, multi-page scale)
> built within the constraints of the PDF engine.

---

## How to use a template

1. Open one of the `.html` files under `html/<industry>/` and review the layout.
2. In DocGen, create a new template (HTML output) and paste the body in.
3. Replace the merge tags (`{Field}`, `{#ChildRelationship}…{/ChildRelationship}`,
   `{@Signature_*}`, chart tags, etc.) with your own object's fields and
   relationships.
4. Set the template's base object, query config, and a test record, then generate.

The tags used here are documented in the main DocGen User Guide; field/relationship
authoring rules specific to these examples are in `DATA-DICTIONARY.md`.

---

## Template catalog (HTML)

| Industry       | Template                       | Showcases                                         |
| -------------- | ------------------------------ | ------------------------------------------------- |
| Prof. Services | Statement of Work              | line items, fees, **signatures**                  |
| Prof. Services | Sales Proposal                 | exec summary, **pipeline bar chart**, SUM/COUNT   |
| Prof. Services | Engagement Letter              | letter format, **signature + date**               |
| Prof. Services | Invoice with QR Pay-Link       | line items, **QR code**, SUM total                |
| Manufacturing  | Packing Slip                   | ship-to, **checkbox column**, qty totals          |
| Manufacturing  | Wholesale Price List           | family-grouped list, zebra rows                   |
| Manufacturing  | Price List with Barcodes       | **barcode per row**, catalog loop                 |
| Manufacturing  | Giant Price List               | **2,200-row scale**, repeating headers            |
| Financial      | Account Statement              | txn loop, running balance, **activity bar chart** |
| Financial      | Homeowner Policy Schedule      | coverage table, declarations page                 |
| Financial      | Loan Estimate                  | loan terms, **borrower signature**                |
| Real Estate    | Purchase Agreement             | clauses, **buyer/seller initials + signatures**   |
| Real Estate    | Non-Disclosure Agreement       | mutual NDA, **two-party signatures**              |
| Events         | Attendee Badge                 | printable name badge                              |
| Events         | Event Program                  | brochure, registration count                      |
| Events         | Attendee Roster                | child loop, check-in column                       |
| Nonprofit      | Donation Tax Receipt           | gift details, IRS language                        |
| Nonprofit      | Donor Impact Report            | gift loop, **giving-by-program bar chart**        |
| Certificates   | Certificate of Completion      | ornate border (landscape)                         |
| Education      | Report Card                    | grades loop, GPA                                  |
| Education      | Enrollment Verification Letter | **registrar signature**, seal                     |
| Education      | Course Schedule                | course loop, credit totals                        |
| Transcripts    | Official Academic Transcript   | full coursework, quality points, GPA              |

---

## Authoring constraints (important)

The PDF engine is **Flying Saucer (CSS 2.1)** and most documents are generated
server-side. When editing these templates:

- **HTML:** table-based layout only. No flex/grid/gap/calc/CSS-vars/gradient/shadow.
- **Charts (server-side / Flow):** only `bar`, `stacked`, `clustered`, `pivot`.
  `pie`/`donut`/`line`/`area`/`column` render only through the Runner UI. Always
  use the field **API name** in the chart tag.
- **`{PageNumber}`/`{TotalPages}`** only work in the template footer field, not the body.
- **QR / barcodes** (`{*Field:qr}` / `{*Field:code128}`) are **Word-only**; the
  examples that use them were authored as Word templates.

Full field/relationship reference: `DATA-DICTIONARY.md`.
