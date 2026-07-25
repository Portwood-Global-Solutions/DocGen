# QA-only UI host fixtures

**These never ship.** `sfdx-project.json` has exactly one packageDirectory —
`force-app` — so nothing here can be picked up by a package build.

## Why they exist

`docGenRunner`, `docGenSignatureSender` and `docGenButton` are the components a
customer actually touches, and they had **zero browser coverage**. Not because
they were skipped, but because they are `lightning__RecordPage` /
`lightning__RecordAction` components and the package deliberately ships no
FlexiPage or QuickAction — customers place them themselves. There is no
supported URL that renders an LWC on a record without a page assignment, so
there was nowhere for a test to reach them.

That is a reasonable packaging decision and a serious testing gap at the same
time. This resolves it without changing what ships.

## What it deploys

| Metadata                               | Purpose                                                                                       |
| -------------------------------------- | --------------------------------------------------------------------------------------------- |
| `QA_DocGen_Account_Record` (FlexiPage) | A record page hosting `docGenRunner` and `docGenSignatureSender`                              |
| `Account` (CustomObject)               | A `View` actionOverride pointing at that page, so it is the Account record page in the QA org |

## Use

```bash
./scripts/qa/fixtures/deploy.sh docgen-verify
```

Run it once per fresh verify org, then `npm run qa -- --suite ui-runner` can
reach the components.

## Still uncovered

`docGenButton` is `lightning__RecordAction` only, and hosting it needs a
`QuickAction` of type LightningComponent plus a layout entry. Adding one would
change the Account layout in the QA org; it is left undone deliberately and
reported as a named skip rather than quietly dropped.
