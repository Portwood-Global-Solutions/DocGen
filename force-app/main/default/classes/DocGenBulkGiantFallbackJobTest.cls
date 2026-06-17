/**
 * #155 — DocGenBulkGiantFallbackJob: the deferred giant-query recovery Queueable.
 *
 * Queueable chaining is unavailable in test context, so these drive a single hop and
 * assert its effect. generateDocumentGiantQuery runs synchronously for the (childless)
 * test account and falls through to normal generation, which fails on the body-less test
 * template — that failure is caught and logged by the job, which is the intended behavior
 * (recovery dispatch is best-effort per record).
 */
@isTest
private class DocGenBulkGiantFallbackJobTest {
    private static Id newTemplate() {
        DocGen_Template__c tpl = new DocGen_Template__c(
            Name = 'Bulk Fallback Test Tpl',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert tpl;
        return tpl.Id;
    }

    private static Id newJob(Id templateId, String status) {
        DocGen_Job__c job = new DocGen_Job__c(Template__c = templateId, Status__c = status);
        insert job;
        return job.Id;
    }

    private static Id anAccountId() {
        Account a = new Account(Name = 'Fallback Acct');
        insert a;
        return a.Id;
    }

    @isTest
    static void emptyListFinalizesParentJob() {
        Id tplId = newTemplate();
        Id jobId = newJob(tplId, 'Recovering');

        Test.startTest();
        System.enqueueJob(new DocGenBulkGiantFallbackJob(jobId, tplId, new List<Id>()));
        Test.stopTest();

        DocGen_Job__c job = [SELECT Status__c FROM DocGen_Job__c WHERE Id = :jobId];
        System.assertEquals(
            'Completed with Errors',
            job.Status__c,
            'Empty list → recovery dispatch is done → parent flips to Completed with Errors'
        );
    }

    @isTest
    static void lastRecordDispatchedFinalizesParentJob() {
        Id tplId = newTemplate();
        Id jobId = newJob(tplId, 'Recovering');
        Id recId = anAccountId();

        Test.startTest();
        System.enqueueJob(new DocGenBulkGiantFallbackJob(jobId, tplId, new List<Id>{ recId }));
        Test.stopTest();

        DocGen_Job__c job = [SELECT Status__c FROM DocGen_Job__c WHERE Id = :jobId];
        System.assertEquals(
            'Completed with Errors',
            job.Status__c,
            'Single record dispatched → no more remaining → parent finalized'
        );
    }

    @isTest
    static void remainingRecordsDoNotFinalizeEarly() {
        Id tplId = newTemplate();
        Id jobId = newJob(tplId, 'Recovering');
        Id recA = anAccountId();
        Id recB = anAccountId();

        Test.startTest();
        // Two records, but chaining is suppressed in tests, so only one hop runs: it
        // dispatches one record and would chain for the rest — it must NOT finalize yet.
        System.enqueueJob(new DocGenBulkGiantFallbackJob(jobId, tplId, new List<Id>{ recA, recB }));
        Test.stopTest();

        DocGen_Job__c job = [SELECT Status__c FROM DocGen_Job__c WHERE Id = :jobId];
        System.assertEquals(
            'Recovering',
            job.Status__c,
            'With records still remaining, the parent stays Recovering (no premature finalize)'
        );
    }
}
