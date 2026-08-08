# Element linking — Flying Saucer spike

Measured 2026-08-08 against `Blob.toPdf` in a namespaced scratch org, rendering
through the normal `DocGenService.generatePdfBlob` path. Probes are in
`scripts/qa/flowspike.html`; every finding below is from a rendered PDF read
back with `pdftotext -bbox`, not from documentation.

## The problem

A canvas box is either **pinned** (`position: absolute`, lands exactly where it
was drawn, never moves) or **flow** (`dg-flow`, stacks by `margin-top`). Neither
survives content that grows at merge time:

- A pinned box below a table is overrun the moment the table exceeds the height
  it had on the artboard.
- Flow is a single implicit chain per artboard ordered by `y`. You cannot say
  "these three travel together" or "this one follows that one".
- `flowMarginTop` computes the gap as `box.y - cursor`, where `cursor` advances
  by the box's **authored** height. After merge that height is fiction, so every
  gap downstream is wrong by however much the table grew.

## What the engine actually does

| # | Probe | Result |
|---|-------|--------|
| 1 | Pinned caption below a growing table | **Overrun.** Table starts y=89.9, caption pinned at y=255.5 — same page, 38 rows rendered straight through it |
| 2 | Table + caption inside one flow container | **Works.** Group grew, caption stayed attached, following content pushed to the next page |
| 5 | `position: absolute` child inside a `position: relative` flowing parent | **Anchors to the parent, exactly.** Child styled `top:1in; left:2in` rendered at +72.0pt / +144.0pt from the parent's origin |
| 6 | `page-break-inside: avoid` on a group that FITS a page | **Honoured.** Moved whole to the next page rather than straddling |
| 7 | Same group without `avoid` (control) | Split across pages — confirms 6 is the property, not chance |
| 4 | `<thead>` on a table split across pages | **Does not repeat.** Header appears once, on the first page of the table |

Probe 3 (`avoid` on a group taller than a page) split, which is correct — the
spec makes `avoid` a preference that cannot be satisfied when the content
exceeds the page box. It is listed here only because it looks like a failure and
is not.

## What this means

Finding 5 is the hinge. Because an absolutely-positioned child anchors to a
positioned **parent** rather than to the page, an anchored group does not have to
give up precise placement to gain flow behaviour:

```html
<!-- the group flows; the page pushes it when content above grows -->
<div class="dg-group" style="position: relative; page-break-inside: avoid;">
  <!-- members keep their exact authored offsets, now relative to the group -->
  <div style="position: absolute; top: 1in; left: 2in;">…</div>
  <table>…</table>
</div>
```

So the model is not "linking on top of absolute positioning". It is: **an
anchored group becomes a flow container, and its members become absolute
relative to the group.** The author's layout is preserved to the inch; the
browser resolves the pushing instead of us predicting heights from stale
authored dimensions.

That also disposes of the `flowMarginTop` problem — nothing has to compute a gap
from a height that no longer exists.

## Proposed model

- `anchorTo` (parent box id) on the box model, with `data-dg-anchor` for exact
  round-trip, as `chartAttrs`/`readChart` already do.
- Serializer emits each anchored set as one `position: relative` container,
  members offset from the group origin rather than the artboard origin.
- `keepTogether` on the group maps to `page-break-inside: avoid` — now known to
  work, so this is a real option rather than a hope.
- Cycle detection: A→B→A is one drag away, and an anchor graph without it will
  hang the serializer.
- Validation in the `chartConfigIssue` style — an anchor pointing at a deleted
  box should surface on the artboard, not fail silently at merge.

## Open, not yet answered

- **Repeating headers.** Finding 4 means a table spanning pages loses its header.
  That is independent of linking but will be the first complaint about any
  expanding table, so it wants its own decision.
- **Groups taller than a page.** `avoid` cannot help. Either the group breaks, or
  the author is warned at design time that it cannot be kept together.
- **Cross-artboard flow.** Artboards are discrete `<div>`s; a group still cannot
  begin on one and continue on the next. Nothing here changes that, and it is the
  harder half of "traverse the pages".
