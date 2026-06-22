import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplates from '@salesforce/apex/DocGenEmailTemplateController.getTemplates';
import saveTemplate from '@salesforce/apex/DocGenEmailTemplateController.saveTemplate';
import getDefault from '@salesforce/apex/DocGenEmailTemplateController.getDefault';
import renderPreview from '@salesforce/apex/DocGenEmailTemplateController.renderPreview';
import sendTest from '@salesforce/apex/DocGenEmailTemplateController.sendTest';

export default class DocGenEmailTemplates extends LightningElement {
    @track rows = [];
    @track selectedType;
    @track isLoading = true;

    // Working copy of the selected template (edited in place, saved on demand).
    @track recordId;
    @track name = '';
    @track subject = '';
    @track bodyHtml = '';
    @track bodyPlain = '';
    @track brandColor = '';
    @track logoUrl = '';
    @track footerText = '';
    @track isActive = true;
    @track tokens = [];

    @track testEmail = '';
    @track previewHtml = '';
    @track isSaving = false;
    @track isTesting = false;

    _previewDirty = false;

    connectedCallback() {
        this.loadTemplates();
    }

    async loadTemplates() {
        this.isLoading = true;
        try {
            this.rows = await getTemplates();
            if (this.rows.length) {
                const keep = this.rows.find((r) => r.type === this.selectedType) || this.rows[0];
                this.applyRow(keep);
            }
        } catch (error) {
            this.toast('Error loading templates', this.errMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    applyRow(row) {
        this.selectedType = row.type;
        this.recordId = row.recordId;
        this.name = row.name;
        this.subject = row.subject || '';
        this.bodyHtml = row.bodyHtml || '';
        this.bodyPlain = row.bodyPlain || '';
        this.brandColor = row.brandColor || '';
        this.logoUrl = row.logoUrl || '';
        this.footerText = row.footerText || '';
        this.isActive = row.isActive !== false;
        this.tokens = (row.tokens || []).map((t) => '{' + t + '}');
        this.refreshPreview();
    }

    get typeOptions() {
        return this.rows.map((r) => ({ label: r.typeLabel, value: r.type }));
    }

    get currentData() {
        return {
            type: this.selectedType,
            recordId: this.recordId,
            name: this.name,
            subject: this.subject,
            bodyHtml: this.bodyHtml,
            bodyPlain: this.bodyPlain,
            brandColor: this.brandColor,
            logoUrl: this.logoUrl,
            footerText: this.footerText,
            isActive: this.isActive
        };
    }

    get statusLabel() {
        return this.recordId ? 'Saved template' : 'Built-in default (not yet saved as a record)';
    }

    // ===== Field handlers =====
    handleTypeChange(event) {
        const row = this.rows.find((r) => r.type === event.detail.value);
        if (row) {
            this.applyRow(row);
        }
    }
    handleSubjectChange(event) {
        this.subject = event.target.value;
    }
    handleBodyChange(event) {
        this.bodyHtml = event.target.value;
    }
    handleBrandChange(event) {
        this.brandColor = event.target.value;
    }
    handleLogoChange(event) {
        this.logoUrl = event.target.value;
    }
    handleFooterChange(event) {
        this.footerText = event.target.value;
    }
    handleActiveChange(event) {
        this.isActive = event.target.checked;
    }
    handleTestEmailChange(event) {
        this.testEmail = event.target.value;
    }

    // ===== Actions =====
    async handleSave() {
        this.isSaving = true;
        try {
            const id = await saveTemplate({ data: this.currentData });
            this.recordId = id;
            this.toast('Saved', 'Email template saved.', 'success');
            await this.loadTemplates();
        } catch (error) {
            this.toast('Save failed', this.errMsg(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleReset() {
        try {
            const def = await getDefault({ type: this.selectedType });
            this.subject = def.subject || '';
            this.bodyHtml = def.bodyHtml || '';
            this.toast('Reset to default', 'Default content loaded — click Save to keep it.', 'info');
            this.refreshPreview();
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        }
    }

    async refreshPreview() {
        try {
            const r = await renderPreview({ data: this.currentData });
            this.previewHtml = r.htmlBody;
            this._previewDirty = true;
        } catch (error) {
            this.previewHtml =
                '<p style="color:#c23934;padding:16px;font-family:sans-serif;">Preview error: ' +
                this.errMsg(error) +
                '</p>';
            this._previewDirty = true;
        }
    }

    handleRefreshPreview() {
        this.refreshPreview();
    }

    async handleSendTest() {
        if (!this.testEmail) {
            this.toast('Enter an address', 'Type an email address to send the test to.', 'warning');
            return;
        }
        this.isTesting = true;
        try {
            await sendTest({ data: this.currentData, toAddress: this.testEmail });
            this.toast('Test sent', 'A test email was sent to ' + this.testEmail + '.', 'success');
        } catch (error) {
            this.toast('Test failed', this.errMsg(error), 'error');
        } finally {
            this.isTesting = false;
        }
    }

    renderedCallback() {
        if (this._previewDirty) {
            const frame = this.template.querySelector('iframe.preview-frame');
            if (frame) {
                frame.srcdoc = this.previewHtml;
                this._previewDirty = false;
            }
        }
    }

    // ===== Helpers =====
    errMsg(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return (error && error.message) || String(error);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
