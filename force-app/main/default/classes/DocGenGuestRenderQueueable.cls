/**
 * Renders a DocGen template + record as PDF in system context for Experience
 * Cloud guest users. Enqueued by DocGenGuestRenderTrigger from a platform event
 * the guest LWC publishes — meaning this class executes as the Automated Process
 * user, NOT the guest. That context swap is the whole reason this exists:
 * Blob.toPdf() resolves relative shepherd URLs against the org's lightning
 * subdomain, which the guest has no session against, so guest-context renders
 * lose every embedded image. Internal users (admin, Automated Process) authenticate
 * fine, so running render here restores image fetching.
 *
 * On success: updates the tracking DocGen_Job__c to Completed and stamps the
 * resulting ContentVersion Id on Merged_PDF_CV__c. The LWC polls the job and
 * downloads via the site domain when it sees a CV Id. The result CDL is
 * flipped to Visibility = AllUsers so the guest can fetch it.
 *
 * On failure: job → Failed with the error message captured in Label__c so the
 * LWC can surface a useful message instead of a silent blank.
 */
public without sharing class DocGenGuestRenderQueueable implements Queueable {
    private final Id jobId;
    private final Id templateId;
    private final Id recordId;

    public DocGenGuestRenderQueueable(Id jobId, Id templateId, Id recordId) {
        this.jobId = jobId;
        this.templateId = templateId;
        this.recordId = recordId;
    }

    public void execute(QueueableContext ctx) {
        update new DocGen_Job__c(Id = jobId, Status__c = 'Processing');

        try {
            Id contentDocId = DocGenService.generateDocument(templateId, recordId);

            ContentVersion latestCv = [
                SELECT Id
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocId AND IsLatest = TRUE
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            // Flip the result file's CDL to AllUsers so the guest browser
            // (using its site-domain session) can fetch via shepherd. Without
            // this the file is internal-only and the LWC's download fails.
            List<ContentDocumentLink> toFlip = new List<ContentDocumentLink>();
            for (ContentDocumentLink cdl : [
                SELECT Id, Visibility
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocId
            ]) {
                if (cdl.Visibility == 'InternalUsers') {
                    cdl.Visibility = 'AllUsers';
                    toFlip.add(cdl);
                }
            }
            if (!toFlip.isEmpty()) {
                update toFlip;
            }

            update new DocGen_Job__c(
                Id = jobId,
                Status__c = 'Completed',
                Merged_PDF_CV__c = String.valueOf(latestCv.Id)
            );
        } catch (Exception e) {
            String msg = e.getMessage();
            String trimmed = String.isBlank(msg) ? 'Unknown error' : msg.left(255);
            update new DocGen_Job__c(Id = jobId, Status__c = 'Failed', Label__c = trimmed);
            System.debug(LoggingLevel.ERROR, 'DocGenGuestRenderQueueable failed for job ' + jobId + ': ' + e);
        }
    }
}
