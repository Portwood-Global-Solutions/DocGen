/**
 * Resolves the org's DocGenAiProvider. One seam, so the Einstein entitlement
 * only gates the final hop.
 *
 * The provider class is resolved BY NAME at runtime, never referenced at compile
 * time. That is load bearing, and it is what makes the whole feature shippable:
 * an implementation mentions `ConnectApi.EinsteinLLM`, which is not a visible
 * type in an org without the entitlement — including the org Salesforce spins up
 * to BUILD the package. A compile-time reference here would make DocGen itself
 * unbuildable. Measured 2026-07-26 against a fresh namespaced scratch org from
 * the Dev Hub: "Type is not visible: ConnectApi.EinsteinLLM".
 *
 * Resolution order mirrors DocGenDataRetriever's custom-data-provider lookup:
 * the subscriber's own namespace first, then ours.
 */
public with sharing class DocGenAiProviderFactory {
    /** Used when DocGen_Settings__c.AI_Provider_Class__c is blank. */
    @TestVisible
    private static final String DEFAULT_PROVIDER_CLASS = 'DocGenEinsteinProvider';

    /** Used when DocGen_Settings__c.AI_Prompt_Template__c is blank. */
    public static final String DEFAULT_PROMPT_TEMPLATE = 'DocGen_HTML_Body';

    /**
     * The default "no AI here" message. Always names the fallback the author can
     * actually use — an unavailable provider that only says "not set up" leaves
     * someone stuck mid-task with nowhere to go.
     */
    @TestVisible
    private static final String NOT_CONFIGURED = 'In-org AI generation is not set up in this org. Use Copy AI Prompt and paste the result back, or ask an administrator to deploy an AI provider class (see the DocGen Agentforce setup guide).';

    /** Shown when the org has not opted in. Names the exact switch. */
    @TestVisible
    private static final String NOT_ENABLED = 'AI authoring is turned off in this org. An administrator can enable it in Setup > Custom Settings > DocGen Settings > Enable AI Authoring, once Einstein Prompt Builder and the DocGen_HTML_Body prompt template are set up. Until then, use Copy AI Prompt and paste the result back.';

    /** Set by tests, or to force a specific implementation. */
    @TestVisible
    private static DocGenAiProvider overrideProvider;

    public static DocGenAiProvider get() {
        if (overrideProvider != null) {
            return overrideProvider;
        }
        if (Test.isRunningTest()) {
            return new DocGenAiStubProvider();
        }

        // Explicit opt-in. The Einstein provider now ships INSIDE the package,
        // so "is the class present?" no longer answers "is AI usable here?" —
        // Type.forName finds it in every org, entitled or not. Without this gate
        // every subscriber would see a button that throws when pressed. The
        // admin turns it on once setup is actually complete.
        if (!aiAuthoringEnabled()) {
            return new DocGenUnavailableProvider(NOT_ENABLED);
        }

        String className = configuredProviderClass();
        Type providerType = Type.forName(className);
        if (providerType == null) {
            // Subscriber namespace first (their own class), then ours.
            providerType = Type.forName('portwoodglobal', className);
        }
        if (providerType == null) {
            return new DocGenUnavailableProvider(NOT_CONFIGURED);
        }

        Object instance;
        try {
            instance = providerType.newInstance();
        } catch (Exception e) {
            return new DocGenUnavailableProvider(
                'The AI provider class "' +
                    className +
                    '" could not be instantiated: ' +
                    e.getMessage() +
                    '. It needs a public no-argument constructor.'
            );
        }
        if (!(instance instanceof DocGenAiProvider)) {
            // Named but wrong — say so rather than pretending AI is unavailable,
            // or an admin will hunt a missing entitlement that is not missing.
            return new DocGenUnavailableProvider(
                'The class "' +
                    className +
                    '" does not implement the DocGenAiProvider interface, so DocGen cannot use it.'
            );
        }
        return (DocGenAiProvider) instance;
    }

    /**
     * Has an admin confirmed AI authoring is set up in this org?
     * Defaults to FALSE, so an upgrade never surfaces a button that fails.
     */
    public static Boolean aiAuthoringEnabled() {
        String v = readSetting('Enable_AI_Authoring__c');
        return v == 'true';
    }

    /** Provider class name from settings, falling back to the default. */
    public static String configuredProviderClass() {
        String configured = readSetting('AI_Provider_Class__c');
        return String.isNotBlank(configured) ? configured.trim() : DEFAULT_PROVIDER_CLASS;
    }

    /**
     * Prompt template API name from settings, falling back to the default.
     *
     * DocGen never calls Prompt Builder itself — the provider class does — so
     * this exists purely so an admin can point a provider at a differently named
     * template without editing Apex.
     */
    public static String configuredPromptTemplate() {
        String configured = readSetting('AI_Prompt_Template__c');
        return String.isNotBlank(configured) ? configured.trim() : DEFAULT_PROMPT_TEMPLATE;
    }

    /**
     * Read one field off the hierarchy custom setting. Never throws: a settings
     * problem must degrade to "AI unavailable", not break the Designer.
     * Read dynamically so an org that has not yet upgraded past the release
     * adding these fields still compiles and runs.
     */
    private static String readSetting(String fieldName) {
        try {
            DocGen_Settings__c s = DocGen_Settings__c.getOrgDefaults();
            if (s == null) {
                return null;
            }
            Object v = s.get(fieldName);
            return v == null ? null : String.valueOf(v);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Honest no-op for an org with no usable provider. Never throws on the
     * availability probe, and carries a reason the admin can act on.
     */
    public class DocGenUnavailableProvider implements DocGenAiProvider {
        private final String reason;

        public DocGenUnavailableProvider() {
            this(NOT_CONFIGURED);
        }

        public DocGenUnavailableProvider(String reason) {
            this.reason = reason;
        }

        public Boolean isAvailable() {
            return false;
        }

        public String getName() {
            return 'Unavailable';
        }

        public String generateHtml(String prompt) {
            throw new DocGenAiUnavailableException(this.reason);
        }
    }

    public class DocGenAiUnavailableException extends Exception {
    }

    @TestVisible
    private static void setProvider(DocGenAiProvider p) {
        overrideProvider = p;
    }
}
