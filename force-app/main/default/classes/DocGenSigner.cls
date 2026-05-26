/**
 * Standalone signer record for the "DocGen: Create Signature Request" Flow action.
 *
 * MUST be a top-level (standalone) class. Flow does NOT expose inner/nested Apex
 * classes as Apex-Defined variable types — @AuraEnabled on a nested class's fields
 * does nothing for the variable picker (confirmed: katiekodes.com/flow-apex-defined-data-types).
 * The original inner DocGenSignatureFlowAction.Signer therefore could never appear
 * in Flow; this standalone class replaces it for Flow authoring.
 *
 * Requirements for a managed-package Apex-Defined Flow variable, all satisfied here:
 *   - top-level (standalone) class        — Flow ignores inner classes
 *   - global class + global members       — subscriber visibility
 *   - @AuraEnabled members                — exposes the type and lets Flow set fields
 *   - explicit global no-arg constructor  — subscriber Flow must instantiate it;
 *                                           the implicit constructor is public (invisible)
 */
global class DocGenSigner {
    global DocGenSigner() {
    }

    @AuraEnabled
    global String name;

    @AuraEnabled
    global String email;

    @AuraEnabled
    global String role;

    @AuraEnabled
    global Id contactId;
}
