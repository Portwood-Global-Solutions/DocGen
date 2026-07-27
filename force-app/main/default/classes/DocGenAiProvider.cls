/**
 * Interface for AI text generation in DocGen. Implement this to let the
 * Designer's "Generate with Agentforce" button write and revise HTML templates.
 *
 * WHY YOU IMPLEMENT THIS RATHER THAN US SHIPPING IT
 * -------------------------------------------------
 * The Einstein implementation references `ConnectApi.EinsteinLLM`, which is not
 * a visible Apex type in an org without the Einstein entitlement. That makes it
 * impossible to BUILD a package version containing it — the build org has no
 * Einstein, so the Apex fails to compile long before anyone installs anything.
 * Measured, not assumed. So DocGen ships everything except the final hop, and
 * the class that makes the call lives in YOUR org, where your entitlement
 * applies. This mirrors {@link DocGenDataProvider}, which works the same way and
 * for a similar reason.
 *
 * Without an implementation present, DocGen degrades quietly: the Designer hides
 * the Agentforce button and the existing "Copy AI Prompt" workflow is unchanged.
 *
 * REFERENCE IMPLEMENTATION
 * ------------------------
 * `DocGenEinsteinProvider.cls` in the DocGen repository is a complete, working
 * Einstein/Prompt Builder implementation — deploy it as-is into your own org.
 * See docs/AGENTFORCE_SETUP.md for the four setup steps.
 *
 * EXAMPLE
 * -------
 *   public with sharing class MyAiProvider implements portwoodglobal.DocGenAiProvider {
 *       public Boolean isAvailable() {
 *           return true;
 *       }
 *       public String getName() {
 *           return 'My AI';
 *       }
 *       public String generateHtml(String prompt) {
 *           // Return a complete HTML document. DocGen validates it against the
 *           // PDF engine's constraints before anything is saved, so you do not
 *           // need to sanitize it yourself.
 *           return callMyModel(prompt);
 *       }
 *   }
 *
 * Then point DocGen at it: Setup > Custom Settings > DocGen Settings >
 * AI Provider Class = MyAiProvider.
 *
 * CONTRACT NOTES
 * --------------
 * - `generateHtml` receives a fully assembled prompt: the record's schema, the
 *   DocGen merge-tag syntax, the PDF engine's CSS constraints, and what the
 *   author asked for. Send it verbatim; do not summarise it. On an edit it also
 *   contains the current template.
 * - Return the model's raw output. DocGen sanitizes and reports on it.
 * - Do NOT make an HTTP callout. DocGen is a 100% native package and reaches
 *   Einstein through ConnectApi precisely so that stays true. A provider that
 *   calls out breaks that guarantee for the whole product.
 * - Expect to be called synchronously from a Lightning component, and to take
 *   10-25 seconds.
 */
global interface DocGenAiProvider {
    /**
     * True when this org can actually generate. The Designer calls this to
     * decide whether to show the button at all, so it must never throw — return
     * false rather than raising if configuration is missing.
     */
    Boolean isAvailable();

    /** Short name for logs and the UI, e.g. 'Einstein'. */
    String getName();

    /**
     * @param prompt Fully assembled authoring prompt. Send it as-is.
     * @return Raw model output — a complete HTML document. DocGen validates it.
     */
    String generateHtml(String prompt);
}
