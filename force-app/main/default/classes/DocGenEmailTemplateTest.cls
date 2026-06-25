/**
 * Tests for the configurable email template system (#193):
 * DocGenEmailTemplateService (render engine + built-in fallback + escaping +
 * branding + send-time override), DocGenEmailTemplateController (admin CRUD +
 * preview + test send), and DocGenEmailTemplateInstall (idempotent seeding).
 */
@IsTest
private class DocGenEmailTemplateTest {
    // ---- Service: built-in defaults render for every type with no records ----
    @IsTest
    static void builtInDefaults_renderForAllTypes() {
        DocGenEmailTemplateService.clearCache();
        Test.startTest();
        for (String type : DocGenEmailTemplateService.ALL_TYPES) {
            DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(type, sampleTokens(type));
            System.assert(String.isNotBlank(r.subject), 'subject for ' + type);
            System.assert(String.isNotBlank(r.htmlBody), 'html for ' + type);
            System.assert(r.htmlBody.contains('<!DOCTYPE html>'), 'chrome wrap for ' + type);
            System.assert(String.isNotBlank(r.plainBody), 'plain for ' + type);
            // No unresolved tokens should leak.
            System.assert(!r.htmlBody.contains('{'), 'no leftover token in ' + type + ': ' + r.htmlBody);
            System.assert(!r.subject.contains('{'), 'no leftover token in subject ' + type);
        }
        Test.stopTest();
    }

    // ---- Service: request email includes the signing button + URL ----
    @IsTest
    static void requestEmail_hasActionButtonAndUrl() {
        DocGenEmailTemplateService.clearCache();
        Map<String, String> tk = sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST);
        tk.put('SignatureUrl', 'https://sign.example.com/?token=ABC123');
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_REQUEST,
            tk
        );
        System.assert(r.htmlBody.contains('Review &amp; Sign Document'), 'button label present');
        System.assert(r.htmlBody.contains('https://sign.example.com/?token=ABC123'), 'signing url present');
        System.assert(r.plainBody.contains('https://sign.example.com/?token=ABC123'), 'url in plain part');
    }

    // ---- Service: merge values are HTML-escaped (no injection) ----
    @IsTest
    static void mergeValues_areEscaped() {
        DocGenEmailTemplateService.clearCache();
        Map<String, String> tk = sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST);
        tk.put('SignerName', '<script>alert(1)</script>');
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_REQUEST,
            tk
        );
        System.assert(!r.htmlBody.contains('<script>alert(1)</script>'), 'raw script must not survive');
        System.assert(r.htmlBody.contains('&lt;script&gt;'), 'name should be escaped');
    }

    // ---- Service: send-time message override replaces {Message} ----
    @IsTest
    static void messageOverride_replacesMessage() {
        DocGenEmailTemplateService.clearCache();
        String custom = 'Please review and sign before Friday — thanks!';
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_REQUEST,
            sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST),
            custom
        );
        System.assert(r.htmlBody.contains('Please review and sign before Friday'), 'override prose present');
    }

    // ---- Service: a stored record overrides the built-in; branding override applies ----
    @IsTest
    static void storedRecord_overridesBuiltIn() {
        insert new DocGen_Email_Template__c(
            Name = 'Custom Request',
            Type__c = DocGenEmailTemplateService.TYPE_REQUEST,
            Subject__c = 'Custom subject for {DocumentTitle}',
            Body_Html__c = '<p>Custom body for {SignerName}. {ActionButton}</p>',
            Brand_Color__c = '#FF0000',
            Is_Active__c = true
        );
        DocGenEmailTemplateService.clearCache();
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_REQUEST,
            sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST)
        );
        System.assert(r.subject.startsWith('Custom subject for'), 'stored subject used: ' + r.subject);
        System.assert(r.htmlBody.contains('Custom body for'), 'stored body used');
        System.assert(r.htmlBody.contains('#FF0000'), 'brand override applied');
    }

    // ---- Service: invalid brand color falls back to the safe default ----
    @IsTest
    static void invalidBrandColor_fallsBackSafe() {
        // The field caps at 7 chars (first defense); safeBrandColor rejects any
        // non-#RRGGBB value (second defense) and substitutes the safe default.
        insert new DocGen_Email_Template__c(
            Name = 'Bad Color',
            Type__c = DocGenEmailTemplateService.TYPE_COMPLETION,
            Brand_Color__c = '#ZZ000',
            Is_Active__c = true
        );
        DocGenEmailTemplateService.clearCache();
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_COMPLETION,
            sampleTokens(DocGenEmailTemplateService.TYPE_COMPLETION)
        );
        System.assert(!r.htmlBody.contains('#ZZ000'), 'invalid color must not survive');
        System.assert(r.htmlBody.contains('#1589EE'), 'safe default color used');
    }

    // ---- Install: seeding is idempotent ----
    @IsTest
    static void seedDefaults_isIdempotent() {
        Test.startTest();
        Integer first = DocGenEmailTemplateInstall.seedDefaults();
        Integer second = DocGenEmailTemplateInstall.seedDefaults();
        Test.stopTest();
        System.assertEquals(DocGenEmailTemplateService.ALL_TYPES.size(), first, 'seeds one per type');
        System.assertEquals(0, second, 'second run inserts nothing');
        System.assertEquals(
            DocGenEmailTemplateService.ALL_TYPES.size(),
            [SELECT COUNT() FROM DocGen_Email_Template__c],
            'one record per type total'
        );
    }

    // ---- Install handler entry point ----
    @IsTest
    static void onInstall_seeds() {
        Test.startTest();
        new DocGenEmailTemplateInstall().onInstall(null);
        Test.stopTest();
        System.assertEquals(
            DocGenEmailTemplateService.ALL_TYPES.size(),
            [SELECT COUNT() FROM DocGen_Email_Template__c]
        );
    }

    // ---- Controller: getTemplates returns one row per type ----
    @IsTest
    static void controller_getTemplates_rowPerType() {
        List<Map<String, Object>> rows = DocGenEmailTemplateController.getTemplates();
        System.assertEquals(DocGenEmailTemplateService.ALL_TYPES.size(), rows.size());
        for (Map<String, Object> row : rows) {
            System.assert(String.isNotBlank((String) row.get('subject')), 'row has subject');
            System.assert(row.get('tokens') != null, 'row has tokens');
        }
    }

    // ---- Controller: save then re-read reflects the edit ----
    @IsTest
    static void controller_save_and_reload() {
        Map<String, Object> data = new Map<String, Object>{
            'type' => DocGenEmailTemplateService.TYPE_PIN,
            'name' => 'My PIN email',
            'subject' => 'Your code is here',
            'bodyHtml' => '<p>{VerificationCode}</p>',
            'isActive' => true
        };
        Test.startTest();
        Id newId = DocGenEmailTemplateController.saveTemplate(data);
        // Update path
        data.put('recordId', newId);
        data.put('subject', 'Updated subject');
        Id sameId = DocGenEmailTemplateController.saveTemplate(data);
        Test.stopTest();
        System.assertEquals(newId, sameId, 'upsert keeps the same record');
        DocGen_Email_Template__c rec = [SELECT Subject__c FROM DocGen_Email_Template__c WHERE Id = :newId];
        System.assertEquals('Updated subject', rec.Subject__c);
    }

    // ---- Controller: getDefault + renderPreview ----
    @IsTest
    static void controller_default_and_preview() {
        Map<String, Object> def = DocGenEmailTemplateController.getDefault(DocGenEmailTemplateService.TYPE_REQUEST);
        System.assert(String.isNotBlank((String) def.get('bodyHtml')));

        Map<String, Object> data = new Map<String, Object>{
            'type' => DocGenEmailTemplateService.TYPE_REQUEST,
            'subject' => 'Preview {DocumentTitle}',
            'bodyHtml' => '<p>Hi {SignerName} {ActionButton}</p>'
        };
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateController.renderPreview(data);
        System.assert(r.htmlBody.contains('Jordan Rivera'), 'sample signer name rendered');
        System.assert(r.subject.contains('Master Services Agreement'), 'sample doc title in subject');
    }

    // ---- Controller: sendTest guards on missing OWA / sends when one exists ----
    @IsTest
    static void controller_sendTest_owaGuard() {
        Map<String, Object> data = new Map<String, Object>{
            'type' => DocGenEmailTemplateService.TYPE_REQUEST,
            'subject' => 'x',
            'bodyHtml' => '<p>{ActionButton}</p>'
        };
        List<OrgWideEmailAddress> owas = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        Test.startTest();
        if (owas.isEmpty()) {
            // No OWA configured → the guard should reject the test send.
            Boolean threw = false;
            try {
                DocGenEmailTemplateController.sendTest(data, 'someone@example.com');
            } catch (Exception e) {
                threw = true;
            }
            System.assert(threw, 'sendTest must reject when no OWA is configured');
        } else {
            insert new DocGen_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Signature_OWA_Id__c = owas[0].Id
            );
            DocGenEmailTemplateController.sendTest(data, 'someone@example.com');
        }
        // Empty recipient always rejected.
        Boolean blankThrew = false;
        try {
            DocGenEmailTemplateController.sendTest(data, '');
        } catch (Exception e) {
            blankThrew = true;
        }
        System.assert(blankThrew, 'blank recipient rejected');
        Test.stopTest();
    }

    // ---- Email service: the send path bails cleanly with no OWA ----
    @IsTest
    static void emailService_noOwa_setsStatus() {
        DocGen_Signature_Request__c req = new DocGen_Signature_Request__c(Status__c = 'Sent');
        insert req;
        DocGenEmailTemplateService.clearCache();
        Test.startTest();
        DocGenSignatureEmailService.sendSignatureRequestEmails(
            new List<DocGenSignatureEmailService.SignerEmail>{
                new DocGenSignatureEmailService.SignerEmail('A', 'a@example.com', 'Signer', 'https://x/y', null)
            },
            'Doc',
            req.Id
        );
        Test.stopTest();
        DocGen_Signature_Request__c after = [
            SELECT Email_Status__c
            FROM DocGen_Signature_Request__c
            WHERE Id = :req.Id
        ];
        System.assert(
            after.Email_Status__c != null && after.Email_Status__c.contains('Org-Wide Email Address'),
            'no-OWA status surfaced: ' + after.Email_Status__c
        );
    }

    // ---- Service: Full HTML mode sends the admin's document with no chrome ----
    @IsTest
    static void fullHtmlMode_skipsChrome() {
        insert new DocGen_Email_Template__c(
            Name = 'Raw Request',
            Type__c = DocGenEmailTemplateService.TYPE_REQUEST,
            Layout_Mode__c = DocGenEmailTemplateService.MODE_FULL_HTML,
            Subject__c = 'Raw {DocumentTitle}',
            Body_Html__c = '<div id="mine">Hi {SignerName} {ActionButton}</div>',
            Is_Active__c = true
        );
        DocGenEmailTemplateService.clearCache();
        Map<String, String> tk = sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST);
        tk.put('SignatureUrl', 'https://sign.example.com/?token=RAW');
        DocGenEmailTemplateService.RenderedEmail r = DocGenEmailTemplateService.render(
            DocGenEmailTemplateService.TYPE_REQUEST,
            tk
        );
        System.assert(r.htmlBody.startsWith('<div id="mine">'), 'admin markup is the document root: ' + r.htmlBody);
        System.assert(r.htmlBody.contains('Jordan Rivera'), 'merge token resolved in full HTML');
        System.assert(r.htmlBody.contains('https://sign.example.com/?token=RAW'), 'action button widget resolved');
        System.assert(!r.htmlBody.contains('Powered by DocGen'), 'no DocGen chrome footer in full HTML');
        System.assert(!r.htmlBody.contains('max-width:600px'), 'no DocGen chrome wrapper in full HTML');
    }

    // ---- Service: per-send subject override resolves tokens ----
    @IsTest
    static void renderSubject_resolvesTokens() {
        String out = DocGenEmailTemplateService.renderSubject(
            'Please sign {DocumentTitle}, {SignerName}',
            sampleTokens(DocGenEmailTemplateService.TYPE_REQUEST)
        );
        System.assertEquals('Please sign Master Services Agreement, Jordan Rivera', out);
    }

    // ---- Controller: layoutMode round-trips through save + reload ----
    @IsTest
    static void controller_layoutMode_roundTrips() {
        Map<String, Object> data = new Map<String, Object>{
            'type' => DocGenEmailTemplateService.TYPE_COMPLETION,
            'subject' => 'Done',
            'bodyHtml' => '<html><body>Thanks {SignerName}</body></html>',
            'layoutMode' => DocGenEmailTemplateService.MODE_FULL_HTML,
            'isActive' => true
        };
        Test.startTest();
        DocGenEmailTemplateController.saveTemplate(data);
        // Preview from unsaved full-HTML values skips chrome too.
        DocGenEmailTemplateService.RenderedEmail pv = DocGenEmailTemplateController.renderPreview(data);
        Test.stopTest();
        System.assert(!pv.htmlBody.contains('Powered by DocGen'), 'full-HTML preview has no chrome');

        List<Map<String, Object>> rows = DocGenEmailTemplateController.getTemplates();
        for (Map<String, Object> row : rows) {
            if (row.get('type') == DocGenEmailTemplateService.TYPE_COMPLETION) {
                System.assertEquals(
                    DocGenEmailTemplateService.MODE_FULL_HTML,
                    (String) row.get('layoutMode'),
                    'saved layoutMode round-trips'
                );
            }
        }
    }

    // ---- helpers ----
    private static Map<String, String> sampleTokens(String type) {
        return new Map<String, String>{
            'SignerName' => 'Jordan Rivera',
            'RoleName' => 'Signer',
            'DocumentTitle' => 'Master Services Agreement',
            'SenderName' => 'Casey Sender',
            'SignatureUrl' => 'https://example.com/sign?token=SAMPLE',
            'ExpirationHours' => '48',
            'ExpirationMinutes' => '15',
            'Pin' => '481627',
            'RequestId' => 'a0X000000000SAMPLE',
            'Message' => DocGenEmailTemplateService.defaultMessage(type)
        };
    }
}
