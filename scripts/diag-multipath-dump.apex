// Dumps the most recent signature request's cached previewHtml + Template_Ids__c
// so you can verify what got cached without having to load the signer VF page
// (scratch org has no Site provisioned).

DocGen_Signature_Request__c req = [
    SELECT Id, Template_Ids__c, Signature_Data__c
    FROM DocGen_Signature_Request__c
    ORDER BY CreatedDate DESC
    LIMIT 1
];

System.debug('REQ_ID: ' + req.Id);
System.debug('TEMPLATE_IDS: ' + req.Template_Ids__c);

if (String.isBlank(req.Signature_Data__c)) {
    System.debug('PREVIEW_HTML: <empty>');
    return;
}

Map<String, Object> cached = (Map<String, Object>) JSON.deserializeUntyped(req.Signature_Data__c);
String previewHtml = (String) cached.get('previewHtml');
System.debug('PREVIEW_HTML_LEN: ' + (previewHtml == null ? 0 : previewHtml.length()));

// Count DIAG marker occurrences per template — proves uniqueness end-to-end
for (String marker : new List<String>{ 'DIAG_ALPHA', 'DIAG_BRAVO', 'DIAG_CHARLIE', 'DIAG_DELTA' }) {
    Integer count = 0;
    Integer idx = 0;
    while (idx != -1) {
        idx = previewHtml.indexOf(marker, idx);
        if (idx != -1) {
            count++;
            idx += marker.length();
        }
    }
    System.debug('MARKER ' + marker + ' appears ' + count + ' time(s)');
}

// Emit the full HTML in chunks so it can be reassembled from the log
Integer chunkSize = 8000;
Integer chunks = (previewHtml.length() + chunkSize - 1) / chunkSize;
System.debug('PREVIEW_HTML_CHUNKS: ' + chunks);
for (Integer i = 0; i < chunks; i++) {
    Integer startIdx = i * chunkSize;
    Integer endIdx = Math.min(startIdx + chunkSize, previewHtml.length());
    System.debug('CHUNK_' + i + '_START');
    System.debug(previewHtml.substring(startIdx, endIdx));
    System.debug('CHUNK_' + i + '_END');
}
