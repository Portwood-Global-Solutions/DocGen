/**
 * Platform Event trigger for signer form-field writeback to the base record.
 * Runs as the Automated Process user (system context), bypassing guest user
 * limitations on base-object DML. Published by the signature finalizer
 * (TemplateSignaturePdfQueueable) only AFTER the signed PDF is saved, so
 * writeback fires once, post-completion, decoupled from the guest request and
 * from PDF render limits.
 *
 * The subscriber re-derives the writable field allowlist from the template
 * config and re-checks FLS per field; the event carries only the request Id.
 * DocGenFieldWritebackService.performWriteback never re-throws — failures are
 * logged to DocGen_Signature_Audit__c — so a writeback error can neither escalate
 * nor strand the signing flow.
 */
trigger DocGenFieldWritebackTrigger on DocGen_Field_Writeback__e(after insert) {
    for (DocGen_Field_Writeback__e evt : Trigger.New) {
        if (String.isBlank(evt.Request_Id__c)) {
            continue;
        }
        try {
            DocGenFieldWritebackService.performWriteback((Id) evt.Request_Id__c);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DocGen: Field writeback event trigger error: ' + e.getMessage());
        }
    }
}
