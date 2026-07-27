// Try the Flying Saucer validator by hand — NO Einstein needed, runs in any org
// that has the DocGen source deployed.
//
//   sf apex run --target-org <org> -f scripts/agentforce-validator-demo.apex
//
// This is what "Generate with Agentforce" runs on the model's output before the
// body is ever written. Edit DIRTY below to throw your own HTML at it.

String dirty =
    '<!DOCTYPE html>\n<html>\n<head>\n<style>\n' +
    '@page { size: Letter portrait; margin: 0.6in; }\n' +
    ':root { --brand: #0b3d91; }\n' +
    'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; box-sizing: border-box; }\n' +
    '.band { background: linear-gradient(90deg,#0b3d91,#63b3ed); color: #fff; padding: 12pt;\n' +
    '        display: flex; justify-content: space-between; align-items: center;\n' +
    '        border-radius: 6pt; box-shadow: 2pt 2pt 4pt #888; }\n' +
    '.tint { background: rgba(11,61,145,0.12); padding: 8pt; }\n' +
    '.muted { opacity: 0.75; color: var(--brand); }\n' +
    '.total { font-weight: 600; width: calc(100% - 20pt); }\n' +
    'table.items tr:nth-child(even) { background: #f5f7fa; }\n' +
    '.dash { border: 2pt dashed #2b6cb0; }\n' +
    '@media print { body { padding: 0; } }\n' +
    '</style>\n</head>\n<body>\n' +
    '<div class="band"><span>Invoice</span><span>{Account.Name}</span></div>\n' +
    '<div class="tint muted">{Name}</div>\n' +
    '<table class="items">\n<thead>\n<tr><th>Product</th><th>Qty</th></tr>\n</thead>\n<tbody>\n' +
    '{#OpportunityLineItems}\n<tr><td>{Product2.Name}</td><td>{Quantity}</td></tr>\n{/OpportunityLineItems}\n' +
    '</tbody>\n</table>\n' +
    '<p>Page {PageNumber} of {TotalPages}</p>\n' +
    '</body>\n</html>';

DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(dirty);

System.debug('================ WHAT CHANGED ================');
System.debug(r.summary);
System.debug('');
for (DocGenAiHtmlValidator.Finding f : r.findings) {
    System.debug(f.action.toUpperCase() + '  ' + f.rule + '  (x' + f.occurrences + ')');
    System.debug('        ' + f.detail);
}
System.debug('');
System.debug('================ CLEANED HTML ================');
for (Integer i = 0; i < r.html.length(); i += 2500) {
    System.debug(r.html.substring(i, Math.min(i + 2500, r.html.length())));
}

// Things that must survive — all measured to render correctly.
System.debug('');
System.debug('SANITY: @page kept          = ' + r.html.contains('@page'));
System.debug('SANITY: dashed border kept  = ' + r.html.contains('dashed'));
System.debug('SANITY: nth-child kept      = ' + r.html.contains('nth-child'));
System.debug('SANITY: merge tags kept     = ' + r.html.contains('{Account.Name}'));
System.debug('SANITY: loop moved into td  = ' + r.html.contains('<td>{#OpportunityLineItems}'));
