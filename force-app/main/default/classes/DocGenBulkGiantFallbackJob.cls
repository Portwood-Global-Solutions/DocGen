/**
 * #155 — Deferred giant-query fallback for oversized bulk records.
 *
 * DocGenBatch flags records that fail with heap/oversize errors (too many related
 * rows to render in one transaction) but cannot recover them itself: Apex forbids
 * launching a Batchable from a running batch's start/execute/finish. DocGenBatch.finish()
 * therefore enqueues THIS Queueable — from a Queueable, launching a Batchable (the
 * giant-query path) is allowed.
 *
 * Each execute() processes ONE oversized record through DocGenController.generateDocumentGiantQuery
 * (which launches its own giant-query Batchable), then self-chains for the next record.
 * "One giant render per Queueable" keeps each transaction within limits.
 *
 * Concurrency (decision A): each recovered record launches an async Batchable, and the
 * platform caps concurrent batch jobs. Before launching, we check how many batch jobs are
 * already in flight; if at/over MAX_ACTIVE_BATCHES we re-enqueue self WITHOUT consuming a
 * record, backing off until a slot frees rather than throwing a LimitException.
 *
 * Status (decision B): the parent DocGen_Job__c is left at 'Recovering' by finish() while
 * dispatch is in flight, then set to 'Completed with Errors' once every record has been
 * dispatched. Each per-record giant job reports its own completion separately; we do not
 * try to roll child results back into the parent's Success_Count__c.
 */
public with sharing class DocGenBulkGiantFallbackJob implements Queueable, Database.AllowsCallouts {
    private final Id jobId;
    private final Id templateId;
    private final List<Id> remaining;

    // Headroom under the platform's 5-concurrent-batch limit — leave one slot so an
    // unrelated job launched between our check and executeBatch doesn't tip us over.
    @TestVisible
    private static final Integer MAX_ACTIVE_BATCHES = 4;

    public DocGenBulkGiantFallbackJob(Id jobId, Id templateId, List<Id> recordIds) {
        this.jobId = jobId;
        this.templateId = templateId;
        this.remaining = recordIds == null ? new List<Id>() : recordIds;
    }

    public void execute(QueueableContext ctx) {
        if (remaining.isEmpty()) {
            finalizeRecovery();
            return;
        }

        // Decision A — back off if the batch slots are full; don't consume a record.
        if (activeBatchCount() >= MAX_ACTIVE_BATCHES) {
            chainSelf();
            return;
        }

        Id recordId = remaining.remove(0);
        try {
            // Launches the giant-query Batchable (or falls through to normal generation
            // if the record turns out not to be oversized after all).
            DocGenController.generateDocumentGiantQuery(templateId, recordId);
        } catch (Exception e) {
            logFailure(recordId, e);
        }

        if (!remaining.isEmpty()) {
            chainSelf();
        } else {
            finalizeRecovery();
        }
    }

    /** Count batch jobs currently occupying a slot (not yet finished). */
    private Integer activeBatchCount() {
        return [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND Status IN ('Queued', 'Preparing', 'Processing')
        ];
    }

    /**
     * Chain the next hop with whatever remains. Queueable chaining is not supported in
     * test context (throws a stack-depth limit), so the chain is suppressed under
     * Test.isRunningTest(); tests drive a single hop directly and assert on its effect.
     */
    private void chainSelf() {
        if (Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new DocGenBulkGiantFallbackJob(jobId, templateId, remaining));
    }

    /** All records dispatched — mark the parent job done (it had bulk failures). */
    private void finalizeRecovery() {
        try {
            DocGen_Job__c parent = new DocGen_Job__c(Id = jobId, Status__c = 'Completed with Errors');
            DocGenFlsGuard.assertUpdateable(parent, new Set<String>{ 'Status__c' });
            /* code-analyzer-suppress ApexFlsViolation */
            Database.update(parent, false, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            // Non-fatal: the per-record giant jobs still run and report their own status.
            String noop = e.getMessage(); // NOPMD UnusedLocalVariable
        }
    }

    private void logFailure(Id recordId, Exception e) {
        try {
            DocGenErrorLogger.Entry entry = new DocGenErrorLogger.Entry();
            entry.severity = 'Error';
            entry.context = 'Bulk Giant Fallback';
            entry.operation = 'generateDocumentGiantQuery';
            entry.recordId = recordId == null ? null : String.valueOf(recordId);
            entry.cause = e;
            DocGenErrorLogger.log(entry);
        } catch (Exception logErr) {
            String noop = logErr.getMessage(); // NOPMD UnusedLocalVariable
        }
    }
}
