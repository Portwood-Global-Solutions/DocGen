/**
 * Einstein / Prompt Builder provider.
 *
 * Calls a Flex prompt template through ConnectApi — NOT an HTTP callout, which
 * is what keeps DocGen's "no external services" claim true. The template is a
 * thin carrier: DocGen assembles the real authoring prompt (schema + tag syntax
 * + Flying Saucer constraints) in the Designer and passes it as one input.
 *
 * SETUP REQUIRED IN THE SUBSCRIBER ORG (this is org-owned, not packaged — a
 * GenAiPromptTemplate cannot be hand-authored into a package because its
 * versionIdentifier is platform-generated):
 *   Setup > Einstein > Prompt Builder > New Prompt Template
 *     Type:  Flex
 *     API name: DocGen_HTML_Body
 *     Input: Free Text, API name "Instructions", required
 *     Prompt: any framing text, then insert the Instructions resource
 *     Save, then Activate.
 *
 * MEASURED QUIRKS (talentstacker-buildalong, 2026-07-26):
 *  - additionalConfig.applicationName is REQUIRED. Leave additionalConfig null
 *    and the call fails with the useless "Failed to generate Einstein LLM
 *    generations response" and a null cause. 'PromptBuilderPreview' is accepted;
 *    arbitrary names are rejected with "Application Name is a required field
 *    providing existing registered ai applicaton".
 *  - Limits.getCallouts() stays at 0 — this does not consume the callout limit.
 *  - Wall clock ~13s for a ~5KB body. The caller must budget for a slow call.
 */
public with sharing class DocGenEinsteinProvider implements DocGenAiProvider {
    /** Flex prompt template the subscriber creates. */
    public static final String TEMPLATE_DEV_NAME = 'DocGen_HTML_Body';

    /** Free Text input on that template. Both 'Input:X' and 'Input.X' resolve. */
    private static final String INPUT_KEY = 'Input:Instructions';

    /**
     * Must name an AI application the org already has registered. Empty string
     * is also accepted by the platform, but the named value is clearer in logs.
     */
    private static final String APPLICATION_NAME = 'PromptBuilderPreview';

    public String getName() {
        return 'Einstein';
    }

    /**
     * There is no cheap capability probe for Prompt Builder — no SObject to
     * query (GenAiPromptTemplate is metadata-only), no describe, and the only
     * honest test is a generation, which costs ~13s and real credits. So this
     * reports availability of the CODE path (guaranteed, or the class would not
     * compile) and lets generateHtml surface an actionable message on failure.
     * The Designer treats a failed generation as "AI unavailable" and points the
     * author back at Copy AI Prompt.
     */
    public Boolean isAvailable() {
        return !Test.isRunningTest();
    }

    public String generateHtml(String prompt) {
        if (String.isBlank(prompt)) {
            throw new DocGenAiException('Nothing to send — the authoring prompt was empty.');
        }
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
                TEMPLATE_DEV_NAME,
                input
            );
            if (response == null || response.generations == null || response.generations.isEmpty()) {
                throw new DocGenAiException(
                    'Einstein returned no content. Check that the ' +
                        TEMPLATE_DEV_NAME +
                        ' prompt template has an active version.'
                );
            }
            return response.generations[0].text;
        } catch (DocGenAiException e) {
            throw e;
        } catch (Exception e) {
            // ConnectApiException messages here are frequently generic, so say
            // what the author should go look at rather than echoing it alone.
            throw new DocGenAiException(
                'Einstein could not generate the template: ' +
                    e.getMessage() +
                    ' — confirm the "' +
                    TEMPLATE_DEV_NAME +
                    '" prompt template exists and is Activated, and that you have an Einstein Generative AI permission set.',
                e
            );
        }
    }

    public class DocGenAiException extends Exception {
    }
}
