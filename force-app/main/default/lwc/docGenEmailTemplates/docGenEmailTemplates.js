import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplates from '@salesforce/apex/DocGenEmailTemplateController.getTemplates';
import saveTemplate from '@salesforce/apex/DocGenEmailTemplateController.saveTemplate';
import getDefault from '@salesforce/apex/DocGenEmailTemplateController.getDefault';
import renderPreview from '@salesforce/apex/DocGenEmailTemplateController.renderPreview';
import sendTest from '@salesforce/apex/DocGenEmailTemplateController.sendTest';
import resolveAssetPublicUrl from '@salesforce/apex/DocGenEmailTemplateController.resolveAssetPublicUrl';
import getAssets from '@salesforce/apex/DocGenController.getAssets';

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
    @track layoutMode = 'Managed';
    @track isActive = true;
    @track tokens = [];

    @track testEmail = '';
    @track previewHtml = '';
    @track isSaving = false;
    @track isTesting = false;

    // "Override with Asset File" — Shared Asset images selectable as the logo.
    @track logoAssets = [];
    @track selectedLogoAssetId = '';

    _previewDirty = false;

    connectedCallback() {
        this.loadTemplates();
        this.loadLogoAssets();
    }

    async loadLogoAssets() {
        try {
            const assets = await getAssets();
            this.logoAssets = (assets || []).filter((a) => a.isActive && a.latestVersionCvId);
        } catch (_e) {
            this.logoAssets = []; // Assets tab optional — picker just disables
        }
    }

    get logoAssetOptions() {
        return this.logoAssets.map((a) => ({
            label: a.name + (a.category ? ' (' + a.category + ')' : ''),
            value: a.id
        }));
    }

    get logoAssetsUnavailable() {
        return this.logoAssets.length === 0;
    }

    async handleLogoAssetChange(event) {
        const assetId = event.detail.value;
        this.selectedLogoAssetId = assetId;
        if (!assetId) return;
        try {
            const url = await resolveAssetPublicUrl({ assetId });
            this.logoUrl = url;
            this._previewDirty = true;
            this.toast(
                'Logo set from Asset',
                'A public file link was created and filled into Logo URL Override. Save to apply.',
                'success'
            );
            this.refreshPreview();
        } catch (error) {
            this.selectedLogoAssetId = '';
            this.toast('Could not use this asset', this.errMsg(error), 'error');
        }
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
        this.layoutMode = row.layoutMode || 'Managed';
        this.isActive = row.isActive !== false;
        this.tokens = (row.tokens || []).map((t) => '{' + t + '}');
        this.selectedLogoAssetId = ''; // picker is a one-shot fill, not stored state
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
            layoutMode: this.layoutMode,
            isActive: this.isActive
        };
    }

    get statusLabel() {
        return this.recordId ? 'Saved template' : 'Built-in default (not yet saved as a record)';
    }

    get layoutModeOptions() {
        return [
            { label: 'DocGen layout — edit body, branded chrome', value: 'Managed' },
            { label: 'Full custom HTML — your entire document', value: 'Full_Html' }
        ];
    }

    get isFullHtml() {
        return this.layoutMode === 'Full_Html';
    }

    get isManaged() {
        return this.layoutMode !== 'Full_Html';
    }

    handleLayoutModeChange(event) {
        this.layoutMode = event.detail.value;
        this.refreshPreview();
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
        this.selectedLogoAssetId = ''; // manual edit supersedes the asset pick
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
        } catch (error) {
            this.previewHtml =
                '<p style="color:#c23934;padding:16px;font-family:sans-serif;">Preview error: ' +
                this.errMsg(error) +
                '</p>';
        }
        // previewHtml is not bound in the template, so setting it does not
        // re-render — push it into the iframe imperatively. The frame already
        // exists (refreshPreview runs after first render); renderedCallback is
        // the backstop for the first paint if it doesn't yet.
        this._previewDirty = true;
        this.updatePreviewFrame();
    }

    updatePreviewFrame() {
        const surface = this.template.querySelector('.preview-surface');
        if (surface && this._previewDirty) {
            // Render the email markup directly (not an iframe — Salesforce CSP
            // blocks iframe srcdoc/data: frames). lwc:dom="manual" lets us set
            // innerHTML; LWS sanitizes it (our content is style-only, no script).
            // The <!DOCTYPE>/<html>/<body> wrappers are dropped by the parser;
            // the inline-styled tables that carry the branding survive.
            // Justified suppression: the preview renders ONLY admin-authored
            // (FLS-gated) template HTML through the lwc:dom="manual" escape hatch,
            // Lightning Web Security strips scripts/event handlers, and there is no
            // LWC-native way to render arbitrary table+inline-style markup otherwise.
            // See code-analyzer.yml + DocGen_False_Positive_Report.md.
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            surface.innerHTML = this.previewHtml || '';
            this._previewDirty = false;
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
        // Backstop for the first paint: if the preview resolved before the
        // iframe existed, push it now that the frame is in the DOM.
        this.updatePreviewFrame();
    }

    // ===== Helpers =====
    errMsg(error) {
        const body = error && error.body;
        if (Array.isArray(body) && body[0] && typeof body[0].message === 'string') {
            return body[0].message;
        }
        if (body && typeof body.message === 'string' && body.message) {
            return body.message;
        }
        if (body && body.pageErrors && body.pageErrors[0] && body.pageErrors[0].message) {
            return String(body.pageErrors[0].message);
        }
        if (error && typeof error.message === 'string' && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
