---
title: 'DocGen Chart Gallery'
subtitle: 'Button-ready Word template for chart rendering'
---

# {Name}

DocGen Chart Gallery

Generated {TODAY:date:MMMM d, yyyy}

This Word template is designed to be uploaded as a DocGen **Word** template and generated from a demo survey record. Each chart tag below is top-level text so DocGen can discover it, rasterize the chart, and replace the tag with a generated PNG when you press the runner button.

Use this template with survey-style demo data:

| Placeholder        | Expected value                 |
| ------------------ | ------------------------------ |
| Parent record      | A survey or survey-like record |
| Child relationship | `Survey_Responses__r`          |
| Bucket field       | `Selected_Answer__c`           |
| Cross-tab field    | `Location__c`                  |

\newpage

## 1. Horizontal Bar

Best for ranked categories and long answer labels.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Commute Mode Distribution&width=560&colors=#1e3a8a,#f59e0b,#10b981,#ef4444,#7c3aed}

\newpage

## 2. Vertical Column

Best when categories have short labels and you want a familiar dashboard-style chart.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:column:title=Commute Mode by Count&width=560&height=300&colors=#1e3a8a,#f59e0b,#10b981,#ef4444,#7c3aed}

\newpage

## 3. Pie

Best for a compact share-of-total view.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:pie:title=Commute Mode Share&width=460&height=240&colors=#1e3a8a,#f59e0b,#10b981,#ef4444,#7c3aed}

\newpage

## 4. Donut

Best for a lighter share-of-total visual with room for surrounding commentary.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:donut:title=Commute Mode Share Donut&width=460&height=240&colors=#1e3a8a,#f59e0b,#10b981,#ef4444,#7c3aed}

\newpage

## 5. Stacked Bar by Location

Best for showing composition across a second dimension. This chart groups each commute mode by office location.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:stacked:groupBy=Location__c&colSort=8000 Marina,3260 Bayshore&title=Location Mix by Commute Mode&width=560&colors=#1e3a8a,#f59e0b,#10b981}

\newpage

## 6. Clustered Bar by Location

Best for direct side-by-side comparison across locations.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:clustered:groupBy=Location__c&colSort=8000 Marina,3260 Bayshore&title=Commute Mode Comparison by Location&width=560&height=310&colors=#1e3a8a,#f59e0b,#10b981}

\newpage

## 7. Line by Location

Best for showing a sequence or trend-like comparison across ordered buckets. In survey data, treat the x-axis as ordered categories.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:line:groupBy=Location__c&colSort=8000 Marina,3260 Bayshore&title=Commute Mode Line Comparison&width=560&height=300&colors=#1e3a8a,#f59e0b,#10b981}

\newpage

## 8. Area by Location

Best when you want the line chart to read more like volume or accumulated share.

<!-- prettier-ignore -->
{Chart:Survey_Responses__r:Selected_Answer__c:area:groupBy=Location__c&colSort=8000 Marina,3260 Bayshore&title=Commute Mode Area Comparison&width=560&height=300&colors=#1e3a8a,#f59e0b,#10b981}

\newpage

## Author Notes

The eight chart tags above are the Word/PDF chart-image styles currently supported end-to-end: `bar`, `column`, `pie`, `donut`, `stacked`, `clustered`, `line`, and `area`.

## What About Pivot Tables?

Pivot tables are supported best in HTML templates. A pivot needs one outer bucket loop for the row labels and one inner column loop for the cross-tab values. HTML can express that cleanly with div-based table rows and table cells, which also renders reliably to PDF.

Word is better for the image-rendered chart styles in this gallery. Word can split template tags across internal XML runs, and nested pivot loops are more fragile there than in HTML. For a polished pivot-table report, start from `docs/CommuteSurveyExample.html` or `docs/ChartingQuickCourseExample.html`.

Use pivot when you want a table like this:

| Answer   | Engineering | Sales | Marketing | Support | Total |
| -------- | ----------: | ----: | --------: | ------: | ----: |
| Drive    |         42% |   31% |       20% |     18% |   29% |
| Transit  |         25% |   18% |       36% |     30% |   27% |
| Telework |         33% |   51% |       44% |     52% |   44% |

Keep chart tags on one plain-text line in Word. If Word splits a tag across styled runs, DocGen may not detect it during chart preflight.
