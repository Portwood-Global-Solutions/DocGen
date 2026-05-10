# Triage rubric

How we prioritize issues and enhancement requests on this repo. Reporters are welcome to suggest a priority in their issue body, but maintainers make the call when applying labels.

## Priority

| Label         | Use when…                                                                                                                           | Examples                                                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `priority:P0` | Output is silently wrong, data loss, or the package is unusable for an entire customer segment. Ship in the next dot release.       | #69 (`{#IF Field = "literal"}` silently false), #68 (`{:else}` misappropriated across nested IFs)                              |
| `priority:P1` | Visible regression or significant bug, but a workaround exists OR impact is scoped to one feature. Plan into the next 1–2 releases. | #67 (ProcessInstance grandchild stitcher), #71 (rich-text PDF image sizing), #60 (HTML/CSS rendering), #72 (guest DOCX images) |
| `priority:P2` | Planned enhancement on the roadmap. Specced and actionable.                                                                         | #31 (partials), #66 (Classic Approvals related list)                                                                           |
| `priority:P3` | Backlog. Idea has merit but needs more scoping, or impact is low. Revisit when capacity allows.                                     | #55 (drag-and-drop builder)                                                                                                    |

**The P0 test:** would a customer hit this and not know their output is wrong? If yes, it's P0 regardless of how rare. Silent corruption beats loud crashes.

## Severity (orthogonal to priority)

| Label                         | Meaning                                                                                                                                      |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `severity:silent-corruption`  | Output looks fine but is wrong. No error surfaced. Highest user impact because customers can't detect it. Frequently combined with P0 or P1. |
| `severity:visible-regression` | Quality issue is visible to the user (broken layout, missing image, malformed output). Customer can see it and report it.                    |

A bug should usually carry one severity label. Enhancements don't need a severity.

## Milestones

Three rolling milestones plus a backlog:

- **vNEXT.0** — current release in flight. Bug-fix-only when possible. Pull P0s here unconditionally.
- **vNEXT+1.0** — next release after that. P1 bugs and small enhancements land here.
- **vNEXT+2.0** — enhancement bundle. Larger features with completed specs.
- **Backlog** — P3 items, anything needing more scoping, parking lot.

When we cut a release we close its milestone, rename `vNEXT+1.0` → `vNEXT.0`, etc., and re-evaluate the backlog.

## Other useful labels

- `community-contribution` — reporter included a verified fix or substantial RCA. These are fast wins; surface them in triage.
- `bug`, `enhancement` — the type. Set automatically by issue templates.
- `pdf`, `docx`, `flow-action`, `bulk-generation`, `install-upgrade`, `template-help` — subsystem tags for filtering.

## Filter recipes

```
is:open label:priority:P0                  # fire-now list
is:open milestone:vNEXT.0                  # what's shipping
is:open label:severity:silent-corruption   # quality-of-fix watchlist
is:open label:community-contribution       # reporter-fix-attached
```
