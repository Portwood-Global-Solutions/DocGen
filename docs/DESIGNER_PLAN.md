# Designer 2.0 — plan

## What went wrong, first

I shipped a toolbar rewrite that broke the editor and I did not catch it before handing it over. Two independent defects, both mine:

1. **Popovers could never render.** I set `overflow-x: auto; overflow-y: visible` on the toolbar. CSS coerces `visible` to `auto` when the other axis is not `visible`, so the bar became a clipping container 38px tall and every menu opened inside it, invisible. Confirmed in-org: `getComputedStyle(bar).overflowY === "auto"`.
2. **The menus did not open at all.** `menuOpened: false` on a real click.

Net effect: I moved colours, fonts, alignment, lists and every table property behind menus that did not work. That is the "no buttons are clickable" report, and it is a fair description.

Reverted in `c8b45cb`. The editor is back to its last working state.

**The lesson that shapes this whole plan: I verified the toolbar's _shape_ (9 clusters, 38px, one row) and never verified its _behaviour_.** Measuring layout is not testing. Phase 0 exists so this cannot recur.

---

## Reference research

| Product                        | What is worth stealing                                                                                                                                                                                                     | Source                                                                                                                                         |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Notion**                     | Everything is a block. Drag handle + `+` on hover at the block's left gutter. Slash menu as the primary insert affordance. Block-level menu for delete/duplicate/convert. Keyboard-first.                                  | [Notion slash commands](https://www.notion.com/help/guides/using-slash-commands), [Notion UI analysis](https://dashibase.com/blog/notion-ui/)  |
| **Notion / BlockNote**         | The three-layer rule: **you need a bubble menu AND a static toolbar AND slash commands** — not one of them. Different users reach for different layers.                                                                    | [BlockNote integration guide](https://greta.agency/blog/notion-flexible-editor/)                                                               |
| **Confluence**                 | Column and row **drag handles** that open a menu (add left/right, delete), not a toolbar you travel to. Drag a border to resize. Floating toolbar appears _below the table_.                                               | [Confluence Cloud tables](https://support.atlassian.com/confluence-cloud/docs/simplify-data-with-tables/)                                      |
| **Google Docs / Word**         | Header/footer are **in the page**, in the margin, dimmed until you double-click in. Click into the body to leave. Print-layout shows margins and page breaks as they will print.                                           | [Google Docs headers/footers](https://support.google.com/docs/answer/86629), [Docs zoom & views](https://support.google.com/docs/answer/99753) |
| **Floating UI**                | CSS has no anchored positioning. Floating elements need **collision awareness, overflow prevention and placement flipping**, computed in JS against the viewport — never `position: absolute` inside a scrolling ancestor. | [Floating UI](https://github.com/javascriptDev/floating-ui)                                                                                    |
| **contenteditable, generally** | Raw `contenteditable` + `execCommand` is famously unreliable and produces poor HTML. Ours is already a hybrid (DOM surgery for lists, pills as atoms). Keep moving _away_ from `execCommand`, not toward it.               | [Treehouse on contenteditable](https://blog.teamtreehouse.com/native-rich-text-editing-with-the-contenteditable-attribute)                     |

The single most useful finding is Floating UI's framing: **my bug was not a typo, it was using the wrong positioning strategy.** Popovers anchored inside a scroll container will always be one CSS change away from being clipped. They have to be positioned against the viewport.

---

## Phase 0 — the safety net (blocking; nothing else starts until this is green)

Without this, every phase below is a coin flip. This is the part I should have built first.

**0.1 In-org UI smoke test** — a Node/Playwright script, `scripts/ui-smoke.mjs`, that:

- logs into a target org via `sf org open --url-only`
- clears Lightning's IndexedDB caches (`ldsDurableCache`, `actions`, …) and hard-reloads, because **Lightning serves stale component bundles and silently invalidated two of my verification runs today**
- opens the Designer on a known template
- for **every** control in the toolbar: places a caret/selection, clicks the control, asserts the canvas DOM actually changed (or the expected popover became visible _and hit-testable at its centre point_)
- asserts every `{binding}` in the template resolves to a real JS member (the check that would have caught `fontSizeValue`)
- exits non-zero with a per-control report

**0.2 Wire it in** — `npm run smoke -- --org docgen-verify`, and run it after every deploy in the phases below. A phase is not done until smoke passes.

**0.3 Seeded fixtures that actually load.** Today's seeded templates open with an empty canvas because programmatic inserts skip the `docgen_tmpl_html_<versionId>` snapshot the Designer reads — the same class of gap as the known image pre-decomposition issue. Add a seeding path that routes through the real save pipeline so fixtures are representative.

_Exit criteria: smoke test passes on the current reverted build, and fails loudly if I re-introduce today's overflow bug._

---

## Phase 1 — surfaces: header/footer parity and zoom (your explicit ask)

Right now `_canvas()` resolves to whichever surface holds the caret, which was the right instinct, but the bands are second-class: zoom skips them, `_applyCanvasDimensions` skips them, and they sit outside the sheet.

**1.1 A real `Surface` abstraction.** One descriptor per editable region — `{ id, el, field, isChrome }` for body / header / footer. Every subsystem takes a surface instead of reaching for `.dg-pv`: pillify, caret tracking, zoom, dimensions, drop targets, table tools, slash menu, undo.

**1.2 Zoom applies to the sheet, not the body.** Scale a single `.dg-sheet` wrapper so header, body and footer scale together as one page — which is also the only way the Word-style layout stays true at any zoom. Recompute pointer-derived maths (`caretRangeFromPoint`, drop marker, table handles) against the scale factor in one shared helper rather than per-call-site.

**1.3 Pills spread with zoom, on every surface.** Above 100%, add margin/padding/line-height on top of the scale so dense areas separate into clickable targets. Safe because `_unpillifyTags` keeps only font/colour properties when serializing — verified.

**1.4 Word-style page chrome.** Header/footer as the sheet's top and bottom margin zones: same width, same white, no gap, dashed boundary, dimmed until focused, small in-margin label. Double-click to enter, click into body to leave. The seam I hit before was the canvas host drawing its own panel and border between band and page — the desk gradient moves to the sheet wrapper and the host becomes a pure scroll viewport.

_Closes #247. Exit criteria: smoke test drives bold/colour/table/insert in the header band and the footer band, not just the body, and asserts each writes the correct field._

---

## Phase 2 — chrome: the three-layer toolbar

Per the research, not one toolbar — three layers, each for a different reach:

**2.1 Persistent bar (compact).** Only what is used constantly: B/I/U/S, size, colour, alignment, lists, undo/redo, zoom. Grouped into clusters. One row.

**2.2 Selection bubble.** On a text selection, a small floating toolbar near the selection — the Notion/Medium pattern. This is what makes the persistent bar allowed to be small.

**2.3 Slash menu.** Already exists (`_maybeOpenSlashMenu`); promote it to the primary insert path and broaden its catalogue — blocks, tags, tables, charts, images, signature fields.

**2.4 Popovers, done correctly.** A single `_positionFloating(anchorEl, floatEl)` helper: `position: fixed`, coordinates computed from the anchor's viewport rect, flipping when it would overflow the viewport, **never** relying on an ancestor being non-clipping. One implementation, used by every menu, the pill menu, the slash menu and the bubble.

**2.5 Contextual table row** — only while the caret is in a table.

_Exit criteria: smoke asserts every popover is visible AND `elementFromPoint` at its centre returns a node inside it, at three viewport widths (1280/1440/1920). This is the exact assertion that would have caught today's bug._

---

## Phase 3 — tables, Confluence-grade

**3.1** Column/row hover handles that open a **menu** (insert left/right, delete, distribute) rather than a toolbar trip — Confluence's model. The handles exist (#241) but currently only insert/delete inline.
**3.2** Drag a border to resize columns; live guideline.
**3.3** Table properties: distribute evenly, width, padding, alignment, vertical align (#242, #246).
**3.4** Selection model: click-drag a cell rectangle, shift-click to extend, keyboard Tab/arrow navigation between cells.

_Closes #241, #242, #246._

---

## Phase 4 — blocks, Notion-grade

**4.1** A left gutter on hover per block: drag handle + `+`.
**4.2** Drag to reorder blocks, with a drop indicator.
**4.3** Block menu: duplicate, delete, convert (paragraph ↔ heading ↔ list ↔ quote).
**4.4** Keyboard-first: Enter/Backspace block semantics, arrow traversal across surfaces.

---

## Phase 5 — the rest of the board

Independent of the Designer work, already specced, already have implementations on this branch pending your verification:

- **#236** P0 template-create — needs the v1.4 → v3.44 repro to confirm the picklist theory
- **#245** cell wrap — needs a real PDF render to confirm Flying Saucer honours `word-wrap`; fallback is zero-width-space injection at merge
- **#243** landscape precedence, **#237** title help text, **#248** AI prompt — implemented and tested
- **#238/#239/#240** caret tracker — implemented; needs smoke coverage from Phase 0
- Backlog: **#204** Custom Label tags, **#211** comment syntax, **#212** runner PDF preview

---

## Sequencing

| Order | Phase                   | Why here                                                          |
| ----- | ----------------------- | ----------------------------------------------------------------- |
| 1     | **0 — safety net**      | Blocking. Nothing is trustworthy without it.                      |
| 2     | **1 — surfaces + zoom** | Your explicit ask, and Phase 2's popovers need the surface model. |
| 3     | **2 — toolbar layers**  | The visible fix, but only safe once 0 can prove it works.         |
| 4     | **3 — tables**          | Highest-value editing gap after chrome.                           |
| 5     | **4 — blocks**          | Largest, least urgent.                                            |

Each phase: implement → deploy to `docgen-verify` → smoke → screenshot → commit. Any phase that fails smoke gets reverted immediately rather than left in place.

---

## What I will not do

- **Ship another UI change without behavioural verification.** Layout measurements are not tests.
- **Put controls behind a popover before the popover positioning is proven** at multiple viewport widths.
- **Trust a browser check without busting Lightning's cache** — it invalidated two of my runs today.
- **Claim a phase is done on a green deploy.** Deploy success means it compiled.
