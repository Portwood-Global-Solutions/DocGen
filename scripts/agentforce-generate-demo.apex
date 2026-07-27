// Real in-org AI generation, end to end: DocGen prompt -> Einstein via ConnectApi
// -> Flying Saucer validator.
//
//   sf apex run --target-org talentstacker-buildalong -f scripts/agentforce-generate-demo.apex
//
// REQUIRES, in the target org:
//   1. Einstein / Prompt Builder enabled.
//   2. A Flex prompt template with API name DocGen_HTML_Body, one required Free
//      Text input named Instructions, Saved AND Activated.
//      Setup > Einstein > Prompt Builder > New Prompt Template.
//   3. DocGenEinsteinProvider deployed (it is in .forceignore, so deploy by path):
//      sf project deploy start -o <org> \
//        -d force-app/main/default/classes/DocGenEinsteinProvider.cls
//
// Change WHAT_I_WANT and re-run to try different documents.

String WHAT_I_WANT =
    'A polished, modern invoice. Branded header band in deep blue with the account ' +
    'name, a tinted details panel, a line-item table with alternating row shading ' +
    'and a grand total row, and a footer note.';

String prompt =
    'You are writing an HTML document template for Portwood DocGen. DocGen replaces {merge tags} ' +
    'with Salesforce data, then renders the HTML to PDF with the Flying Saucer engine.\n\n' +
    'DATA SHAPE - use ONLY these fields:\n' +
    '- Base object: Opportunity\n  - {Name}\n  - {Amount} (currency)\n  - {CloseDate} (date)\n' +
    '  - {Account.Name} (parent lookup)\n' +
    '- Child relationship: {#OpportunityLineItems} ... {/OpportunityLineItems}\n' +
    '  Fields (write them BARE inside the loop):\n' +
    '    - {Quantity}\n    - {UnitPrice}\n    - {TotalPrice}\n    - {Product2.Name}\n\n' +
    'WHAT I WANT: ' +
    WHAT_I_WANT +
    '\n\nOUTPUT: ONE complete self-contained HTML file with all CSS in a single <style> block. ' +
    'No commentary, no markdown fences.';

DocGenAiProvider p = DocGenAiProviderFactory.get();
System.debug('PROVIDER = ' + p.getName() + ' (available=' + p.isAvailable() + ')');

Long t0 = System.currentTimeMillis();
String raw = p.generateHtml(prompt);
Long genMs = System.currentTimeMillis() - t0;

DocGenAiHtmlValidator.Result r = DocGenAiHtmlValidator.sanitize(raw);

System.debug('');
System.debug('GENERATED in ' + genMs + 'ms | raw ' + raw.length() + ' chars -> clean ' + r.html.length());
System.debug('CALLOUTS USED = ' + Limits.getCallouts() + '   <- ConnectApi is not an HTTP callout');
System.debug('');
System.debug('================ WHAT THE VALIDATOR CHANGED ================');
System.debug(r.summary);
for (DocGenAiHtmlValidator.Finding f : r.findings) {
    System.debug(f.action.toUpperCase() + '  ' + f.rule + '  (x' + f.occurrences + ')');
    System.debug('        ' + f.detail);
}
System.debug('');
System.debug('================ CLEANED HTML ================');
for (Integer i = 0; i < r.html.length(); i += 2500) {
    System.debug(r.html.substring(i, Math.min(i + 2500, r.html.length())));
}
