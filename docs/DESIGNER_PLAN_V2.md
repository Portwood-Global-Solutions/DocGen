# Designer 2.0 — phase 2 plan

Successor to `docs/DESIGNER_PLAN.md`. That plan's phases 0–4 are done; this one covers
what the last round of testing surfaced, and the re-architecture those bugs point at.

---

## Where things stand

**Branch** `fix/v3.45.0-designer-and-render-batch` → PR #249. **Org** `docgen-verify`
(namespaced, expires 2026-08-07). **Gate** `npm run smoke -- --org docgen-verify` —
60/60 (44/44 when this plan was written; steps 1, 2 and 5 added sixteen).

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

| #   | Work                                    | Size | Status                                                                                                 |
| --- | --------------------------------------- | ---- | ------------------------------------------------------------------------------------------------------ |
| 1   | **Undo stack (B)**                      | M    | **DONE** — `9aa6df5`. Gate 50/50.                                                                      |
| 2   | **Regions (A)**                         | M    | **DONE** — `55fb6cd`. Gate 59/59.                                                                      |
| 3   | **Word `<w:hdr>`/`<w:ftr>` extraction** | M    | **DONE** — `a415f28`. RendererTest 126/126, MiscTests 396/396.                                         |
| 4   | **Header visual polish**                | S    | **DONE** — `e02685b`. Screenshotted rather than guessed; found a functional bug behind it. Gate 63/63. |
| 5   | **Preview from model**                  | S    | **DONE** — `e170243`. Gate 60/60.                                                                      |

Each step: implement → deploy to `docgen-verify` → `npm run smoke` → screenshot →
commit. Revert immediately on a red gate rather than patching forward.

### What shipped, and where it differs from this plan

**1 — Undo.** As specified, with one deliberate divergence. The plan said native
`execCommand` undo would keep handling plain typing while the stack owned only the DOM
surgery. It doesn't: the stack owns typing too, captured on `beforeinput` and coalesced
into ~700ms bursts, and Ctrl+Z is `preventDefault`-ed. Two undo stacks racing over one
document is the exact failure being fixed — whichever the browser picks, the other's
history is silently wrong. The plan already implied this by asking for typing-burst
coalescing, which only makes sense if typing is in the stack.

Discovered while building it: the caret highlight is `data-dg-paint` plus inline style on
a live block, so a naive snapshot restores a purple tint onto a block the caret has since
left, and makes two identical documents compare unequal — which defeats the dedupe that
stops the stack filling with no-ops. `_snapshotSurfaces` strips it and puts it straight
back, the same discipline `_extractVisualBody` already used before saving.

**2 — Regions.** As specified. The bands stay where they are visually: regions live in
the SOURCE string, and the designer decomposes them into surfaces on entry and recomposes
on exit. `_adoptRegions` is wired into `_processAndSaveHtmlBody`, which turns out to be
the single choke point every body reaches on the way to a ContentVersion — so an author
can now also upload an HTML file carrying region markers and have its chrome land in the
right fields.

**3 — Word headers.** Smaller than the plan assumed. `extractBodyContent` concatenating
`<w:hdr>` inline only affects `convertToHtmlFragment` / `convertToHtmlWithHeaderFooter`,
which are test-only. The live path already routed headers through the
`DOCGEN_HEADER_START` markers into Flying Saucer running elements — the PDF was never
wrong. What was missing was a way for the Designer to tell chrome from content, so the
fix is a `data-dg-region` annotation on the `#docgen-header` / `#docgen-footer` divs.
Flying Saucer selects them by `#id` and ignores unknown data attributes, so PDF output is
unchanged, and the test asserts both halves so a future edit cannot trade one for the
other.

Known limitation: only the DEFAULT header/footer pair is marked. The `-first`
(`w:titlePg`) variants have no field to be adopted into — there is one `Header_Html__c`,
not one per page context — so they keep today's behaviour of staying inline.

**4 — Header polish, and the bug underneath it.** The screenshot this was waiting on
was taken with Playwright against `docgen-verify`. Three visual defects, and one
functional one that only showed up because the screenshot prompted a look at how the
bands actually behave:

- The dashed editing outline was on `.dg-pv`, so it boxed the BODY and left the running
  header outside it. The sheet said "one piece of paper"; the outline said "the document
  is this rectangle and the header is not in it". It also drew a second dashed line 6px
  from each band's own margin rule, so every seam showed two parallel dashes meaning
  different things. Moved to a `.dg-sheet-paper` wrapper enclosing all three surfaces.
- The bands rendered in the Salesforce UI font, at a UI size, in UI grey, while the page
  rendered in the document's typeface — so the one surface whose entire point is "what
  you see is what prints" showed something that would never appear in the PDF.
- The first attempt at dimming used element `opacity`, which made the band's white
  background translucent so the grey desk showed through. Dimming is alpha on the
  document's own ink instead.

**The functional bug: inserts never reached the header.** `_insertIntoVisualPage`
resolved its target as the body canvas unconditionally, so with the caret in a band the
containment test failed for every candidate range and the insert fell through to
appending at the end of the body. The drag paths had the same assumption, and the bands
accepted `dragover` but had no `drop` handler at all. Headers containing images or merge
tags were not buildable from the rail — which rules out every header more complex than a
line of static text.

**The scatter.** Header and footer had three editors for two fields: the bands, a
floating panel of raw-HTML textareas, and the Edit Template modal. The panel's textareas
are gone; it now only jumps the caret to a band. Its one unique feature — page-counter
tokens, meaningless outside a running header — became a contextual toolbar cluster on
the same idiom as the table row.

**5 — Preview from model.** The real defect was subtler than "preview renders from the
saved record". The body was read from the live canvas while the chrome was read from the
template fields, so a header keystroke whose `input` event had not yet fired was missing
from both preview AND save. `_liveChrome()` reads the bands through `_syncBandToRecord`
(with a new `markDirty=false`), so one pass brings the fields current and every caller
gets the same document.

### Harness

Sixteen new assertions, written before the code they protect. The undo ones compare
CANONICALIZED serialized HTML — full tree, sorted attributes, sorted style declarations —
rather than raw `innerHTML`, because re-parsing a fragment reorders attributes and LWC
re-stamps its `lwc-xxxxx` scoping attribute; that is still serialized-HTML equality, just
insensitive to ordering the browser owns. Two rounds of false failures came from getting
this wrong, and the second round (`outline-offset`, which carries no colour to filter on)
was only found because the stricter comparison replaced a regex that had been silently
masking real differences.

---

## Harness work this needs — DONE

All written before the code they protect. The gate is now **60/60**.

- **Undo** ✅ — table insert, table delete, block move, redo, header-band coverage, and
  the toolbar's enabled state. Serialized HTML equality (canonicalized), not element
  counts. Column resize is capture-sited but asserted only indirectly; a direct drag
  assertion is still worth adding.
- **Regions** ✅ — round-trip preserves header, body and footer; the header does not leak
  into the body canvas; no `data-dg-region` marker reaches the renderer.
- **Legacy templates** ✅ — a document with no markers loads, and crucially does **not**
  blank a header that lives only in `Header_Html__c`.
- **Word import** ✅ — asserted in Apex (`testRunningHeaderFooterCarryDesignerRegionMarkers`)
  rather than the browser: the marker is present AND the running-element CSS plus `@page`
  margin box are untouched, so the import cannot be bought at the cost of the PDF.
- **Model** ✅ — a header edit with no `input` event still reaches View Source.

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
8. **Compare documents, not serializations.** Raw `innerHTML` equality reports
   differences that are not differences — re-parsing reorders attributes, LWC re-stamps
   its scoping attribute, and the caret highlight is editor chrome. Canonicalize (sorted
   attributes, sorted style declarations, chrome excluded) or the assertion tests the
   browser rather than the code.
9. **A loose comparison that passes is worse than a strict one that fails.** The first
   undo assertions passed against a regex that was stripping whole style attributes; the
   real differences only surfaced once the comparison got stricter. If an assertion has
   to be loosened to go green, find out exactly what it is hiding first.
