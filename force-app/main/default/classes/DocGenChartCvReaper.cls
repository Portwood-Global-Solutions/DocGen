/**
 * Deletes orphaned transient chart ContentVersions.
 *
 * Chart rasterization uploads one `docgen_chart_*` ContentVersion per chart as a
 * render input, and the CALLER owns cleanup. The interactive runner reaps its own
 * in a finally; so does DocGenBatch. But a caller that dies mid-flow — an uncaught
 * limit exception, a killed batch, a browser tab closed between upload and
 * generate — leaves its CVs behind with nothing watching them.
 *
 * That was tolerable while the only producer was a human clicking Generate. Once
 * bulk generation rasterizes per record, the failure mode scales with the job:
 * N records x M charts of orphaned files. This is the backstop.
 *
 * Only reaps CVs older than the age threshold, so it can never delete one that a
 * render is actively using — a chart CV's useful life is a single transaction.
 *
 * Schedule hourly:
 *   System.schedule('DocGen Chart CV Reaper', '0 0 * * * ?', new DocGenChartCvReaper());
 */
global with sharing class DocGenChartCvReaper implements Schedulable { // NOPMD AvoidGlobalModifier — global so subscribers can schedule it in a managed package
    private static final String CV_TITLE_PREFIX = 'docgen_chart_';

    // Chart CVs live for one transaction. An hour is far beyond any legitimate
    // render, including a batch chunk running at the async CPU ceiling, while
    // still keeping orphans short-lived.
    @TestVisible
    private static final Integer ORPHAN_AGE_MINUTES = 60;

    // Batch-friendly cap. A single scheduled run reaps at most this many; the next
    // run picks up the rest rather than risking the DML row limit in one pass.
    @TestVisible
    private static final Integer MAX_PER_RUN = 500;

    global void execute(SchedulableContext ctx) {
        reap();
    }

    /**
     * Deletes orphaned chart CVs. Returns the number of ContentDocuments removed.
     * Separated from execute() so tests and ad-hoc admin runs can call it directly.
     */
    global static Integer reap() {
        DateTime cutoff = System.now().addMinutes(-ORPHAN_AGE_MINUTES);
        String titlePattern = CV_TITLE_PREFIX + '%';

        // SYSTEM_MODE: these are package-internal render artifacts whose
        // ContentDocumentLinks default to Visibility=InternalUsers, which USER_MODE
        // reads silently drop (the #114 quirk) — a USER_MODE query here would report
        // "nothing to clean up" while orphans piled up.
        DocGenFlsGuard.assertAccessible(ContentVersion.sObjectType, new Set<String>{ 'Title', 'ContentDocumentId' });
        /* code-analyzer-suppress ApexFlsViolation */
        List<ContentVersion> orphans = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Title LIKE :titlePattern AND CreatedDate < :cutoff AND IsLatest = TRUE
            WITH SYSTEM_MODE
            LIMIT :MAX_PER_RUN
        ];
        if (orphans.isEmpty()) {
            return 0;
        }

        // Delete the ContentDocument, not the ContentVersion — deleting the version
        // of a single-version document is not permitted.
        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : orphans) {
            if (cv.ContentDocumentId != null) {
                docIds.add(cv.ContentDocumentId);
            }
        }
        if (docIds.isEmpty()) {
            return 0;
        }

        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :docIds WITH SYSTEM_MODE];
        if (docs.isEmpty()) {
            return 0;
        }
        // Partial-success delete: one undeletable document (locked by another
        // transaction, already reaped concurrently) must not block the rest.
        Database.delete(docs, false, AccessLevel.SYSTEM_MODE); // NOPMD ApexCRUDViolation — package-internal transient render artifacts
        return docs.size();
    }
}
