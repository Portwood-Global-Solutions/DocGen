/**
 * Kept separate from DocGenAiTemplateControllerTest on purpose: this suite names
 * DocGenEinsteinProvider, which mentions ConnectApi.EinsteinLLM and therefore
 * only COMPILES in an org with the Einstein entitlement. Everything else in the
 * feature has to build and test in an org without it, so the dependency is
 * quarantined here and in the provider class itself.
 *
 * Deploy this pair only where Einstein is enabled.
 */
@isTest
private class DocGenEinsteinProviderTest {
    @isTest
    static void neverClaimsAvailabilityInsideATest() {
        // A real generation costs ~13s and real credits, so the provider must
        // not let a test transaction wander into the platform call.
        DocGenEinsteinProvider p = new DocGenEinsteinProvider();
        System.assertEquals('Einstein', p.getName());
        System.assertEquals(false, p.isAvailable());
    }

    @isTest
    static void emptyPromptIsRejectedBeforeThePlatformCall() {
        DocGenEinsteinProvider p = new DocGenEinsteinProvider();
        Test.startTest();
        Boolean threw = false;
        try {
            p.generateHtml('   ');
        } catch (DocGenEinsteinProvider.DocGenAiException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an empty prompt must not reach the platform');
    }

    @isTest
    static void factoryResolvesTheProviderByName() {
        // Type.forName is what keeps the rest of the feature deployable in an
        // org without Einstein — prove the name still resolves where it exists.
        System.assertNotEquals(null, Type.forName('DocGenEinsteinProvider'), 'the provider must be resolvable by name');
    }
}
