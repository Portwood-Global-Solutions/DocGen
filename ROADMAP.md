# Roadmap

DocGen is free, native, and community-driven. There are no paid tiers and no feature gates, so this roadmap isn't a sales sheet. It's an honest view of what's queued and what we're still thinking about. Priorities come from real customer reports and community requests, triaged in the open on GitHub — the issue board is the source of truth for what's in flight.

DocGen is [listed on the AppExchange](https://appexchange.salesforce.com/appxListingDetail?listingId=5a580bd8-2745-41e5-b62c-c495957857d3) and ships on a fast release cadence — currently v3.30. Recent releases brought guest e-signing with drawn signatures, a shared image-asset manager, brandable email templates, quick-action generation, and template management upgrades. For the full record, see the [changelog](/changelog).

**Want to shape it?** Open a request on [GitHub Issues](https://github.com/Portwood-Global-Solutions/DocGen/issues) or post in [Slack](/community). Every request gets read, labeled, and tracked. Bugs that silently corrupt output jump the queue.

## Up next

Enhancements with a clear path, planned for the next release or two.

### Preview before you save ([#212](https://github.com/Portwood-Global-Solutions/DocGen/issues/212))

The runner generates and saves in one step. This adds a preview (and print) of the generated PDF before you commit to saving it on the record or downloading it — catch a wrong template or a bad merge before it becomes a File.

### Template comments ([#211](https://github.com/Portwood-Global-Solutions/DocGen/issues/211))

A comment syntax for template authors: leave notes to yourself ("this table feeds from the Opportunity line items") inside the template, and the merge engine strips them from every generated document.

### Custom Label merge tags ([#204](https://github.com/Portwood-Global-Solutions/DocGen/issues/204))

Resolve Salesforce Custom Labels inside templates, so one template can serve a multi-language org — the label renders in each recipient's language instead of hardcoded text.

## On the horizon

Larger items on the list, paced by community demand.

### Images in signature and notification emails ([#198](https://github.com/Portwood-Global-Solutions/DocGen/issues/198))

Logos and branding images in the emails DocGen sends around signing and delivery. Weighing two designs — routing through the shared asset system versus a public-URL hook — before committing.

### Bulk runner and admin in every language

The document runner already follows each user's Salesforce language across ten translations (Spanish, Japanese, Chinese, French, German, Portuguese, Italian, Korean, Dutch). The bulk-generation and template-admin screens are next, so the whole app speaks the user's language without a separate setting.

### Right-to-left line wrapping

Long right-to-left paragraphs that wrap can start their continuation lines from the wrong margin, a limitation of the PDF engine's bidirectional text support. (The signing preview and final PDF render RTL text correctly today.) On the list for a future release.

## Exploring

Ideas with merit that are iceboxed until demand moves them up. Feedback here is especially useful — a few voices asking is what promotes these.

### Reusable template partials ([#31](https://github.com/Portwood-Global-Solutions/DocGen/issues/31))

Define a header, footer, or signature block once and include it across many templates. A design spec is drafted; it's iceboxed until enough teams ask for it.

### Drag-and-drop template builder ([#55](https://github.com/Portwood-Global-Solutions/DocGen/issues/55))

A visual, no-Word path to authoring templates. Iceboxed — Word and HTML templates with merge tags remain the supported authoring path, and they cover the same ground with tools authors already know. Would revisit if demand builds.

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
