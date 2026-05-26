# Roadmap

DocGen is free, native, and community-driven. There are no paid tiers and no feature gates, so this roadmap isn't a sales sheet. It's an honest view of what's shipping, what's queued, and what we're still thinking about. Priorities come from real customer reports and community requests, triaged in the open on GitHub.

**Want to shape it?** Open a request on [GitHub Issues](https://github.com/Portwood-Global-Solutions/DocGen/issues) or post in [Slack](/community). Every request gets read, labeled, and tracked. Bugs that silently corrupt output jump the queue. See what already shipped on the [changelog](/changelog).

## In review

### AppExchange security review

DocGen is in the Salesforce AppExchange security review queue, re-submitted at v2.0.0 on the current managed package. Review typically takes a few months. The latest release stays available through the direct install link the entire time, so nothing blocks you from running DocGen today. Once approved, DocGen earns the AppExchange trust badge and becomes discoverable across the Salesforce ecosystem.

## Up next

Bugs and small enhancements with a clear path, planned for the next release or two.

### Bulk runner and admin in every language

The document runner already follows each user's Salesforce language across ten translations (Spanish, Japanese, Chinese, French, German, Portuguese, Italian, Korean, Dutch). The bulk-generation and template-admin screens are next, so the whole app speaks the user's language without a separate setting.

### Stylesheet leaking into PDF output (#139)

A reported case where template stylesheet markup can surface as text at the top of a generated PDF. Under investigation toward a scoped fix.

### Right-to-left signing preview (#138)

The final signed PDF renders Hebrew and Arabic correctly, but the in-page signing preview still lays them out left-to-right, so signers can't comfortably read the document before signing. Adding right-to-left direction support to the preview container.

## On the horizon

Larger, specced features on the list, paced by community demand.

### Full template fidelity on giant-query jobs (#134)

Documents above the giant-query row threshold currently skip a processing pass, so parent-level sections, conditionals, inverse tags, and secondary child loops can leak as raw text. Bringing the giant-query path to full parity with standard generation, including the "Save to Record" behavior on that path.

### Charts and text boxes in every layout

Two known Office edge cases on the fidelity list. Chart tags whose text Word or PowerPoint split across formatting runs still fall back to placeholder text (#130). And a text box that shares its paragraph with other content, such as an inline image, can drop that neighboring content.

### Reusable template partials (#31)

Define a header, footer, or signature block once and include it across many templates. Specced and ready to build.

### Right-to-left line wrapping

Long right-to-left paragraphs that wrap can start their continuation lines from the wrong margin, a limitation of the PDF engine's bidirectional text support. On the list for a future release.

## Exploring

Ideas with merit that still need scoping. Feedback here is especially useful.

### Drag-and-drop template builder (#55)

A visual, no-Word path to authoring templates. Large surface area, so we're gathering input on which pieces matter most before committing to a design.

### Native, editable Office charts

DocGen charts render as crisp images today — they look right in every format, but you can't click into them in Word or PowerPoint to change the underlying numbers. A future direction is emitting native Office chart objects so recipients can open **Edit Data** and adjust the chart directly. Image charts would stay the default; this would be an opt-in for Office-native output.

### PDF export from Excel and PowerPoint

Excel and PowerPoint templates currently generate in their native formats only, while Word and HTML can also produce PDF. Extending the PDF path to spreadsheets and slide decks is on the list, paced by demand.

## How we prioritize

Everything is triaged in the open. Each issue gets a priority label:

- **P0** — output is silently wrong, there's data loss, or the package is unusable for a whole segment. Ships in the next dot release, no exceptions.
- **P1** — a visible bug or regression with a workaround, or impact scoped to one feature. Planned into the next release or two.
- **P2** — a planned enhancement that's specced and actionable.
- **P3** — backlog. The idea has merit but needs more scoping, or impact is lower. Revisited as capacity allows.

Silent corruption always outranks loud crashes: a bug a customer can't see they hit beats a noisy error every time. Releases ship on a rolling set of milestones, and the backlog is re-evaluated each time one is cut.

> **This roadmap is a direction, not a contract.** Dates aren't promised, ordering can change, and community demand moves things up. For the definitive record of what actually shipped, see the [changelog](/changelog).
