public with sharing class DocGenPdfPreparedBodyQueueable implements Queueable {
    private Id templateId;
    private Id versionId;
    private String fileName;
    private List<Id> chunkVersionIds;

    public DocGenPdfPreparedBodyQueueable(Id templateId, Id versionId, String fileName, List<Id> chunkVersionIds) {
        this.templateId = templateId;
        this.versionId = versionId;
        this.fileName = fileName;
        this.chunkVersionIds = chunkVersionIds == null ? new List<Id>() : new List<Id>(chunkVersionIds);
    }

    public void execute(QueueableContext context) {
        if (templateId == null || versionId == null || chunkVersionIds.isEmpty()) {
            return;
        }

        String base64Content = '';
        for (Id chunkVersionId : chunkVersionIds) {
            /* code-analyzer-suppress ApexFlsViolation */
            ContentVersion chunk = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :chunkVersionId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            base64Content += chunk.VersionData.toString();
        }

        String pathBase = String.isBlank(fileName) ? 'template' : fileName.substringBeforeLast('.');
        if (String.isBlank(pathBase)) {
            pathBase = 'template';
        }

        ContentVersion prepared = new ContentVersion();
        prepared.Title = 'docgen_pdf_body_' + templateId + '_' + Datetime.now().getTime();
        prepared.PathOnClient = pathBase + '.pdf';
        prepared.VersionData = EncodingUtil.base64Decode(base64Content);
        prepared.FirstPublishLocationId = templateId;
        DocGenFlsGuard.assertCreateable(
            prepared,
            new Set<String>{ 'Title', 'PathOnClient', 'VersionData', 'FirstPublishLocationId' }
        );
        /* code-analyzer-suppress ApexFlsViolation */
        Database.insert(prepared, AccessLevel.SYSTEM_MODE);

        DocGen_Template_Version__c version = new DocGen_Template_Version__c(
            Id = versionId,
            Content_Version_Id__c = prepared.Id
        );
        DocGenFlsGuard.assertUpdateable(version, new Set<String>{ 'Content_Version_Id__c' });
        /* code-analyzer-suppress ApexFlsViolation */
        Database.update(version, AccessLevel.SYSTEM_MODE);
    }
}
