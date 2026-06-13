# Portwood DocGen Charting Quick Course

This short course teaches the charting features by building one survey report template. It is written for template authors who already know basic DocGen merge tags and want to add charts without learning Apex.

Use HTML as the preferred source format for chart-heavy documents. Word templates can render simple charts, but HTML gives you better control over table-like chart layouts, nested `{#cols}` loops, and PDF-safe styling.

Related examples:

- `docs/ChartEngineShowcase.html` - all shorthand `{Chart:...}` styles in one document.
- `docs/SurveyChartExample.html` - full survey report with one chart per page.
- `docs/CommuteSurveyExample.html` - advanced pivot, filtering, multi-select splitting, and column ordering.
- `docs/ChartingQuickCourseExample.html` - companion template for this course.

## The Data Shape

The examples assume a parent survey record with a child relationship named `Survey_Responses__r`.

Each child response has fields like:

- `Selected_Answer__c` - the answer to bucket by.
- `Department__c` - a dimension for cross-tab charts.
- `Location__c` - another dimension for cross-tab charts.
- `Mode__c` - a normalized answer such as `Drive`, `Transit`, or `Telework`.
- `Reasons__c` - a semicolon-delimited multi-select style value.

You can substitute any child relationship and child fields from your own Salesforce object model.

## Lesson 1: Add a Simple Chart

The fastest chart is the shorthand tag:

```html
{Chart:Survey_Responses__r:Selected_Answer__c:bar:title=Answer Distribution}
```

Syntax:

```text
{Chart:relationship:field:style:option=value&option=value}
```

Supported styles:

- `bar` - horizontal bars. This is the default.
- `column` - vertical bars.
- `pie` - pie chart.
- `donut` - donut chart.
- `pivot` - table-style cross-tab.
- `stacked` - stacked horizontal bars.
- `clustered` - clustered vertical bars.
- `line` - line chart.
- `area` - filled line chart.

Useful options:

- `title=Your Chart Title`
- `groupBy=Department__c`
- `colSort=Engineering,Sales,Marketing,Support`
- `where=Selected_Answer__c != null`
- `colors=#1e3a8a,#f59e0b,#10b981`
- `width=540`
- `height=300`

For HTML templates that generate PDFs, keep the default rendering unless you are only previewing in a browser. Inline SVG can display in a browser preview, but Salesforce PDF rendering drops inline SVG.

## Lesson 2: Customize the Rows with ChartBucket

Use `{#ChartBucket...}` when you want full control over the markup.

```html
<table class="chart-table">
    {#ChartBucket:Survey_Responses__r:Selected_Answer__c}
    <tr>
        <td>{key_label}</td>
        <td>
            <div class="bar-track">
                <div class="bar-fill" style="width: {percent}%; background-color: {color};">&nbsp;</div>
            </div>
        </td>
        <td>{count} ({percent}%)</td>
    </tr>
    {:else}
    <tr>
        <td colspan="3">No responses found.</td>
    </tr>
    {/ChartBucket}
</table>
```

Inside each bucket row, DocGen exposes:

- `{key}` - raw bucket value.
- `{key_label}` - display label, with blank values shown as "Not Specified".
- `{count}` - number of child records in the bucket.
- `{percent}` - percentage of all records in that chart.
- `{max_percent}` - highest percent across buckets.
- `{color}` - chart color from the default or custom palette.
- `{index}` - 1-based bucket index.

## Lesson 3: Add a Cross-Tab Pivot

Use `groupBy=` to split each bucket into columns. Each row gets a nested `cols` list.

```html
{#ChartBucket:Survey_Responses__r:Selected_Answer__c:groupBy=Department__c&colSort=Engineering,Sales,Marketing,Support}
<div class="row">
    <div class="cell answer">{key_label}</div>
    {#cols}
    <div class="cell metric">{percent}% ({count})</div>
    {/cols}
</div>
{/ChartBucket}
```

The generated columns follow this order:

1. Values named in `colSort=`.
2. Remaining values, alphabetically.
3. `Total`, always last.

For HTML, prefer `div` containers with `display: table-row` and `display: table-cell` for nested `{#cols}` loops. Placing `{#cols}` directly inside a real `<tr>` can cause the outer row to duplicate unexpectedly during merge expansion.

## Lesson 4: Filter and Split Multi-Select Values

`where=` filters the child records used by the chart.

`split=;` treats one stored value as multiple selections. This is useful for multi-select picklist-like fields.

```html
{#ChartBucket:Survey_Responses__r:Reasons__c:where=Mode__c='Drive'&split=;}
```

With `split=`, percentages may add up to more than 100% because one response can contribute to multiple buckets.

## Complete Starter Template

Use `docs/ChartingQuickCourseExample.html` as a copy-paste starting point. It includes:

- A simple shorthand chart.
- A custom HTML bar chart using `{#ChartBucket}`.
- A pivot using `groupBy=` and `{#cols}`.
- A filtered multi-select chart using `where=` and `split=`.

## Authoring Checklist

- Prefer HTML for chart-heavy documents.
- Keep PDF CSS to CSS 2.1 patterns: tables, `display: table`, solid colors, and fixed margins.
- Avoid flexbox, grid, `gap`, CSS variables, gradients, and `calc()` in PDF templates.
- Use shorthand `{Chart:...}` for fast charts.
- Use `{#ChartBucket...}` when you need exact HTML control.
- Add `{:else}` blocks so empty datasets are visible to the reader.
- Use `colSort=` whenever `groupBy=` is present and the column order matters.
- For very large child datasets, omit the chart target relationship from eager-loaded query config when possible so DocGen can aggregate through SOQL fallback instead of loading every row into heap.
