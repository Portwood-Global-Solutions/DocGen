// Verify whether issue #60 (HTML templates with embedded CSS render incorrectly)
// is still reproducible at v1.91. Build a source HTML matching the reporter's
// pattern — <head><style>@page + body styles</style></head><body>... — and
// run it through the package's HTML parsing + wrapping pipeline.
//
// If extractHtmlStyleBlocks captures the CSS, extractHtmlBodyContent isolates
// the body, and wrapHtmlForPdf produces a single well-formed document with
// the CSS inside <style> and the body content rendered (no raw CSS text in
// the body), #60 is fixed by v1.90's @page suppression + the existing
// extraction logic.

String source =
    '<!DOCTYPE html><html>' +
    '<head>' +
    '<title>Repro 60</title>' +
    '<style>' +
    '@page { size: 8.5in 11in; margin: 1in; }' +
    'body { font-family: Arial, sans-serif; font-size: 11pt; color: #222; }' +
    'h1 { color: #1F4E79; font-size: 20pt; }' +
    'p.lead { font-style: italic; }' +
    '</style>' +
    '</head>' +
    '<body>' +
    '<h1>Repro #60 Header</h1>' +
    '<p class="lead">Lead paragraph — should be italic.</p>' +
    '<p>Body paragraph — should be Arial.</p>' +
    '</body>' +
    '</html>';

String css = DocGenService.extractHtmlStyleBlocks(source);
String body = DocGenService.extractHtmlBodyContent(source);
System.debug('===== extractHtmlStyleBlocks =====');
System.debug('Length: ' + (css == null ? 0 : css.length()));
System.debug(css);
System.debug('===== extractHtmlBodyContent =====');
System.debug('Length: ' + (body == null ? 0 : body.length()));
System.debug(body);

System.debug('===== wrapHtmlForPdf output =====');
String wrapped = DocGenService.wrapHtmlForPdf(body, css, '', '');
System.debug('Length: ' + (wrapped == null ? 0 : wrapped.length()));
Integer chunk = 3000;
for (Integer i = 0; i < wrapped.length(); i += chunk) {
    System.debug('WRAPPED[' + i + ']=' + wrapped.substring(i, Math.min(i + chunk, wrapped.length())));
}

System.debug('===== Assertions =====');
Boolean cssExtracted = css != null && css.contains('@page') && css.contains('Arial');
Boolean bodyExtracted =
    body != null &&
    body.contains('<h1>Repro #60 Header</h1>') &&
    !body.contains('<head>') &&
    !body.contains('@page');
Boolean wrappedHasStyle = wrapped.contains('<style') && wrapped.contains('Arial') && wrapped.contains('@page');
Boolean wrappedNoRawCssInBody = !wrapped.replaceAll('(?s)<style.*?</style>', '').contains('@page { size:');
Boolean wrappedHasH1 = wrapped.contains('<h1>Repro #60 Header</h1>');

System.debug('CSS extracted from <style>: ' + (cssExtracted ? 'PASS' : 'FAIL'));
System.debug('Body extracted from <body>: ' + (bodyExtracted ? 'PASS' : 'FAIL'));
System.debug('Wrapped output has <style>: ' + (wrappedHasStyle ? 'PASS' : 'FAIL'));
System.debug('No raw CSS leaks outside <style>: ' + (wrappedNoRawCssInBody ? 'PASS' : 'FAIL'));
System.debug('Wrapped output preserves h1: ' + (wrappedHasH1 ? 'PASS' : 'FAIL'));

Integer pass = 0;
Integer fail = 0;
for (
    Boolean b : new List<Boolean>{ cssExtracted, bodyExtracted, wrappedHasStyle, wrappedNoRawCssInBody, wrappedHasH1 }
) {
    if (b)
        pass++;
    else
        fail++;
}
System.debug('========================================');
System.debug('VERIFY #60 — PASS: ' + pass + '  FAIL: ' + fail);
System.debug('========================================');
