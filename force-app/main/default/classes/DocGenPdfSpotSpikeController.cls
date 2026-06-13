/**
 * SPIKE / throwaway — de-risk for guided PDF signing (Milestone 3).
 *
 * Generates a real engine-produced PDF (Blob.toPdf / Flying Saucer) that embeds
 * several candidate "sign-spot anchor" strings at known positions, so the spike
 * page can prove PDF.js can (a) extract them from the text layer and (b) compute
 * a correct bounding box to overlay an interactive chip on.
 *
 * It deliberately embeds BOTH the verbose real tag form ({@Signature_...}) and a
 * compact sentinel form (@@SIG-n@@) so we can measure which survives PDF text
 * extraction without being split across runs.
 *
 * NOT for release. Delete with the spike VF page once Milestone 3 lands.
 */
public with sharing class DocGenPdfSpotSpikeController {
    // The anchors the spike page will search for, returned to JS as a parallel list.
    public static final List<String> ANCHORS = new List<String>{
        '{@Signature_Buyer:1:Full}',
        '{@Signature_Seller:2:Initials}',
        '@@SIG-1@@',
        '@@SIG-2@@'
    };

    @RemoteAction
    public static String getAnchorsJson() {
        return JSON.serialize(ANCHORS);
    }

    @RemoteAction
    public static String getTestPdfBase64() {
        String html =
            '<html><head><style>' +
            '@page { size: letter; margin: 0.75in; }' +
            'body { font-family: Helvetica, Arial, sans-serif; font-size: 11pt; color:#222; }' +
            'h1 { color:#0176d3; }' +
            '.spot { display:inline-block; background:#fff8c5; border:2px dashed #f59e0b;' +
            '        padding:2px 10px; font-weight:bold; color:#92400e; }' +
            '.gap { margin: 90px 0; }' +
            '</style></head><body>' +
            '<h1>Guided Signing Spike Document</h1>' +
            '<p>This document embeds sign-spot anchors as plain text so PDF.js can locate them.</p>' +
            '<div class="gap"><p>Buyer signature: <span class="spot">{@Signature_Buyer:1:Full}</span></p></div>' +
            '<div class="gap"><p>Seller initials: <span class="spot">{@Signature_Seller:2:Initials}</span></p></div>' +
            '<div class="gap"><p>Compact sentinel A: <span class="spot">@@SIG-1@@</span></p></div>' +
            // Force a second page to prove multi-page positioning.
            '<div style="page-break-before: always;"></div>' +
            '<h1>Page Two</h1>' +
            '<div class="gap"><p>Compact sentinel B: <span class="spot">@@SIG-2@@</span></p></div>' +
            '</body></html>';
        Blob pdf = Blob.toPdf(html);
        return EncodingUtil.base64Encode(pdf);
    }
}
