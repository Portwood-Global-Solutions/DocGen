# DocGen QA report

**Org** `designer-ns` · **Run** 2026-08-08T10:50:24.314Z · **Duration** 494s

## Headline

| | |
| --- | --- |
| Checks evaluated | 169 |
| Passed | 169 (100%) |
| Failed | 0 |
| Skipped (not counted) | 7 |
| Blockers | 0 |
| Major | 0 |
| Minor | 0 |

## Coverage by area

| Suite | Area | Passed | Failed | Skipped | Rate |
| --- | --- | ---: | ---: | ---: | ---: |
| `ui-designer` | Designer UI | 103 | 0 | 2 | 100% |
| `ui-admin` | Admin UI | 64 | 0 | 4 | 100% |
| `template-integrity` | Template integrity | 2 | 0 | 1 | 100% |

## What to fix

Nothing — every evaluated check passed.

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `ui-designer` — header renders asset tags as images: skip: no assets in this org
- `ui-designer` — resizing a header image does not duplicate it: skip: no assets
- `ui-admin` — the floating panels open with their contents rendered: the designer never opened
- `ui-admin` — edit modal tab "Header / Footer" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — edit modal tab "Fillable Fields" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — closing the modal with unsaved edits warns or preserves them: could not re-open the modal: row "QAUI-k981yn-Starter": the menu never offered a visible "Edit" item
- `template-integrity` — merge-tag pills stay inside their table cells: could not open a template in the Designer: no Designer tab

## Every check

### ui-designer — Designer UI

- ✅ designer opens (toolbar + canvas present) — {"bar":true,"pv":true}
- ✅ toolbar: B
- ✅ toolbar: I
- ✅ toolbar: U
- ✅ toolbar: S
- ✅ toolbar: x²
- ✅ toolbar: x₂
- ✅ toolbar: • List
- ✅ toolbar: 1. List
- ✅ toolbar: Left
- ✅ toolbar: Center
- ✅ toolbar: Right
- ✅ toolbar: Clear
- ✅ surface parity: bold works in header
- ✅ surface parity: bold works in footer
- ✅ zoom: body scales — {"pv":816,"hdr":816} -> {"pv":1224,"hdr":1224}
- ✅ zoom: header scales with the sheet — header must scale with the page
- ✅ table tools hidden outside a table — 24 table buttons visible
- ✅ table tools appear inside a table
- ✅ table tools work when shown (+ Row)
- ✅ table seams: render, no ghost targets, insert a column
- ✅ block handle: appears and reorders blocks — AAA,BBB -> BBB,AAA
- ✅ insert-table grid: 4x3 picker inserts and fits the page — cols=4 rows=4 overhang=false
- ✅ table never extends past the canvas after adding columns — table 1008px vs content 1080px
- ✅ cell selection highlight does not hang — 0 cells still marked selected
- ✅ bubble: appears on text selection
- ✅ bubble: position fixed (uncippable) — must be fixed, got true
- ✅ bubble: on screen with real size
- ✅ bubble: no clipping ancestor
- ✅ bubble: centre is hit-testable
- ✅ bubble: does not cover the selection
- ✅ bubble: bold actually formats
- ✅ popover textColor: opens, unclipped, hit-testable, formats
- ✅ popover highlight: opens, unclipped, hit-testable, formats
- ✅ popover font: opens, unclipped, hit-testable, formats
- ✅ header/footer are part of the sheet (width, alignment, flush) — w 1224/1224 left 108/108 gaps 0,0
- ✅ table +/- shows a ghost of what it will add/remove — ok
- ✅ zoom: Fit width fills the column — ok
- ✅ focus mode hides the setup chrome — ok
- ✅ only one region highlighted after moving block->block->cell->cell — 1 regions painted
- ✅ backtick opens the insert menu
- ✅ no invisible chrome intercepts clicks
- ✅ canvas click points reach the page
- ✅ undo: table row insert restores the document exactly — ok
- ✅ undo: table row delete restores the document exactly — ok
- ✅ undo: block move restores block order — ok
- ✅ undo: redo re-applies the undone edit — ok
- ✅ undo: one step covers the header band too — ok
- ✅ undo: toolbar button enables once there is history — ok
- ✅ regions: Source view shows the header as a marked region — header region + content must appear in the one source document
- ✅ regions: Source view shows the body as a marked region
- ✅ regions: Source view shows the footer as a marked region
- ✅ regions: round-trip preserves the header
- ✅ regions: round-trip preserves the body
- ✅ regions: round-trip preserves the footer
- ✅ regions: header does not leak into the body canvas — chrome in the body would print twice
- ✅ regions: no data-dg-region marker reaches the renderer — same discipline as .dg-drop-marker / data-dg-paint
- ✅ regions: a legacy template with no markers still loads and keeps its header — ok
- ✅ model: chrome is read from the live surfaces, not the last synced field
- ✅ header tools appear in the toolbar when the caret is in a band — page counters must be contextual, not in a separate panel
- ✅ insert lands in the header band, not the bottom of the body — ok
- ✅ header tools hide again when the caret returns to the body — page counters are meaningless in the body
- ✅ table seams survive the pointer leaving the table — ok
- ⊘ header renders asset tags as images — skip: no assets in this org
- ✅ a tall header at zoom does not overlap the page — ok
- ⊘ resizing a header image does not duplicate it — skip: no assets
- ✅ Enter inserts a line break, staying in the paragraph — {"blocks":1,"brInP":true}
- ✅ Shift+Enter starts a new paragraph — {"blocks":2,"brInP":true}
- ✅ Enter in a list makes the next item, not a line break — {"items":2,"brs":1}
- ✅ backtick opens the insert menu in the running header
- ✅ right-click opens the context menu in the header
- ✅ table tools appear for a table in the header
- ✅ table tools operate on the header table — 1 -> 2
- ✅ table handles track the pointer over a header table
- ✅ Tab moves to the next cell — landed in {"cell":"a2","rows":2}
- ✅ Shift+Tab moves back a cell — landed in {"cell":"a1","rows":2}
- ✅ Tab in the last cell adds a row and lands in it — rows 2 -> 3 (from cell b2)
- ✅ toolbar creates no fixed-positioning containing block — backdrop=none filter=none transform=none
- ✅ every insert-table grid cell is clickable — ok
- ✅ table handles are visible and clickable over a header table — 8/8 interactive
- ✅ the fill swatch applies a fill — ok
- ✅ fill applies to every cell in a multi-cell selection — ok
- ✅ the fill STAYS through hover, typing and caret moves — ok
- ✅ the fill survives into the serialized body — ok
- ✅ no editor chrome leaks into the serialized body — ok
- ✅ Designer tab offers templates to open when none is loaded — {"list":true,"count":7,"first":"Verify — Designer (pill-dense)AccountDesign →"}
- ✅ template list stays bounded regardless of org size — 7 rendered · 7 templates
- ✅ template search filters the list — ok
- ✅ clearing the search restores the list
- ✅ clicking a template on the Designer tab opens it for editing — {"pv":true,"bar":true}
- ✅ chip drag: a draggable tag chip is present — {Name}
- ✅ chip drag: a ghost follows the cursor mid-drag
- ✅ chip drag: an insertion caret tracks the pointer
- ✅ chip drag: a landing box outlines the receiving block — {"ghost":true,"caret":true,"zoneShown":true,"zoneHasArea":true,"zoneStripsAsChrome":true}
- ✅ chip drag: the landing box is strippable as editor chrome — must carry dg-drop-marker or it leaks into the saved template
- ✅ chip drag: the snippet lands in the page — {"landed":true,"ghostLeft":false,"markerLeft":false,"zoneLeft":false}
- ✅ chip drag: the ghost is cleaned up
- ✅ chip drag: no drop marker is left behind
- ✅ chip drag: no landing box is left behind
- ✅ chip click (no drag) still inserts — {"landed":true,"ghostLeft":false,"markerLeft":false,"zoneLeft":false}
- ✅ insert: caret lands after the tag, not before it — {"tagAt":1283,"typedAt":1288,"text":".dg-pv { background: #fff; max-width: 850px; margin: 0 auto; padding: 48px 56px;"}
- ✅ insert: two inserts keep their order — {"first":"{Name}","second":"{Industry}","a":1283,"b":1289}
- ✅ "/" reaches the canvas instead of global search — {"text":".dg-pv { background: #fff; max-width: 85","focusInSearch":false}
- ✅ "/" does not leave focus in global search
- ✅ no console errors during interaction

### ui-admin — Admin UI

- ✅ admin app mounts with its three main tabs — Create New \| Your Templates \| Designer (Beta) \| More Tabs
- ✅ main tab "Create New" is reachable by a mouse
- ✅ main tab "Your Templates" is reachable by a mouse
- ✅ main tab "Designer" is reachable by a mouse
- ✅ main tab "Your Templates" swaps in its own content
- ✅ main tab "Create New" swaps in its own content
- ✅ authoring card "file" is reachable by a mouse
- ✅ authoring card "file" selects and reveals the Type / Output Format pickers — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "canvas" is reachable by a mouse
- ✅ authoring card "canvas" selects and reveals the Canvas setup fields — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ Advanced options discloses the power-user fields — Data Source radio group visible before=false after=true
- ✅ creating with an empty name is refused with a visible error — Error notification. Name it first Give the template a name, then create. Press Command + F6 to navigate to the next toas
- ✅ a refused create writes no template record
- ✅ wizard Next refuses to advance without a name — error shown; still on step 1 = true
- ✅ wizard Next advances to step 2 (Pick Your Data)
- ✅ wizard Back returns to step 1 and keeps what was typed — onStep1=true name="QAUI-k981yn-File" (expected "QAUI-k981yn-File")
- ✅ wizard step 2 refuses an empty query — Error notification. Error Please add at least one field to the query. Press Command + F6 to navigate to the next toast n
- ✅ wizard step 3 reviews the name, object and query it will save — reviewScreen=true nameEchoed=true queryEchoed=true
- ✅ the wizard creates a template record end to end — a0BRK00000gu1qr2AA, base object Account
- ✅ the created template keeps the query the wizard collected — Query_Config__c = Name, Industry, Phone
- ✅ the canvas path creates the template record — a0BRK00000gtvSF2AY, Canvas/PDF
- ✅ and it is typed Canvas, which is what decides which editor opens — Type__c=Canvas
- ✅ the canvas path lands on the artboard
- ⊘ the floating panels open with their contents rendered — the designer never opened
- ✅ the template list renders rows — 10 rows; count label "10 templates"
- ✅ search narrows the list to matching rows only — 10 -> 2 rows for "k981yn"; every remaining row matches = true
- ✅ the row-count label reports the filtered subset — label reads "2 of 10 templates"
- ✅ a search with no matches empties the list instead of ignoring the query — 0 rows survived a nonsense query
- ✅ clearing the search restores the full list — 10 rows (expected 10)
- ✅ clicking a column header re-orders the rows both ways — clicked=true; first row "QAUI-k981yn-Starter Canvas P" -> asc "QA Fixtures Anchor Demo Canv" -> desc "Verify — Designer (pill-dens"
- ✅ Refresh reloads the list without emptying it — hit-test=ok; 10 rows after refresh (expected 10)
- ✅ "New Template" switches to the Create New wizard
- ✅ the row-action menu button is reachable by a mouse
- ✅ row action View opens the template on its Copy-Paste Tags tab — modalOpen=true, selected tabs: Your Templates, Copy-Paste Tags
- ✅ row action Export downloads a valid .docgen.json bundle — QAUI-k981yn-Starter.docgen.json — export version 1, template "QAUI-k981yn-Starter"
- ✅ Import Template restores an exported bundle as a new template — "QAUI-k981yn-Imported" exists after import
- ✅ row action Clone creates a copy and opens it for editing — created "QAUI-k981yn-File (Copy)" (a0BRK00000gu1vh2AA); the edit modal opened = true
- ✅ row action Delete removes the template — "QAUI-k981yn-File (Copy)" is gone from the org
- ✅ deleting a template asks for confirmation first — a confirmation step was shown
- ✅ row action Design opens that template in an editor — opened the canvas artboard
- ✅ row action Edit opens the edit modal
- ✅ the modal Save button is reachable (nothing covers the footer)
- ✅ edit modal tab "Settings" renders its panel — selected=Settings, controls=30, expected content present=true, text=1599 chars
- ⊘ edit modal tab "Header / Footer" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Watermark" renders its panel — selected=Watermark / Background, controls=2, expected content present=true, text=569 chars
- ✅ edit modal tab "Query Configuration" renders its panel — selected=Query Configuration, controls=7, expected content present=true, text=1265 chars
- ✅ edit modal tab "Signer Inputs" renders its panel — selected=Signer Inputs, controls=3, expected content present=true, text=485 chars
- ✅ edit modal tab "Copy-Paste Tags" renders its panel — selected=Copy-Paste Tags, controls=80, expected content present=true, text=1230 chars
- ⊘ edit modal tab "Fillable Fields" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Document & History" renders its panel — selected=Document & History, controls=2, expected content present=true, text=561 chars
- ✅ a tag chip copies its merge tag to the clipboard — clicked "{Name}"; the clipboard now holds "{Name}"
- ✅ Signer Inputs: "Add Field" adds a field row — signer field rows 0 -> 1
- ✅ Signer Inputs: a field row is editable — label was "New Field"
- ✅ Signer Inputs: removing a field takes it off the list — signer field rows 1 -> 0
- ✅ edit modal inputs accept real typing — description="edited by ui-admin k981yn" category="QAk981yn"
- ✅ the Active toggle flips when clicked — checked true -> false
- ✅ Save as New Version persists the edited fields — stored description="edited by ui-admin k981yn", category="QAk981yn" (expected "edited by ui-admin k981yn" / "QAk981yn")
- ✅ Save as New Version really creates a new version record — template versions 0 -> 1
- ⊘ closing the modal with unsaved edits warns or preserves them — could not re-open the modal: row "QAUI-k981yn-Starter": the menu never offered a visible "Edit" item
- ✅ Command Hub: "My Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Template Library Manage your document designs and create new"; body 1565 chars
- ✅ Command Hub: "Bulk Generation" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Bulk Generation Create documents for hundreds of records at "; body 167 chars
- ✅ Command Hub: "Signatures" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Signature Settings Configure email branding, site URL, and s"; body 1264 chars
- ✅ Command Hub: "Assets" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Shared Assets Manage reusable images like logos and footers "; body 179 chars
- ✅ Command Hub: "Email Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Email Templates Brand and edit every signature email — reque"; body 1536 chars
- ✅ Command Hub: "Learning Center" opens its panel — panel header "Template Library Manage your document designs and create new" -> "User Guide The full Portwood User Guide lives on the web — a"; body 319 chars
- ✅ the Command Hub sidebar stays usable after opening Bulk Generation — 7 nav items reachable throughout
- ✅ no unexpected console errors while driving the admin UI
- ✅ the suite cleans up the templates it created — 3 QAUI- templates deleted

### template-integrity — Template integrity

- ✅ every HTML template returns a body to the visual Designer — all 2 HTML templates return a non-empty body from getHtmlTemplateBody
- ✅ each template agrees with its active version about its own type — no template/version type disagreements
- ⊘ merge-tag pills stay inside their table cells — could not open a template in the Designer: no Designer tab
