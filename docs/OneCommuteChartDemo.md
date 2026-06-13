# OneCommute Scratch-Org Chart Demo

This is a customer-specific demo for OneCommute. It creates a small
OneCommute-flavored data model in a scratch org, seeds realistic TDM survey
data, and uploads a PowerPoint DocGen template that is meant to be run through
the `docGenRunner` LWC from the demo `OneCommute Site` record.

The copy and object model are based on OneCommute's public positioning around
commuter programs, survey management, employer outreach, ordinance compliance,
and mobility analytics.

## Run

```bash
chmod +x scripts/demo-onecommute-setup.sh scripts/build-onecommute-chart-demo.mjs
scripts/demo-onecommute-setup.sh portwood-staging
```

Then open the scratch org, go to the `OneCommute Demo - 925 NorthPoint Parkway`
`OneCommute_Site__c` record, and run `OneCommute Demo PowerPoint Chart Report`
from DocGen Runner.

This demo must be generated through the browser Runner. PowerPoint chart tags
are intentionally prepared client-side: `docGenRunner` reads the `{Chart:...}`
tags, renders the chart images in the browser, uploads transient chart
ContentVersions, and passes the resulting `chartCvMap` into document generation.
Do not use anonymous Apex or server-side chart generation for the demo flow.

## Scratch-Org Objects

The setup deploys demo-only metadata from `demos/onecommute/force-app`:

- `OneCommute_Site__c`
- `OneCommute_Employer__c`
- `OneCommute_Survey_Response__c`
- `OneCommute_Trip_Count__c`
- `OneCommute_Demo` permission set, assigned by the setup script

The DocGen template uses `OneCommute_Site__c` as the base object. Chart visuals
target `Survey_Responses__r` through PowerPoint `{Chart:...}` tags and are
prepared by the Runner in the browser. Supporting tables use live merge tags,
relationship loops, and `ChartBucket` rows against the same seeded data.

## Template

The PowerPoint template is generated at:

```text
docs/OneCommuteChartDemoTemplate.pptx
```
