import { LightningElement, track } from 'lwc';
import verifyDocument from '@salesforce/apex/DocGenAuthenticatorController.verifyDocument';
import verifyByRequestId from '@salesforce/apex/DocGenAuthenticatorController.verifyByRequestId';

export default class DocGenAuthenticator extends LightningElement {
    @track isProcessing = false;
    @track result;
    @track requestResults;
    @track hasRequestId = false;

    connectedCallback() {
        // Check URL for the verification token. The certificate link now carries
        // an unguessable 64-hex token (?token=) instead of the enumerable record
        // Id — see DocGenAuthenticatorController.verifyByRequestId.
        const params = new URLSearchParams(window.location.search);
        const token = params.get('token');
        // DOM XSS mitigation — validate the token is a 64-char hex string before use.
        if (token && /^[a-fA-F0-9]{64}$/.test(token)) {
            this.hasRequestId = true;
            this.loadRequestAudit(token);
        }
    }

    async loadRequestAudit(requestToken) {
        this.isProcessing = true;
        try {
            this.requestResults = await verifyByRequestId({ requestToken });
        } catch (error) {
            this.requestResults = [];
            this.result = {
                isValid: false,
                message: 'Could not load signature details: ' + (error.body ? error.body.message : error.message)
            };
        } finally {
            this.isProcessing = false;
        }
    }

    get hasResults() {
        return this.requestResults && this.requestResults.length > 0;
    }

    get resultContainerClass() {
        if (!this.result) return '';
        return this.result.isValid
            ? 'slds-box slds-theme_success slds-var-m-top_medium'
            : 'slds-box slds-theme_error slds-var-m-top_medium';
    }

    get resultIcon() {
        return this.result && this.result.isValid ? 'utility:success' : 'utility:error';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
    }

    handleDrop(event) {
        event.preventDefault();
        if (event.dataTransfer.files && event.dataTransfer.files.length > 0) {
            this.processFile(event.dataTransfer.files[0]);
        }
    }

    handleFileSelect(event) {
        if (event.target.files && event.target.files.length > 0) {
            this.processFile(event.target.files[0]);
        }
    }

    async processFile(file) {
        this.result = undefined;
        this.requestResults = undefined;
        this.isProcessing = true;

        try {
            const arrayBuffer = await file.arrayBuffer();
            const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');

            // verifyDocument now returns a list — one entry per signer of the
            // matched document (multi-signer docs share the same SHA-256 hash).
            const audits = await verifyDocument({ fileHash: hashHex });
            if (audits && audits.length > 0) {
                this.requestResults = audits;
            } else {
                this.result = {
                    isValid: false,
                    message:
                        'Document could not be verified. It may have been modified after signing or was not signed through this system.'
                };
            }
        } catch (error) {
            this.result = {
                isValid: false,
                message: 'Error processing file: ' + (error.body ? error.body.message : error.message)
            };
        } finally {
            this.isProcessing = false;
        }
    }
}
