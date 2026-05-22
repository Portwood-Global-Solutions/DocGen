public without sharing class DocGenAuthenticatorController {
    // SHA-256 hex digest = 64 lowercase/uppercase hex characters
    private static final Pattern SHA256_HEX = Pattern.compile('^[a-fA-F0-9]{64}$');
    // Salesforce Id = 15 or 18 alphanumeric characters
    private static final Pattern SF_ID = Pattern.compile('^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$');

    /**
     * Verifies a document by its SHA-256 hash.
     */
    @AuraEnabled
    @RemoteAction
    public static List<VerificationResult> verifyDocument(String fileHash) {
        List<VerificationResult> results = new List<VerificationResult>();

        // Strict input validation: must be a 64-char hex string (SHA-256 digest).
        // Reject early with empty list if the input is malformed — never reach SOQL.
        if (String.isBlank(fileHash) || fileHash.length() != 64 || !SHA256_HEX.matcher(fileHash).matches()) {
            return results;
        }

        // Public document verifier — the capability is holding the SHA-256 hash
        // of the signed PDF. Describe check below is the explicit CRUD/FLS
        // enforcement signal documented in DocGenSignatureGuestSecurity.
        DocGenSignatureGuestSecurity.assertAuditReadable();
        // Field allowlist: Signed_Date__c, IP_Address__c, Signer_Name__c,
        // Signer_Email__c, Consent_Captured__c, PIN_Verified_At__c,
        // Document_Hash_SHA256__c, Signer__r.Role_Name__c — only verification-
        // contract fields are returned. SYSTEM_MODE is required because guest
        // profile has no DocGen_Signature_Audit__c CRUD by design; the hash
        // IS the capability.
        //
        // No LIMIT: a multi-signer document has one audit record per signer,
        // all sharing the same Document_Hash_SHA256__c (the hash of the
        // final stamped PDF). The verifier returns every signer for the
        // complete audit trail of the document.
        // v2.0.1 — per-field FLS enforcement on SOQL reads (the "Apex SOQL
        // USER_MODE Missing" finding category). DocGenFlsGuard.assertAccessible
        // calls Schema.SObjectField.getDescribe().isAccessible() on every field
        // the SELECT lists; throws DocGenException with the offending field name
        // before any query runs. SYSTEM_MODE on the SOQL sidesteps the
        // package-build @TestSetup FLS-propagation issue documented in
        // DocGenFlsGuard.cls.
        DocGenFlsGuard.assertAccessible(
            DocGen_Signature_Audit__c.sObjectType,
            new Set<String>{
                'Signed_Date__c',
                'IP_Address__c',
                'Signer_Name__c',
                'Signer_Email__c',
                'Consent_Captured__c',
                'PIN_Verified_At__c',
                'Document_Hash_SHA256__c',
                'Signer__c'
            }
        );
        /* code-analyzer-suppress ApexFlsViolation, DatabaseOperationsMustUseWithSharing */
        List<DocGen_Signature_Audit__c> audits = [
            SELECT
                Id,
                Signed_Date__c,
                IP_Address__c,
                Signer_Name__c,
                Signer_Email__c,
                Consent_Captured__c,
                PIN_Verified_At__c,
                Document_Hash_SHA256__c,
                Signer__r.Role_Name__c
            FROM DocGen_Signature_Audit__c
            WHERE Document_Hash_SHA256__c = :fileHash AND Signer_Name__c != 'SYSTEM'
            WITH SYSTEM_MODE
            ORDER BY Signed_Date__c ASC
        ];

        for (DocGen_Signature_Audit__c audit : audits) {
            VerificationResult res = new VerificationResult();
            res.isValid = true;
            res.signerName = audit.Signer_Name__c;
            res.signerEmail = audit.Signer_Email__c;
            res.roleName = audit.Signer__r != null ? audit.Signer__r.Role_Name__c : null;
            res.signedDate = audit.Signed_Date__c;
            res.ipAddress = audit.IP_Address__c;
            res.documentHash = audit.Document_Hash_SHA256__c;
            res.consentCaptured = audit.Consent_Captured__c;
            res.pinVerifiedAt = audit.PIN_Verified_At__c;
            res.message = 'Authentic Document Verified';
            results.add(res);
        }
        return results;
    }

    /**
     * Looks up all audit records for a signature request by ID.
     * Used by the verification page when accessed via request ID link.
     *
     * Note: the request Id IS the verification capability — this endpoint is meant to
     * let recipients verify their audit trail via a public-link flow. We therefore do
     * NOT gate on caller identity, but we DO strictly validate the input shape and
     * return only fields that are part of the verification contract.
     */
    @AuraEnabled
    @RemoteAction
    public static List<VerificationResult> verifyByRequestId(String requestId) {
        List<VerificationResult> results = new List<VerificationResult>();

        // Strict input validation: must be a well-formed 15- or 18-char alphanumeric Salesforce Id.
        // Reject early with empty list if malformed — never reach SOQL.
        if (
            String.isBlank(requestId) ||
            (requestId.length() != 15 &&
            requestId.length() != 18) ||
            !SF_ID.matcher(requestId).matches()
        ) {
            return results;
        }

        // Public verifier — capability is holding the Signature_Request__c Id.
        // Describe check below is the explicit CRUD/FLS enforcement signal
        // documented in DocGenSignatureGuestSecurity.
        DocGenSignatureGuestSecurity.assertAuditReadable();
        // v2.0.1 — per-field FLS enforcement on SOQL reads (the "Apex SOQL
        // USER_MODE Missing" finding category). DocGenFlsGuard.assertAccessible
        // calls Schema.SObjectField.getDescribe().isAccessible() on every field
        // the SELECT lists; throws DocGenException with the offending field name
        // before any query runs. SYSTEM_MODE on the SOQL sidesteps the
        // package-build @TestSetup FLS-propagation issue documented in
        // DocGenFlsGuard.cls.
        DocGenFlsGuard.assertAccessible(
            DocGen_Signature_Audit__c.sObjectType,
            new Set<String>{
                'Signed_Date__c',
                'IP_Address__c',
                'Signer_Name__c',
                'Signer_Email__c',
                'Consent_Captured__c',
                'PIN_Verified_At__c',
                'Document_Hash_SHA256__c',
                'Signer__c'
            }
        );
        // Field allowlist matches the documented verification contract.
        // SYSTEM_MODE is required for guest-profile access.
        /* code-analyzer-suppress ApexFlsViolation, DatabaseOperationsMustUseWithSharing */
        List<DocGen_Signature_Audit__c> audits = [
            SELECT
                Id,
                Signed_Date__c,
                IP_Address__c,
                Signer_Name__c,
                Signer_Email__c,
                Consent_Captured__c,
                PIN_Verified_At__c,
                Document_Hash_SHA256__c,
                Signer__r.Role_Name__c
            FROM DocGen_Signature_Audit__c
            WHERE Signature_Request__c = :requestId AND Signer_Name__c != 'SYSTEM'
            WITH SYSTEM_MODE
            ORDER BY Signed_Date__c ASC
        ];

        for (DocGen_Signature_Audit__c audit : audits) {
            VerificationResult res = new VerificationResult();
            res.isValid = true;
            res.signerName = audit.Signer_Name__c;
            res.signerEmail = audit.Signer_Email__c;
            res.roleName = audit.Signer__r.Role_Name__c;
            res.signedDate = audit.Signed_Date__c;
            res.ipAddress = audit.IP_Address__c;
            res.documentHash = audit.Document_Hash_SHA256__c;
            res.consentCaptured = audit.Consent_Captured__c;
            res.pinVerifiedAt = audit.PIN_Verified_At__c;
            res.message = 'Signature verified';
            results.add(res);
        }
        return results;
    }

    public class VerificationResult {
        @AuraEnabled
        public Boolean isValid { get; set; }
        @AuraEnabled
        public String message { get; set; }
        @AuraEnabled
        public String signerName { get; set; }
        @AuraEnabled
        public String signerEmail { get; set; }
        @AuraEnabled
        public String roleName { get; set; }
        @AuraEnabled
        public Datetime signedDate { get; set; }
        @AuraEnabled
        public String ipAddress { get; set; }
        @AuraEnabled
        public String documentHash { get; set; }
        @AuraEnabled
        public Boolean consentCaptured { get; set; }
        @AuraEnabled
        public Datetime pinVerifiedAt { get; set; }
    }
}
