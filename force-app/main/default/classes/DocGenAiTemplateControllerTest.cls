/**
 * Proves the whole pipeline minus the model: provider -> staging field ->
 * validator -> ContentVersion -> readable by the Designer's existing loader.
 * Runs anywhere, no Einstein entitlement.
 */
@isTest
private class DocGenAiTemplateControllerTest {
    private static DocGen_Template__c makeTemplate() {
        DocGen_Template__c t = new DocGen_Template__c(
            Name = 'AI Spike Template',
            Type__c = 'HTML',
            Output_Format__c = 'PDF',
            Base_Object_API__c = 'Account',
            Query_Config__c = 'Name',
            Is_Active__c = true
        );
        insert t;
        return t;
    }

    /** Provider that returns exactly what a test wants, or throws on demand. */
    private class FakeProvider implements DocGenAiProvider {
        private String response;
        private Boolean shouldThrow;
        private Boolean available = true;
        FakeProvider(String response) {
            this.response = response;
            this.shouldThrow = false;
        }
        FakeProvider(Boolean shouldThrow) {
            this.shouldThrow = shouldThrow;
        }
        public Boolean isAvailable() {
            return this.available;
        }
        public String getName() {
            return 'Fake';
        }
        public String generateHtml(String prompt) {
            if (this.shouldThrow) {
                throw new FakeProviderException('einstein is unhappy');
            }
            return this.response;
        }
    }

    // Deliberately NOT DocGenEinsteinProvider.DocGenAiException — that class
    // only compiles in an Einstein-enabled org, and this suite has to run
    // everywhere. See DocGenAiProviderFactory for the same constraint.
    private class FakeProviderException extends Exception {
    }

    @isTest
    static void endToEndGenerationWritesAReadableBody() {
        DocGen_Template__c t = makeTemplate();

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'Build me an invoice for the Account object.'
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'a result is expected');
        System.assertEquals('Stub', res.providerName, 'the factory must hand back the stub under test');
        System.assertNotEquals(null, res.contentVersionId, 'a ContentVersion must have been written');
        System.assert(res.rawLength > 0, 'raw output length should be reported');

        // The Designer reads it back through the existing loader — the whole
        // point of reusing saveHtmlTemplateBody rather than a bespoke write.
        String loaded = DocGenController.getHtmlTemplateBody(t.Id);
        System.assertNotEquals(null, loaded, 'the Designer loader must find the body');
        System.assertEquals(res.html, loaded, 'what the Designer loads is what the validator produced');
        System.assert(!loaded.containsIgnoreCase('display:flex'), 'the SAVED body must be the sanitized one');
        System.assert(!loaded.containsIgnoreCase('rgba('), 'the SAVED body must be the sanitized one');

        // Raw output is staged for comparison, and is NOT the sanitized version.
        DocGen_Template__c reread = [SELECT Draft_Body__c FROM DocGen_Template__c WHERE Id = :t.Id];
        System.assertNotEquals(null, reread.Draft_Body__c, 'raw output should be staged');
        System.assert(
            reread.Draft_Body__c.containsIgnoreCase('display: flex'),
            'the staging field holds the RAW model output'
        );
        System.assertNotEquals(reread.Draft_Body__c, loaded, 'staged raw and saved clean must differ');
    }

    @isTest
    static void findingsAreReportedToTheCaller() {
        DocGen_Template__c t = makeTemplate();
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'anything'
        );
        Test.stopTest();

        System.assert(res.findings.size() > 0, 'the author must be told what changed');
        System.assert(res.removedCount > 0, 'the dirty sample has removals');
        System.assert(res.repairedCount > 0, 'the dirty sample has repairs');
        Boolean sawDetail = false;
        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            System.assertNotEquals(null, f.rule, 'every finding names a rule');
            System.assert(String.isNotBlank(f.detail), 'every finding explains itself: ' + f.rule);
            if (f.rule.containsIgnoreCase('rgba')) {
                sawDetail = true;
            }
        }
        System.assert(sawDetail, 'the rgba repair must be surfaced by name');
    }

    @isTest
    static void providerIsSwappable() {
        DocGen_Template__c t = makeTemplate();
        String canned = '<html><body><p style="opacity:0.5">{Name}</p></body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(canned));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(t.Id, 'x');
        Test.stopTest();

        System.assertEquals('Fake', res.providerName, 'the seam must be honoured');
        System.assert(!res.html.contains('opacity'), 'the validator still runs on a swapped provider');
    }

    @isTest
    static void providerFailureSurfacesAnActionableMessage() {
        DocGen_Template__c t = makeTemplate();
        DocGenAiProviderFactory.setProvider(new FakeProvider(true));

        Test.startTest();
        Boolean threw = false;
        try {
            DocGenAiTemplateController.generateTemplateBody(t.Id, 'x');
        } catch (Exception e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('einstein'),
                'the underlying reason must reach the UI: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'a provider failure must not be swallowed');
    }

    @isTest
    static void guardsRejectMissingInput() {
        DocGen_Template__c t = makeTemplate();
        Integer caught = 0;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateTemplateBody(null, 'x');
        } catch (Exception e) {
            caught++;
        }
        try {
            DocGenAiTemplateController.generateTemplateBody(t.Id, '   ');
        } catch (Exception e) {
            caught++;
        }
        Test.stopTest();
        System.assertEquals(2, caught, 'both guards must fire');
    }

    @isTest
    static void validateOnlyRunsWithoutGenerating() {
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.validateOnly(
            '<div style="border-radius:4pt;background:rgba(0,0,0,0.5)">x</div>'
        );
        Test.stopTest();
        System.assert(!res.html.contains('border-radius'), 'still sanitizes');
        System.assert(!res.html.contains('rgba('), 'still sanitizes');
        System.assert(res.findings.size() >= 2, 'still reports');
    }

    @isTest
    static void availabilityIsReportedNotThrown() {
        Test.startTest();
        Boolean available = DocGenAiTemplateController.isAiAvailable();
        Test.stopTest();
        // Under test the factory hands back the stub, which is always available.
        System.assertEquals(true, available, 'availability must be a boolean, never an exception');
    }

    @isTest
    static void unavailableProviderIsHonestRatherThanBroken() {
        // What an org with no Einstein classes gets. It must report false and
        // give an actionable message, never blow up on the availability probe.
        DocGenAiProvider p = new DocGenAiProviderFactory.DocGenUnavailableProvider();
        System.assertEquals(false, p.isAvailable());
        System.assertEquals('Unavailable', p.getName());
        Test.startTest();
        Boolean threw = false;
        try {
            p.generateHtml('anything');
        } catch (DocGenAiProviderFactory.DocGenAiUnavailableException e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('Copy AI Prompt'),
                'must point at the fallback path: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'generating with no provider must fail loudly, not silently');
    }

    @isTest
    static void stubHonoursACannedResponse() {
        DocGenAiProvider p = new DocGenAiStubProvider('<p>canned</p>');
        System.assertEquals('<p>canned</p>', p.generateHtml('ignored'));
        System.assertEquals(true, p.isAvailable());
        System.assertEquals('Stub', p.getName());
    }
}
