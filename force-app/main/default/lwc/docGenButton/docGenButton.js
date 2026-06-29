import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getButtons from '@salesforce/apex/DocGenButtonController.getButtons';
import generate from '@salesforce/apex/DocGenButtonController.generate';

/**
 * docGenButton
 * ------------
 * Screen quick action that generates a DocGen document from a pre-configured
 * template (DocGen_Button__mdt) and downloads it. When exactly one configuration
 * exists for the object it runs immediately; when several exist it shows a small
 * picker. No DocGen Runner, no field choices.
 */
export default class DocGenButton extends LightningElement {
    _recordId;
    _started = false;
    _waitTimer;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.maybeStart();
    }

    @api objectApiName; // provided by the record action; not used (object is derived from recordId server-side)

    loading = true;
    statusMessage = 'Preparing…';
    errorMessage;
    options = [];
    showPicker = false;

    connectedCallback() {
        this.maybeStart();
        // Fallback: if recordId never arrives, don't spin forever.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._waitTimer = setTimeout(() => {
            if (!this._started) {
                this.fail('Could not determine the record. Please reopen the record and try again.');
            }
        }, 4000);
    }

    disconnectedCallback() {
        if (this._waitTimer) {
            clearTimeout(this._waitTimer);
        }
    }

    /** Runs the flow exactly once, and only after recordId has been injected. */
    maybeStart() {
        if (this._started || !this._recordId) {
            return;
        }
        this._started = true;
        if (this._waitTimer) {
            clearTimeout(this._waitTimer);
        }
        this.init();
    }

    async init() {
        try {
            const opts = await getButtons({ recordId: this.recordId });
            if (!opts || opts.length === 0) {
                this.fail('No DocGen document is configured for this record type.');
                return;
            }
            if (opts.length === 1) {
                this.run(opts[0].developerName);
            } else {
                this.options = opts;
                this.showPicker = true;
                this.loading = false;
            }
        } catch (e) {
            this.fail(this.toMessage(e));
        }
    }

    handlePick(event) {
        const developerName = event.currentTarget.dataset.name;
        this.showPicker = false;
        this.loading = true;
        this.run(developerName);
    }

    async run(configDeveloperName) {
        this.loading = true;
        this.statusMessage = 'Generating document…';
        try {
            const res = await generate({
                recordId: this.recordId,
                configDeveloperName
            });
            if (!res || !res.success) {
                this.fail((res && res.errorMessage) || 'Document generation failed.');
                return;
            }
            this.deliver(res);
            this.showToast('Document generated', `${res.fileName} is downloading.`, 'success');
            this.close();
        } catch (e) {
            this.fail(this.toMessage(e));
        }
    }

    deliver(res) {
        let href;
        let revoke = false;
        // LWS sanitizes URL.createObjectURL against a MIME allowlist (PDF, images,
        // plain text). Office formats (.docx/.pptx/.xlsx) are rejected, so use the
        // servlet download URL for anything not on the allowlist.
        if (res.base64Data && this.isBlobSafeMime(res.mimeType)) {
            const blob = this.base64ToBlob(res.base64Data, res.mimeType);
            href = URL.createObjectURL(blob);
            revoke = true;
        } else if (res.downloadUrl) {
            href = res.downloadUrl;
        } else if (res.base64Data) {
            const blob = this.base64ToBlob(res.base64Data, res.mimeType);
            href = URL.createObjectURL(blob);
            revoke = true;
        } else {
            return;
        }
        const anchor = document.createElement('a');
        anchor.href = href;
        anchor.download = res.fileName || 'document';
        anchor.target = '_blank';
        document.body.appendChild(anchor);
        anchor.click();
        document.body.removeChild(anchor);
        if (revoke) {
            // Give the browser a moment to start the download before releasing the URL.
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => URL.revokeObjectURL(href), 4000);
        }
    }

    isBlobSafeMime(mimeType) {
        if (!mimeType) {
            return false;
        }
        return (
            mimeType === 'application/pdf' ||
            mimeType.startsWith('image/') ||
            mimeType === 'text/plain'
        );
    }

    base64ToBlob(base64, mimeType) {
        const binary = atob(base64);
        const length = binary.length;
        const bytes = new Uint8Array(length);
        for (let i = 0; i < length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return new Blob([bytes], { type: mimeType || 'application/octet-stream' });
    }

    fail(message) {
        this.loading = false;
        this.showPicker = false;
        this.errorMessage = message;
        this.showToast('Could not generate document', message, 'error');
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleClose() {
        this.close();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    toMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unexpected error.';
    }
}
