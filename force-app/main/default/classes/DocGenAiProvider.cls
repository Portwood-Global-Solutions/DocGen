/**
 * Text-generation provider for AI-assisted template authoring.
 *
 * Everything downstream of this interface — the validator, the staging field,
 * the ContentVersion write and the Designer load — is testable with a canned
 * response, so the Einstein entitlement only gates the final wiring.
 *
 * Implementations must never make an HTTP callout. Einstein is reached through
 * ConnectApi, which is the only reason an AI feature is allowable in a package
 * that advertises "100% native, no external services".
 */
public interface DocGenAiProvider {
    /**
     * True when this org can actually generate. The Designer uses this to hide
     * the button rather than let a subscriber click into an error — the feature
     * degrades to the existing copy-paste prompt when AI is unavailable.
     */
    Boolean isAvailable();

    /** Short name for logs and the UI ("Einstein", "Stub"). */
    String getName();

    /**
     * @param prompt Fully assembled authoring prompt (schema + tag syntax +
     *               rendering constraints + what the author asked for).
     * @return Raw model output. Callers must assume it needs sanitizing.
     */
    String generateHtml(String prompt);
}
