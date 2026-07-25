# DocGen QA report

**Org** `docgen-verify` · **Run** 2026-07-25T16:57:09.313Z · **Duration** 420s

## Headline

|                       |             |
| --------------------- | ----------- |
| Checks evaluated      | 107         |
| Passed                | 106 (99.1%) |
| Failed                | 1           |
| Skipped (not counted) | 2           |
| Blockers              | 0           |
| Major                 | 0           |
| Minor                 | 1           |

## Coverage by area

| Suite      | Area     | Passed | Failed | Skipped |  Rate |
| ---------- | -------- | -----: | -----: | ------: | ----: |
| `ui-admin` | Admin UI |    106 |      1 |       2 | 99.1% |

## What to fix

Ordered by severity. The detail column is written to say WHERE to look.

| Severity  | Suite      | Check                                                   | Evidence                                                                                                                                                                                                                                                                                                     |
| --------- | ---------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **minor** | `ui-admin` | no unexpected console errors while driving the admin UI | 1 errors, first: Connecting to 'https://business-business-345-dev-ed.scratch.lightning.force.com/aura?message=%7B%22actions%22%3A%5B%7B%22descriptor%22%3A%22serviceComponent%3A%2F%2Fui.force.components.controllers.empApi.EmpApiController%2FACTION%24getEmpConfig%22%2C%22callingDescriptor%22%3A%22UNKN |

## Not covered by this run

A skipped check is not a passing one. Each of these is a gap in the evidence.

- `ui-admin` — edit modal tab "Fillable Fields" renders its panel: not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- `ui-admin` — closing the modal with unsaved edits warns or preserves them: could not re-open the modal: row "QAUI-0m3haq-Starter": the menu never offered a visible "Edit" item

## Every check

### ui-admin — Admin UI

- ✅ admin app mounts with its three main tabs — Create New \| Your Templates \| Designer (Beta) \| More Tabs
- ✅ main tab "Create New" is reachable by a mouse
- ✅ main tab "Your Templates" is reachable by a mouse
- ✅ main tab "Designer" is reachable by a mouse
- ✅ main tab "Your Templates" swaps in its own content
- ✅ main tab "Create New" swaps in its own content
- ✅ authoring card "starter" is reachable by a mouse
- ✅ authoring card "starter" selects and reveals the starter gallery — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "ai" is reachable by a mouse
- ✅ authoring card "ai" selects and reveals the AI intro and its Next button — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "scratch" is reachable by a mouse
- ✅ authoring card "scratch" selects and reveals the blank-page CTA — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ authoring card "file" is reachable by a mouse
- ✅ authoring card "file" selects and reveals the Type / Output Format pickers — clicked=true selected=true otherCardsSelected=0 pathContentShown=true
- ✅ the starter gallery renders every predesigned starter — rendered 5: report, invoice, letter, agreement, certificate — expected report, invoice, letter, agreement, certificate
- ✅ every starter card takes selection when clicked — 5 starters each selected
- ✅ Advanced options discloses the power-user fields — Data Source radio group visible before=false after=true
- ✅ creating with an empty name is refused with a visible error — Error notification. Name it first Give the template a name, then create. Press Command + F6 to navigate to the next toas
- ✅ a refused create writes no template record
- ✅ wizard Next refuses to advance without a name — error shown; still on step 1 = true
- ✅ wizard Next advances to step 2 (Pick Your Data)
- ✅ wizard Back returns to step 1 and keeps what was typed — onStep1=true name="QAUI-0m3haq-File" (expected "QAUI-0m3haq-File")
- ✅ wizard step 2 refuses an empty query — Error notification. Error Please add at least one field to the query. Press Command + F6 to navigate to the next toast n
- ✅ wizard step 3 reviews the name, object and query it will save — reviewScreen=true nameEchoed=true queryEchoed=true
- ✅ the wizard creates a template record end to end — a0BO500000OqwRxMAJ, base object Account
- ✅ the created template keeps the query the wizard collected — Query_Config\_\_c = Name, Industry, Phone
- ✅ the AI path reaches the prompt screen
- ✅ the AI prompt is assembled with merge-tag syntax and the template fields — 7495 chars; contains merge-tag braces = true
- ✅ the AI prompt rebuilds live from what the author describes — prompt 7296 chars; carries the typed description = true
- ✅ Copy Prompt puts the whole prompt on the clipboard — clipboard holds 7356 chars; includes the live description = true
- ✅ the AI paste-back box accepts the returned HTML — textarea holds "<html><body><p>pasted</p></body></html>"
- ✅ the starter path creates the template record — a0BO500000OrC8TMAV, HTML/PDF
- ✅ the starter path lands in the designer with the design loaded
- ✅ the starter body is real content, not an empty page — 11649 chars of HTML — ".dg-pv { background: #fff; max-width: 850px; margin: 0 auto; padding: 48px 56px; box-shadow: 0 2px 1"
- ✅ panel button "insert" is reachable by a mouse
- ✅ panel "insert" opens with its contents rendered — title="Insert blocks" (expected "Insert blocks"), interactive children=66, text=1245 chars
- ✅ panel "insert" is not clipped or covered once open — hit-test says: ok
- ✅ panel "insert" closes from its own X
- ✅ panel button "tags" is reachable by a mouse
- ✅ panel "tags" opens with its contents rendered — title="Merge tags" (expected "Merge tags"), interactive children=75, text=2312 chars
- ✅ panel "tags" is not clipped or covered once open — hit-test says: ok
- ✅ panel "tags" closes from its own X
- ✅ panel button "images" is reachable by a mouse
- ✅ panel "images" opens with its contents rendered — title="Image assets" (expected "Image assets"), interactive children=2, text=186 chars
- ✅ panel "images" is not clipped or covered once open — hit-test says: ok
- ✅ panel "images" closes from its own X
- ✅ panel button "query" is reachable by a mouse
- ✅ panel "query" opens with its contents rendered — title="Query fields" (expected "Query fields"), interactive children=37, text=915 chars
- ✅ panel "query" is not clipped or covered once open — hit-test says: ok
- ✅ panel "query" closes from its own X
- ✅ panel button "versions" is reachable by a mouse
- ✅ panel "versions" opens with its contents rendered — title="Version history" (expected "Version history"), interactive children=1, text=170 chars
- ✅ panel "versions" is not clipped or covered once open — hit-test says: ok
- ✅ panel "versions" closes from its own X
- ✅ panel button "hf" is reachable by a mouse
- ✅ panel "hf" opens with its contents rendered — title="Header & Footer" (expected "Header & Footer"), interactive children=3, text=502 chars
- ✅ panel "hf" is not clipped or covered once open — hit-test says: ok
- ✅ panel "hf" closes from its own X
- ✅ panel button "watermark" is reachable by a mouse
- ✅ panel "watermark" opens with its contents rendered — title="Watermark" (expected "Watermark"), interactive children=3, text=260 chars
- ✅ panel "watermark" is not clipped or covered once open — hit-test says: ok
- ✅ panel "watermark" closes from its own X
- ✅ Tags panel: clicking a tag puts it on the page — inserted "Name"
- ✅ the designer exposes its page size and orientation pickers — 2 page-setup selects found (expected at least size + orientation)
- ✅ changing page orientation resizes the sheet — sheet width 816 -> 1056 switching to landscape
- ✅ the template list renders rows — 13 rows; count label "13 templates"
- ✅ search narrows the list to matching rows only — 13 -> 2 rows for "0m3haq"; every remaining row matches = true
- ✅ the row-count label reports the filtered subset — label reads "2 of 13 templates"
- ✅ a search with no matches empties the list instead of ignoring the query — 0 rows survived a nonsense query
- ✅ clearing the search restores the full list — 13 rows (expected 13)
- ✅ clicking a column header re-orders the rows both ways — clicked=true; first row "QAUI-0m3haq-Starter HTML PDF" -> asc "Account HTML PDF Account Act" -> desc "Verify — Landscape Precedenc"
- ✅ Refresh reloads the list without emptying it — hit-test=ok; 13 rows after refresh (expected 13)
- ✅ "New Template" switches to the Create New wizard
- ✅ the row-action menu button is reachable by a mouse
- ✅ row action View opens the template on its Copy-Paste Tags tab — modalOpen=true, selected tabs: Your Templates, Copy-Paste Tags
- ✅ row action Export downloads a valid .docgen.json bundle — QAUI-0m3haq-Starter.docgen.json — export version 1, template "QAUI-0m3haq-Starter"
- ✅ Import Template restores an exported bundle as a new template — "QAUI-0m3haq-Imported" exists after import
- ✅ row action Clone creates a copy and opens it for editing — created "QAUI-0m3haq-File (Copy)" (a0BO500000OrCDJMA3); the edit modal opened = true
- ✅ row action Delete removes the template — "QAUI-0m3haq-File (Copy)" is gone from the org
- ✅ deleting a template asks for confirmation first — a confirmation step was shown
- ✅ row action Design opens that template in the designer
- ✅ row action Edit opens the edit modal
- ✅ the modal Save button is reachable (nothing covers the footer)
- ✅ edit modal tab "Settings" renders its panel — selected=Settings, controls=36, expected content present=true, text=1576 chars
- ✅ edit modal tab "Header / Footer" renders its panel — selected=Header / Footer, controls=38, expected content present=true, text=680 chars
- ✅ edit modal tab "Watermark" renders its panel — selected=Watermark / Background, controls=2, expected content present=true, text=569 chars
- ✅ edit modal tab "Query Configuration" renders its panel — selected=Query Configuration, controls=7, expected content present=true, text=521 chars
- ✅ edit modal tab "Signer Inputs" renders its panel — selected=Signer Inputs, controls=3, expected content present=true, text=485 chars
- ✅ edit modal tab "Copy-Paste Tags" renders its panel — selected=Copy-Paste Tags, controls=18, expected content present=true, text=326 chars
- ⊘ edit modal tab "Fillable Fields" renders its panel — not offered for an HTML/PDF template — this tab is type-gated and needs a template of the gating type
- ✅ edit modal tab "Document & History" renders its panel — selected=Document & History, controls=8, expected content present=true, text=405 chars
- ✅ a tag chip copies its merge tag to the clipboard — clicked "{Name}"; the clipboard now holds "{Name}"
- ✅ Signer Inputs: "Add Field" adds a field row — signer field rows 0 -> 1
- ✅ Signer Inputs: a field row is editable — label was "New Field"
- ✅ Signer Inputs: removing a field takes it off the list — signer field rows 1 -> 0
- ✅ edit modal inputs accept real typing — description="edited by ui-admin 0m3haq" category="QA0m3haq"
- ✅ the Active toggle flips when clicked — checked true -> false
- ✅ Save as New Version persists the edited fields — stored description="edited by ui-admin 0m3haq", category="QA0m3haq" (expected "edited by ui-admin 0m3haq" / "QA0m3haq")
- ✅ Save as New Version really creates a new version record — template versions 0 -> 1
- ⊘ closing the modal with unsaved edits warns or preserves them — could not re-open the modal: row "QAUI-0m3haq-Starter": the menu never offered a visible "Edit" item
- ✅ Command Hub: "My Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Template Library Manage your document designs and create new"; body 1842 chars
- ✅ Command Hub: "Bulk Generation" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Bulk Generation Create documents for hundreds of records at "; body 167 chars
- ✅ Command Hub: "Signatures" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Signature Settings Configure email branding, site URL, and s"; body 1399 chars
- ✅ Command Hub: "Assets" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Shared Assets Manage reusable images like logos and footers "; body 481 chars
- ✅ Command Hub: "Email Templates" opens its panel — panel header "Template Library Manage your document designs and create new" -> "Email Templates Brand and edit every signature email — reque"; body 1561 chars
- ✅ Command Hub: "Learning Center" opens its panel — panel header "Template Library Manage your document designs and create new" -> "User Guide The full DocGen User Guide lives on the web — alw"; body 317 chars
- ✅ the Command Hub sidebar stays usable after opening Bulk Generation — 7 nav items reachable throughout
- ❌ no unexpected console errors while driving the admin UI — 1 errors, first: Connecting to 'https://business-business-345-dev-ed.scratch.lightning.force.com/aura?message=%7B%22actions%22%3A%5B%7B%22descriptor%22%3A%22serviceComponent%3A%2F%2Fui.force.component
- ✅ the suite cleans up the templates it created — 3 QAUI- templates deleted
