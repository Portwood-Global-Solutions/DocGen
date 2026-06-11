public with sharing class DocGenContentDocumentCleanupQueueable implements Queueable {
    private final List<Id> contentDocumentIds;

    public DocGenContentDocumentCleanupQueueable(List<Id> contentDocumentIds) {
        this.contentDocumentIds = new List<Id>();
        if (contentDocumentIds != null) {
            this.contentDocumentIds.addAll(contentDocumentIds);
        }
    }

    public void execute(QueueableContext context) {
        if (contentDocumentIds.isEmpty()) {
            return;
        }
        Set<Id> uniqueIds = new Set<Id>(contentDocumentIds);
        /* code-analyzer-suppress ApexFlsViolation */
        List<ContentDocument> docs = [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN :uniqueIds
            WITH SYSTEM_MODE
        ];
        if (!docs.isEmpty()) {
            /* code-analyzer-suppress ApexFlsViolation */
            Database.delete(docs, false, AccessLevel.SYSTEM_MODE);
        }
    }
}
