/**
 * Einstein / Prompt Builder implementation of DocGenAiProvider.
 *
 * Ships in the **Portwood DocGen Agentforce Extension** package, separately from
 * DocGen itself, and that separation is not stylistic. This class references
 * `ConnectApi.EinsteinLLM`, which is not a visible Apex type in an org without
 * the Einstein entitlement. A base package containing it BUILDS fine but is
 * REFUSED AT INSTALL for every customer who does not have Einstein:
 *
 *   ApexClass Type is not visible: ConnectApi.EinsteinLLM
 *
 * The prompt template alongside it is worse — a packaged `GenAiPromptTemplate`
 * makes the whole package require the "Generative AI Prompt Templates" feature,
 * gating install for everyone. Both measured 2026-07-26. Keeping them in this
 * extension is what lets DocGen stay installable everywhere.
 *
 * The extension shares the `portwoodglobal` namespace with the base package, so
 * `DocGenAiProviderFactory.get()` finds this class through its existing
 * `Type.forName('portwoodglobal', className)` fallback — the base package needs
 * no knowledge of the extension at all.
 *
 * A subscriber can still supply their own provider instead: implement
 * `portwoodglobal.DocGenAiProvider` and name the class in
 * DocGen Settings > AI Provider Class. See UserGuide section 5.7.11.
 *
 * MEASURED QUIRKS (2026-07-26)
 * ----------------------------
 *  - `additionalConfig.applicationName` is REQUIRED. Leave additionalConfig null
 *    and the call fails with the useless "Failed to generate Einstein LLM
 *    generations response", a null cause, and "(System Code)" as the entire
 *    stack trace. 'PromptBuilderPreview' is accepted; most other names are
 *    rejected with "Application Name is a required field providing existing
 *    registered ai applicaton".
 *  - This is NOT an HTTP callout — Limits.getCallouts() stays 0 — which is what
 *    keeps DocGen's "no external services" guarantee true.
 *  - Budget 10-25 seconds for a 5KB document.
 */
public with sharing class DocGenEinsteinProvider implements DocGenAiProvider {

    /** Free Text input on the Flex template. Both 'Input:X' and 'Input.X' work. */
    private static final String INPUT_KEY = 'Input:Instructions';

    /**
     * Must name an AI application the org already has registered. Empty string
     * is also accepted by the platform, but a named value is clearer in logs.
     */
    private static final String APPLICATION_NAME = 'PromptBuilderPreview';

    /** Fallback when the DocGen setting is blank and for unmanaged source. */
    private static final String FALLBACK_TEMPLATE = 'DocGen_HTML_Body';

    public String getName() {
        return 'Einstein';
    }

    /**
     * There is no cheap capability probe for Prompt Builder — no SObject to
     * query (GenAiPromptTemplate is metadata-only) and no describe. The only
     * honest test is a generation, which costs real time and credits. So report
     * that the code path exists and let generateHtml surface an actionable
     * message. Must never throw: DocGen calls this to decide whether to show
     * the button.
     */
    public Boolean isAvailable() {
        return !Test.isRunningTest();
    }

    public String generateHtml(String prompt) {
        if (String.isBlank(prompt)) {
            throw new DocGenAiException('Nothing to send — the authoring prompt was empty.');
        }
        String templateName = resolveTemplateName();

        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;

        // Required. Omitting this is the single most common cause of the opaque
        // "Failed to generate Einstein LLM generations response".
        ConnectApi.EinsteinLlmAdditionalConfigInput cfg = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        cfg.applicationName = APPLICATION_NAME;
        input.additionalConfig = cfg;

        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = prompt;
        input.inputParams = new Map<String, ConnectApi.WrappedValue>{ INPUT_KEY => wrapped };

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                templateName,
                input
            );
            if (response == null || response.generations == null || response.generations.isEmpty()) {
                throw new DocGenAiException(
                    'Einstein returned no content. Check that the "' +
                        templateName +
                        '" prompt template has an ACTIVE version.'
                );
            }
            return response.generations[0].text;
        } catch (DocGenAiException e) {
            throw e;
        } catch (Exception e) {
            // ConnectApiException messages here are frequently generic, so name
            // what the admin should go and look at rather than echoing it alone.
            throw new DocGenAiException(
                'Einstein could not generate the template: ' +
                    e.getMessage() +
                    ' — confirm the "' +
                    templateName +
                    '" prompt template exists and is Activated, and that you hold an Einstein Generative AI permission set.',
                e
            );
        }
    }

    /**
     * Prefer the DocGen setting so an admin can rename the template without
     * editing Apex; fall back to the constant.
     *
     * Reads the packaged CUSTOM SETTING directly rather than calling
     * DocGenAiProviderFactory. That class is `public`, so it is NOT visible
     * across a namespace boundary — a subscriber class calling it fails to
     * compile with "Type is not visible: portwoodglobal.DocGenAiProviderFactory".
     * Measured against a real managed install, 2026-07-26. The custom setting is
     * Public and IS readable, which is why this route works.
     */
    private String resolveTemplateName() {
        try {
            // Same namespace as the base package, so no prefix is needed here.
            DocGen_Settings__c s = DocGen_Settings__c.getOrgDefaults();
            String configured = s == null ? null : s.AI_Prompt_Template__c;
            if (String.isNotBlank(configured)) {
                return configured.trim();
            }
        } catch (Exception e) {
            // Older DocGen, or the setting is unreadable — the constant is fine.
        }
        return FALLBACK_TEMPLATE;
    }

    public class DocGenAiException extends Exception {
    }
}
