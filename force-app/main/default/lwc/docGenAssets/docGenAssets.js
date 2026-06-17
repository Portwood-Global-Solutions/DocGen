import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Apex — Workstream A (DocGenController) builds these in parallel.
// Imported against the exact names/signatures in the approved plan (#185 A6).
import getAssets from '@salesforce/apex/DocGenController.getAssets';
import createAsset from '@salesforce/apex/DocGenController.createAsset';
import checkAssetKey from '@salesforce/apex/DocGenController.checkAssetKey';
import addAssetVersion from '@salesforce/apex/DocGenController.addAssetVersion';
import renameAsset from '@salesforce/apex/DocGenController.renameAsset';
import deactivateAsset from '@salesforce/apex/DocGenController.deactivateAsset';
import getLatestContentVersionId from '@salesforce/apex/DocGenController.getLatestContentVersionId';

// Client-side mirror of DocGenAssetKeyHandler.normalizeKey for the live tag
// preview + name->key suggestion. The server is authoritative; this only avoids
// a round-trip on every keystroke.
function slugify(value) {
    if (!value) {
        return '';
    }
    return value
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 40)
        .replace(/-+$/g, '');
}

const COLUMNS = [
    { label: 'Name', fieldName: 'name' },
    {
        label: 'Merge Tag',
        fieldName: 'mergeTag',
        cellAttributes: {
            iconName: 'utility:copy',
            iconPosition: 'right',
            iconAlternativeText: 'Copy merge tag'
        }
    },
    {
        label: 'Copy',
        type: 'button-icon',
        initialWidth: 70,
        cellAttributes: { alignment: 'center' },
        typeAttributes: {
            iconName: 'utility:copy_to_clipboard',
            name: 'copyTag',
            title: 'Copy merge tag',
            variant: 'border-filled',
            alternativeText: 'Copy merge tag'
        }
    },
    {
        label: 'Thumbnail',
        fieldName: 'thumbnailUrl',
        type: 'image',
        initialWidth: 120,
        typeAttributes: { alt: { fieldName: 'name' }, height: 48 }
    },
    { label: 'Version #', fieldName: 'versionNumber', type: 'number', initialWidth: 100 },
    {
        label: 'Last Updated',
        fieldName: 'lastModified',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'numeric',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Upload New Version', name: 'uploadVersion' },
                { label: 'Rename', name: 'rename' },
                { label: 'Preview', name: 'preview' },
                { label: 'Deactivate', name: 'deactivate' }
            ]
        }
    }
];

// Image MIME types accepted for asset uploads (v1 = images only).
const ACCEPTED_FORMATS = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp'];

export default class DocGenAssets extends LightningElement {
    @track assets = [];
    columns = COLUMNS;
    acceptedFormats = ACCEPTED_FORMATS;
    wiredAssetsResult;

    // Create modal state
    @track isCreateModalOpen = false;
    @track createName = '';
    @track createKey = '';
    @track createdAssetId = null;
    @track isUploading = false;
    // Live key validation
    @track keyNormalized = '';
    @track keyValid = false;
    @track keyAvailable = false;
    @track keyMessage = '';
    keyEdited = false;
    _keyCheckTimer;

    // Upload-new-version modal state
    @track isVersionModalOpen = false;
    @track versionAssetId = null;
    @track versionAssetName = '';

    // Rename modal state
    @track isRenameModalOpen = false;
    @track renameAssetId = null;
    @track renameValue = '';

    @wire(getAssets)
    wiredAssets(result) {
        this.wiredAssetsResult = result;
        if (result.data) {
            this.assets = result.data.map((row) => this.decorateRow(row));
        } else if (result.error) {
            this.showToast('Error loading assets', this.errMsg(result.error), 'error');
        }
    }

    // Build display-derived fields the datatable binds to. getAssets() returns
    // camelCase row keys (id, name, assetKey, assetType, isActive, mergeTag,
    // latestVersionCvId, versionNumber, lastModified). mergeTag is precomputed
    // server-side; thumbnailUrl is derived from the latest-version CV Id.
    decorateRow(row) {
        const key = row.assetKey || '';
        return {
            ...row,
            mergeTag: row.mergeTag || '{%asset:' + key + '}',
            thumbnailUrl: row.latestVersionCvId
                ? '/sfc/servlet.shepherd/version/download/' + row.latestVersionCvId
                : null
        };
    }

    get hasAssets() {
        return this.assets && this.assets.length > 0;
    }

    get isCreateDisabled() {
        return !this.createName || !this.createName.trim() || !this.keyValid || !this.keyAvailable || this.isUploading;
    }

    // Live preview of the merge tag the author will paste into a template.
    get createTagPreview() {
        return this.keyNormalized ? '{%asset:' + this.keyNormalized + '}' : '{%asset:…}';
    }

    get keyHintClass() {
        if (!this.createKey) {
            return 'slds-text-body_small slds-text-color_weak';
        }
        return this.keyValid && this.keyAvailable
            ? 'slds-text-body_small slds-text-color_success'
            : 'slds-text-body_small slds-text-color_error';
    }

    get isRenameDisabled() {
        return !this.renameValue || !this.renameValue.trim();
    }

    // ===== Datatable interactions =====

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'copyTag') {
            await this.copyTag(row.mergeTag);
        } else if (actionName === 'uploadVersion') {
            this.versionAssetId = row.id;
            this.versionAssetName = row.name;
            this.isVersionModalOpen = true;
        } else if (actionName === 'rename') {
            this.renameAssetId = row.id;
            this.renameValue = row.name;
            this.isRenameModalOpen = true;
        } else if (actionName === 'preview') {
            if (row.thumbnailUrl) {
                window.open(row.thumbnailUrl, '_blank');
            } else {
                this.showToast('No image', 'This asset has no uploaded version to preview yet.', 'warning');
            }
        } else if (actionName === 'deactivate') {
            await this.handleDeactivate(row);
        }
    }

    async copyTag(tag) {
        if (!tag) {
            return;
        }
        try {
            await this._copyToClipboard(tag);
            this.showToast('Copied', tag, 'success');
        } catch {
            this.showToast('Copy Failed', 'Unable to copy to clipboard.', 'error');
        }
    }

    _copyToClipboard(text) {
        if (navigator.clipboard) {
            return navigator.clipboard.writeText(text);
        }
        return Promise.reject(new Error('Clipboard unavailable'));
    }

    // ===== Create asset =====

    handleOpenCreate() {
        this.createName = '';
        this.createKey = '';
        this.createdAssetId = null;
        this.isUploading = false;
        this.keyEdited = false;
        this.keyNormalized = '';
        this.keyValid = false;
        this.keyAvailable = false;
        this.keyMessage = '';
        this.isCreateModalOpen = true;
    }

    handleCloseCreate() {
        this.isCreateModalOpen = false;
    }

    handleCreateNameChange(event) {
        this.createName = event.target.value;
        // Suggest a key from the name until the user hand-edits the key field.
        if (!this.keyEdited) {
            this.createKey = slugify(this.createName);
            this.scheduleKeyCheck();
        }
    }

    handleCreateKeyChange(event) {
        this.keyEdited = true;
        this.createKey = event.target.value;
        this.scheduleKeyCheck();
    }

    // Debounced server check so the user sees the final slug + availability live.
    scheduleKeyCheck() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        clearTimeout(this._keyCheckTimer);
        const raw = this.createKey;
        if (!slugify(raw)) {
            this.keyNormalized = '';
            this.keyValid = false;
            this.keyAvailable = false;
            this.keyMessage = raw ? 'Use letters or numbers.' : '';
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._keyCheckTimer = setTimeout(() => {
            checkAssetKey({ assetKey: raw })
                .then((res) => {
                    // Ignore a stale response if the field changed meanwhile.
                    if (this.createKey !== raw) {
                        return;
                    }
                    this.keyNormalized = res.normalized;
                    this.keyValid = res.valid;
                    this.keyAvailable = res.available;
                    this.keyMessage = res.available
                        ? 'Available — your tag will be ' + res.mergeTag
                        : 'That key is already in use.';
                })
                .catch((error) => {
                    this.keyValid = false;
                    this.keyAvailable = false;
                    this.keyMessage = this.errMsg(error);
                });
        }, 300);
    }

    // Step 1: create the asset record so the upload has a record to attach to.
    async handleCreateAsset() {
        if (this.isCreateDisabled) {
            return;
        }
        this.isUploading = true;
        try {
            const asset = await createAsset({ name: this.createName.trim(), assetKey: this.createKey });
            // createAsset returns a map { id, name, assetKey, mergeTag }.
            this.createdAssetId = asset && asset.id ? asset.id : asset;
            this.showToast('Asset created', 'Now upload an image for "' + this.createName.trim() + '".', 'success');
            await refreshApex(this.wiredAssetsResult);
        } catch (error) {
            this.showToast('Error creating asset', this.errMsg(error), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    // Step 2 (create flow): file uploaded against the new asset record.
    async handleCreateUploadFinished(event) {
        await this.processUpload(event, this.createdAssetId, () => {
            this.isCreateModalOpen = false;
        });
    }

    // ===== Upload new version =====

    handleCloseVersion() {
        this.isVersionModalOpen = false;
    }

    async handleVersionUploadFinished(event) {
        await this.processUpload(event, this.versionAssetId, () => {
            this.isVersionModalOpen = false;
        });
    }

    // Shared upload handler: resolve the ContentVersion Id then link it to the
    // asset via addAssetVersion. Mirrors docGenAdmin.handleEditUploadFinished
    // (contentVersionId -> getLatestContentVersionId fallback).
    async processUpload(event, assetId, onDone) {
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }
        if (!assetId) {
            this.showToast('Error', 'No asset selected for this upload.', 'error');
            return;
        }
        const file = uploadedFiles[0];
        let contentVersionId;
        try {
            contentVersionId = file.contentVersionId;
            if (!contentVersionId && file.documentId) {
                contentVersionId = await getLatestContentVersionId({
                    contentDocumentId: file.documentId
                });
            }
            if (!contentVersionId || !String(contentVersionId).startsWith('068')) {
                throw new Error('Uploaded file version could not be resolved.');
            }
        } catch (error) {
            this.showToast('Upload failed', this.errMsg(error), 'error');
            return;
        }

        try {
            await addAssetVersion({ assetId: assetId, contentVersionId: contentVersionId });
            this.showToast('Success', 'New version uploaded: ' + file.name, 'success');
            if (onDone) {
                onDone();
            }
            await refreshApex(this.wiredAssetsResult);
        } catch (error) {
            this.showToast('Error saving version', this.errMsg(error), 'error');
        }
    }

    // ===== Rename =====

    handleCloseRename() {
        this.isRenameModalOpen = false;
    }

    handleRenameChange(event) {
        this.renameValue = event.target.value;
    }

    async handleRenameSave() {
        if (this.isRenameDisabled) {
            return;
        }
        try {
            await renameAsset({ assetId: this.renameAssetId, newName: this.renameValue.trim() });
            this.showToast('Renamed', 'Asset renamed to "' + this.renameValue.trim() + '".', 'success');
            this.isRenameModalOpen = false;
            await refreshApex(this.wiredAssetsResult);
        } catch (error) {
            this.showToast('Error renaming asset', this.errMsg(error), 'error');
        }
    }

    // ===== Deactivate =====

    async handleDeactivate(row) {
        try {
            await deactivateAsset({ assetId: row.id });
            this.showToast('Deactivated', '"' + row.name + '" is no longer active.', 'success');
            await refreshApex(this.wiredAssetsResult);
        } catch (error) {
            this.showToast('Error deactivating asset', this.errMsg(error), 'error');
        }
    }

    // ===== Helpers =====

    errMsg(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return (error && error.message) || String(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
