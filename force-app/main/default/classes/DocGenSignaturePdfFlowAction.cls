/**
 * Flow-invocable action to send an ALREADY-GENERATED document (a ContentVersion)
 * for signature, using the Milestone 1 flat-PDF signing page.
 *
 * Two-step flow: generate the document first (DocGenFlowAction.generateDocument →
 * ContentVersion Id), then pass that Id here. This creates a Template__c-null
 * signature request bound to the CV (Source_Document_Id__c), renders the real
 * PDF to each signer, and captures a name+consent signature → audit +
 * Status='Signed'. No template merge, no placements, no DOCX-XML stamping.
 *
 * PREREQUISITES:
 * 1. A pre-generated document stored as a ContentVersion (e.g. via "DocGen: Generate Document")
 * 2. An Org-Wide Email Address configured in DocGen > Signatures settings (for branded emails)
 * 3. A Salesforce Site configured for the flat-PDF signing page
 *
 * QUICK START:
 * 1. Generate a PDF and capture its ContentVersion Id
 * 2. Build a collection of DocGen Signers (Name + Email + optional Role/Contact Id)
 * 3. Drag "DocGen: Send Existing Document for Signature" into your Flow
 * 4. Set Content Version Id, Related Record Id, and the Signers collection
 * 5. The action returns signing URLs and a request Id for downstream automation
 */
global with sharing class DocGenSignaturePdfFlowAction { // NOPMD AvoidGlobalModifier - required for @InvocableMethod visibility in subscriber orgs
    global class Request {
        @InvocableVariable(
            required=true
            label='Content Version Id'
            description='The Id of the ContentVersion (068...) to send for signature. This is the already-generated document the signer will see. Example: capture it from the "DocGen: Generate Document" action output.'
        )
        global Id contentVersionId;

        @InvocableVariable(
            required=true
            label='Related Record Id'
            description='The record this signature request is for. In a record-triggered Flow, use {!$Record.Id}.'
        )
        global Id relatedRecordId;

        @InvocableVariable(
            label='Signers'
            description='A collection of DocGen Signers. Create an Apex-Defined variable of type DocGenSigner (Name + Email required; Role and Contact Id optional), add each to a collection with an Assignment element, and pass it here.'
        )
        global List<DocGenSigner> signerRecords;

        @InvocableVariable(
            label='Signing Order'
            description='Enter "Parallel" (default) to email all signers at once, or "Sequential" to send one at a time — each signer is emailed only after the previous one completes.'
        )
        global String signingOrder;

        @InvocableVariable(
            label='Document Title Format'
            description='Optional. Overrides the title shown on the signing page and signed-document records. Leave blank to use the source document title.'
        )
        global String documentTitleFormat;
    }

    global class Result {
        @InvocableVariable(
            label='Signature Request Id'
            description='The Id of the created DocGen Signature Request record. Use this to track status or link in downstream Flow elements.'
        )
        global Id signatureRequestId;

        @InvocableVariable(
            label='Signer URLs'
            description='A collection of unique signing URLs — one per signer, in the same order as the Signers input. Each URL is valid for 48 hours.'
        )
        global List<String> signerUrls;

        @InvocableVariable(label='Signer Names' description='The resolved signer names, in order.')
        global List<String> signerNames;

        @InvocableVariable(label='Signer Emails' description='The resolved signer emails, in order.')
        global List<String> signerEmails;

        @InvocableVariable(
            label='Signer Roles'
            description='The resolved role names per signer. Shows "Signer" for any role not specified.'
        )
        global List<String> signerRoles;

        @InvocableVariable(
            label='Success'
            description='TRUE if the signature request was created successfully. FALSE if there was an error — check Error Message.'
        )
        global Boolean success;

        @InvocableVariable(
            label='Error Message'
            description='Error details if Success is FALSE. Common: missing document, missing signer data, or permission issues.'
        )
        global String errorMessage;
    }

    @InvocableMethod(
        label='DocGen: Send Existing Document for Signature'
        description='Sends an already-generated document (a ContentVersion) for signature on the flat-PDF signing page. Pass the Content Version Id and a collection of Signers. Returns signing URLs.'
        category='Document Generation'
    )
    global static List<Result> send(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null)
            return results;
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Result processOne(Request req) {
        Result r = new Result();
        r.success = false;
        r.signerUrls = new List<String>();
        r.signerNames = new List<String>();
        r.signerEmails = new List<String>();
        r.signerRoles = new List<String>();

        // Validation throws (preserves existing Flow behavior where bad input stops the Flow)
        if (req == null) {
            throw new DocGenException('Request is null');
        }
        if (req.contentVersionId == null) {
            throw new DocGenException(
                'Content Version Id is required — pass the Id of an already-generated document (068...).'
            );
        }
        if (req.relatedRecordId == null) {
            throw new DocGenException('Related Record Id is required — pass the record this signature is for.');
        }

        // Build signer inputs from the standalone DocGenSigner collection — the only
        // signer type Flow can expose as an Apex-Defined variable (inner classes never appear).
        List<Map<String, Object>> signerInputs = buildSignerInputs(req);
        if (signerInputs.isEmpty()) {
            throw new DocGenException('At least one signer is required. Pass a Signers collection.');
        }

        // Runtime errors (DML failures, deleted CV) are caught and returned in Result
        try {
            String signingOrder = String.isNotBlank(req.signingOrder) ? req.signingOrder : 'Parallel';
            if (signingOrder != 'Parallel' && signingOrder != 'Sequential') {
                signingOrder = 'Parallel';
            }

            String signersJson = JSON.serialize(signerInputs);
            List<DocGenSignatureSenderController.SignerResult> signerResults = DocGenSignatureSenderController.createRequestFromContentVersion(
                req.contentVersionId,
                req.relatedRecordId,
                signersJson,
                signingOrder,
                req.documentTitleFormat
            );

            // Resolve the created request Id from the first signer
            if (!signerResults.isEmpty()) {
                String firstEmail = (String) signerInputs[0].get('signerEmail');
                // v2.0.1 — per-field FLS enforcement on SOQL reads. SYSTEM_MODE sidesteps
                // the package-build @TestSetup FLS-propagation issue (see DocGenFlsGuard.cls).
                DocGenFlsGuard.assertAccessible(
                    DocGen_Signer__c.sObjectType,
                    new Set<String>{ 'Signature_Request__c', 'Signer_Email__c' }
                );
                /* code-analyzer-suppress ApexFlsViolation */
                List<DocGen_Signer__c> createdSigners = [
                    SELECT Signature_Request__c
                    FROM DocGen_Signer__c
                    WHERE
                        Signer_Email__c = :firstEmail
                        AND Signature_Request__r.Source_Document_Id__c = :req.contentVersionId
                        AND Signature_Request__r.Related_Record_Id__c = :req.relatedRecordId
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ]; // NOPMD ApexCRUDViolation - package-internal
                if (!createdSigners.isEmpty()) {
                    r.signatureRequestId = createdSigners[0].Signature_Request__c;
                }
            }

            // Populate result
            for (DocGenSignatureSenderController.SignerResult sr : signerResults) {
                r.signerUrls.add(sr.signerUrl);
                r.signerNames.add(sr.signerName);
                r.signerEmails.add(sr.signerEmail);
                r.signerRoles.add(sr.roleName);
            }

            r.success = true;
        } catch (Exception e) {
            r.errorMessage = e.getMessage();
            r.success = false;
        }

        return r;
    }

    /**
     * Builds signer input maps from the standalone DocGenSigner collection.
     */
    private static List<Map<String, Object>> buildSignerInputs(Request req) {
        List<Map<String, Object>> inputs = new List<Map<String, Object>>();
        if (req.signerRecords == null || req.signerRecords.isEmpty()) {
            return inputs;
        }
        for (DocGenSigner s : req.signerRecords) {
            if (String.isBlank(s.name)) {
                throw new DocGenException('Each signer must have a Name.');
            }
            if (String.isBlank(s.email)) {
                throw new DocGenException(
                    'Each signer must have an Email. Signer "' + s.name + '" is missing an email.'
                );
            }
            inputs.add(
                new Map<String, Object>{
                    'signerName' => s.name,
                    'signerEmail' => s.email,
                    'roleName' => String.isNotBlank(s.role) ? s.role : 'Signer',
                    'contactId' => s.contactId
                }
            );
        }
        return inputs;
    }
}
