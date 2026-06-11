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
}
