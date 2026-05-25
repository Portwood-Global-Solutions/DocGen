/**
 * Coverage for the deprecated DocGenGuestRenderQueueable stub. The stub itself
 * is a no-op retained for 2GP packaging compatibility (see that class for the
 * fuller context); this test exists only to keep the class coverage non-zero
 * until both can be removed via Remove Metadata Components feature access.
 */
@IsTest
private class DocGenGuestRenderQueueableTest {
    @IsTest
    static void deprecatedStubEnqueuesWithoutEffect() {
        Test.startTest();
        System.enqueueJob(new DocGenGuestRenderQueueable());
        Test.stopTest();
        System.assert(true, 'Deprecated queueable stub enqueued without error');
    }
}
