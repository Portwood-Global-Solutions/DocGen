// CxSAST: Test class — SOQL/DML findings are test data operations, not production code paths
@IsTest
private class DocGenChartCvReaperTest {
    @TestSetup
    static void setup() {
        TestDataFactory.assignAdminPermissionSet();
    }

    private static ContentVersion makeChartCv(String suffix) {
        ContentVersion cv = new ContentVersion(
            Title = 'docgen_chart_' + suffix,
            PathOnClient = 'chart.png',
            VersionData = Blob.valueOf('fake-png-bytes')
        );
        Database.insert(cv, AccessLevel.SYSTEM_MODE);
        return cv;
    }

    @IsTest
    static void freshChartCvsAreLeftAlone() {
        makeChartCv('fresh1');
        makeChartCv('fresh2');

        Test.startTest();
        Integer reaped = DocGenChartCvReaper.reap();
        Test.stopTest();

        // A CV created seconds ago may still be an in-flight render input. Reaping it
        // would blank the chart in a document that is mid-generation.
        System.assertEquals(0, reaped, 'Chart CVs younger than the age threshold must not be reaped');
        System.assertEquals(
            2,
            [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'docgen_chart_%'],
            'Both fresh chart CVs should survive'
        );
    }

    @IsTest
    static void nonChartFilesAreNeverTouched() {
        ContentVersion keep = new ContentVersion(
            Title = 'CustomerContract',
            PathOnClient = 'contract.pdf',
            VersionData = Blob.valueOf('not-a-chart')
        );
        Database.insert(keep, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        DocGenChartCvReaper.reap();
        Test.stopTest();

        // The reaper deletes ContentDocuments. Scoping it to the docgen_chart_ prefix
        // is the only thing standing between it and a customer's real files.
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentVersion WHERE Title = 'CustomerContract'],
            'A file without the docgen_chart_ prefix must never be reaped'
        );
    }

    @IsTest
    static void schedulableEntryPointRuns() {
        Test.startTest();
        String cron = System.schedule('DocGen Chart CV Reaper Test', '0 0 0 1 1 ? 2099', new DocGenChartCvReaper());
        Test.stopTest();

        System.assertNotEquals(null, cron, 'Reaper should be schedulable');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE Id = :cron],
            'A CronTrigger should exist for the scheduled reaper'
        );
    }
}
