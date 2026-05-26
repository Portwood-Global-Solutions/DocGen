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

    @InvocableMethod(label='Validate Signature Token' category='DocGen')
    global static List<FlowOutput> validateToken(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            DocGenSignatureController.SignatureInitResponse res = DocGenSignatureController.validateToken(input.token);
            FlowOutput out = new FlowOutput();
            out.isValid = res.isValid;
            out.errorMessage = res.errorMessage;
            out.signerName = res.signerName;
            out.documentTitle = res.documentTitle;
            out.documentUrl = res.documentUrl;
            results.add(out);
        }
        return results;
    }
}
