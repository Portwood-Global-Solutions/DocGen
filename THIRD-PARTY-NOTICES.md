# Third-Party Notices

Portwood DocGen runs 100% on the Salesforce platform — no external services, no
callouts, and document data never leaves the org. It does, however, **vendor** a
small number of open-source **client-side** JavaScript libraries as pinned static
resources. They execute entirely in the user's browser, make no network calls, and
are shipped inside the managed package (not pulled from npm at install time).

This file is the component disclosure (SBOM) for those libraries. Keep it current
when versions change, and disclose it in AppExchange security materials.

| Component | Version                     | License            | Purpose                                                                                         | Source                             |
| --------- | --------------------------- | ------------------ | ----------------------------------------------------------------------------------------------- | ---------------------------------- |
| PDF.js    | 2.16.105 (legacy UMD build) | Apache License 2.0 | Renders the document + text layer in the guided signing viewer so sign-spots can be located.    | https://github.com/mozilla/pdf.js  |
| pdf-lib   | 1.17.1 (UMD build)          | MIT                | Composites drawn/typed signatures onto the signed PDF in the browser at the located sign-spots. | https://github.com/Hopding/pdf-lib |

## Security notes

- **PDF.js / CVE-2024-4367** — the 2.x line is affected by an arbitrary-JS-execution
  vector via a crafted PDF's font path. DocGen mitigates it by calling
  `getDocument({ ..., isEvalSupported: false })`, which disables the affected
  Function-constructor path. Track this until the bundle is upgraded to a fixed
  release (>= 4.2.67).
- These libraries make **no network requests** and have **no external runtime
  dependency** — they operate only on PDF bytes already in the browser.

## Licenses

- **Apache License 2.0** (PDF.js): https://www.apache.org/licenses/LICENSE-2.0
- **MIT License** (pdf-lib): https://opensource.org/licenses/MIT

Full upstream license text is retained in each project's repository linked above.
