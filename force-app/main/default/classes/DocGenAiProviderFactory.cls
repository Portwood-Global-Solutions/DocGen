/**
 * Chooses the AI provider. One seam, so the entitlement only gates the last hop.
 *
 * Tests and orgs without Einstein get the stub; everything downstream is
 * identical, which is what makes the validator, the staging field, the
 * ContentVersion write and the Designer load verifiable without an entitlement.
 */
public with sharing class DocGenAiProviderFactory {
    /** Set by tests, or by an org that wants to force the canned path. */
    @TestVisible
    private static DocGenAiProvider overrideProvider;

    /**
     * Resolved by NAME, not by a compile-time reference, and this is load
     * bearing: DocGenEinsteinProvider mentions ConnectApi.EinsteinLLM, which is
     * not a visible type in an org without the Einstein entitlement. A static
     * `new DocGenEinsteinProvider()` here would make this class — and therefore
     * the validator, the controller and the Designer — fail to compile in every
     * org that does not have Einstein turned on. Measured 2026-07-26 in
     * Portwood Dev: "Type is not visible: ConnectApi.EinsteinLLM".
     *
     * So the Einstein class ships (or does not ship) independently, and its
     * absence degrades to "no button" rather than "package will not deploy".
     */
    private static final String EINSTEIN_PROVIDER = 'DocGenEinsteinProvider';

    public static DocGenAiProvider get() {
        if (overrideProvider != null) {
            return overrideProvider;
        }
        if (Test.isRunningTest()) {
            return new DocGenAiStubProvider();
        }
        Type t = Type.forName(EINSTEIN_PROVIDER);
        if (t == null) {
            // Einstein classes are not present in this org — the Designer hides
            // the button and the existing Copy AI Prompt path stays the answer.
            return new DocGenUnavailableProvider();
        }
        return (DocGenAiProvider) t.newInstance();
    }

    /** Honest no-op for an org with no AI. Never throws on the availability probe. */
    public class DocGenUnavailableProvider implements DocGenAiProvider {
        public Boolean isAvailable() {
            return false;
        }
        public String getName() {
            return 'Unavailable';
        }
        public String generateHtml(String prompt) {
            throw new DocGenAiUnavailableException(
                'In-org AI generation is not set up in this org. Use Copy AI Prompt and paste the result back, or ask an administrator to enable Einstein Prompt Builder.'
            );
        }
    }

    public class DocGenAiUnavailableException extends Exception {
    }

    @TestVisible
    private static void setProvider(DocGenAiProvider p) {
        overrideProvider = p;
    }
}
