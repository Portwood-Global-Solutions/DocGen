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
            'Build me an invoice for the Account object.',
            null
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
            'anything',
            null
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
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'x',
            null
        );
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
            DocGenAiTemplateController.generateTemplateBody(t.Id, 'x', null);
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
            DocGenAiTemplateController.generateTemplateBody(null, 'x', null);
        } catch (Exception e) {
            caught++;
        }
        try {
            DocGenAiTemplateController.generateTemplateBody(t.Id, '   ', null);
        } catch (Exception e) {
            caught++;
        }
        Test.stopTest();
        System.assertEquals(2, caught, 'both guards must fire');
    }

    @isTest
    static void editModeRunsTheEditGuardAndFlagsLostTags() {
        DocGen_Template__c t = makeTemplate();
        String previous =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<h1>{Account.Name}</h1><table><tr><td>{Name}</td><td>{Amount:currency}</td></tr></table>' +
            '</body></html>';
        // The model "edits" but silently loses a binding — the failure the guard exists for.
        String mangled =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<h1 style="color:#184d47;">{Account.Name}</h1><table><tr><td>{Name}</td><td>&nbsp;</td></tr></table>' +
            '</body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(mangled));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'make the heading dark green',
            previous
        );
        Test.stopTest();

        System.assertEquals(true, res.wasEdit, 'passing a previous body means this was an edit');
        Boolean flagged = false;
        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            if (f.rule == 'Merge tags lost in the edit') {
                flagged = true;
                System.assert(f.detail.contains('{Amount:currency}'), 'the lost tag is named: ' + f.detail);
            }
        }
        System.assert(flagged, 'the edit guard must run on an edit: ' + res.findings);
        System.assert(res.warningCount > 0, 'guard findings must count toward the warnings');
        System.assert(
            res.summary.containsIgnoreCase('check it'),
            'the summary must lead with the problem: ' + res.summary
        );
    }

    @isTest
    static void aFaithfulEditReportsCleanly() {
        DocGen_Template__c t = makeTemplate();
        String previous =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<h1>{Account.Name}</h1><table><tr><td>{Name}</td></tr></table></body></html>';
        String edited = previous.replace('<h1>', '<h1 style="color:#184d47;">');
        DocGenAiProviderFactory.setProvider(new FakeProvider(edited));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'make the heading dark green',
            previous
        );
        Test.stopTest();

        System.assertEquals(true, res.wasEdit);
        System.assert(res.html.contains('#184d47'), 'the requested change must be present');
        System.assert(res.html.contains('{Account.Name}'), 'and everything else preserved');
        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            System.assertNotEquals('Merge tags lost in the edit', f.rule, 'nothing was lost, so do not cry wolf');
        }
        System.assert(res.summary.containsIgnoreCase('survived'), 'a clean edit should say so: ' + res.summary);
    }

    @isTest
    static void theValidatorsOwnRemovalsAreNotBlamedOnTheEdit() {
        // The validator strips {!} and rewrites {!Field} by design. Comparing a
        // RAW previous body against a SANITIZED result reported both as "lost in
        // the edit" — a false alarm on the guard's most important signal.
        DocGen_Template__c t = makeTemplate();
        String previous = '<html><body><p>{Name}</p><td>Industry {!}</td><p>{!Account.Name}</p></body></html>';
        // A faithful edit: only the colour changed. The {!} / {!Field} handling
        // is entirely the validator's doing, on both sides.
        String edited = '<html><body><p style="color:#184d47;">{Name}</p><td>Industry {!}</td><p>{!Account.Name}</p></body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(edited));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'make it green',
            previous
        );
        Test.stopTest();

        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            System.assertNotEquals(
                'Merge tags lost in the edit',
                f.rule,
                'the validator cleaning both sides is not a loss: ' + f.detail
            );
        }
    }

    @isTest
    static void aRefusalNeverOverwritesTheTemplate() {
        // Einstein intermittently answers a good prompt with "I don't know."
        // The old code saved it, replacing a 6,883-character template with 13.
        // Nothing downstream can recover from that, so it must be refused here.
        DocGen_Template__c t = makeTemplate();
        String previous = '<!DOCTYPE html><html><body><h1>{Account.Name}</h1><p>{Name}</p></body></html>';
        DocGenAiTemplateController.generateTemplateBody(t.Id, 'seed', null); // establish a body
        String bodyBefore = DocGenController.getHtmlTemplateBody(t.Id);

        DocGenAiProviderFactory.setProvider(new FakeProvider('I don\'t know.'));

        Test.startTest();
        Boolean threw = false;
        try {
            DocGenAiTemplateController.generateTemplateBody(t.Id, 'make the header green', previous);
        } catch (Exception e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('has NOT been changed'),
                'the author must be told the template is intact: ' + e.getMessage()
            );
            System.assert(e.getMessage().contains('I don\'t know.'), 'quote what came back: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(threw, 'a refusal must not be treated as a document');
        System.assertEquals(
            bodyBefore,
            DocGenController.getHtmlTemplateBody(t.Id),
            'THE TEMPLATE MUST BE UNTOUCHED — this is the whole point'
        );
    }

    @isTest
    static void shortProseIsRefusedButRealHtmlIsAccepted() {
        DocGen_Template__c t = makeTemplate();
        DocGenAiProviderFactory.setProvider(new FakeProvider('Sure! Here is a summary of what I would do.'));
        Integer caught = 0;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateBodyPreview('x');
        } catch (Exception e) {
            caught++;
            System.assert(e.getMessage().containsIgnoreCase('nothing was saved'), e.getMessage());
        }
        // A real document of adequate length passes.
        String realDoc =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<table><tr><td>{Name}</td></tr></table><p>' +
            'x'.repeat(200) +
            '</p></body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(realDoc));
        DocGenAiTemplateController.GenerationResult ok = DocGenAiTemplateController.generateBodyPreview('x');
        Test.stopTest();
        System.assertEquals(1, caught, 'prose must be refused');
        System.assert(ok.html.contains('{Name}'), 'real HTML must pass through');
    }

    @isTest
    static void generatingFreshDoesNotRunTheEditGuard() {
        DocGen_Template__c t = makeTemplate();
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateTemplateBody(
            t.Id,
            'a fresh invoice',
            null
        );
        Test.stopTest();
        System.assertEquals(false, res.wasEdit, 'no previous body means this was not an edit');
        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            System.assertNotEquals('Merge tags lost in the edit', f.rule, 'there was nothing to lose');
        }
    }

    @isTest
    static void previewGeneratesWithoutTouchingAnyRecord() {
        // The wizard calls this before the template record exists, so it must
        // not write a ContentVersion, a Draft_Body__c, or anything else.
        Integer cvBefore = [SELECT COUNT() FROM ContentVersion];

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateBodyPreview(
            'an invoice for the Account object'
        );
        Test.stopTest();

        System.assertNotEquals(null, res.html, 'HTML must come back');
        System.assert(res.html.length() > 0, 'and it must be non-empty');
        System.assertEquals(null, res.contentVersionId, 'preview must NOT save a ContentVersion');
        System.assertEquals(false, res.wasEdit, 'a preview is never an edit');
        System.assertEquals('Stub', res.providerName);
        System.assert(res.findings.size() > 0, 'the validator still runs and still reports');
        System.assert(!res.html.containsIgnoreCase('display:flex'), 'and still sanitizes');
        System.assertEquals(cvBefore, [SELECT COUNT() FROM ContentVersion], 'nothing may be persisted');
    }

    @isTest
    static void previewRejectsABlankPrompt() {
        Test.startTest();
        Boolean threw = false;
        try {
            DocGenAiTemplateController.generateBodyPreview('  ');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'a blank prompt must not reach the model');
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
    static void providerClassNameComesFromSettings() {
        // An admin can point Portwood at their own class without editing Apex.
        System.assertEquals(
            'DocGenEinsteinProvider',
            DocGenAiProviderFactory.configuredProviderClass(),
            'blank settings fall back to the documented default'
        );
        System.assertEquals(
            'DocGen_HTML_Body',
            DocGenAiProviderFactory.configuredPromptTemplate(),
            'blank settings fall back to the documented default'
        );

        DocGen_Settings__c s = DocGen_Settings__c.getOrgDefaults();
        s.AI_Provider_Class__c = '  MyOwnProvider  ';
        s.AI_Prompt_Template__c = 'My_Template';
        upsert s;

        Test.startTest();
        System.assertEquals('MyOwnProvider', DocGenAiProviderFactory.configuredProviderClass(), 'trimmed and honoured');
        System.assertEquals('My_Template', DocGenAiProviderFactory.configuredPromptTemplate(), 'honoured');
        Test.stopTest();
    }

    @isTest
    static void aClassThatDoesNotImplementTheInterfaceSaysSo() {
        // Named but wrong. Reporting "AI unavailable" would send an admin
        // hunting a missing entitlement that is not missing.
        DocGenAiProvider p = new DocGenAiProviderFactory.DocGenUnavailableProvider(
            'The class "Foo" does not implement the DocGenAiProvider interface, so Portwood cannot use it.'
        );
        System.assertEquals(false, p.isAvailable());
        Test.startTest();
        Boolean threw = false;
        try {
            p.generateHtml('x');
        } catch (DocGenAiProviderFactory.DocGenAiUnavailableException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('does not implement'),
                'the real reason must reach the admin: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw);
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

    // -----------------------------------------------------------------------
    // Fragment generation — the Canvas editor's per-element rewrite.
    // -----------------------------------------------------------------------

    @isTest
    static void fragmentGenerationSavesNothing() {
        // The canvas holds its document in memory and owns its own save cycle. A
        // ContentVersion written here would leave the template record and the open
        // canvas describing two different documents.
        DocGen_Template__c t = makeTemplate();
        Integer cvBefore = [SELECT COUNT() FROM ContentVersion];
        DocGenAiProviderFactory.setProvider(new FakeProvider('<strong>Total</strong> {SUM:Lines.Amount:currency}'));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateFragment(
            'rewrite this',
            '<b>Total</b> {SUM:Lines.Amount:currency}'
        );
        Test.stopTest();

        System.assert(res.html.contains('{SUM:Lines.Amount:currency}'), 'the merge tag must survive');
        System.assertEquals(null, res.contentVersionId, 'a fragment must NOT save a ContentVersion');
        System.assertEquals(cvBefore, [SELECT COUNT() FROM ContentVersion], 'nothing may be persisted');
        System.assertEquals(true, res.wasEdit, 'a previous fragment means this was an edit');
        System.assertEquals(
            null,
            [SELECT Draft_Body__c FROM DocGen_Template__c WHERE Id = :t.Id].Draft_Body__c,
            'and the staging field is untouched — there is no template body involved'
        );
    }

    @isTest
    static void aFragmentNeedNotLookLikeADocument() {
        // assertLooksLikeDocument accepts only <html/<!doctype/<body/<table/<div, which
        // is right for a file and wrong for a block: a text element's content is
        // legitimately an inline run, or bare text carrying a merge tag.
        List<String> goodFragments = new List<String>{
            '<strong>Prepared for</strong> {Account.Name}',
            '<p style="color:#1e40af">Thanks for your business.</p>',
            'Total due: {Amount:currency}',
            '<span>x</span>'
        };
        Test.startTest();
        for (String frag : goodFragments) {
            DocGenAiProviderFactory.setProvider(new FakeProvider(frag));
            DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateFragment('x', null);
            System.assertNotEquals(null, res.html, 'accepted: ' + frag);
            System.assert(res.html.length() > 0, 'accepted and non-empty: ' + frag);
        }
        Test.stopTest();
    }

    @isTest
    static void aFragmentRefusalIsStillCaught() {
        // The reason the guard exists at all: Einstein intermittently answers a good
        // prompt with prose. That must not silently replace an element's content.
        DocGenAiProviderFactory.setProvider(
            new FakeProvider('I do not know. Please specify the exact change you want made.')
        );
        Boolean threw = false;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateFragment('x', '<p>{Name}</p>');
        } catch (Exception e) {
            threw = true;
            System.assert(
                e.getMessage().containsIgnoreCase('has NOT been changed'),
                'the message must say the block is untouched: ' + e.getMessage()
            );
        }
        Test.stopTest();
        System.assert(threw, 'prose must be refused');
    }

    @isTest
    static void fragmentEditGuardFlagsALostMergeTag() {
        // Same protection the whole-document edit path gets. A rewrite that quietly
        // drops a binding looks perfectly fine on the canvas.
        DocGenAiProviderFactory.setProvider(new FakeProvider('<p>Thanks for your business.</p>'));
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateFragment(
            'make it friendlier',
            '<p>Thanks, {Account.Name}. Total {Amount:currency}.</p>'
        );
        Test.stopTest();
        Boolean flagged = false;
        for (DocGenAiHtmlValidator.Finding f : res.findings) {
            if (f.rule.containsIgnoreCase('lost')) {
                flagged = true;
            }
        }
        System.assert(flagged, 'dropping {Account.Name} and {Amount} must be reported: ' + res.summary);
    }

    @isTest
    static void fragmentStillSanitizes() {
        // The validator is string-level and assumes no document wrapper, so every rule
        // applies to a fragment unchanged.
        DocGenAiProviderFactory.setProvider(
            new FakeProvider('<div style="display:flex; border-radius:6pt">{Name}</div>')
        );
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateFragment('x', null);
        Test.stopTest();
        System.assert(!res.html.containsIgnoreCase('display:flex'), 'flex must be stripped: ' + res.html);
        System.assert(res.html.contains('{Name}'), 'the merge tag must survive');
    }

    @isTest
    static void fragmentRejectsABlankPrompt() {
        Boolean threw = false;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateFragment('   ', '<p>x</p>');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'a blank prompt must not reach the model');
    }

    @isTest
    static void anEmptyModelResponseIsRefusedForAFragment() {
        DocGenAiProviderFactory.setProvider(new FakeProvider(''));
        Boolean threw = false;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateFragment('x', '<p>{Name}</p>');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an empty response must not blank the element');
    }

    // -----------------------------------------------------------------------
    // Canvas preview — placement must survive the validator.
    // -----------------------------------------------------------------------

    @isTest
    static void canvasModeKeepsAbsolutePositioning() {
        // A Canvas document IS a set of absolutely positioned boxes at inch
        // coordinates, and the engine honours them. The generic rule strips
        // position:absolute, which is right for a flowing template and silently
        // flattened every placed block of a Canvas draft into the flow.
        String placed =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<h1 style="position: absolute; left: 0.75in; top: 0.6in; width: 4.5in">{Name}</h1>' +
            '<div style="position: absolute; left: 5.75in; top: 0.65in; width: 2in">{Today}</div>' +
            '<table style="width: 7in"><tr><td>{LastName}</td></tr></table>' +
            '</body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(placed));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult canvasRes = DocGenAiTemplateController.generateCanvasPreview('x');
        DocGenAiTemplateController.GenerationResult htmlRes = DocGenAiTemplateController.generateBodyPreview('x');
        Test.stopTest();

        System.assertEquals(
            2,
            canvasRes.html.countMatches('position: absolute'),
            'canvas mode must keep every placed block: ' + canvasRes.html
        );
        System.assert(canvasRes.html.contains('left: 0.75in'), 'and its coordinates');
        System.assertEquals(
            0,
            htmlRes.html.countMatches('position: absolute'),
            'while the flowing-template path still strips it'
        );
        for (DocGenAiHtmlValidator.Finding f : canvasRes.findings) {
            System.assert(
                !f.rule.containsIgnoreCase('position:'),
                'and canvas mode must not warn about it either: ' + f.rule
            );
        }
    }

    @isTest
    static void canvasModeStillAppliesEveryOtherRule() {
        // Only the positioning rule is relaxed. Flex, gradients and the rest are just
        // as wrong on a canvas as anywhere else.
        String dirty =
            '<!DOCTYPE html><html><head><style>@page{size:Letter portrait;}</style></head><body>' +
            '<div style="position: absolute; left: 1in; top: 1in; display: flex; ' +
            'background: linear-gradient(90deg,#000,#fff); border-radius: 6pt">{Name}</div>' +
            '</body></html>';
        DocGenAiProviderFactory.setProvider(new FakeProvider(dirty));

        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateCanvasPreview('x');
        Test.stopTest();

        System.assert(res.html.contains('position: absolute'), 'placement is kept');
        System.assert(!res.html.containsIgnoreCase('display: flex'), 'flex is not');
        System.assert(!res.html.containsIgnoreCase('linear-gradient'), 'nor gradients');
        System.assert(!res.html.containsIgnoreCase('border-radius'), 'nor rounded corners');
    }

    @isTest
    static void canvasPreviewSavesNothing() {
        DocGen_Template__c t = makeTemplate();
        Integer cvBefore = [SELECT COUNT() FROM ContentVersion];
        Test.startTest();
        DocGenAiTemplateController.GenerationResult res = DocGenAiTemplateController.generateCanvasPreview(
            'a roster for the Account object'
        );
        Test.stopTest();
        System.assertNotEquals(null, res.html, 'HTML must come back');
        System.assertEquals(null, res.contentVersionId, 'a canvas preview must NOT save a ContentVersion');
        System.assertEquals(cvBefore, [SELECT COUNT() FROM ContentVersion], 'nothing may be persisted');
    }

    @isTest
    static void canvasPreviewRefusesProseAndBlankPrompts() {
        Integer caught = 0;
        Test.startTest();
        try {
            DocGenAiTemplateController.generateCanvasPreview('   ');
        } catch (Exception e) {
            caught++;
        }
        DocGenAiProviderFactory.setProvider(new FakeProvider('I do not know what you want.'));
        try {
            DocGenAiTemplateController.generateCanvasPreview('x');
        } catch (Exception e) {
            caught++;
        }
        Test.stopTest();
        System.assertEquals(2, caught, 'a blank prompt and a refusal must both be rejected');
    }
}
