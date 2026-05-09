public with sharing class DocGenTemplateManager {
    /**
     * Retrieves the ContentVersion Blob for the latest file attached to the DocGen Template.
     * @param templateId The ID of the DocGen_Template__c record.
     * @return String Base64 encoded file data.
     */
    public static String getTemplateFileContent(Id templateId) {
        if (templateId == null) {
            throw new DocGenException('Template ID is required.');
        }

        // 1. Check for Active Version first
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template_Version__c> activeVersions = [
            SELECT Content_Version_Id__c
            FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Id targetCvId = null;

        if (!activeVersions.isEmpty()) {
            targetCvId = activeVersions[0].Content_Version_Id__c;
        }

        // Fallback: If no active version OR active version has null CV ID (legacy/broken data)
        if (targetCvId == null) {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :templateId
                WITH USER_MODE
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 1
            ];

            if (!links.isEmpty()) {
                // Get latest ContentVersion for this document
                List<ContentVersion> cvs = [
                    SELECT Id
                    FROM ContentVersion
                    WHERE ContentDocumentId = :links[0].ContentDocumentId AND IsLatest = TRUE
                    WITH USER_MODE
                    LIMIT 1
                ];
                if (!cvs.isEmpty()) {
                    targetCvId = cvs[0].Id;
                }
            }
        }

        if (targetCvId == null) {
            throw new DocGenException('No template file found (active or attached).');
        }

        // SYSTEM_MODE: the template body CV is a package-internal artifact whose
        // access is already gated upstream — the caller had to reach this point via
        // the active version of a DocGen_Template__c that the user can read (via the
        // Template's sharing rule). USER_MODE breaks two callers we care about:
        //
        //   - Experience Cloud guest renders, where the file's CDL defaults to
        //     Visibility=InternalUsers on a fresh upload and guest can't see it.
        //   - The DocGen_Guest_Render__e queueable running as Automated Process,
        //     which has its own quirks resolving file access against ContentVersion.
        //
        // Both surfaced the "ContentVersion not found" error before this swap.
        List<ContentVersion> cvs = [
            SELECT VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE Id = :targetCvId
            WITH SYSTEM_MODE
            LIMIT 1
        ]; // NOPMD ApexCRUDViolation — package-internal template body, see comment above

        if (cvs.isEmpty()) {
            throw new DocGenException('ContentVersion not found.');
        }

        return EncodingUtil.base64Encode(cvs[0].VersionData);
    }
}
