// =========================================================================
// repro-pr104-table-colgroup.apex
// =========================================================================
// Validates the PR #104 / v1.97.0 fix: DocGenHtmlRenderer.processTable now
// emits <colgroup> with column widths from <w:tblGrid> and adds
// table-layout:fixed to the table style.
//
// Before fix: tables with empty cells in middle columns collapsed those
// columns and redistributed the space to filled neighbors (typically the
// description column). Result: visually identical Word tables rendering
// with different column widths in PDF output.
//
// After fix: column widths come from the authored <w:tblGrid> regardless
// of which cells happen to have content.
//
// Run anonymously:
//   sf apex run --target-org <org> -f scripts/repro-pr104-table-colgroup.apex
//
// All assertions check string contents of the rendered HTML — no template
// upload or PDF generation needed. Tests the renderer in isolation.
// =========================================================================

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

String tableShell =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
    '<w:body>%TABLE%</w:body></w:document>';

// -------------------------------------------------------------------------
// Test 1: Customer-reported scenario.
// Three tables with IDENTICAL <w:tblGrid> declarations. Table 1 has content
// in every column; tables 2 and 3 have empty cells in columns 4 and 5.
// All three should render with the same column widths.
// -------------------------------------------------------------------------

String gridSrc =
    '<w:tblGrid>' +
    '<w:gridCol w:w="1000"/>' + //   50.00 pt   (QTY)
    '<w:gridCol w:w="3000"/>' + //  150.00 pt   (Description)
    '<w:gridCol w:w="2000"/>' + //  100.00 pt   (Country)
    '<w:gridCol w:w="2000"/>' + //  100.00 pt   (middle col — empty in T2/T3)
    '<w:gridCol w:w="2000"/>' + //  100.00 pt   (middle col — empty in T2/T3)
    '</w:tblGrid>';

String rowAllFilled =
    '<w:tr>' +
    '<w:tc><w:p><w:r><w:t>500</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>Hospital Bed</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>USA</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>12 months</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>USD 6</w:t></w:r></w:p></w:tc>' +
    '</w:tr>';

String rowEmptyMiddle =
    '<w:tr>' +
    '<w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>I-STAT Analyzer</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p><w:r><w:t>USA</w:t></w:r></w:p></w:tc>' +
    '<w:tc><w:p></w:p></w:tc>' + // EMPTY
    '<w:tc><w:p></w:p></w:tc>' + // EMPTY
    '</w:tr>';

String table1 = '<w:tbl><w:tblPr></w:tblPr>' + gridSrc + rowAllFilled + '</w:tbl>';
String table2 = '<w:tbl><w:tblPr></w:tblPr>' + gridSrc + rowEmptyMiddle + '</w:tbl>';
String table3 = '<w:tbl><w:tblPr></w:tblPr>' + gridSrc + rowEmptyMiddle + '</w:tbl>';

String fullXml = tableShell.replace('%TABLE%', table1 + table2 + table3);
String html = DocGenHtmlRenderer.convertToHtml(fullXml);

Integer colgroupCount = html.split('<colgroup>').size() - 1;
if (colgroupCount == 3) {
    pass++;
    System.debug('PASS: All 3 tables emitted <colgroup>');
} else {
    fail++;
    failures.add('Expected 3 <colgroup> elements, got ' + colgroupCount);
}

Integer fixedLayoutCount = html.split('table-layout:fixed').size() - 1;
if (fixedLayoutCount == 3) {
    pass++;
    System.debug('PASS: All 3 tables forced table-layout:fixed');
} else {
    fail++;
    failures.add('Expected 3 table-layout:fixed declarations, got ' + fixedLayoutCount);
}

if (html.contains('<col style="width:50.00pt"/>')) {
    pass++;
    System.debug('PASS: Column 1 (50pt) width emitted');
} else {
    fail++;
    failures.add('Missing column 1 width 50pt');
}

if (html.contains('<col style="width:150.00pt"/>')) {
    pass++;
    System.debug('PASS: Column 2 (150pt) width emitted');
} else {
    fail++;
    failures.add('Missing column 2 width 150pt');
}

Integer hundredCount = html.split('width:100.00pt').size() - 1;
// 3 tables × 3 columns @ 100pt each = 9 occurrences
if (hundredCount >= 9) {
    pass++;
    System.debug('PASS: 100pt column widths repeated ' + hundredCount + ' times');
} else {
    fail++;
    failures.add('Expected >=9 occurrences of width:100.00pt, got ' + hundredCount);
}

// -------------------------------------------------------------------------
// Test 2: Backward compatibility — table without <w:tblGrid> should NOT
// emit colgroup or force fixed layout.
// -------------------------------------------------------------------------

String noGridXml = tableShell.replace(
    '%TABLE%',
    '<w:tbl><w:tblPr></w:tblPr>' + '<w:tr><w:tc><w:p><w:r><w:t>Plain cell</w:t></w:r></w:p></w:tc></w:tr>' + '</w:tbl>'
);
String noGridHtml = DocGenHtmlRenderer.convertToHtml(noGridXml);

if (!noGridHtml.contains('<colgroup>')) {
    pass++;
    System.debug('PASS: Table without <w:tblGrid> does NOT emit colgroup');
} else {
    fail++;
    failures.add('Table without <w:tblGrid> incorrectly emitted colgroup');
}

if (!noGridHtml.contains('table-layout:fixed')) {
    pass++;
    System.debug('PASS: Table without <w:tblGrid> does NOT force fixed layout');
} else {
    fail++;
    failures.add('Table without <w:tblGrid> incorrectly forced fixed layout');
}

// -------------------------------------------------------------------------
// Test 3: <w:tblGrid> with zero/missing w:w attributes — should NOT force
// fixed layout (preserves auto-sizing when widths are unspecified).
// -------------------------------------------------------------------------

String zeroWidthXml = tableShell.replace(
    '%TABLE%',
    '<w:tbl><w:tblPr></w:tblPr>' +
        '<w:tblGrid><w:gridCol w:w="0"/><w:gridCol/></w:tblGrid>' +
        '<w:tr><w:tc><w:p><w:r><w:t>Cell</w:t></w:r></w:p></w:tc></w:tr>' +
        '</w:tbl>'
);
String zeroHtml = DocGenHtmlRenderer.convertToHtml(zeroWidthXml);

if (!zeroHtml.contains('table-layout:fixed')) {
    pass++;
    System.debug('PASS: Zero/missing widths do NOT force fixed layout');
} else {
    fail++;
    failures.add('Zero-width grid incorrectly forced fixed layout');
}

// -------------------------------------------------------------------------
// Test 4: Direct repro of the reporter pattern. Render the 3-table HTML
// to a snippet and confirm the column-2 (Description) width is identical
// across all three tables, regardless of cell content in columns 4 and 5.
// -------------------------------------------------------------------------

Integer firstDescIdx = html.indexOf('width:150.00pt');
Integer lastDescIdx = html.lastIndexOf('width:150.00pt');
Integer descOccurrences = html.split('width:150.00pt').size() - 1;
if (descOccurrences == 3) {
    pass++;
    System.debug('PASS: Description column 150pt width appears in all 3 tables');
} else {
    fail++;
    failures.add('Description column width missing or duplicated: ' + descOccurrences + ' occurrences (expected 3)');
}

// -------------------------------------------------------------------------

System.debug('\n=========================================');
System.debug('PASS: ' + pass + '  FAIL: ' + fail);
if (fail == 0) {
    System.debug('ALL TESTS PASSED');
} else {
    System.debug('FAILURES:');
    for (String f : failures) {
        System.debug('  - ' + f);
    }
}
System.debug('=========================================');
