// CxSAST: Test class — SOQL/DML findings are test data operations, not production code paths
@IsTest
private class DocGenErrorLoggerTest {
    @IsTest
    static void testLogWritesNonSensitiveDiagnosticRow() {
        DocGen_Template__c template = new DocGen_Template__c(
            Name = 'Logger Template',
            Base_Object_API__c = 'Account',
            Type__c = 'Word'
        );
        Database.insert(template, AccessLevel.SYSTEM_MODE);

        Exception cause;
        try {
            throw new DocGenException('Template sharing probe failed');
        } catch (Exception e) {
            cause = e;
        }

        Test.startTest();
        DocGenErrorLogger.logBulkFlowFailure(cause, template.Id, 'Name = \'Acme\'', 'Nightly Job');
        Test.stopTest();

        List<DocGen_Error_Log__c> logs = [
            SELECT
                Severity__c,
                Context__c,
                Operation__c,
                Exception_Type__c,
                Message__c,
                Additional_Info__c,
                Template_Id__c,
                User_Id__c
            FROM DocGen_Error_Log__c
            WHERE Template_Id__c = :String.valueOf(template.Id)
        ];
        System.assertEquals(1, logs.size(), 'Logger should create one diagnostic row');
        System.assertEquals('Error', logs[0].Severity__c);
        System.assertEquals('DocGenBulkFlowAction', logs[0].Context__c);
        System.assertEquals('Generate Bulk Documents', logs[0].Operation__c);
        System.assertEquals('DocGenException', logs[0].Exception_Type__c);
        System.assert(logs[0].Message__c.contains('Template sharing probe failed'));
        System.assert(logs[0].Additional_Info__c.contains('Nightly Job'));
        System.assertEquals(String.valueOf(UserInfo.getUserId()), logs[0].User_Id__c);
    }

    @IsTest
    static void testLoggerNeverThrowsToCaller() {
        DocGenErrorLogger.Entry entry = new DocGenErrorLogger.Entry();
        entry.context = 'Logger test';
        entry.message = 'This should be swallowed';

        Test.startTest();
        DocGenErrorLogger.forceFailureForTest = true;
        DocGenErrorLogger.log(entry);
        DocGenErrorLogger.forceFailureForTest = false;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM DocGen_Error_Log__c], 'Forced logger failure should be swallowed');
    }

    /* ==================================================================== *
     * warn() — the degradation buffer.
     *
     * These record SUCCESSFUL-BUT-WRONG outcomes: an image skipped, a chart
     * resolved empty. They fire inside per-row loops, so the buffering is not a
     * nicety — inserting per occurrence would spend the 150-DML limit on
     * diagnostics and break generation that currently works.
     * ==================================================================== */

    @IsTest
    static void warnBuffersAndCostsNoDmlUntilFlushed() {
        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        for (Integer i = 0; i < 200; i++) {
            DocGenErrorLogger.warn('Ctx', 'Op', 'repeated degradation');
        }
        Integer dmlAfterWarns = Limits.getDmlStatements();
        DocGenErrorLogger.flush();
        Integer dmlAfterFlush = Limits.getDmlStatements();
        Test.stopTest();

        System.assertEquals(dmlBefore, dmlAfterWarns, '200 warnings must not perform any DML on their own');
        System.assertEquals(dmlBefore + 1, dmlAfterFlush, 'flush must write everything in exactly ONE statement');
    }

    @IsTest
    static void identicalWarningsCollapseToOneRowThatCountsThem() {
        Test.startTest();
        for (Integer i = 0; i < 500; i++) {
            DocGenErrorLogger.warn('ImgCtx', 'Resolve image', 'Image omitted');
        }
        DocGenErrorLogger.flush();
        Test.stopTest();

        List<DocGen_Error_Log__c> rows = [
            SELECT Severity__c, Additional_Info__c
            FROM DocGen_Error_Log__c
            WHERE Context__c = 'ImgCtx'
        ];
        // 2,000 rows each skipping the same broken image is ONE fact. Writing it
        // 2,000 times would bury every other entry in the log.
        System.assertEquals(1, rows.size(), 'identical warnings collapse to a single row');
        System.assertEquals('Warning', rows[0].Severity__c, 'degradation is a Warning, not an Error');
        System.assert(
            rows[0].Additional_Info__c != null && rows[0].Additional_Info__c.contains('occurrences=500'),
            'the count is the useful part — "one image failed" and "every image failed" are different ' +
                'problems with the same message. Got: ' +
                rows[0].Additional_Info__c
        );
    }

    @IsTest
    static void differentWarningsAreKeptApart() {
        Test.startTest();
        DocGenErrorLogger.warn('A', 'Op', 'first');
        DocGenErrorLogger.warn('A', 'Op', 'second');
        DocGenErrorLogger.warn('B', 'Op', 'first');
        DocGenErrorLogger.flush();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM DocGen_Error_Log__c], 'distinct warnings each get a row');
    }

    @IsTest
    static void aPathologicalTemplateCannotProduceUnboundedLogging() {
        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            DocGenErrorLogger.warn('Ctx', 'Op', 'unique message ' + i);
        }
        DocGenErrorLogger.flush();
        Test.stopTest();

        Integer rows = [SELECT COUNT() FROM DocGen_Error_Log__c];
        System.assert(rows > 0, 'some warnings are recorded');
        System.assert(rows <= 25, 'the buffer is capped so one bad template cannot flood the log; got ' + rows);
    }

    @IsTest
    static void warnCarriesTheTemplateAndRecordItRelatesTo() {
        DocGen_Template__c t = new DocGen_Template__c(
            Name = 'WarnCtx ' + Datetime.now().getTime(),
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name'
        );
        insert t;
        Account a = new Account(Name = 'Warn Co');
        insert a;

        Test.startTest();
        DocGenErrorLogger.warn('DocGenService', 'Resolve image', 'Image omitted', t.Id, String.valueOf(a.Id));
        DocGenErrorLogger.flush();
        Test.stopTest();

        DocGen_Error_Log__c row = [
            SELECT Template_Id__c, Record_Id__c, Operation__c
            FROM DocGen_Error_Log__c
            LIMIT 1
        ];
        // Without these two, a warning says something went wrong somewhere for
        // someone — which is barely better than no log at all.
        System.assertEquals(String.valueOf(t.Id), row.Template_Id__c, 'the template is identified');
        System.assertEquals(String.valueOf(a.Id), row.Record_Id__c, 'the record is identified');
        System.assertEquals('Resolve image', row.Operation__c);
    }

    @IsTest
    static void flushIsSafeWhenNothingWasBuffered() {
        Test.startTest();
        DocGenErrorLogger.flush();
        DocGenErrorLogger.flush();
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM DocGen_Error_Log__c], 'nothing buffered, nothing written');
    }
}
