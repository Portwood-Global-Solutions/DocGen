// DocGen — find HTML template bodies that may have been overwritten with a blank
// document, and show what to restore them from.
//
// Run: sf apex run --target-org <org> -f scripts/audit-blanked-template-bodies.apex
//
// WHY: before v3.48, getHtmlTemplateBody looked its file up with a bare
// `WHERE Title LIKE 'docgen_html_body_<templateId>%'`. File access is not governed by
// Apex sharing keywords or WITH SYSTEM_MODE, so that query returned ZERO rows for any
// user without View All Data. The Designer treats a blank read as a new template and
// seeds a placeholder scaffold — and a Save then wrote that placeholder over the
// author's real body. Admins never saw it; everyone else did.
//
// The read is fixed and saveHtmlTemplateBody now refuses to overwrite a real body with
// an empty one, but neither helps a body already clobbered. This finds those.
//
// READ-ONLY. It reports; it does not modify anything. Restore instructions are printed
// per finding.

// Substantive = something an author would be sorry to lose. Mirrors
// DocGenController.hasSubstantiveHtml.
Boolean isSubstantive(String html) {
    if (String.isBlank(html)) {
        return false;
    }
    String lower = html.toLowerCase();
    if (lower.contains('<img') || lower.contains('<table') || lower.contains('<svg')) {
        return true;
    }
    if (Pattern.compile('\\{[#^/%@]?[A-Za-z_][^}]*\\}').matcher(html).find()) {
        return true;
    }
    String text = html.replaceAll('(?is)<(head|style|script)\\b[^>]*>.*?</\\1\\s*>', ' ');
    text = text.replaceAll('(?s)<[^>]*>', ' ');
    text = text.replaceAll('&nbsp;|&#160;', ' ').replaceAll('\\s+', ' ').trim();
    if (String.isBlank(text)) {
        return false;
    }
    return !text.startsWithIgnoreCase('Start typing your document here');
}

// Every body file, newest first per document. ALL versions, not just IsLatest — the
// previous version is the thing worth restoring.
List<ContentVersion> all = [
    SELECT Id, Title, ContentDocumentId, VersionNumber, CreatedDate, CreatedBy.Name, IsLatest, VersionData
    FROM ContentVersion
    WHERE Title LIKE 'docgen_html_body_%'
    ORDER BY ContentDocumentId, CreatedDate DESC
];

Map<Id, List<ContentVersion>> byDoc = new Map<Id, List<ContentVersion>>();
for (ContentVersion cv : all) {
    if (!byDoc.containsKey(cv.ContentDocumentId)) {
        byDoc.put(cv.ContentDocumentId, new List<ContentVersion>());
    }
    byDoc.get(cv.ContentDocumentId).add(cv);
}

Integer scanned = 0, suspect = 0, recoverable = 0;
List<String> findings = new List<String>();

for (Id docId : byDoc.keySet()) {
    List<ContentVersion> versions = byDoc.get(docId);
    ContentVersion newest = versions[0];
    scanned++;
    if (isSubstantive(newest.VersionData.toString())) {
        continue;
    }
    suspect++;
    // Walk back for the most recent version that still had content.
    ContentVersion restoreFrom = null;
    for (Integer i = 1; i < versions.size(); i++) {
        if (isSubstantive(versions[i].VersionData.toString())) {
            restoreFrom = versions[i];
            break;
        }
    }
    String tplId = newest.Title.substringAfter('docgen_html_body_').substringBefore('_');
    if (restoreFrom == null) {
        findings.add(
            'BLANK (no prior content to restore) template=' +
                tplId +
                ' doc=' +
                docId +
                ' savedBy=' +
                newest.CreatedBy.Name +
                ' on ' +
                newest.CreatedDate
        );
    } else {
        recoverable++;
        findings.add(
            'BLANKED template=' +
                tplId +
                ' doc=' +
                docId +
                ' blankedBy=' +
                newest.CreatedBy.Name +
                ' on ' +
                newest.CreatedDate +
                ' | RESTORE FROM ContentVersion ' +
                restoreFrom.Id +
                ' (v' +
                restoreFrom.VersionNumber +
                ', ' +
                restoreFrom.VersionData.size() +
                ' bytes, ' +
                restoreFrom.CreatedDate +
                ')'
        );
    }
}

for (String f : findings) {
    System.debug('AUDIT >> ' + f);
}
System.debug(
    'AUDIT RESULT >> templatesScanned=' +
        scanned +
        ' blankBodies=' +
        suspect +
        ' recoverable=' +
        recoverable +
        (suspect == 0 ? ' >> ALL CLEAN' : ' >> REVIEW THE FINDINGS ABOVE')
);
System.debug(
    'AUDIT RESTORE HOWTO >> For each BLANKED row, re-upload the named ContentVersion\'s ' +
        'VersionData as a NEW version of the same ContentDocument, or paste it back via ' +
        'the Designer Source view. Nothing was deleted — the old version is still there.'
);
