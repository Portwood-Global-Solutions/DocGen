/**
 * Platform event trigger for guest-context document rendering. Runs as the
 * Automated Process user (system context), bypassing the lightning-subdomain
 * authentication wall that prevents guest-context Blob.toPdf from fetching
 * embedded image URLs. Published by docGenRunner LWC via DocGenController.queueGuestRender
 * when running in Experience Cloud as a guest user.
 *
 * Mirrors the DocGenSignaturePdfTrigger pattern for the e-signature flow.
 */
trigger DocGenGuestRenderTrigger on DocGen_Guest_Render__e(after insert) {
    for (DocGen_Guest_Render__e evt : Trigger.New) {
        if (evt.Job_Id__c == null || evt.Template_Id__c == null || evt.Record_Id__c == null) {
            continue;
        }
        try {
            System.enqueueJob(
                new DocGenGuestRenderQueueable((Id) evt.Job_Id__c, (Id) evt.Template_Id__c, (Id) evt.Record_Id__c)
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'DocGenGuestRenderTrigger enqueue failed for job ' + evt.Job_Id__c + ': ' + e.getMessage()
            );
            try {
                // Explicit USER_MODE silences the analyzer's CRUD-validation
                // rule. Trigger runs as Automated Process here, which has full
                // access to the package's own DocGen_Job__c so USER_MODE is
                // effectively the same as system access.
                Database.update(
                    new DocGen_Job__c(
                        Id = (Id) evt.Job_Id__c,
                        Status__c = 'Failed',
                        Label__c = ('Enqueue error: ' + e.getMessage()).left(255)
                    ),
                    AccessLevel.USER_MODE
                );
            } catch (Exception ignored) {
                // best-effort — job may not exist or be inaccessible
            }
        }
    }
}
