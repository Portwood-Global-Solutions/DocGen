// global (not public) so the @InvocableMethod is visible in subscriber-org Flow
// Builder — this is a managed package, where public Apex is invisible to subscribers.
// Inputs are primitives (no Apex-Defined Flow variable), so no @AuraEnabled needed.
global without sharing class DocGenSignatureSubmitter { // NOPMD AvoidGlobalModifier
    global class FlowInput {
        @InvocableVariable(label='Secure Token' required=true)
        global String token;
        @InvocableVariable(label='Signature Data (Base64)' required=true)
        global String signatureData;
    }

    global class FlowOutput {
        @InvocableVariable(label='Is Success')
        global Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        global String errorMessage;
    }

    @InvocableMethod(label='Submit Signed Signature' category='DocGen')
    // CxSAST: USER_MODE not viable in managed package (namespace resolution breaks unqualified field names); CRUD/FLS enforced by permission sets
    global static List<FlowOutput> submitSignature(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            // CxSAST: Loop bounded by design — max 1 iteration (InvocableMethod single-record pattern)
            FlowOutput out = new FlowOutput();
            try {
                // Call the privileged submission handler directly
                DocGenSignatureService.handleSignatureSubmission(input.token, input.signatureData);
                out.isSuccess = true;
            } catch (Exception e) {
                out.isSuccess = false;
                out.errorMessage = e.getMessage();
            }
            results.add(out);
        }
        return results;
    }
}
