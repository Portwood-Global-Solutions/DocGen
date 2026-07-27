/**
 * Canned-response provider. Lets the whole pipeline — validator, staging field,
 * ContentVersion write, Designer load — be exercised in an org with no Einstein
 * entitlement, and in every unit test.
 *
 * The default response is deliberately DIRTY: it reproduces what a general model
 * actually returned when asked for an invoice with the CSS 2.1 constraint stated
 * up front (measured 2026-07-26 against GPT-5-mini through Prompt Builder). It
 * carries display:flex, box-sizing, opacity, an rgba() tint, a gradient,
 * border-radius, a numeric font-weight, an @media block, and a loop tag placed
 * between table rows. Sanitizing THIS is the thing worth testing.
 */
public with sharing class DocGenAiStubProvider implements DocGenAiProvider {
    /** Overridable so a test can pin an exact response. */
    @TestVisible
    private String cannedResponse;

    public DocGenAiStubProvider() {
        this(null);
    }

    public DocGenAiStubProvider(String cannedResponse) {
        this.cannedResponse = cannedResponse;
    }

    public Boolean isAvailable() {
        return true;
    }

    public String getName() {
        return 'Stub';
    }

    public String generateHtml(String prompt) {
        return String.isNotBlank(this.cannedResponse) ? this.cannedResponse : DIRTY_SAMPLE;
    }

    @TestVisible
    private static final String DIRTY_SAMPLE =
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
        'table.items { width: 100%; border-collapse: collapse; }\n' +
        'table.items tr:nth-child(even) { background: #f5f7fa; }\n' +
        '@media print { body { padding: 0; } }\n' +
        '</style>\n</head>\n<body>\n' +
        '<div class="band"><span>Invoice</span><span>{Account.Name}</span></div>\n' +
        '<div class="tint muted">{Name} &mdash; {CloseDate:MMMM d, yyyy}</div>\n' +
        '<table class="items">\n<thead>\n<tr><th>Product</th><th>Qty</th><th>Total</th></tr>\n</thead>\n<tbody>\n' +
        '{#OpportunityLineItems}\n<tr><td>{Product2.Name}</td><td>{Quantity}</td><td>{TotalPrice:currency}</td></tr>\n{/OpportunityLineItems}\n' +
        '</tbody>\n</table>\n' +
        '<p class="total">Grand total: {SUM:OpportunityLineItems.TotalPrice:currency}</p>\n' +
        '<p>Page {PageNumber} of {TotalPages}</p>\n' +
        '</body>\n</html>';
}
