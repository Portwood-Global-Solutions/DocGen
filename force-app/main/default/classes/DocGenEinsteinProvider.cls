/**
 * REFERENCE IMPLEMENTATION — DEPLOY THIS INTO YOUR OWN ORG.
 *
 * This class is deliberately NOT part of the Portwood DocGen package, and cannot
 * be: it references `ConnectApi.EinsteinLLM`, which is not a visible Apex type in
 * an org without the Einstein entitlement — including the org Salesforce spins up
 * to build the package. A package version containing this file fails to compile
 * at BUILD time, long before anyone installs it. Measured, not assumed. It is in
 * `.forceignore` for exactly that reason; removing it from there will break the
 * next DocGen release build.
 *
 * So it ships as source you deploy yourself:
 *
 *   sf project deploy start -o <your-org> \
 *     -d force-app/main/default/classes/DocGenEinsteinProvider.cls
 *
 * Full instructions, including the prompt template you must create, are in
 * docs/AGENTFORCE_SETUP.md.
 *
 * NAMESPACE NOTE
 * --------------
 * When DocGen is installed as a managed package, its Apex lives under the
 * `portwoodglobal` namespace, so the interface is referenced with that prefix
 * below. If you are working against unmanaged DocGen source (the development
 * repo), drop the prefix — see the commented alternative on the class line.
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
    // Managed-package installs use:
    //   implements portwoodglobal.DocGenAiProvider

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
            // Managed-package installs use the namespaced names:
            //   portwoodglobal__DocGen_Settings__c s = portwoodglobal__DocGen_Settings__c.getOrgDefaults();
            //   String configured = s == null ? null : s.portwoodglobal__AI_Prompt_Template__c;
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
