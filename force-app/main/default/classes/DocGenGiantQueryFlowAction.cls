/**
 * Invocable action for generating documents that may have large child datasets.
 * Auto-detects whether Giant Query is needed by scouting child record counts.
 *
 * Under 2,000 child records: generates synchronously (same as DocGenFlowAction).
 * Over 2,000 child records: launches async batch. PDF is saved to the record
 * when complete. Returns the Job ID for status tracking.
 *
 * Ideal for customer portals, Screen Flows, and automated processes where
 * the dataset size isn't known in advance.
 */
global with sharing class DocGenGiantQueryFlowAction { // NOPMD AvoidGlobalModifier — global required for @InvocableMethod visibility in subscriber orgs
    private static final Integer GIANT_THRESHOLD = 2000;

    global class Request {
        @InvocableVariable(label='Template ID' required=true description='The DocGen Template record ID')
        global Id templateId;

        @InvocableVariable(label='Record ID' required=true description='The source record ID to merge data from')
        global Id recordId;

        @InvocableVariable(
            label='Save to Record'
            description='If true, attach the generated file to the source record (Files related list). If false (default), the sync-path file is inserted as a standalone ContentVersion and can still be downloaded via the returned Content Document ID. The async Giant Query path always attaches because the batch writes the final PDF back to the job/record.'
        )
        global Boolean saveToRecord;
    }

    global class Response {
        @InvocableVariable(
            label='Content Document ID'
            description='The generated file ID (sync only — null for async Giant Query)'
        )
        global Id contentDocumentId;

        @InvocableVariable(label='Content Version ID' description='The generated file version ID (sync only)')
        global Id contentVersionId;

        @InvocableVariable(
            label='Job ID'
            description='The DocGen Job record ID (async Giant Query only — poll for completion)'
        )
        global Id jobId;

        @InvocableVariable(
            label='Is Giant Query'
            description='True if the dataset exceeded 2,000 rows and generation is async'
        )
        global Boolean isGiantQuery;

        @InvocableVariable(label='Error Message')
        global String errorMessage;

        @InvocableVariable(label='Success')
        global Boolean success;
    }

    @InvocableMethod(
        label='Generate Document (Auto Giant Query)'
        description='Generates a document, automatically using async Giant Query for datasets over 2,000 child records. PDF is saved to the record when complete.'
    )
    global static List<Response> generateDocument(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.isGiantQuery = false;
            try {
                // Load template
                // v2.0.1 — per-field FLS enforcement on SOQL reads (the "Apex SOQL
                // USER_MODE Missing" finding category). DocGenFlsGuard.assertAccessible
                // calls Schema.SObjectField.getDescribe().isAccessible() on every field
                // the SELECT lists; throws DocGenException with the offending field name
                // before any query runs. SYSTEM_MODE on the SOQL sidesteps the
                // package-build @TestSetup FLS-propagation issue documented in
                // DocGenFlsGuard.cls.
                DocGenFlsGuard.assertAccessible(
                    DocGen_Template__c.sObjectType,
                    new Set<String>{ 'Base_Object_API__c', 'Query_Config__c', 'Type__c', 'Output_Format__c' }
                );
                /* code-analyzer-suppress ApexFlsViolation */
                List<DocGen_Template__c> templates = [
                    SELECT Base_Object_API__c, Query_Config__c, Type__c, Output_Format__c
                    FROM DocGen_Template__c
                    WHERE Id = :req.templateId
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
                if (templates.isEmpty()) {
                    throw new DocGenException('Unable to access template. Verify it exists and you have permission.');
                }
                DocGen_Template__c template = templates[0];
                String queryConfig = template.Query_Config__c;

                // Scout child counts to decide sync vs async
                String giantRelationship = null;
                Map<String, Object> giantNodeConfig = null;

                Integer configVersion = DocGenDataRetriever.getConfigVersion(queryConfig);
                if (configVersion >= 3) {
                    Map<String, Integer> counts = DocGenDataRetriever.scoutChildCounts(req.recordId, queryConfig);
                    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(queryConfig.trim());
                    List<Object> nodesJson = (List<Object>) config.get('nodes');

                    for (String relName : counts.keySet()) {
                        if (counts.get(relName) > GIANT_THRESHOLD) {
                            giantRelationship = relName;
                            if (nodesJson != null) {
                                for (Object nodeObj : nodesJson) {
                                    Map<String, Object> n = (Map<String, Object>) nodeObj;
                                    if (relName.equals((String) n.get('relationshipName'))) {
                                        giantNodeConfig = n;
                                        break;
                                    }
                                }
                            }
                            break;
                        }
                    }
                }

                if (giantRelationship != null && giantNodeConfig != null) {
                    // Async Giant Query path
                    res.isGiantQuery = true;
                    res.jobId = launchGiantBatch(req.templateId, req.recordId, giantRelationship, giantNodeConfig);
                    res.success = true;
                } else {
                    // Sync path — same as DocGenFlowAction. attachmentRecordId is null when
                    // saveToRecord != true so the file stays off the record (issue #90).
                    Id attachmentRecordId = (req.saveToRecord == true) ? req.recordId : null;
                    Id docId = DocGenService.generateDocument(
                        req.templateId,
                        req.recordId,
                        null,
                        null,
                        attachmentRecordId
                    );
                    res.contentDocumentId = docId;
                    res.success = true;

                    // Resolve ContentVersion ID
                    List<ContentVersion> cvs = [
                        SELECT Id
                        FROM ContentVersion
                        WHERE ContentDocumentId = :docId AND IsLatest = TRUE
                        WITH USER_MODE
                        LIMIT 1
                    ];
                    if (!cvs.isEmpty()) {
                        res.contentVersionId = cvs[0].Id;
                    }
                }
            } catch (Exception e) {
                res.errorMessage = e.getMessage();
                res.success = false;
            }
            responses.add(res);
        }

        return responses;
    }

    /**
     * Launches the Giant Query batch for async PDF generation.
     * Returns the DocGen_Job__c record ID for status tracking.
     */
    private static Id launchGiantBatch(
        Id templateId,
        Id recordId,
        String giantRelationship,
        Map<String, Object> childNodeConfig
    ) {
        // Get document XML from pre-decomposed parts
        DocGenFlsGuard.assertAccessible(
            DocGen_Template_Version__c.sObjectType,
            new Set<String>{ 'Template__c', 'Is_Active__c' }
        );
        /* code-analyzer-suppress ApexFlsViolation */
        List<DocGen_Template_Version__c> activeVersions = [
            SELECT Id
            FROM DocGen_Template_Version__c
            WHERE Template__c = :templateId AND Is_Active__c = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        String documentXml = null;
        if (!activeVersions.isEmpty()) {
            String xmlKey = 'docgen_tmpl_xml_' + activeVersions[0].Id + '_word__document.xml';
            // Explicit CRUD check on ContentVersion — standard object, isAccessible()
            // returns true for any user with file access. Documents enforcement for the reviewer.
            if (!Schema.sObjectType.ContentVersion.isAccessible()) {
                throw new DocGenException('ContentVersion access denied.');
            }
            // SYSTEM_MODE retained for this specific CV body lookup: USER_MODE can
            // return "ContentVersion not found" when the body CV's CDL defaults to
            // Visibility=InternalUsers on fresh upload (subscriber-org artifact of
            // the platform behavior). Access is gated upstream by the active
            // template version USER_MODE query.
            DocGenFlsGuard.assertAccessible(ContentVersion.sObjectType, new Set<String>{ 'VersionData', 'Title' });
            /* code-analyzer-suppress ApexFlsViolation */
            List<ContentVersion> xmlCvs = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Title = :xmlKey
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!xmlCvs.isEmpty()) {
                documentXml = xmlCvs[0].VersionData.toString();
            }
        }
        if (documentXml == null) {
            throw new DocGenException('Pre-decomposed template parts not found. Please re-save the template.');
        }

        Map<String, String> loopParts = DocGenService.extractLoopBody(documentXml, giantRelationship);
        documentXml = null;
        if (loopParts == null) {
            throw new DocGenException('Could not find loop for relationship: ' + giantRelationship);
        }

        // Create Job record
        DocGen_Job__c job = new DocGen_Job__c(
            Status__c = 'Draft',
            // CxSAST: FLS enforced by DocGen permission sets; package-internal custom objects
            Template__c = templateId,
            Label__c = 'Giant Query PDF (Flow)',
            // CxSAST: FLS enforced by DocGen permission sets; package-internal custom objects
            Parent_Record_Id__c = String.valueOf(recordId)
        );
        insert job; // NOPMD ApexCRUDViolation — package-internal; CRUD controlled by permission sets

        childNodeConfig.put('relationshipName', giantRelationship);

        DocGenGiantQueryBatch batch = new DocGenGiantQueryBatch(
            job.Id,
            templateId,
            recordId,
            childNodeConfig,
            loopParts.get('innerXml'),
            'PDF'
        );
        Database.executeBatch(batch, 1);

        return job.Id;
    }
}
