// global (not public) so the @InvocableMethod is visible in subscriber-org Flow
// Builder — this is a managed package, where public Apex is invisible to subscribers.
// Inputs are primitives (no Apex-Defined Flow variable), so no @AuraEnabled needed.
global without sharing class DocGenSignatureValidator { // NOPMD AvoidGlobalModifier
    global class FlowInput {
        @InvocableVariable(label='Secure Token' required=true)
        global String token;
    }

    global class FlowOutput {
        @InvocableVariable(label='Is Valid')
        global Boolean isValid;
        @InvocableVariable(label='Error Message')
        global String errorMessage;
        @InvocableVariable(label='Signer Name')
        global String signerName;
        @InvocableVariable(label='Document Title')
        global String documentTitle;
        @InvocableVariable(label='Document Preview URL')
        global String documentUrl;
    }

    /**
     * Queries this action needs in hand before it dares start another token.
     *
     * validateToken costs up to three: the guest-security capability check, the
     * multi-signer lookup, and the legacy single-signer fallback. Four leaves a margin
     * for whatever else shares the transaction.
     */
    private static final Integer QUERY_BUDGET_PER_TOKEN = 4;

    @InvocableMethod(label='Validate Signature Token' category='Portwood')
    global static List<FlowOutput> validateToken(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        if (inputs == null) {
            return results;
        }

        // WHY THIS IS NOT SIMPLY A LOOP.
        //
        // Flow can hand an invocable action up to 200 requests in one transaction, and
        // DocGenSignatureController.validateToken queries per token. Past roughly fifty
        // the transaction hit "System.LimitException: Too many SOQL queries: 101" and
        // the whole interview faulted — every token lost, including the ones already
        // validated, and nothing in the message telling the author what to do about it.
        //
        // The real fix is a bulk validateTokens(Set<String>). That means restructuring
        // guest-facing token security — the capability assert, the multi-signer path and
        // the legacy fallback all key off a single token — and it is not a change to
        // make without the review that guest access deserves. See docs/known-issues.md.
        //
        // Until then: validate as many as the transaction can actually afford, and tell
        // the truth about the rest. A caller gets real answers for those, an explicit
        // "not attempted" for the remainder, and never a fault. Partial and honest beats
        // total and cryptic.
        Integer skipped = 0;
        for (FlowInput input : inputs) {
            FlowOutput out = new FlowOutput();
            if (Limits.getLimitQueries() - Limits.getQueries() < QUERY_BUDGET_PER_TOKEN) {
                skipped++;
                out.isValid = false;
                out.errorMessage =
                    'Not validated — this Flow transaction ran out of its SOQL query allowance. ' +
                    'Portwood validated the earlier tokens in this batch and stopped rather than failing them all. ' +
                    'Validate signature tokens in smaller batches, or one per interview.';
                results.add(out);
                continue;
            }
            DocGenSignatureController.SignatureInitResponse res = DocGenSignatureController.validateToken(input.token);
            out.isValid = res.isValid;
            out.errorMessage = res.errorMessage;
            out.signerName = res.signerName;
            out.documentTitle = res.documentTitle;
            out.documentUrl = res.documentUrl;
            results.add(out);
        }
        if (skipped > 0) {
            System.debug(
                LoggingLevel.WARN,
                'Portwood: Validate Signature Token skipped ' +
                    skipped +
                    ' of ' +
                    inputs.size() +
                    ' tokens — SOQL allowance exhausted.'
            );
        }
        return results;
    }
}
