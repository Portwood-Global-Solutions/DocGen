# Designer 2.0 — phase 2 plan

Successor to `docs/DESIGNER_PLAN.md`. That plan's phases 0–4 are done; this one covers
what the last round of testing surfaced, and the re-architecture those bugs point at.

---

## Where things stand

**Branch** `fix/v3.45.0-designer-and-render-batch` → PR #249. **Org** `docgen-verify`
(namespaced, expires 2026-08-07). **Gate** `npm run smoke -- --org docgen-verify` —
44/44.

Shipped and verified: behavioural smoke harness; surface abstraction (body + running
header/footer with full toolbar parity); sheet-level zoom with pill spreading;
viewport-anchored floating layer; selection bubble; colour/font popovers (19 controls →
3); contextual table row (24 controls hidden until relevant); Confluence-style gutters
with seam inserts and ghost previews; Notion-style block handles; Word-style insert-table
grid picker; Fit-width zoom and focus mode (chrome 389px → 243px, page 816px → 1306px).

Bugs found and fixed along the way, all pre-existing: `_restoreCaret` clobbering live
selections; `_selectedBlockElement` using the LWS-unreliable `pv.contains()`; the rAF
throttle that had silently disabled table handles entirely; `.dg-pill-menu` clipped by
its scroll container; invisible chrome eating clicks; header/footer missing from PDF
preview; the backtick insert menu; stranded highlight residue; Backspace destroying the
canvas floor.

---

## The problem underneath the remaining bugs

Three of the open items are not independent defects. They share a cause.

**There are three sources of truth for one document.**

| Part   | Lives in                                             | Edited via               |
| ------ | ---------------------------------------------------- | ------------------------ |
| Body   | ContentVersion HTML (`docgen_tmpl_html_<versionId>`) | `.dg-pv` canvas          |
| Header | `Header_Html__c`                                     | `.dg-chrome-band_header` |
| Footer | `Footer_Html__c`                                     | `.dg-chrome-band_footer` |

And **the canvas is re-derived from source on every render** — `scopeHtmlForInlinePreview`
builds the preview, `renderedCallback` writes it into the `lwc:dom="manual"` host, and
`_extractVisualBody` reads `innerHTML` back out as a string on the way to saving.

That single design decision is why:

- **Undo is broken for tables.** Every table operation is direct DOM surgery
  (`insertAdjacentElement`, `remove()`, `_safeReplace`). The browser's native undo stack
  has no record of it, so Ctrl+Z steps straight past those edits to the last thing
  `execCommand` did. There is nothing to undo _to_, because no state was captured.
- **Word headers land in the body.** The DOCX converter produces one HTML blob. There is
  no region in it that means "this is the running header", so `<w:hdr>` content has
  nowhere to go except inline.
- **Preview and source can disagree.** The preview renders from the _saved_ record for
  anything that is not the body — which is exactly the header/footer bug just fixed by
  passing draft overrides. That fix works, but it is a patch on a shape that will keep
  producing this class of bug: every new surface needs its own draft plumbing.
- **Every feature is implemented per surface.** Surface parity had to be retrofitted into
  the caret tracker, pillify, zoom, dimensions, table tools and the slash menu — one at a
  time, each a separate bug when missed.

Your instinct in the last session was right on both counts: _"it can all be derived from
the same source html"_ and _"separate the live preview from the live source"_.

---

## Proposal

Two changes, sequenced so each is independently shippable and independently revertible.

### A. Regions — one source HTML (medium)

Header and footer become **marked regions inside the template's own HTML** rather than
separate fields:

```html
<body>
    <div data-dg-region="header">…running header…</div>
    <div data-dg-region="body">…the document…</div>
    <div data-dg-region="footer">…running footer…</div>
</body>
```

- The **author** has one source document. "View Source" shows the whole thing, header
  included, which is what makes the mental model click.
- On **save**, `splitRegions()` peels the header/footer regions off and writes
  `Header_Html__c` / `Footer_Html__c` as it does today, so **the render engine is
  untouched** — `wrapHtmlForPdf` keeps its current contract and nothing about PDF output
  changes. That is what keeps this from being a risky change.
- On **load**, `joinRegions()` recombines them. Templates saved before this change have
  no region markers, so the join synthesizes them from the existing fields — backwards
  compatible with every existing template, no migration.
- **Word import gets somewhere to put `<w:hdr>`/`<w:ftr>`** — straight into the header
  and footer regions. This is what fixes "Word headers show up in the body".
- The bands stop being a special case: they are regions of the one canvas, so surface
  parity stops being something to retrofit per feature.

Region markers must be stripped from anything that reaches the renderer, the same
discipline already used for `.dg-drop-marker` and `data-dg-paint`.

### B. An edit model + undo stack (medium)

Not a full ProseMirror-style rewrite — that is a rewrite of the whole editor and is not
justified here. The pragmatic version:

- **`_pushUndo(label)`** snapshots the canvas HTML (all regions) into a bounded stack
  before every _structural_ mutation — table ops, block moves, pill edits, region edits.
- **Ctrl/Cmd+Z** pops the stack and restores. Native `execCommand` undo continues to
  handle plain typing, which it already does correctly; the stack only owns the DOM
  surgery the browser cannot see.
- Coalesce rapid same-label edits (typing bursts) so one Ctrl+Z is not one keystroke.
- Cap the stack (~50 entries) — the snapshots are strings and a large template is
  ~100KB, so memory needs a bound.

This closes the undo gap **and** gives the preview a stable thing to render from: preview
renders the current model snapshot rather than racing the live DOM.

**Why snapshots rather than an operation log:** the mutations are already written as
direct DOM surgery in ~15 places. An operation log means rewriting all of them with
inverse operations and keeping the pair in sync forever. Snapshots are O(1) to add per
call site and cannot drift out of sync with the operation they describe.

---

## Sequencing

| #   | Work                                    | Size | Notes                                                                                                                                          |
| --- | --------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Undo stack (B)**                      | M    | Highest user-visible pain. Independent of regions — do it first, ship it alone.                                                                |
| 2   | **Regions (A)**                         | M    | Unlocks Word headers and collapses the surface-parity tax.                                                                                     |
| 3   | **Word `<w:hdr>`/`<w:ftr>` extraction** | M    | Depends on 2 having somewhere to put them. Renderer work in `DocGenHtmlRenderer`.                                                              |
| 4   | **Header visual polish**                | S    | Measured flush and identical width already, so what remains is aesthetic — needs a screenshot of what still reads wrong before guessing again. |
| 5   | **Preview from model**                  | S    | Falls out of 1 + 2; retires the per-surface draft plumbing added for the header/footer preview fix.                                            |

Each step: implement → deploy to `docgen-verify` → `npm run smoke` → screenshot →
commit. Revert immediately on a red gate rather than patching forward.

---

## Harness work this needs

The smoke gate has caught six real regressions, including two I introduced. It needs
extending for the above, and these are the assertions to write **before** the code:

- **Undo**: after a table insert, delete, block move and column resize, Ctrl+Z restores
  the previous DOM exactly. Assert on serialized HTML equality, not on element counts.
- **Regions**: a save/load round-trip preserves header, body and footer content, and no
  `data-dg-region` marker survives into what reaches the renderer.
- **Legacy templates**: a template with no region markers still loads, edits and saves
  correctly. This is the backwards-compatibility guarantee and it must be asserted, not
  assumed.
- **Word import**: a DOCX with a header produces header-region content and a body that
  does _not_ contain it.

---

## Also still open

Carried from earlier sessions, unrelated to the above:

- **#245** — cell wrapping is implemented and emits both `word-wrap` and `overflow-wrap`,
  but Flying Saucer is CSS 2.1 plus a small subset and these are CSS 3. **Needs a real
  PDF render** with a 200-character unbroken string in a fixed-layout cell. If the engine
  ignores it, the fallback is zero-width-space injection at merge time.
- **#236** — the template-create P0. The `Type__c` restricted-picklist theory is
  well-evidenced (`HTML` was added in v1.61.0; the wizard defaults to it) but unconfirmed.
  Needs the v1.4.0-1 (`04tal000006PEltAAG`) → v3.44.0 (`04tVx000000rlATIAY`) upgrade
  repro, then `scripts/diag-template-create.apex`.
- **Pill spread on zoom** — implemented as you asked. The design review argues for
  removing it: at 200% a 7px margin becomes 14 effective px, so the screen stops matching
  print. Their compromise is a "Spread tags" toggle, default off. Your call.
- **Design spec leftovers** — `docs/` design review has specced but unimplemented items:
  the persistent-bar breakpoint behaviour (1280/1440/1920), the table properties panel as
  a corner-handle popover, and pill styling via `box-shadow: inset` instead of `border`
  (zero layout cost, so on-screen metrics match print).

---

## Ground rules that earned their place

1. **Behavioural verification, not layout measurement.** The toolbar rewrite that broke
   the editor measured perfectly — one row, 9 clusters, 38px.
2. **Assertions before the change they protect.** The colour/font popovers only shipped
   safely because the popover assertions were green before the inline controls were
   removed.
3. **Bust Lightning's IndexedDB cache before believing a browser check.** It silently
   invalidated two verification runs.
4. **Never `position: absolute` for floating chrome.** Use `_positionFloating`; a
   scrolling ancestor will clip it eventually.
5. **`opacity: 0` does not remove an element from hit-testing.** Invisible overlays need
   `pointer-events: none` or they eat clicks.
6. **Surgical edits, never blunt range replaces.** One range replace silently deleted
   every popover, bubble, seam and block-handle rule.
7. **`pv.contains()` is unreliable under LWS.** Use `_surfaceContaining` /
   `_isInCanvas`. It has broken four separate features.
