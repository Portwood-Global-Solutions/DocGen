# Portwood DocGen — Demonstration Environment

A complete, reproducible demo environment for **Portwood DocGen** in the
**Portwood DemoBox** sandbox (`dave@portwood.dev.demo`). It ships **29 templates
across 9 industries** in all three output families (HTML→PDF, Word, PowerPoint),
realistic sample data, one-command install, team access, and a **two-tier reset**
to keep sandbox storage under control.

> Everything here is reproducible from source. Nothing depends on manual clicks.

---

## Quick start

```bash
# Stand up the whole environment (schema + data + templates) in one command:
bash "DEMO TEMPLATES/install/setup.sh" dave@portwood.dev.demo
```

Then open the **DocGen Demo** app to browse the sample records, pick a record,
and generate a document with the DocGen runner.

### Keep storage under control

```bash
# QUICK REFRESH — delete generated PDFs/DOCX + signature data, keep everything else.
bash "DEMO TEMPLATES/reset/reset.sh" dave@portwood.dev.demo refresh

# FULL RESET — wipe all demo data + templates back to clone-clean (schema kept).
bash "DEMO TEMPLATES/reset/reset.sh" dave@portwood.dev.demo full
```

Run **refresh** often (generated documents are the storage hogs). Use **full**
when you want a clean slate; re-seed with `setup.sh`.

---

## Template catalog (29)

| Industry       | Template                       | Format               | Base object           | Showcases                                         |
| -------------- | ------------------------------ | -------------------- | --------------------- | ------------------------------------------------- |
| Prof. Services | Invoice with QR Pay-Link       | Word→PDF             | Opportunity           | line items, **QR code**, SUM total                |
| Prof. Services | Statement of Work              | HTML→PDF             | Opportunity           | line items, fees, **signatures**                  |
| Prof. Services | Sales Proposal                 | HTML→PDF             | Account               | exec summary, **pipeline bar chart**, SUM/COUNT   |
| Prof. Services | Engagement Letter              | HTML→PDF             | Contact               | letter format, **signature + date**               |
| Manufacturing  | Product Catalog with Barcodes  | Word→PDF             | Pricebook2            | **Code 128 barcode per row**, catalog loop        |
| Manufacturing  | Packing Slip                   | HTML→PDF             | Opportunity           | ship-to, **checkbox column**, qty totals          |
| Manufacturing  | Wholesale Price List           | HTML→PDF             | Pricebook2            | family-grouped list, zebra rows                   |
| Manufacturing  | Giant Price List               | HTML→PDF             | Pricebook2            | **2,200-row scale**, repeating headers            |
| Financial      | Account Statement              | HTML→PDF             | Demo_Statement\_\_c   | txn loop, running balance, **activity bar chart** |
| Financial      | Homeowner Policy Schedule      | HTML→PDF             | Demo_Property\_\_c    | coverage table, declarations page                 |
| Financial      | Loan Estimate                  | HTML→PDF             | Demo_Property\_\_c    | loan terms, **borrower signature**                |
| Real Estate    | Purchase Agreement             | HTML→PDF             | Demo_Property\_\_c    | clauses, **buyer/seller initials + signatures**   |
| Real Estate    | Residential Lease              | Word→PDF             | Demo_Property\_\_c    | contract, **landlord/tenant signatures**          |
| Legal          | Non-Disclosure Agreement       | HTML→PDF             | Contact               | mutual NDA, **two-party signatures**              |
| Events         | Event Ticket with QR           | Word→PDF             | Demo_Attendee\_\_c    | **QR check-in code**, event details               |
| Events         | Attendee Badge                 | HTML→PDF             | Demo_Attendee\_\_c    | printable name badge                              |
| Events         | Event Program                  | HTML→PDF             | Demo_Event\_\_c       | brochure, registration count                      |
| Events         | Attendee Roster                | HTML→PDF             | Demo_Event\_\_c       | child loop, check-in column                       |
| Events         | Sponsor Prospectus             | **PowerPoint**       | Demo_Event\_\_c       | multi-slide deck                                  |
| Nonprofit      | Donation Tax Receipt           | HTML→PDF             | Opportunity           | gift details, IRS language                        |
| Nonprofit      | Donor Impact Report            | HTML→PDF             | Account               | gift loop, **giving-by-program bar chart**        |
| Certificates   | Certificate of Completion      | HTML→PDF (landscape) | Demo_Certificate\_\_c | ornate border                                     |
| Certificates   | Award Certificate              | Word→PDF (landscape) | Demo_Certificate\_\_c | formal award                                      |
| Certificates   | Verifiable Certificate (QR)    | Word→PDF (landscape) | Demo_Certificate\_\_c | **QR verification**                               |
| Education      | Report Card                    | HTML→PDF             | Demo_Student\_\_c     | grades loop, GPA                                  |
| Education      | Enrollment Verification Letter | HTML→PDF             | Demo_Student\_\_c     | **registrar signature**, seal                     |
| Education      | Course Schedule                | HTML→PDF             | Demo_Student\_\_c     | course loop, credit totals                        |
| Transcripts    | Official Academic Transcript   | HTML→PDF             | Demo_Student\_\_c     | full coursework, quality points, GPA              |
| Transcripts    | Verifiable Transcript (QR)     | Word→PDF             | Demo_Student\_\_c     | **QR + registrar signature**                      |

---

## Permissions

Each demo user needs two permission sets:

| Permset                           | Source                | Grants                                                                           |
| --------------------------------- | --------------------- | -------------------------------------------------------------------------------- |
| `DocGen_Admin` (or `DocGen_User`) | managed package       | Template Builder + generate (User = generate only)                               |
| `DocGen_Demo`                     | this repo (`schema/`) | the 8 `Demo_*__c` objects, their fields & tabs, and `Opportunity.Designation__c` |

`setup.sh` assigns both to the running user. Grant teammates:

```bash
bash "DEMO TEMPLATES/install/assign-team.sh" dave@portwood.dev.demo alice@co.com bob@co.com
```

---

## How it's built

```
DEMO TEMPLATES/
  DATA-DICTIONARY.md      every object/field/relationship + authoring rules
  schema/gen_schema.py    generates the 8 Demo_*__c objects + permset + app + Opportunity.Designation__c
  schema/force-app/       generated deployable metadata
  seed/seed-01..05.apex   idempotent demo data (core, events, education, records, giant)
  html/<industry>/*.html  21 HTML template bodies
  docx/build_docx.py      generates 7 Word templates  -> docx/out/*.docx
  pptx/build_pptx.py      generates 1 PowerPoint deck -> pptx/out/*.pptx
  install/manifest.json   the catalog: base object, query config, metadata per template
  install/install.mjs     uploads each body as a ContentVersion, creates template + active version
  install/fetch-doc.mjs   download a generated doc by ContentVersion id (for preview)
  install/validate.mjs    generate from every template and report PASS/FAIL
  install/setup.sh        one-command full environment setup
  install/assign-team.sh  grant permsets to teammates
  reset/reset.sh          wrapper: refresh | full
  reset/quick-refresh.apex / full-reset.apex / full-reset-giant.apex
```

Install or update a subset without re-seeding:

```bash
node "DEMO TEMPLATES/install/install.mjs" dave@portwood.dev.demo --only=ps-invoice,fin-account-statement
```

Re-validate everything renders:

```bash
node "DEMO TEMPLATES/install/validate.mjs" dave@portwood.dev.demo --skip=Giant
```

---

## Authoring constraints (important)

The PDF engine is **Flying Saucer (CSS 2.1)** and most documents are generated
server-side. When editing templates:

- **HTML:** table-based layout only. No flex/grid/gap/calc/CSS-vars/gradient/shadow.
- **Charts (server-side / Flow):** only `bar`, `stacked`, `clustered`, `pivot`.
  `pie`/`donut`/`line`/`area`/`column` render only through the Runner UI. Always
  use the field **API name** in the chart tag.
- **`{PageNumber}`/`{TotalPages}`** only work in the template footer field, not the body.
- **QR / barcodes** (`{*Field:qr}` / `{*Field:code128}`) are **Word-only**.
- DOCX/PPTX templates are intentionally **image-free** so they render with no
  pre-decomposition step in the subscriber org.

Full reference: `DATA-DICTIONARY.md`.

---

## Removing the schema (optional)

`full` reset keeps the custom objects so you can re-seed instantly. To remove the
`Demo_*__c` schema, permset, and app entirely (true clone-clean metadata):

```bash
sf project delete source --target-org dave@portwood.dev.demo \
  --source-dir "DEMO TEMPLATES/schema/force-app" --no-prompt
```
