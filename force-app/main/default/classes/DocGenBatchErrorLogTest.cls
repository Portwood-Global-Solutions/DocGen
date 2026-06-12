/**
 * Tests for bulk-batch failure diagnostics (DocGen_Job__c.Error_Log__c).
 *
 * Previously DocGenBatch.execute swallowed per-record failures with a bare
 * `failCount++` — no record Id, no reason, and no signal that a record failed only
 * because it was too large for standard generation. These verify failures are now
 * captured with their reason and that oversized records are flagged with guidance to
 * use the giant-query path (which the bulk batch cannot launch itself).
 */
@isTest
private class DocGenBatchErrorLogTest {
    private static Id newJob() {
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Batch Err Test Tpl',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert tpl;
        DocGen_Job__c job = new DocGen_Job__c(Template__c = tpl.Id, Status__c = 'Queued');
        insert job;
        return job.Id;
    }

    private static Id anAccountId() {
        Account a = new Account(Name = 'Batch Err Acct');
        insert a;
        return a.Id;
    }

    @isTest
    static void heapFailureIsFlaggedWithGiantQueryGuidance() {
        Id jobId = newJob();
        Id recId = anAccountId();
        DocGenBatch batch = new DocGenBatch(jobId);

        HeapPressureException hpe = new HeapPressureException();
        hpe.relationshipName = 'Contacts';
        batch.recordFailure(recId, hpe);

        System.assertEquals(1, batch.heapFailCount, 'Heap pressure counted as an oversized failure');
        batch.failCount = 1;
        String log = batch.buildErrorLog();
        System.assert(log.contains('too large'), 'Oversized guidance present: ' + log);
        System.assert(log.contains('giant-query'), 'Points to the giant-query path: ' + log);
        System.assert(log.contains(String.valueOf(recId)), 'Names the failing record: ' + log);
    }

    @isTest
    static void genericFailureCapturesTypeAndMessage() {
        Id jobId = newJob();
        Id recId = anAccountId();
        DocGenBatch batch = new DocGenBatch(jobId);

        batch.recordFailure(recId, new DocGenException('boom happened'));
        batch.failCount = 1;
        String log = batch.buildErrorLog();

        System.assert(log.contains('boom happened'), 'Captures the exception message: ' + log);
        System.assert(log.contains(String.valueOf(recId)), 'Names the failing record: ' + log);
        System.assertEquals(0, batch.heapFailCount, 'A generic failure is not miscounted as heap pressure');
    }

    @isTest
    static void cappedLogNotesAdditionalFailures() {
        Id jobId = newJob();
        DocGenBatch batch = new DocGenBatch(jobId);

        batch.recordFailure(anAccountId(), new DocGenException('only-captured-line'));
        // Simulate more failures than captured lines (the cap path).
        batch.failCount = 5;
        String log = batch.buildErrorLog();

        System.assert(log.contains('and 4 more'), '"+N more" note surfaces hidden failures: ' + log);
    }

    @isTest
    static void noFailuresProducesNullLog() {
        Id jobId = newJob();
        DocGenBatch batch = new DocGenBatch(jobId);
        System.assertEquals(null, batch.buildErrorLog(), 'No failures → null (Error_Log__c stays empty)');
    }
}
