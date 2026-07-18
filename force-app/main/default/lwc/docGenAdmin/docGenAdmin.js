import { LightningElement, track, wire } from 'lwc';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { downloadBase64 as downloadBase64Util, parseSOQLFields, stripOuterSelectFrom } from 'c/docGenUtils';
// HTML-first authoring: starter designs, AI prompt builder, query-shape extractor
import {
    STARTERS,
    extractQueryShape,
    buildStarterHtml,
    buildAiPrompt,
    prettyPrintHtml,
    scopeHtmlForInlinePreview,
    buildTagPalette,
    buildBlockPalette
} from './docGenAuthoringKit';

// Each predesigned starter carries its natural object — the wizard's starter
// path never asks for one (Advanced options exposes the picker for overrides).
const STARTER_OBJECTS = {
    report: 'Account',
    invoice: 'Opportunity',
    letter: 'Contact',
    agreement: 'Account'
};

// Flexipage-style section presets — equal-width columns, Flying Saucer safe
// (display:table/table-cell, never flex/grid).
const SECTION_COLUMN_PRESETS = [2, 3, 4, 6, 12];
function columnsSectionSnippet(n) {
    let cells = '';
    for (let i = 0; i < n; i++) {
        cells +=
            '<div style="display: table-cell; vertical-align: top; padding: 0 5pt"><p>Column ' + (i + 1) + '</p></div>';
    }
    return '\n<div style="display: table; width: 100%; table-layout: fixed; margin: 8pt 0">' + cells + '</div>\n';
}

// Apex
import getAllTemplates from '@salesforce/apex/DocGenController.getAllTemplates';
import deleteTemplate from '@salesforce/apex/DocGenController.deleteTemplate';
import saveTemplate from '@salesforce/apex/DocGenController.saveTemplate';
import generateDocumentData from '@salesforce/apex/DocGenController.generateDocumentData';
import getTemplateVersions from '@salesforce/apex/DocGenController.getTemplateVersions';
import getVersionBodyFileInfo from '@salesforce/apex/DocGenController.getVersionBodyFileInfo';
import deleteTemplateVersion from '@salesforce/apex/DocGenController.deleteTemplateVersion';
import generateDocumentParts from '@salesforce/apex/DocGenController.generateDocumentParts';
import getContentVersionBase64 from '@salesforce/apex/DocGenController.getContentVersionBase64';
import getLatestContentVersionId from '@salesforce/apex/DocGenController.getLatestContentVersionId';
import generatePdf from '@salesforce/apex/DocGenController.generatePdf';
import previewDraftPdf from '@salesforce/apex/DocGenController.previewDraftPdf';
import generatePdfAsync from '@salesforce/apex/DocGenController.generatePdfAsync';
import getPdfSampleGenerationStatus from '@salesforce/apex/DocGenController.getPdfSampleGenerationStatus';
import prepareChartImages from '@salesforce/apex/DocGenChartImageController.prepareChartImages';
import uploadChartImage from '@salesforce/apex/DocGenChartImageController.uploadChartImage';
import deleteChartImages from '@salesforce/apex/DocGenChartImageController.deleteChartImages';
import activateVersion from '@salesforce/apex/DocGenController.activateVersion';
import createSampleTemplates from '@salesforce/apex/DocGenController.createSampleTemplates';
import exportTemplate from '@salesforce/apex/DocGenController.exportTemplate';
import importTemplate from '@salesforce/apex/DocGenController.importTemplate';
import cloneTemplate from '@salesforce/apex/DocGenController.cloneTemplate';
import getObjectFields from '@salesforce/apex/DocGenController.getObjectFields';
// #161 — updateable-only field list for writeback-target dropdowns (Signer Inputs tab).
// New Apex method (backend agent); if not yet deployed, QA deploys — import/usage is wired here.
import getUpdateableObjectFields from '@salesforce/apex/DocGenController.getUpdateableObjectFields';
import getObjectOptions from '@salesforce/apex/DocGenController.getObjectOptions';
import getChildRelationships from '@salesforce/apex/DocGenController.getChildRelationships';
import getParentRelationships from '@salesforce/apex/DocGenController.getParentRelationships';
import previewRecordData from '@salesforce/apex/DocGenController.previewRecordData';
import saveWatermarkImage from '@salesforce/apex/DocGenController.saveWatermarkImage';
import clearWatermarkImage from '@salesforce/apex/DocGenController.clearWatermarkImage';
import searchDataProviders from '@salesforce/apex/DocGenController.searchDataProviders';
import getHtmlTemplateBody from '@salesforce/apex/DocGenController.getHtmlTemplateBody';
import getConvertedHtmlSnapshot from '@salesforce/apex/DocGenController.getConvertedHtmlSnapshot';
import listHtmlTemplateImages from '@salesforce/apex/DocGenController.listHtmlTemplateImages';
import getAssets from '@salesforce/apex/DocGenController.getAssets';
import createAsset from '@salesforce/apex/DocGenController.createAsset';
import addAssetVersion from '@salesforce/apex/DocGenController.addAssetVersion';
import validateDataProvider from '@salesforce/apex/DocGenController.validateDataProvider';

// Schema
import DOCGEN_TEMPLATE_OBJECT from '@salesforce/schema/DocGen_Template__c';
import NAME_FIELD from '@salesforce/schema/DocGen_Template__c.Name';
import CATEGORY_FIELD from '@salesforce/schema/DocGen_Template__c.Category__c';
import TYPE_FIELD from '@salesforce/schema/DocGen_Template__c.Type__c';
import BASE_OBJECT_FIELD from '@salesforce/schema/DocGen_Template__c.Base_Object_API__c';
import QUERY_CONFIG_FIELD from '@salesforce/schema/DocGen_Template__c.Query_Config__c';
import DESC_FIELD from '@salesforce/schema/DocGen_Template__c.Description__c';
import OUTPUT_FORMAT_FIELD from '@salesforce/schema/DocGen_Template__c.Output_Format__c';
import TEST_RECORD_FIELD from '@salesforce/schema/DocGen_Template__c.Test_Record_Id__c';
import DOC_TITLE_FIELD from '@salesforce/schema/DocGen_Template__c.Document_Title_Format__c';
import IS_ACTIVE_FIELD from '@salesforce/schema/DocGen_Template__c.Is_Active__c';
import IS_DEFAULT_FIELD from '@salesforce/schema/DocGen_Template__c.Is_Default__c';
// 1.47 — runner visibility & sort
import SORT_ORDER_FIELD from '@salesforce/schema/DocGen_Template__c.Sort_Order__c';
import LOCK_OUTPUT_FORMAT_FIELD from '@salesforce/schema/DocGen_Template__c.Lock_Output_Format__c';
import SPECIFIC_RECORD_IDS_FIELD from '@salesforce/schema/DocGen_Template__c.Specific_Record_Ids__c';
import REQUIRED_PERM_SETS_FIELD from '@salesforce/schema/DocGen_Template__c.Required_Permission_Sets__c';
import RECORD_FILTER_FIELD from '@salesforce/schema/DocGen_Template__c.Record_Filter__c';
// 1.61 — HTML template type: header/footer fields
import HEADER_HTML_FIELD from '@salesforce/schema/DocGen_Template__c.Header_Html__c';
import FOOTER_HTML_FIELD from '@salesforce/schema/DocGen_Template__c.Footer_Html__c';
// 1.68 — page orientation (Portrait | Landscape) + size + margins for PDF rendering
import PAGE_ORIENTATION_FIELD from '@salesforce/schema/DocGen_Template__c.Page_Orientation__c';
import PAGE_SIZE_FIELD from '@salesforce/schema/DocGen_Template__c.Page_Size__c';
import PAGE_MARGINS_FIELD from '@salesforce/schema/DocGen_Template__c.Page_Margins__c';
import CUSTOM_MARGINS_FIELD from '@salesforce/schema/DocGen_Template__c.Custom_Margins__c';
// #verification — template-level signer-verification defaults
import SIGNER_VERIFICATION_FIELD from '@salesforce/schema/DocGen_Template__c.Signer_Verification__c';
import PREFILL_SIGNER_EMAIL_FIELD from '@salesforce/schema/DocGen_Template__c.Prefill_Signer_Email__c';
import testRecordFilter from '@salesforce/apex/DocGenController.testRecordFilter';
// 1.61 — HTML zip sidesteps File Upload Security via client-side unzip + per-part upload
import saveHtmlTemplateImage from '@salesforce/apex/DocGenController.saveHtmlTemplateImage';
import saveHtmlTemplateBody from '@salesforce/apex/DocGenController.saveHtmlTemplateBody';
import savePdfAcroFormPreparedBodyChunk from '@salesforce/apex/DocGenController.savePdfAcroFormPreparedBodyChunk';
import finalizePdfAcroFormPreparedBody from '@salesforce/apex/DocGenController.finalizePdfAcroFormPreparedBody';
import getPdfAcroFormPreparedBodyStatus from '@salesforce/apex/DocGenController.getPdfAcroFormPreparedBodyStatus';
import savePdfAcroFormSnapshot from '@salesforce/apex/DocGenController.savePdfAcroFormSnapshot';
import getActivePdfAcroFormSnapshot from '@salesforce/apex/DocGenController.getActivePdfAcroFormSnapshot';
// 1.74 — guard rail for the async-decompose Queueable's 12 MB heap budget
import getContentVersionSize from '@salesforce/apex/DocGenController.getContentVersionSize';
import deleteContentVersionDocument from '@salesforce/apex/DocGenController.deleteContentVersionDocument';
import renderImageAsPdfBase64 from '@salesforce/apex/DocGenController.renderImageAsPdfBase64';
import { readZip, bytesToBase64 } from './docGenZipReader';
import { buildDocx } from './docGenZipWriter';
import { extractFirstImageFromPdfBase64 } from './docGenPdfImageExtractor';
import { decomposePdfAcroFormBase64 } from './docGenPdfAcroFormDecomposer';
// Version fields (DocGen_Template_Version__c)
import VER_IS_ACTIVE_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Is_Active__c';
import VER_CV_ID_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Content_Version_Id__c';
import VER_WATERMARK_CV_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Watermark_Image_CV_Id__c';
// 1.68 — orientation + size + margins snapshot on the version
import VER_PAGE_ORIENTATION_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Page_Orientation__c';
import VER_PAGE_SIZE_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Page_Size__c';
import VER_PAGE_MARGINS_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Page_Margins__c';
import VER_CUSTOM_MARGINS_FIELD from '@salesforce/schema/DocGen_Template_Version__c.Custom_Margins__c';

// Field API name map — resolves namespace automatically
const F = {
    Name: 'Name',
    Category: CATEGORY_FIELD.fieldApiName,
    Type: TYPE_FIELD.fieldApiName,
    OutputFormat: OUTPUT_FORMAT_FIELD.fieldApiName,
    BaseObject: BASE_OBJECT_FIELD.fieldApiName,
    QueryConfig: QUERY_CONFIG_FIELD.fieldApiName,
    // #161 follow-up — dedicated storage for Signer Inputs form-field config.
    // The field has no @salesforce/schema import yet (backend ships it in
    // parallel), so resolve its namespace from an already-resolved field's
    // prefix (e.g. `portwoodglobal__` in subscriber orgs, '' in staging).
    FormFieldsConfig:
        QUERY_CONFIG_FIELD.fieldApiName.slice(0, QUERY_CONFIG_FIELD.fieldApiName.length - 'Query_Config__c'.length) +
        'Form_Fields_Config__c',
    Desc: DESC_FIELD.fieldApiName,
    TestRecordId: TEST_RECORD_FIELD.fieldApiName,
    DocTitleFormat: DOC_TITLE_FIELD.fieldApiName,
    IsActive: IS_ACTIVE_FIELD.fieldApiName,
    IsDefault: IS_DEFAULT_FIELD.fieldApiName,
    // 1.47 — runner visibility & sort
    SortOrder: SORT_ORDER_FIELD.fieldApiName,
    LockOutputFormat: LOCK_OUTPUT_FORMAT_FIELD.fieldApiName,
    SpecificRecordIds: SPECIFIC_RECORD_IDS_FIELD.fieldApiName,
    RequiredPermSets: REQUIRED_PERM_SETS_FIELD.fieldApiName,
    RecordFilter: RECORD_FILTER_FIELD.fieldApiName,
    // 1.61 — HTML header/footer
    HeaderHtml: HEADER_HTML_FIELD.fieldApiName,
    FooterHtml: FOOTER_HTML_FIELD.fieldApiName,
    // 1.68 — page orientation + size + margins
    PageOrientation: PAGE_ORIENTATION_FIELD.fieldApiName,
    PageSize: PAGE_SIZE_FIELD.fieldApiName,
    PageMargins: PAGE_MARGINS_FIELD.fieldApiName,
    CustomMargins: CUSTOM_MARGINS_FIELD.fieldApiName,
    // #verification — template-level defaults
    SignerVerification: SIGNER_VERIFICATION_FIELD.fieldApiName,
    PrefillSignerEmail: PREFILL_SIGNER_EMAIL_FIELD.fieldApiName,
    // PHD-9 — stable developer key for Flow lookups; namespace resolved from an
    // already-imported field (same pattern as FormFieldsConfig).
    ApiName:
        QUERY_CONFIG_FIELD.fieldApiName.slice(0, QUERY_CONFIG_FIELD.fieldApiName.length - 'Query_Config__c'.length) +
        'API_Name__c',
    // #208 — per-template default {Message} for signature emails; namespace
    // resolved from an already-imported field (same pattern as FormFieldsConfig).
    DefaultEmailMessage:
        QUERY_CONFIG_FIELD.fieldApiName.slice(0, QUERY_CONFIG_FIELD.fieldApiName.length - 'Query_Config__c'.length) +
        'Default_Email_Message__c',
    // Version fields
    VerIsActive: VER_IS_ACTIVE_FIELD.fieldApiName,
    VerCvId: VER_CV_ID_FIELD.fieldApiName,
    VerWatermarkCv: VER_WATERMARK_CV_FIELD.fieldApiName,
    VerPageOrientation: VER_PAGE_ORIENTATION_FIELD.fieldApiName,
    VerPageSize: VER_PAGE_SIZE_FIELD.fieldApiName,
    VerPageMargins: VER_PAGE_MARGINS_FIELD.fieldApiName,
    VerCustomMargins: VER_CUSTOM_MARGINS_FIELD.fieldApiName
};

const COLUMNS = [
    { label: 'Category', fieldName: F.Category, initialWidth: 150 },
    { label: 'Name', fieldName: 'Name' },
    { label: 'Type', fieldName: F.Type, initialWidth: 100 },
    { label: 'Output Format', fieldName: F.OutputFormat, initialWidth: 120 },
    { label: 'Base Object', fieldName: 'displayBaseObject' },
    {
        label: 'Status',
        fieldName: 'activeLabel',
        initialWidth: 90,
        cellAttributes: { class: { fieldName: 'activeClass' } }
    },
    {
        label: 'Default',
        fieldName: 'defaultLabel',
        initialWidth: 80,
        cellAttributes: { class: { fieldName: 'defaultClass' } }
    },
    { label: 'Description', fieldName: F.Desc },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View', name: 'view' },
                { label: 'Edit', name: 'edit' },
                { label: 'Design', name: 'design' },
                { label: 'Clone', name: 'clone' },
                { label: 'Export', name: 'export' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

const VERSION_COLUMNS = [
    { label: 'Version', fieldName: 'VersionNumber' },
    {
        label: 'Active',
        fieldName: 'isActiveLabel',
        cellAttributes: {
            class: { fieldName: 'activeClass' }
        }
    },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'numeric',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { label: 'Created By', fieldName: 'CreatedByName' },
    // Body file the version points at — surfaces which underlying ContentVersion
    // generation actually reads (diagnostic for stale/mismatched template bodies).
    // The same CV Id across rows = a metadata-only save reused the prior body.
    { label: 'File CV Id', fieldName: 'bodyCvId' },
    { label: 'File Name', fieldName: 'bodyCvFileName' },
    // Action buttons: uniform fixed width + centered so they line up at the right.
    {
        type: 'button',
        initialWidth: 130,
        cellAttributes: { alignment: 'center' },
        typeAttributes: {
            label: 'Preview',
            name: 'preview',
            variant: 'neutral',
            iconName: 'utility:preview'
        }
    },
    {
        type: 'button',
        initialWidth: 130,
        cellAttributes: { alignment: 'center' },
        typeAttributes: {
            label: 'Activate',
            name: 'restore',
            title: 'Restore and Activate this version',
            variant: 'brand',
            disabled: { fieldName: 'disableAction' }
        }
    },
    {
        // Issue #83 — Delete a non-active version + its body and pre-decomp CVs.
        // Disabled on the active version via the namespace-safe disableAction
        // flag set in loadVersions().
        type: 'button',
        initialWidth: 130,
        cellAttributes: { alignment: 'center' },
        typeAttributes: {
            label: 'Delete',
            name: 'deleteVersion',
            title: 'Delete this version and its files',
            variant: 'destructive-text',
            iconName: 'utility:delete',
            disabled: { fieldName: 'disableAction' }
        }
    }
];

export default class DocGenAdmin extends NavigationMixin(LightningElement) {
    @track templates = [];
    columns = COLUMNS;
    versionColumns = VERSION_COLUMNS;
    wiredTemplatesResult;

    @track versions = [];

    // Form/Wizard State
    @track activeMainTab = 'new_template';
    @track currentWizardStep = '1';

    // Create State
    newTemplateName = '';
    // PHD-9 — auto-derived from the name until the author edits it by hand
    @track newTemplateApiName = '';
    _newApiNameEdited = false;
    newTemplateCategory = '';
    // HTML-first: the wizard's default authoring path (starter) creates HTML templates.
    @track newTemplateType = 'HTML';
    @track newTemplateOutputFormat = 'PDF';
    @track newTemplatePageOrientation = 'Portrait';
    @track newTemplatePageSize = 'Letter';
    @track newTemplatePageMargins = 'Default';
    @track newTemplateCustomMargins = '';
    newTemplateObject = 'Account';
    newTemplateDesc = '';
    newTemplateQuery = '';
    // HTML-first authoring path. 'starter' (recommended) and 'ai' both create
    // HTML templates; 'file' exposes the classic Type picker for uploads.
    @track newAuthoringMode = 'file';
    @track newStarterKey = 'report';
    // One-click create: auto-built query + optional company logo asset
    @track isAutoCreating = false;
    @track newTemplateLogoName = '';
    _logoFile = null;
    // Starter/AI paths hide the power-user fields behind this toggle.
    @track showAdvancedOptions = false;
    // AI wizard step: assets the prompt can reference + the paste-back box.
    @track wizardAssets = [];
    _aiPastedHtml = null;
    // Logo control: 'none' | asset id | 'upload'.
    @track newTemplateLogoChoice = 'none';
    @track newTemplateSampleRecordId = '';
    @track sampleRecordData = null;
    isCreating = true;
    createdTemplateId;

    // Edit State
    @track isEditModalOpen = false;
    @track activeEditTab = 'details';
    editTemplateId;
    editTemplateName;
    editTemplateCategory;
    @track editTemplateType;
    editTemplateObject;
    @track editTemplateOutputFormat;
    @track editTemplatePageOrientation = 'Portrait';
    @track editTemplatePageSize = 'Letter';
    @track editTemplatePageMargins = 'Default';
    @track editTemplateCustomMargins = '';
    @track editTemplateWatermarkCvId;
    @track isUploadingWatermark = false;
    editTemplateDesc;
    @track editTemplateQuery;
    // #161 follow-up — raw JSON string for the dedicated Form_Fields_Config__c
    // field (shape `{formFields:[...]}`). Signer Inputs no longer live on
    // Query_Config__c, so this is independent of editTemplateQuery.
    @track editFormFieldsConfig = '';
    editTemplateTestRecordId;
    editTemplateTitleFormat;
    editTemplateIsActive = true;
    editTemplateIsDefault = false;
    // 1.47 — runner visibility & sort
    editTemplateSortOrder;
    editTemplateLockOutputFormat = false;
    // #verification — template-level defaults (tri-state: Inherit / Required|Off / Yes|No)
    @track editTemplateSignerVerification = 'Inherit';
    // PHD-9 — stable developer key for Flow lookups
    @track editTemplateApiName = '';
    // #208 — per-template default {Message} for signature emails
    @track editTemplateDefaultEmailMessage = '';
    @track editTemplatePrefillSignerEmail = 'Inherit';
    editTemplateSpecificRecordIds;
    editTemplateRequiredPermissionSets;
    editTemplateRecordFilter;
    @track editTemplateRecordFilterResult = '';
    @track editTemplateRecordFilterResultMessage = '';
    @track editTemplateRecordFilterTesting = false;
    // 1.61 — HTML type header/footer
    @track editTemplateHeaderHtml;
    @track editTemplateFooterHtml;
    // Show-source toggles so authors can hand-edit raw HTML (image widths,
    // inline styles, merge-tag attributes the WYSIWYG can't expose).
    @track showHeaderHtmlSource = false;
    @track showFooterHtmlSource = false;
    // v1.90 — set true when an uploaded HTML body contains its own @page CSS rule.
    // Drives the "your HTML defines its own page setup" banner and hides the
    // template-level page-layout fields, which the engine ignores in this case.
    @track editHtmlBodyOwnsPageRule = false;
    // HTML body editor (paste-back surface for LLM-generated templates)
    @track showHtmlBodyEditor = false;
    @track isLoadingHtmlBody = false;
    @track isApplyingHtmlBody = false;
    // What "Save as New Version" will save: 'file' | 'editor' | 'starter' | null
    // (null = nothing staged this session; the stored body remains active).
    @track stagedBodySource = null;
    // True when the textarea has been typed in since the last stage/reload.
    @track htmlEditorDirty = false;
    // DOCX→HTML transparency viewer (Word templates, PDF output)
    @track showDocxHtmlViewer = false;
    @track isLoadingDocxHtml = false;
    @track isSwitchingToHtml = false;
    @track docxSnapshotInfo = null;
    // Code ⇄ Preview toggles (textarea stays mounted-but-hidden so its value survives)
    @track showDocxHtmlPreview = false;
    // Tags palette (click-to-insert merge tags from the template's own schema)
    @track showTagPanel = false;
    // Blocks palette (drag-in layout pieces: columns, tables, bands, breaks…)
    @track showBlockPanel = false;
    // Images panel (upload/insert <img> tags without knowing shepherd URLs)
    @track showImagePanel = false;
    @track isLoadingTemplateImages = false;
    @track isUploadingInsertImage = false;
    @track templateImages = [];
    // Visual mode — the scoped preview rendered contenteditable, so authors
    // edit text in place with the real layout visible. Only the body content
    // round-trips; head/styles/@page never do.
    @track showHtmlBodyVisual = false;
    _visualOriginalCode = null;
    _visualEnteredDom = null;
    // What the caret is on ("Editing: Table cell") — answers "what am I
    // about to color?"
    @track selectionContextLabel = '';
    // Pill inspector: click a pill → formatting menu (currency, date, QR…)
    @track pillMenu = null;
    // Notion-style slash-command menu: type "/" in the canvas → searchable insert palette.
    @track slashMenu = null;
    // Right-click context menu in the canvas.
    @track ctxMenu = null;
    _slashCtx = null;
    _slashSel = 0;
    // Floating searchable panels replace the fixed right rail: 'insert' | 'tags' | 'images' | 'watermark'.
    @track activePanel = null;
    @track panelSearch = '';
    // Query panel describe cache.
    @track designerQueryMeta = null;
    _queryMetaFor = null;
    // AI-wizard field checklist describe cache + search.
    @track wizardQueryMeta = null;
    _wizardQueryMetaFor = null;
    @track aiFieldSearch = '';
    // AI step: which shared assets ride into the prompt (null = all).
    @track aiSelectedAssetIds = null;
    // Step 3: the author's own description, injected into the prompt.
    @track aiDocDescription = '';
    // Live PDF preview: draft HTML → real Blob.toPdf render → blob: iframe.
    @track pdfPreviewUrl = null;
    @track isPdfPreviewLoading = false;
    _activePill = null;
    // Canvas page setup, mirrored into the template's @page rule. Custom
    // sizes cover everything from 3x4in nametags to poster PDFs.
    @track pageSetup = {
        size: 'Letter',
        orient: 'portrait',
        margin: '0.75',
        customW: '8.5',
        customH: '11',
        customMargin: '0.75'
    };
    // Last HTML body text this session touched (upload, starter, or Apply) so
    // reopening the editor doesn't need a server round-trip.
    _lastUploadedHtmlText = null;

    @track currentFileId;
    @track uploadedFileName = '';
    @track uploadedContentVersionId;
    @track showEditFileUpload = true;
    @track uploadedPdfAcroFormSnapshot = null;
    @track pdfAcroFormSnapshotVersionId = null;
    @track isPdfAcroFormSnapshotLoaded = false;
    @track isSavingPdfAcroFormMapping = false;
    @track isPreparingPdfAcroFormBody = false;
    @track pdfAcroFormPreparationText = '';
    @track pdfAcroFormSearchTerm = '';
    @track pdfAcroFormFilter = 'all';
    uploadedPdfAcroFormSnapshotJson = null;
    uploadedPdfAcroFormNormalizedBase64 = null;

    // Preview/Restore State
    @track isPreviewModalOpen = false;
    @track previewVersion = {};
    isLoadingVersions = false;

    // Visual builder toggle (wizard + edit modal)
    @track useVisualBuilder = false;
    @track editUseVisualBuilder = false;

    // Apex Data Provider mode (V4 — class-backed templates).
    // Wizard + edit modal both feed the same picker state via the _editContext flag.
    @track useApexProvider = false;
    @track editUseApexProvider = false;

    // Step 1 data-source choice. 'record' = pick a base SObject (default, classic
    // path); 'apex' = bind to a DocGenDataProvider class right from the start so
    // the wizard skips the base-object/sample-record requirements.
    @track dataSourceMode = 'record';
    @track providerSearchTerm = '';
    @track providerOptions = [];
    @track showProviderPicker = false;
    @track selectedProviderClassName = '';
    @track providerFields = [];
    @track isValidatingProvider = false;
    // Optional base SObject API name for v4 Apex Provider templates. When set,
    // overrides the 'ApexProvider' sentinel in Base_Object_API__c so the template
    // is filterable by record context (cross-object aggregation use case).
    @track apexProviderBaseObject = '';

    // Edit modal manual query toggle (for backward compat with existing V3 configs)
    @track isManualQuery = false;
    // Context flag: true when editing in modal, false when in wizard
    _editContext = false;

    get _activeQuery() {
        return this._editContext ? this.editTemplateQuery : this.newTemplateQuery;
    }
    set _activeQuery(v) {
        if (this._editContext) {
            this.editTemplateQuery = v;
        } else {
            this.newTemplateQuery = v;
        }
    }
    get _activeObject() {
        return this._editContext ? this.editTemplateObject : this.newTemplateObject;
    }
    get _activeSampleId() {
        return this._editContext ? this.editTemplateTestRecordId : this.newTemplateSampleRecordId;
    }
    // Builder 2.0 state
    @track objectOptions = [];
    @track filteredObjectOptions = [];
    @track showObjectSuggestions = false;
    @track queryTreeNodes = [];
    @track queryWarnings = null;
    @track builderTab = 'fields';
    @track builderSearchTerm = '';
    @track _allFields = [];
    @track _allChildren = [];
    @track _allParents = [];
    // #161 — Signer Inputs (form fields). Updateable-only field list for writeback
    // targets; rows of { key, label, fieldApiName, type, required, writeback,
    // mergeTag, choices, listOnCertificate }.
    @track _allUpdateableFields = [];
    @track signerFields = [];

    get builderFieldsTabClass() {
        return this.builderTab === 'fields' ? 'builder-tab-active' : '';
    }
    get builderRelatedTabClass() {
        return this.builderTab === 'related' ? 'builder-tab-active' : '';
    }
    get builderParentsTabClass() {
        return this.builderTab === 'parents' ? 'builder-tab-active' : '';
    }
    get builderPanelItems() {
        const s = (this.builderSearchTerm || '').toLowerCase();
        if (this.builderTab === 'fields') {
            return (this._allFields || [])
                .filter((f) => !s || f.label.toLowerCase().includes(s) || f.value.toLowerCase().includes(s))
                .slice(0, 150)
                .map((f) => ({ value: f.value, label: f.label, extra: f.type || '' }));
        } else if (this.builderTab === 'related') {
            return (this._allChildren || [])
                .filter((c) => !s || c.label.toLowerCase().includes(s) || c.value.toLowerCase().includes(s))
                .slice(0, 80)
                .map((c) => ({ value: c.value, label: c.label, extra: c.childObjectApiName || '' }));
        } else if (this.builderTab === 'parents') {
            return (this._allParents || [])
                .filter((p) => !s || p.label.toLowerCase().includes(s) || p.value.toLowerCase().includes(s))
                .slice(0, 80)
                .map((p) => ({ value: p.value, label: p.label, extra: p.targetObject || '' }));
        }
        return [];
    }

    get hasUploadedPdfAcroFormFields() {
        return (
            this.uploadedPdfAcroFormSnapshot &&
            this.uploadedPdfAcroFormSnapshot.fields &&
            this.uploadedPdfAcroFormSnapshot.fields.length > 0
        );
    }

    get pdfAcroFormMappedCount() {
        if (!this.hasUploadedPdfAcroFormFields) {
            return 0;
        }
        return this.uploadedPdfAcroFormSnapshot.fields.filter((field) => !!(field.mappedPath || '').trim()).length;
    }

    get hasSavedPdfAcroFormSnapshotTarget() {
        return String(this.pdfAcroFormSnapshotVersionId || '').startsWith('a07');
    }

    get isPdfAcroFormSaveMappingDisabled() {
        return (
            this.isSavingPdfAcroFormMapping ||
            this.isPreparingPdfAcroFormBody ||
            !this.editTemplateId ||
            !this.hasSavedPdfAcroFormSnapshotTarget ||
            !this.uploadedPdfAcroFormSnapshotJson
        );
    }

    get pdfAcroFormMappingStatusText() {
        if (!this.hasUploadedPdfAcroFormFields) {
            return '';
        }
        if (this.isPdfAcroFormSnapshotLoaded && this.hasSavedPdfAcroFormSnapshotTarget) {
            return 'Saved on the active template version.';
        }
        if (this.hasSavedPdfAcroFormSnapshotTarget) {
            return 'Mapping changes are ready to save to the active template version.';
        }
        return 'Draft mapping. Save as New Version will store it.';
    }

    get pdfAcroFormFieldCount() {
        if (!this.hasUploadedPdfAcroFormFields) {
            return 0;
        }
        return this.uploadedPdfAcroFormSnapshot.fields.length;
    }

    get pdfAcroFormVisibleFieldCount() {
        return this.pdfAcroFormFieldRows.length;
    }

    get pdfAcroFormFilterOptions() {
        return [
            { label: 'All fields', value: 'all' },
            { label: 'Mapped', value: 'mapped' },
            { label: 'Unmapped', value: 'unmapped' },
            { label: 'Text fields', value: 'text' },
            { label: 'Buttons', value: 'button' }
        ];
    }

    get pdfAcroFormDataPathOptions() {
        const paths = this._pdfAcroFormDataPathsFromQuery(this.editTemplateQuery);
        return [
            { label: 'Not mapped', value: '' },
            ...paths.map((path) => ({
                label: path.label,
                value: path.value
            }))
        ];
    }

    get hasPdfAcroFormDataPathOptions() {
        return this.pdfAcroFormDataPathOptions.length > 1;
    }

    get pdfAcroFormFieldRows() {
        if (!this.hasUploadedPdfAcroFormFields) {
            return [];
        }
        const search = (this.pdfAcroFormSearchTerm || '').trim().toLowerCase();
        const filter = this.pdfAcroFormFilter || 'all';
        return this.uploadedPdfAcroFormSnapshot.fields
            .map((field, index) => {
                const displayName = field.name || field.partialName || 'Field ' + (index + 1);
                const rect = field.rect || [];
                const positionText = this._pdfAcroFormPositionText(rect, field.mediaBox);
                const estimatedPageNumber =
                    field.estimatedPageNumber || this._pdfAcroFormEstimatedPageNumber(displayName);
                return {
                    key: (field.objectNumber || 'field') + '-' + index,
                    index,
                    rect,
                    displayName,
                    friendlyLabel: field.friendlyLabel || '',
                    partialName: field.partialName,
                    fieldType: field.fieldType || 'Field',
                    pageLabel: field.pageNumber
                        ? 'Page ' + field.pageNumber
                        : estimatedPageNumber
                          ? 'Page ~' + estimatedPageNumber
                          : '',
                    locationLabel: field.locationLabel || '',
                    positionText,
                    isButton: field.fieldType === 'Btn',
                    mappedPath: field.mappedPath || '',
                    buttonOnValue: field.buttonOnValue || 'Yes',
                    buttonOnValuesText:
                        field.buttonOnValues && field.buttonOnValues.length ? field.buttonOnValues.join(', ') : '',
                    rowClass: field.mappedPath ? 'pdf-acroform-row pdf-acroform-row_mapped' : 'pdf-acroform-row'
                };
            })
            .filter((row) => {
                if (filter === 'mapped' && !row.mappedPath) {
                    return false;
                }
                if (filter === 'unmapped' && row.mappedPath) {
                    return false;
                }
                if (filter === 'text' && row.fieldType !== 'Tx') {
                    return false;
                }
                if (filter === 'button' && !row.isButton) {
                    return false;
                }
                if (!search) {
                    return true;
                }
                return [
                    row.friendlyLabel,
                    row.displayName,
                    row.partialName,
                    row.fieldType,
                    row.pageLabel,
                    row.locationLabel,
                    row.positionText,
                    row.mappedPath,
                    row.buttonOnValue,
                    row.buttonOnValuesText
                ]
                    .filter(Boolean)
                    .some((value) => String(value).toLowerCase().includes(search));
            })
            .sort((a, b) => this._comparePdfAcroFormRows(a, b));
    }

    _pdfAcroFormEstimatedPageNumber(fieldName) {
        const match = /#subform\[(\d+)\]/.exec(fieldName || '');
        return match ? Number(match[1]) + 1 : null;
    }

    _comparePdfAcroFormRows(a, b) {
        const pageA = this._pdfAcroFormSortPage(a);
        const pageB = this._pdfAcroFormSortPage(b);
        if (pageA !== pageB) {
            return pageA - pageB;
        }

        const boxA = this._pdfAcroFormSortBox(a);
        const boxB = this._pdfAcroFormSortBox(b);
        const rowTolerance = 8;
        if (Math.abs(boxA.top - boxB.top) > rowTolerance) {
            return boxB.top - boxA.top;
        }
        if (Math.abs(boxA.left - boxB.left) > 0.01) {
            return boxA.left - boxB.left;
        }
        if (Math.abs(boxA.bottom - boxB.bottom) > 0.01) {
            return boxB.bottom - boxA.bottom;
        }
        return a.displayName.localeCompare(b.displayName);
    }

    _pdfAcroFormSortPage(row) {
        const match = /^Page\s+~?(\d+)/.exec(row.pageLabel || '');
        return match ? Number(match[1]) : Number.MAX_SAFE_INTEGER;
    }

    _pdfAcroFormSortBox(row) {
        const rect = row.rect || [];
        const left = Math.min(Number(rect[0]), Number(rect[2]));
        const right = Math.max(Number(rect[0]), Number(rect[2]));
        const bottom = Math.min(Number(rect[1]), Number(rect[3]));
        const top = Math.max(Number(rect[1]), Number(rect[3]));
        if (![left, right, bottom, top].every(Number.isFinite)) {
            return {
                left: Number.MAX_SAFE_INTEGER,
                right: Number.MAX_SAFE_INTEGER,
                bottom: Number.MIN_SAFE_INTEGER,
                top: Number.MIN_SAFE_INTEGER
            };
        }
        return { left, right, bottom, top };
    }

    _pdfAcroFormDataPathsFromQuery(queryConfig) {
        if (!queryConfig) {
            return [];
        }
        const byValue = new Map();
        const addPath = (value, labelPrefix) => {
            if (!value || typeof value !== 'string') {
                return;
            }
            const trimmed = value.trim();
            if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('/')) {
                return;
            }
            if (!byValue.has(trimmed)) {
                byValue.set(trimmed, {
                    value: trimmed,
                    label: labelPrefix ? labelPrefix + ': ' + trimmed : trimmed
                });
            }
        };

        try {
            const qc = queryConfig.trim();
            if (qc.startsWith('{')) {
                const config = JSON.parse(qc);
                if (config.v === 4 && config.provider) {
                    const declaredLoops = new Set();
                    for (const fieldName of this.providerFields || []) {
                        if (typeof fieldName === 'string' && fieldName.startsWith('#')) {
                            declaredLoops.add(fieldName.substring(1));
                        }
                    }
                    for (const fieldName of this.providerFields || []) {
                        if (typeof fieldName !== 'string' || fieldName.startsWith('#') || fieldName.startsWith('/')) {
                            continue;
                        }
                        const prefix = fieldName.includes('.') ? fieldName.split('.')[0] : '';
                        if (!prefix || !declaredLoops.has(prefix)) {
                            addPath(fieldName, prefix ? 'Parent' : 'Field');
                        }
                    }
                    return Array.from(byValue.values());
                }
                if (config.v >= 3 && config.nodes) {
                    const root = (config.nodes || []).find((node) => !node.parentNode) || {};
                    for (const fieldName of root.fields || []) {
                        addPath(fieldName, 'Field');
                    }
                    for (const fieldName of root.parentFields || []) {
                        addPath(fieldName, 'Parent');
                    }
                    return Array.from(byValue.values());
                }
            }

            const parsed = parseSOQLFields(queryConfig);
            for (const fieldName of parsed.baseFields || []) {
                addPath(fieldName, 'Field');
            }
            for (const fieldName of parsed.parentFields || []) {
                addPath(fieldName, 'Parent');
            }
        } catch {
            return [];
        }
        return Array.from(byValue.values());
    }

    _pdfAcroFormPositionText(rect, mediaBox) {
        if (!rect || rect.length < 4) {
            return '';
        }
        const pointsPerInch = 72;
        const pageTop = mediaBox && Number.isFinite(Number(mediaBox.top)) ? Number(mediaBox.top) : 792;
        const pageLeft = mediaBox && Number.isFinite(Number(mediaBox.left)) ? Number(mediaBox.left) : 0;
        const left = Math.min(Number(rect[0]), Number(rect[2]));
        const right = Math.max(Number(rect[0]), Number(rect[2]));
        const bottom = Math.min(Number(rect[1]), Number(rect[3]));
        const top = Math.max(Number(rect[1]), Number(rect[3]));
        if (![left, right, bottom, top].every(Number.isFinite)) {
            return '';
        }
        const fromLeft = (left - pageLeft) / pointsPerInch;
        const fromTop = (pageTop - top) / pointsPerInch;
        const width = (right - left) / pointsPerInch;
        const height = (top - bottom) / pointsPerInch;
        return (
            fromLeft.toFixed(1) +
            ' in from left, ' +
            fromTop.toFixed(1) +
            ' in from top, ' +
            width.toFixed(1) +
            ' x ' +
            height.toFixed(1) +
            ' in'
        );
    }

    handleBuilderTabClick(event) {
        this.builderTab = event.currentTarget.dataset.tab;
        this.builderSearchTerm = '';
    }

    handleBuilderSearch(event) {
        this.builderSearchTerm = event.target.value;
    }

    handleBuilderItemClick(event) {
        const val = event.currentTarget.dataset.value;
        const q = (this.newTemplateQuery || '').trim();
        const sep = q && !q.endsWith(',') ? ', ' : '';

        let insert = '';
        if (this.builderTab === 'fields') {
            insert = sep + val;
        } else if (this.builderTab === 'related') {
            insert = (q ? ',\n' : '') + '(SELECT Id FROM ' + val + ')';
        } else if (this.builderTab === 'parents') {
            insert = sep + val + '.Name';
        }

        this.newTemplateQuery = q + insert;
        this._updateQueryTree();
    }

    @track suggestions = [];
    @track showSuggestions = false;

    handleDirectQueryEdit(event) {
        this.newTemplateQuery = event.target.value;
        this._updateQueryTree();
        this._updateSuggestions(event.target);
        // Debounced sample data refresh
        clearTimeout(this._sampleDebounce);
        this._sampleDebounce = setTimeout(() => {
            this._loadSampleData();
        }, 800);
    }

    _findUnmatchedParen(str) {
        let depth = 0;
        for (let i = str.length - 1; i >= 0; i--) {
            if (str[i] === ')') depth++;
            if (str[i] === '(') {
                if (depth === 0) return i;
                depth--;
            }
        }
        return -1;
    }

    _getToken(before) {
        // Token = text after the last comma, open-paren, or newline
        let sepIdx = -1;
        for (let i = before.length - 1; i >= 0; i--) {
            const ch = before[i];
            if (ch === ',' || ch === '(' || ch === '\n') {
                sepIdx = i;
                break;
            }
        }
        return {
            token: before.substring(sepIdx + 1).trim(),
            sepChar: sepIdx >= 0 ? before[sepIdx] : '',
            start: sepIdx + 1
        };
    }

    _updateSuggestions(textarea) {
        const text = textarea.value;
        const cursor = textarea.selectionStart || text.length;
        const before = text.substring(0, cursor);
        this._suggestCursor = cursor;

        const { token, sepChar, start } = this._getToken(before);
        this._tokenReplaceStart = start;

        // Skip SOQL keywords
        const upper = token.toUpperCase();
        if (
            [
                'SELECT',
                'FROM',
                'WHERE',
                'AND',
                'OR',
                'ORDER',
                'BY',
                'LIMIT',
                'ASC',
                'DESC',
                'LIKE',
                'IN',
                'NOT',
                'NULL',
                '=',
                '!=',
                '>',
                '<',
                '>=',
                '<='
            ].includes(upper)
        ) {
            this.showSuggestions = false;
            return;
        }

        // 1) Just typed "(" — show child relationships
        if (sepChar === '(' && token === '') {
            this._suggestMode = 'related-scaffold';
            this.suggestions = (this._allChildren || [])
                .slice(0, 15)
                .map((c) => ({ value: c.value, label: c.label, extra: c.childObjectApiName || '' }));
            this.showSuggestions = this.suggestions.length > 0;
            return;
        }

        // 2) Are we inside an unmatched paren? (subquery context)
        const parenIdx = this._findUnmatchedParen(before);
        if (parenIdx !== -1) {
            const insideParen = before.substring(parenIdx + 1).trim();
            const upperInside = insideParen.toUpperCase();

            // 2a) After FROM with no space after relationship name yet — suggest child relationships
            const fromAtEnd = upperInside.match(/FROM\s*(\S*)$/);
            if (fromAtEnd) {
                this._suggestMode = 'related';
                const s = (fromAtEnd[1] || '').toLowerCase();
                this.suggestions = (this._allChildren || [])
                    .filter((c) => !s || c.value.toLowerCase().includes(s) || c.label.toLowerCase().includes(s))
                    .slice(0, 15)
                    .map((c) => ({ value: c.value, label: c.label, extra: c.childObjectApiName || '' }));
                this.showSuggestions = this.suggestions.length > 0;
                return;
            }

            // 2b) We know the FROM object — suggest that child object's fields
            const fromMatch = insideParen.match(/FROM\s+(\w+)/i);
            if (fromMatch && token.length >= 1) {
                const relName = fromMatch[1];
                const childRel = (this._allChildren || []).find((c) => c.value.toLowerCase() === relName.toLowerCase());
                if (childRel) {
                    this._suggestMode = 'child-field';
                    const cacheKey = '_cache_' + childRel.childObjectApiName;
                    const s = token.toLowerCase();
                    if (this[cacheKey]) {
                        this._showSimpleSuggestions(this[cacheKey], s);
                    } else {
                        getObjectFields({ objectName: childRel.childObjectApiName })
                            .then((data) => {
                                this[cacheKey] = data || [];
                                this._showSimpleSuggestions(data || [], s);
                            })
                            .catch(() => {
                                this.showSuggestions = false;
                            });
                    }
                    return;
                }
            }

            // 2c) Inside paren but no FROM yet and token has text — could be typing SELECT fields or relationship name
            if (token.length >= 1 && !upperInside.includes('FROM')) {
                this._suggestMode = 'related';
                const s = token.toLowerCase();
                this.suggestions = (this._allChildren || [])
                    .filter((c) => c.value.toLowerCase().includes(s) || c.label.toLowerCase().includes(s))
                    .slice(0, 15)
                    .map((c) => ({ value: c.value, label: c.label, extra: c.childObjectApiName || '' }));
                this.showSuggestions = this.suggestions.length > 0;
                return;
            }
        }

        // 3) After a dot — parent field lookup
        if (token.includes('.')) {
            const dot = token.lastIndexOf('.');
            const parentName = token.substring(0, dot);
            const fieldSearch = token.substring(dot + 1).toLowerCase();
            const parentRel = (this._allParents || []).find((p) => p.value.toLowerCase() === parentName.toLowerCase());
            if (parentRel) {
                this._suggestMode = 'parent-field';
                this._suggestParent = parentName;
                const cacheKey = '_cache_' + parentRel.targetObject;
                if (this[cacheKey]) {
                    this._showParentFieldSuggestions(this[cacheKey], fieldSearch, parentName);
                } else {
                    getObjectFields({ objectName: parentRel.targetObject })
                        .then((data) => {
                            this[cacheKey] = data || [];
                            this._showParentFieldSuggestions(data || [], fieldSearch, parentName);
                        })
                        .catch(() => {
                            this.showSuggestions = false;
                        });
                }
                return;
            }
        }

        // 4) Default — base object fields + parent relationship names
        if (token.length >= 1) {
            this._suggestMode = 'field';
            const s = token.toLowerCase();
            const fieldResults = (this._allFields || [])
                .filter((f) => f.value.toLowerCase().includes(s) || f.label.toLowerCase().includes(s))
                .slice(0, 8)
                .map((f) => ({ value: f.value, label: f.label, extra: f.type || '' }));
            const parentResults = (this._allParents || [])
                .filter((p) => p.value.toLowerCase().includes(s) || p.label.toLowerCase().includes(s))
                .slice(0, 4)
                .map((p) => ({ value: p.value + '.', label: p.label, extra: '→ ' + (p.targetObject || '') }));
            this.suggestions = [...fieldResults, ...parentResults];
            this.showSuggestions = this.suggestions.length > 0;
        } else {
            this.showSuggestions = false;
        }
    }

    _showSimpleSuggestions(fields, search) {
        this.suggestions = (fields || [])
            .filter((f) => !search || f.value.toLowerCase().includes(search) || f.label.toLowerCase().includes(search))
            .slice(0, 10)
            .map((f) => ({ value: f.value, label: f.label, extra: f.type || '' }));
        this.showSuggestions = this.suggestions.length > 0;
    }

    _showParentFieldSuggestions(fields, search, parentName) {
        this.suggestions = (fields || [])
            .filter((f) => !search || f.value.toLowerCase().includes(search) || f.label.toLowerCase().includes(search))
            .slice(0, 10)
            .map((f) => ({ value: parentName + '.' + f.value, label: f.label, extra: f.type || '' }));
        this.showSuggestions = this.suggestions.length > 0;
    }

    handleSuggestionClick(event) {
        const val = event.currentTarget.dataset.value;
        const text = this._activeQuery || '';
        const cursor = this._suggestCursor || text.length;

        // Find the token boundaries fresh — don't rely on cached values
        const before = text.substring(0, cursor);
        let sepIdx = -1;
        for (let i = before.length - 1; i >= 0; i--) {
            const ch = before[i];
            if (ch === ',' || ch === '(' || ch === '\n') {
                sepIdx = i;
                break;
            }
        }
        // prefix = everything up to and including the separator
        // after = everything after cursor
        const prefix = text.substring(0, sepIdx + 1);
        const after = text.substring(cursor);
        // Add a space after separator if needed
        const needSpace = prefix.length > 0 && !prefix.endsWith(' ') && !prefix.endsWith('(') && !prefix.endsWith('\n');

        let result;
        if (this._suggestMode === 'related-scaffold') {
            // Typed "(" — scaffold full subquery, prefix already ends with "("
            result = prefix + 'SELECT Id FROM ' + val + ')' + after;
        } else if (this._suggestMode === 'related') {
            // Replacing relationship name (after FROM)
            result = prefix + (needSpace ? ' ' : '') + val + after;
        } else if (val.endsWith('.')) {
            // Parent relationship — "Owner." — no comma, they pick a field next
            result = prefix + (needSpace ? ' ' : '') + val + after;
        } else {
            // Regular field — replace token, add trailing comma
            result = prefix + (needSpace ? ' ' : '') + val + ', ' + after;
        }

        this._activeQuery = result;
        // Native textarea doesn't re-render from tracked property after user input — set DOM directly
        const taSelector = this._editContext ? '.edit-query-textarea' : '.wizard-query-textarea';
        const ta = this.template.querySelector(taSelector);
        if (ta) {
            ta.value = result;
        }
        this.showSuggestions = false;
        this._updateQueryTree();

        // If parent with dot, re-trigger to show that parent's fields
        if (val.endsWith('.')) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const ta = this.template.querySelector(taSelector);
                if (ta) {
                    const newPos = prefix.length + (needSpace ? 1 : 0) + val.length;
                    ta.setSelectionRange(newPos, newPos);
                    ta.focus();
                    this._updateSuggestions(ta);
                }
            }, 50);
        }
    }

    handleSuggestionMouseDown(event) {
        // Prevent textarea blur from firing before onclick
        event.preventDefault();
    }

    handleQueryKeyDown(event) {
        if (event.key === 'Escape' && this.showSuggestions) {
            this.showSuggestions = false;
            event.stopPropagation();
        }
    }

    // Filter State
    searchKey = '';

    @track isInstallingSamples = false;
    _samplesChecked = false;

    @wire(getAllTemplates)
    wiredTemplates(result) {
        this.wiredTemplatesResult = result;
        if (result.data) {
            this.templates = result.data.map((t) => {
                // F.IsActive may be undefined on rows created before the field
                // shipped — treat null/undefined as Active to match the server
                // OR-NULL filter in getTemplatesForObjectInternal.
                const isActive = t[F.IsActive] !== false;
                const rawBase = t[F.BaseObject];
                const displayBaseObject =
                    rawBase === 'FlowJsonData'
                        ? 'JSON Data (from Flow)'
                        : rawBase === 'ApexProvider'
                          ? 'Apex Data Provider'
                          : rawBase;
                return {
                    ...t,
                    displayBaseObject,
                    defaultLabel: t[F.IsDefault] ? '★' : '',
                    defaultClass: t[F.IsDefault] ? 'slds-text-color_success slds-text-title_bold' : '',
                    activeLabel: isActive ? 'Active' : 'Inactive',
                    activeClass: isActive
                        ? 'slds-text-color_success slds-text-title_bold'
                        : 'slds-text-color_weak slds-text-title_bold'
                };
            });
            this._samplesChecked = true;
        } else if (result.error) {
            this.showToast('Error', 'Error loading templates', 'error');
        }
    }

    get filteredTemplates() {
        if (!this.searchKey) return this.templates;
        const lowerKey = this.searchKey.toLowerCase();
        return this.templates.filter(
            (t) =>
                (t.Name && t.Name.toLowerCase().includes(lowerKey)) ||
                (t[F.Category] && t[F.Category].toLowerCase().includes(lowerKey)) ||
                (t[F.BaseObject] && t[F.BaseObject].toLowerCase().includes(lowerKey)) ||
                (t.displayBaseObject && t.displayBaseObject.toLowerCase().includes(lowerKey)) ||
                (t[F.Type] && t[F.Type].toLowerCase().includes(lowerKey)) ||
                (t[F.OutputFormat] && t[F.OutputFormat].toLowerCase().includes(lowerKey)) ||
                (t[F.Desc] && t[F.Desc].toLowerCase().includes(lowerKey)) ||
                (t.Id && t.Id.toLowerCase().includes(lowerKey))
        );
    }

    handleRefresh() {
        return refreshApex(this.wiredTemplatesResult);
    }

    handleSearch(event) {
        this.searchKey = event.detail.value;
    }

    async installSampleTemplates() {
        this.isInstallingSamples = true;
        try {
            // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
            const count = await createSampleTemplates();
            this.showToast(
                'Welcome to DocGen!',
                count + ' sample templates installed. Open any template to see how merge tags work.',
                'success'
            );
            await refreshApex(this.wiredTemplatesResult);
            this.activeMainTab = 'list';
        } catch (error) {
            const msg = error.body ? error.body.message : error.message;
            this.showToast('Error', 'Failed to create sample templates: ' + msg, 'error');
        } finally {
            this.isInstallingSamples = false;
        }
    }

    // --- A11y live region ─────────────────────────────────────
    // Page-level ARIA live announcement channel. Children dispatch a bubbling
    // CustomEvent('announce', {detail:{message}, composed:true}); we mirror
    // the message into a `slds-assistive-text` element with aria-live="polite".
    @track liveAnnouncement = '';

    handleA11yAnnounce(event) {
        const msg = event && event.detail && event.detail.message;
        if (!msg) return;
        // Re-trigger if same string is announced again. Empty briefly so the
        // SR re-reads identical messages.
        if (this.liveAnnouncement === msg) {
            this.liveAnnouncement = '';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.liveAnnouncement = msg;
            }, 50);
        } else {
            this.liveAnnouncement = msg;
        }
    }

    // Modal Esc-to-close handlers. Focus restoration is handled by the
    // standard browser flow when the dialog DOM unmounts; full focus trap
    // (Tab/Shift+Tab cycling) is deferred to v1.85.
    handleEditModalKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closeEditModal();
        }
    }
    handlePreviewModalKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closePreviewModal();
        }
    }

    // --- Wizard Logic ---

    disconnectedCallback() {
        if (this._selListenerAdded) {
            document.removeEventListener('selectionchange', this._onSelectionChange);
            this._selListenerAdded = false;
        }
        if (this._docMouseListenerAdded) {
            document.removeEventListener('mousedown', this._onDocMouseDown, true);
            this._docMouseListenerAdded = false;
        }
    }

    /**
     * Yank focus and caret back from Lightning's global-search box after its
     * "/" hotkey fired while the user was typing in the visual canvas, then
     * insert the "/" they typed. See the key-trap comment in renderedCallback.
     */
    _recoverStolenSlash() {
        // The search dialog keeps re-grabbing focus asynchronously while it
        // opens, so a single focus() call loses the race — retry until the
        // canvas HOLDS focus, inserting the "/" exactly once.
        let inserted = false;
        const attempt = (triesLeft) => {
            try {
                const host = this.template.querySelector('.dg-visual-host');
                const pv = host && host.querySelector('.dg-pv');
                if (!pv) {
                    return;
                }
                pv.focus();
                const s = window.getSelection();
                if (this._lastCanvasRange) {
                    s.removeAllRanges();
                    s.addRange(this._lastCanvasRange);
                }
                if (this._canvasFocused && !inserted) {
                    inserted = true;
                    document.execCommand('insertText', false, '/');
                    this.htmlEditorDirty = true;
                    this._maybePillifyTyped();
                    this._maybeOpenSlashMenu();
                }
                if (triesLeft > 0) {
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        if (!this._canvasFocused) {
                            attempt(triesLeft - 1);
                        }
                    }, 220);
                }
            } catch (e) {
                /* best effort */
            }
        };
        attempt(5);
    }

    /**
     * Fit tables wider than the sheet (Word-conversion twips math, extra
     * loop-tag cells) back onto the page: width 100% + table-layout fixed
     * scales the authored column widths proportionally. The inline styles
     * persist into the saved body, so the PDF is fixed too — flagged dirty
     * and announced so the author knows their document was touched.
     */
    _fitOversizeTables(pv) {
        try {
            const cs = getComputedStyle(pv);
            const contentW =
                pv.getBoundingClientRect().width -
                (parseFloat(cs.paddingLeft) || 0) -
                (parseFloat(cs.paddingRight) || 0);
            let fixed = 0;
            for (const t of pv.querySelectorAll('table')) {
                if (t.getBoundingClientRect().width > contentW + 1) {
                    t.style.width = '100%';
                    t.style.tableLayout = 'fixed';
                    t.style.maxWidth = '100%';
                    fixed++;
                }
            }
            if (fixed) {
                this.htmlEditorDirty = true;
                this.showToast(
                    'Table fit to page',
                    fixed +
                        (fixed === 1 ? ' table was' : ' tables were') +
                        ' wider than the page and got scaled to fit — column proportions kept. Save as New Version keeps the fix.',
                    'info'
                );
            }
        } catch (e) {
            /* best effort */
        }
    }

    /**
     * Word-style "click and type": place the caret exactly where the user
     * double-clicked. Inside existing content the browser range is used
     * directly; in empty space below the last block, a fresh paragraph is
     * created there so typing can start immediately.
     */
    _placeCaretAtPoint(e, pv) {
        try {
            const sel = window.getSelection();
            let range = null;
            if (document.caretRangeFromPoint) {
                range = document.caretRangeFromPoint(e.clientX, e.clientY);
            } else if (document.caretPositionFromPoint) {
                const pos = document.caretPositionFromPoint(e.clientX, e.clientY);
                if (pos) {
                    range = document.createRange();
                    range.setStart(pos.offsetNode, pos.offset);
                }
            }
            const blocks = Array.from(pv.children).filter((c) => !c.matches('style'));
            const last = blocks[blocks.length - 1];
            const belowContent = last && e.clientY > last.getBoundingClientRect().bottom + 4;
            // Empty container under the pointer (section column, table cell,
            // panel div): start a paragraph inside IT, not wherever the range
            // snapped to.
            const under = document.elementFromPoint(e.clientX, e.clientY);
            const container =
                under && pv.contains(under) && under !== pv && /^(DIV|TD|TH)$/.test(under.tagName) ? under : null;
            const rangeMissesContainer = container && (!range || !container.contains(range.startContainer));
            if (rangeMissesContainer) {
                const p = document.createElement('p');
                p.appendChild(document.createElement('br'));
                container.appendChild(p);
                range = document.createRange();
                range.setStart(p, 0);
                this.htmlEditorDirty = true;
            } else if (belowContent || !range || !pv.contains(range.startContainer)) {
                const p = document.createElement('p');
                p.appendChild(document.createElement('br'));
                pv.appendChild(p);
                range = document.createRange();
                range.setStart(p, 0);
                this.htmlEditorDirty = true;
            }
            range.collapse(true);
            sel.removeAllRanges();
            sel.addRange(range);
            pv.focus();
        } catch (err) {
            /* caret placement is best-effort */
        }
    }

    renderedCallback() {
        // Sync native textarea DOM value with tracked property after re-render
        if (this.currentWizardStep === '2' && this.newTemplateQuery) {
            const ta = this.template.querySelector('.wizard-query-textarea');
            if (ta && ta.value !== this.newTemplateQuery) {
                ta.value = this.newTemplateQuery;
            }
        }
        if (this._editContext && this.isEditModalOpen && this.editTemplateQuery) {
            const ta = this.template.querySelector('.edit-query-textarea');
            if (ta && ta.value !== this.editTemplateQuery) {
                ta.value = this.editTemplateQuery;
            }
        }
        // Page-setup controls: LWC doesn't bind value on native <select>, so
        // mirror state into the DOM the same way the query textareas do —
        // but never clobber a control the user is currently typing in.
        for (const sel of this.template.querySelectorAll('.dg-page-select, .dg-page-input')) {
            const want = this.pageSetup[sel.dataset.field];
            if (want != null && sel.value !== want && !sel.matches(':focus')) {
                sel.value = want;
            }
        }
        // Header/Footer panel textareas: sync tracked values into the DOM
        // (LWC textareas have no value binding); skip while focused.
        if (this.activePanel === 'hf') {
            const hta = this.template.querySelector('.dg-hf-header');
            if (hta && hta !== document.activeElement && hta.value !== (this.editTemplateHeaderHtml || '')) {
                hta.value = this.editTemplateHeaderHtml || '';
            }
            const fta = this.template.querySelector('.dg-hf-footer');
            if (fta && fta !== document.activeElement && fta.value !== (this.editTemplateFooterHtml || '')) {
                fta.value = this.editTemplateFooterHtml || '';
            }
        }
        // Right-click menu just opened — cursor into its search box.
        if (this._focusCtxSearch && this.ctxMenu) {
            const ci = this.template.querySelector('.dg-ctx-search');
            if (ci) {
                ci.focus();
                this._focusCtxSearch = false;
            }
        }
        // Searchable panel just opened — put the cursor in its search box.
        if (this._focusPanelSearch) {
            const inp = this.template.querySelector('.dg-panel-search');
            if (inp) {
                inp.focus();
                this._focusPanelSearch = false;
            }
        }
        // Inline HTML preview: the lwc:dom="manual" host only exists after the
        // re-render that the Preview toggle triggers, so the content write has
        // to happen here rather than in the click handler.
        if (this._pendingPreviewWrite) {
            const host = this.template.querySelector(this._pendingPreviewWrite.selector);
            if (host) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                host.innerHTML = this._pendingPreviewWrite.html;
                // Visual mode: the rendered page becomes the editor.
                if (this._pendingPreviewWrite.editable) {
                    const pv = host.querySelector('.dg-pv');
                    if (pv) {
                        pv.setAttribute('contenteditable', 'true');
                        pv.setAttribute('spellcheck', 'false');
                        // Component CSS can't reach manual DOM — style inline.
                        pv.style.outline = '2px dashed #b49aef';
                        pv.style.outlineOffset = '6px';
                        pv.style.caretColor = '#7c3aed';
                        pv.style.cursor = 'text';
                        // Merge tags render as friendly atomic pills.
                        this._pillifyTags(pv);
                        // Drag targets: tag chips and image thumbnails drop
                        // exactly where the user points — with a live insertion
                        // marker so the drop point is never a guess.
                        pv.addEventListener('dragover', (e) => {
                            e.preventDefault();
                            this._showDropMarker(e, pv);
                        });
                        pv.addEventListener('dragleave', (e) => {
                            if (e.target === pv) {
                                this._hideDropMarker(pv);
                            }
                        });
                        pv.addEventListener('drop', (e) => this._handleVisualDrop(e, pv));
                        // Live dirty signal while typing in the page — and
                        // type-to-pill: a completed {tag} snaps into a pill.
                        pv.addEventListener('input', () => {
                            this.htmlEditorDirty = true;
                            this._maybePillifyTyped();
                            // Notion-style: "/" at the caret opens the insert menu.
                            this._maybeOpenSlashMenu();
                        });
                        // Click a pill → its formatting menu; click elsewhere closes it.
                        // Double-click a pill → edit its tag text in place.
                        pv.addEventListener('click', (e) => {
                            const pill = e.target && e.target.closest ? e.target.closest('[data-dg-tag]') : null;
                            if (pill && pill.getAttribute('contenteditable') !== 'true') {
                                e.preventDefault();
                                this._openPillMenu(pill);
                            } else if (!pill) {
                                this.pillMenu = null;
                                this._closeSlashMenu();
                                this.ctxMenu = null;
                            }
                        });
                        pv.addEventListener('dblclick', (e) => {
                            const pill = e.target && e.target.closest ? e.target.closest('[data-dg-tag]') : null;
                            if (pill) {
                                e.preventDefault();
                                this._beginPillEdit(pill);
                                return;
                            }
                            // Word-style click-and-type: double-click empty page
                            // space starts a cursor right there.
                            this._placeCaretAtPoint(e, pv);
                        });
                        // Right-click: contextual menu (pill menu on pills;
                        // insert/format/table actions elsewhere).
                        pv.addEventListener('contextmenu', (e) => {
                            e.preventDefault();
                            this._closeSlashMenu();
                            const pill = e.target && e.target.closest ? e.target.closest('[data-dg-tag]') : null;
                            if (pill && pill.getAttribute('contenteditable') !== 'true') {
                                this.ctxMenu = null;
                                this._openPillMenu(pill);
                                return;
                            }
                            this.pillMenu = null;
                            this._placeCaretAtPoint(e, pv);
                            const col = this.template.querySelector('.dg-designer-canvas-col');
                            const colRect = col ? col.getBoundingClientRect() : { left: 0, top: 0 };
                            this._ctxPoint = { x: e.clientX, y: e.clientY };
                            try {
                                const cs = window.getSelection();
                                this._ctxRange = cs && cs.rangeCount ? cs.getRangeAt(0).cloneRange() : null;
                            } catch (err) {
                                this._ctxRange = null;
                            }
                            this._focusCtxSearch = true;
                            this.ctxMenu = {
                                inTable: !!(e.target && e.target.closest && e.target.closest('td, th')),
                                posStyle:
                                    'left: ' +
                                    Math.max(0, e.clientX - colRect.left) +
                                    'px; top: ' +
                                    (e.clientY - colRect.top + 4) +
                                    'px;'
                            };
                        });
                        // Column resize: grab a cell's right edge and drag.
                        pv.addEventListener('mousemove', (e) => {
                            this._imgResizeHover(e);
                            this._tableResizeHover(e, pv);
                        });
                        pv.addEventListener('mousedown', (e) => {
                            // Nested-contenteditable blur is unreliable — a click
                            // outside an in-edit pill commits it explicitly, so
                            // the user is never "caught" inside the pill.
                            if (this._editingPill && !this._editingPill.contains(e.target) && this._finishPillEdit) {
                                this._finishPillEdit();
                            }
                            if (this._imgResizeStart(e, pv)) {
                                return;
                            }
                            this._tableResizeStart(e, pv);
                        });
                        // Chip drops staged by the document-level drag listener
                        // execute HERE — pv listeners are the context where DOM
                        // insertion reliably works under LWS.
                        pv.addEventListener('mouseup', () => this._performPendingDropInsert());
                        // Keep keystrokes OURS: Lightning binds "/" (and more) to
                        // global shortcuts via a capture-phase listener high in the
                        // tree, so stopping propagation at the page is too late.
                        // Trap at the window in capture phase — fires before
                        // Lightning's hotkey handler — and stop only events that
                        // originate inside the editable page. preventDefault is
                        // NOT called, so typing itself is untouched.
                        // Synthetic shadow retargets e.target for listeners
                        // outside the component, so the trap can't identify the
                        // canvas from the event — track focus from INSIDE it.
                        pv.addEventListener('focusin', () => {
                            this._canvasFocused = true;
                        });
                        pv.addEventListener('keydown', (e) => {
                            // Open slash menu drives arrows/Enter/Escape.
                            if (this._slashMenuKeydown(e)) {
                                return;
                            }
                            // Track typing recency for the "/" recovery below.
                            // Only content keys — Tab/arrows must not count, or
                            // tabbing away right after typing would false-match.
                            if (e.key && (e.key.length === 1 || e.key === 'Backspace' || e.key === 'Enter')) {
                                this._lastCanvasKeyTs = Date.now();
                            }
                            e.stopPropagation();
                        });
                        // Lightning's "/" global-search hotkey preempts us
                        // completely: its window-capture handler runs first,
                        // preventDefaults, stops propagation (the canvas never
                        // sees the keydown), and focuses the search box. LWS
                        // never delivers window-capture listeners to component
                        // code, so the ONLY reliable signal is the SYMPTOM: a
                        // focusout to the search input (saInput) while the user
                        // was mid-typing with no mouse involved. On that
                        // signature, steal focus back, restore the caret, and
                        // type the "/" the user actually pressed.
                        pv.addEventListener('focusout', (e) => {
                            this._canvasFocused = false;
                            this._canvasBlurTs = Date.now();
                            const rt = e.relatedTarget;
                            const toSearchBox = rt && String(rt.className || '').indexOf('saInput') !== -1;
                            const typedRecently = this._lastCanvasKeyTs && Date.now() - this._lastCanvasKeyTs < 1500;
                            const mousedRecently = this._lastDocMouseTs && Date.now() - this._lastDocMouseTs < 150;
                            if (toSearchBox && typedRecently && !mousedRecently) {
                                // eslint-disable-next-line @lwc/lwc/no-async-operation
                                setTimeout(() => this._recoverStolenSlash(), 120);
                            }
                        });
                        // Distinguishes hotkey focus-theft from a deliberate
                        // click into global search (document listeners DO fire
                        // for component code — see _onSelectionChange).
                        if (!this._docMouseListenerAdded) {
                            this._onDocMouseDown = () => {
                                this._lastDocMouseTs = Date.now();
                            };
                            document.addEventListener('mousedown', this._onDocMouseDown, true);
                            this._docMouseListenerAdded = true;
                        }
                        // Land ready-to-type: focus the page with the caret at
                        // the first text block so the cursor is never a hunt.
                        try {
                            pv.focus();
                            const first = pv.querySelector('p, h1, h2, h3, li, td');
                            if (first) {
                                const r = document.createRange();
                                r.selectNodeContents(first);
                                r.collapse(true);
                                const s = window.getSelection();
                                s.removeAllRanges();
                                s.addRange(r);
                            }
                        } catch (e) {
                            /* focus best-effort */
                        }
                        // Sheet dimensions follow the page setup.
                        this._applyCanvasDimensions();
                        // Word-converted tables with absolute widths can't be
                        // tamed by max-width alone (auto layout won't shrink
                        // below min-content) — refit them onto the sheet.
                        this._fitOversizeTables(pv);
                        // Context label ("Editing: Table cell") follows the caret.
                        if (!this._selListenerAdded) {
                            document.addEventListener('selectionchange', this._onSelectionChange);
                            this._selListenerAdded = true;
                        }
                        // Snapshot AFTER pillify so "unchanged" compares
                        // like-for-like on exit.
                        // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                        this._visualEnteredDom = pv.innerHTML;
                    }
                }
                this._pendingPreviewWrite = null;
            }
        }
    }

    get isStep1() {
        return this.currentWizardStep === '1';
    }
    get isStep2() {
        return this.currentWizardStep === '2';
    }
    get isStep3() {
        return this.currentWizardStep === '3';
    }
    /** Dedicated AI step: prompt + assets + paste-back, no query builder. */
    get isStepAi() {
        return this.currentWizardStep === 'ai';
    }
    get isStepAiOrLater() {
        return this.currentWizardStep !== '1';
    }
    get hideWizardFooterNext() {
        if (this.currentWizardStep === '3' || this.currentWizardStep === 'ai') {
            return true;
        }
        // One place to move forward: on Step 1 the starter/AI paths advance
        // ONLY via their in-card button; the footer Next belongs to the file
        // path. Query refinement lives in the template's Query Configuration
        // tab after creation, not in a parallel wizard branch.
        return this.currentWizardStep === '1' && !this.isAuthoringFile;
    }

    // --- Step-1 declutter: starter/AI paths hide power-user fields ---
    get showStep1AdvancedFields() {
        return this.isAuthoringFile || this.showAdvancedOptions;
    }
    /** Starters bring their own object+query — hide the picker on that path. */
    get showBaseObjectField() {
        return this.isRecordDataSource && (!this.isAuthoringStarter || this.showAdvancedOptions);
    }
    get showAdvancedToggle() {
        return !this.isAuthoringFile;
    }
    get advancedToggleLabel() {
        return this.showAdvancedOptions
            ? 'Hide advanced options'
            : 'Advanced options (API name, category, data source)';
    }
    handleToggleAdvanced() {
        this.showAdvancedOptions = !this.showAdvancedOptions;
    }
    get isBackDisabled() {
        return this.currentWizardStep === '1';
    }
    /** Progress ring value — the AI screen maps to the "Pick Your Data" slot. */
    get wizardProgressStep() {
        return this.currentWizardStep === 'ai' ? '2' : this.currentWizardStep;
    }

    async handleNextStep() {
        if (this.currentWizardStep === '1') {
            if (!this.newTemplateName || !this.newTemplateType) {
                this.showToast('Error', 'Please fill in the template name and type.', 'error');
                return;
            }
            // AI path: skip the query builder entirely. Auto-build a sensible
            // query for the prompt, load shared assets it can reference, and
            // land on the prompt + paste screen.
            if (this.isAuthoringAi && this.dataSourceMode === 'record') {
                if (!this.newTemplateObject) {
                    this.showToast('Pick an object', 'Choose the Base Object this document is about.', 'error');
                    return;
                }
                this.isAutoCreating = true;
                try {
                    if (!(this.newTemplateQuery || '').trim()) {
                        this.newTemplateQuery = await this._buildDefaultQueryConfig(this.newTemplateObject);
                    }
                    await this._loadWizardAssets();
                } finally {
                    this.isAutoCreating = false;
                }
                this._loadWizardQueryMeta();
                this.currentWizardStep = 'ai';
                return;
            }
            if (this.isAuthoringAi && this.dataSourceMode === 'flow') {
                await this._loadWizardAssets();
                this.currentWizardStep = 'ai';
                return;
            }
            // JSON Data (from Flow) data source: no SOQL, no provider class.
            // Skip Step 2 entirely — there's nothing to configure between name
            // and template upload. The FlowJsonData sentinel and v4 marker were
            // stamped at handleDataSourceModeChange time; just advance to upload.
            if (this.dataSourceMode === 'flow') {
                this.useApexProvider = false;
                this.useVisualBuilder = false;
                this.currentWizardStep = '3';
                return;
            }
            // Apex Data Provider data source bypasses the base-object requirement —
            // the provider class supplies its own data shape. We require a class to
            // be selected and validated before advancing, and stamp the v4 config
            // so Step 2 lands directly on the connected-provider view.
            if (this.dataSourceMode === 'apex') {
                if (!this.selectedProviderClassName || !this.hasProviderFields) {
                    this.showToast('Error', 'Please select an Apex Data Provider class first.', 'error');
                    return;
                }
                // Base_Object_API__c is non-nullable downstream. If the user supplied
                // an SObject API name (cross-object aggregation: provider returns data
                // about a specific record type), use it; otherwise fall back to the
                // 'ApexProvider' sentinel that docGenColumnBuilder also emits.
                const apexBase = (this.apexProviderBaseObject || '').trim();
                this.newTemplateObject = apexBase || 'ApexProvider';
                this.useApexProvider = true;
                this.useVisualBuilder = false;
                this.newTemplateQuery = JSON.stringify({ v: 4, provider: this.selectedProviderClassName });
                this.currentWizardStep = '2';
                return;
            }
            if (!this.newTemplateObject) {
                this.showToast('Error', 'Please select a base object.', 'error');
                return;
            }
            // Salesforce Record path — load metadata for step 2 before transitioning.
            this.useApexProvider = false;
            this._loadObjectMetadata(this.newTemplateObject);
            this.currentWizardStep = '2';
        } else if (this.currentWizardStep === '2') {
            // Clean up trailing commas/whitespace
            let q = (this.newTemplateQuery || '').replace(/[\s,]+$/, '').replace(/^[\s,]+/, '');
            this.newTemplateQuery = q;
            const ta = this.template.querySelector('.wizard-query-textarea');
            if (ta) {
                ta.value = q;
            }

            if (!q) {
                this.showToast('Error', 'Please add at least one field to the query.', 'error');
                return;
            }
            this.currentWizardStep = '3';
        }
    }

    handlePrevStep() {
        if (this.currentWizardStep === 'ai') {
            this.currentWizardStep = '1';
        } else if (this.currentWizardStep === '3') {
            // JSON-flow templates skip Step 2 going forward; mirror that going back
            // so the user lands on Step 1 (where they can re-pick the data source).
            this.currentWizardStep = this.dataSourceMode === 'flow' ? '1' : '2';
        } else if (this.currentWizardStep === '2') {
            this.currentWizardStep = '1';
        }
    }

    /** Shared image assets: the ONE image pipeline — wizard logo picker,
     *  designer asset panel, slash menu, and the AI prompt all read this. */
    async _loadWizardAssets() {
        try {
            const assets = (await getAssets()) || [];
            this.wizardAssets = assets.map((a) => ({
                id: a.id,
                name: a.name,
                assetKey: a.assetKey,
                mergeTag: a.mergeTag || '{%asset:' + a.assetKey + '}',
                previewUrl: a.latestVersionCvId ? '/sfc/servlet.shepherd/version/download/' + a.latestVersionCvId : null
            }));
            this._assetUrlByKey = {};
            for (const a of this.wizardAssets) {
                if (a.previewUrl) {
                    this._assetUrlByKey[(a.assetKey || '').toLowerCase()] = a.previewUrl;
                }
            }
            this._imagifyAssetPills();
        } catch (e) {
            this.wizardAssets = [];
        }
    }

    get hasWizardAssets() {
        return (this.wizardAssets || []).length > 0;
    }

    /** Paste step is "3" after the assets step, "2" when there are no assets yet. */
    get aiPasteStepNum() {
        return this.hasWizardAssets ? '3' : '2';
    }

    get aiAssetRows() {
        const sel = this.aiSelectedAssetIds;
        return (this.wizardAssets || []).map((a) => ({
            ...a,
            selected: sel === null ? true : sel.includes(a.id)
        }));
    }

    handleAiAssetToggle(event) {
        const id = event.currentTarget.dataset.id;
        const current =
            this.aiSelectedAssetIds === null
                ? (this.wizardAssets || []).map((a) => a.id)
                : [...this.aiSelectedAssetIds];
        const idx = current.indexOf(id);
        if (idx > -1) {
            current.splice(idx, 1);
        } else {
            current.push(id);
        }
        this.aiSelectedAssetIds = current;
    }

    handleAssetTagCopy(event) {
        const tag = event.currentTarget.dataset.tag;
        if (tag) {
            this._copyToClipboard(tag, tag + ' copied — the AI prompt already lists it too.');
        }
    }

    handleAiPasteChange(event) {
        this._aiPastedHtml = event.target.value;
    }

    /** AI step finale: create the template with the pasted HTML staged as its body. */
    async handleAiCreateFromPaste() {
        const ta = this.template.querySelector('.dg-ai-paste');
        if (ta) {
            this._aiPastedHtml = ta.value;
        }
        this.isAutoCreating = true;
        try {
            await this.createTemplate();
        } finally {
            this.isAutoCreating = false;
        }
    }

    handleWizardTabActive() {
        this.activeMainTab = 'new_template';
        this.resetForm();
        // Existing shared assets feed the logo picker and the AI prompt.
        this._loadWizardAssets();
    }

    handleTabActive(event) {
        this.activeMainTab = event.target.value;
    }

    // --- Create Handlers ---
    handleNameChange(event) {
        this.newTemplateName = event.detail.value;
        if (!this._newApiNameEdited) {
            this.newTemplateApiName = this._deriveApiName(this.newTemplateName);
        }
    }
    handleNewApiNameChange(event) {
        this.newTemplateApiName = (event.detail.value || '').trim();
        // Clearing the field hands control back to auto-derive.
        this._newApiNameEdited = this.newTemplateApiName !== '';
    }
    /** Name → stable key: letters/digits/underscores, no leading digit, max 80. */
    _deriveApiName(name) {
        return (name || '')
            .replace(/[^a-zA-Z0-9]+/g, '_')
            .replace(/^[_0-9]+/, '')
            .replace(/_+$/, '')
            .slice(0, 80);
    }
    handleCategoryChange(event) {
        this.newTemplateCategory = event.detail.value;
    }
    handleTypeChange(event) {
        this.newTemplateType = event.detail.value;
        // Excel only supports Native output — auto-switch from PDF
        if (event.detail.value === 'Excel' && this.newTemplateOutputFormat === 'PDF') {
            this.newTemplateOutputFormat = 'Native';
        }
        if (event.detail.value === 'HTML' || event.detail.value === 'PDF') {
            this.newTemplateOutputFormat = 'PDF';
        }
    }

    // --- HTML-first authoring path ---
    get isAuthoringStarter() {
        return this.newAuthoringMode === 'starter';
    }
    get isAuthoringAi() {
        return this.newAuthoringMode === 'ai';
    }
    get isAuthoringFile() {
        return this.newAuthoringMode === 'file';
    }
    get isAuthoringScratch() {
        return this.newAuthoringMode === 'scratch';
    }

    get authoringCards() {
        const defs = [
            {
                mode: 'starter',
                title: 'Start from a Design',
                badge: 'Recommended',
                icon: 'utility:brush',
                desc: 'Pick a professional starter layout — your fields are dropped in automatically and the template renders on the first click. Creates an HTML template, the most reliable path to pixel-perfect PDFs.'
            },
            {
                mode: 'ai',
                title: 'Generate with AI',
                badge: null,
                icon: 'utility:einstein',
                desc: "We assemble a ready-to-paste prompt with your fields and DocGen's tag syntax. Paste it into Claude, ChatGPT, or Copilot, then paste the HTML it returns straight into the template editor."
            },
            {
                mode: 'scratch',
                title: 'Start From Scratch',
                badge: null,
                icon: 'utility:edit',
                desc: 'A blank page in the visual designer. Click anywhere and type, drag in blocks and merge tags, or hit ` for the insert menu — build the document your way.'
            },
            {
                mode: 'file',
                title: 'I Have an Existing File',
                badge: null,
                icon: 'utility:upload',
                desc: 'Upload a Word, PowerPoint, Excel, fillable PDF, or HTML file you already maintain. Word documents are converted to HTML for PDF output — complex layouts may not convert exactly.'
            }
        ];
        return defs.map((d) => ({
            ...d,
            selected: this.newAuthoringMode === d.mode,
            cardClass:
                this.newAuthoringMode === d.mode ? 'dg-authoring-card dg-authoring-card_selected' : 'dg-authoring-card'
        }));
    }

    get starterCards() {
        return STARTERS.map((s) => ({
            ...s,
            targetObject: STARTER_OBJECTS[s.key] || 'Account',
            selected: this.newStarterKey === s.key,
            cardClass: this.newStarterKey === s.key ? 'dg-starter-card dg-starter-card_selected' : 'dg-starter-card'
        }));
    }

    get selectedStarterLabel() {
        const s = STARTERS.find((x) => x.key === this.newStarterKey);
        return s ? s.label : '';
    }

    handleAuthoringModeSelect(event) {
        const mode = event.currentTarget.dataset.mode;
        if (!mode || mode === this.newAuthoringMode) {
            return;
        }
        this.newAuthoringMode = mode;
        if (mode === 'starter' || mode === 'ai' || mode === 'scratch') {
            this.newTemplateType = 'HTML';
            this.newTemplateOutputFormat = 'PDF';
        } else {
            this.newTemplateType = 'Word';
            this.newTemplateOutputFormat = 'PDF';
        }
    }

    handleAuthoringModeKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleAuthoringModeSelect(event);
        }
    }

    handleStarterSelect(event) {
        this.newStarterKey = event.currentTarget.dataset.key;
        // Predesigned templates carry their natural object — no object picker
        // on this path (Advanced options exposes it for power users).
        if (!this.showAdvancedOptions) {
            const obj = STARTER_OBJECTS[this.newStarterKey] || 'Account';
            if (obj !== this.newTemplateObject) {
                this.newTemplateObject = obj;
                this.newTemplateQuery = '';
                this.newTemplateSampleRecordId = null;
            }
        }
    }

    /** Logo control: pick from the shared asset library — the one image
     *  pipeline. New images are added under the Assets tab. */
    get logoChoiceOptions() {
        const opts = [{ label: 'No logo', value: 'none' }];
        for (const a of this.wizardAssets || []) {
            opts.push({ label: a.name + ' — ' + a.mergeTag, value: a.id });
        }
        return opts;
    }

    get hasNoAssetsYet() {
        return !(this.wizardAssets || []).length;
    }

    /** Thumbnail of the chosen logo asset, shown under the picker. */
    get selectedLogoPreviewUrl() {
        const a = (this.wizardAssets || []).find((x) => x.id === this.newTemplateLogoChoice);
        return a ? a.previewUrl : null;
    }

    handleLogoChoiceChange(event) {
        this.newTemplateLogoChoice = event.detail.value;
    }

    /** Merge tag the starter's logo slots should carry, per the user's choice. */
    get _chosenLogoTag() {
        const choice = this.newTemplateLogoChoice;
        if (choice && choice !== 'none' && choice !== 'upload') {
            const a = (this.wizardAssets || []).find((x) => x.id === choice);
            if (a) {
                return a.mergeTag;
            }
        }
        return '{%asset:logo}';
    }

    handleLogoSelected(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        if (!/\.(png|jpe?g)$/i.test(file.name)) {
            this.showToast('Unsupported logo', 'Use a .png or .jpg image.', 'error');
            event.target.value = '';
            return;
        }
        this._logoFile = file;
        this.newTemplateLogoName = file.name;
    }

    /**
     * The fluid path: name it, pick a design, click once. A sensible Query
     * Config is auto-built from the object's describe (top fields + up to
     * two child relationships), the template is created, the starter body
     * attached, and the designer opens on the finished document.
     */
    async handleCreateAndDesign() {
        if (!this.newTemplateName) {
            this.showToast('Name it first', 'Give the template a name, then create.', 'error');
            return;
        }
        if (this.dataSourceMode === 'record' && !this.newTemplateObject) {
            this.showToast('Pick an object', 'Choose the Base Object this document is about.', 'error');
            return;
        }
        this.isAutoCreating = true;
        try {
            // Predesigned path with the object picker hidden: the starter's
            // natural object drives the auto-built query.
            if (this.isAuthoringStarter && !this.showAdvancedOptions) {
                this.newTemplateObject = STARTER_OBJECTS[this.newStarterKey] || 'Account';
            }
            if (this.dataSourceMode === 'record' && !(this.newTemplateQuery || '').trim()) {
                // Scratch builds get the RICH query — the author picks fields
                // from the palette, so all usable fields must be available.
                this.newTemplateQuery = await this._buildDefaultQueryConfig(
                    this.newTemplateObject,
                    this.isAuthoringScratch
                );
            }
            await this.createTemplate();
        } finally {
            this.isAutoCreating = false;
        }
    }

    /** Sensible default query from the object's describe — refinable later.
     *  rich=true (Start From Scratch): pull EVERY usable field (capped at 40)
     *  and more relationships, so the tag palette isn't a six-field diet. */
    async _buildDefaultQueryConfig(objectApiName, rich) {
        try {
            const [fields, rels] = await Promise.all([
                getObjectFields({ objectName: objectApiName }),
                getChildRelationships({ objectName: objectApiName })
            ]);
            const names = (fields || []).map((f) => f.value);
            const typeOf = {};
            (fields || []).forEach((f) => {
                typeOf[f.value] = f.type;
            });
            const fieldCap = rich ? 40 : 6;
            const PREF = [
                'Name',
                'Industry',
                'Phone',
                'Email',
                'Website',
                'Amount',
                'StageName',
                'CloseDate',
                'Status',
                'Title',
                'Type',
                'Description'
            ];
            const GOOD =
                /^(STRING|CURRENCY|DOUBLE|INTEGER|PERCENT|DATE|DATETIME|EMAIL|PHONE|URL|PICKLIST|TEXTAREA|BOOLEAN)$/;
            const SKIP =
                /^(Id|OwnerId|CreatedById|LastModifiedById|SystemModstamp|IsDeleted|CurrencyIsoCode|Jigsaw.*|CleanStatus|PhotoUrl)$/;
            const chosen = [];
            for (const p of PREF) {
                if (chosen.length < fieldCap && names.includes(p)) {
                    chosen.push(p);
                }
            }
            for (const f of names) {
                if (chosen.length >= fieldCap) {
                    break;
                }
                if (!chosen.includes(f) && !SKIP.test(f) && !f.endsWith('Id') && GOOD.test(typeOf[f] || '')) {
                    chosen.push(f);
                }
            }
            if (!chosen.length) {
                chosen.push('Name');
            }
            const parts = [chosen.join(', ')];
            const RELPREF = ['Contacts', 'Opportunities', 'OpportunityLineItems', 'OrderItems', 'Cases', 'Assets'];
            const NOISE =
                /Histories|Feeds|Shares|Teams|ContentDocumentLinks|ProcessInstances|ActivityHistories|Emails|Events|Tasks|Notes|Attachments|DuplicateRecord|RecordAction|TopicAssign|Vote/i;
            const picked = [];
            const relCap = rich ? 4 : 2;
            const childCap = rich ? 8 : 4;
            for (const rp of RELPREF) {
                const r = (rels || []).find((x) => x.value === rp);
                if (r && picked.length < relCap) {
                    picked.push(r);
                }
            }
            if (rich) {
                for (const r of rels || []) {
                    if (picked.length >= relCap) {
                        break;
                    }
                    if (!picked.includes(r) && !NOISE.test(r.value)) {
                        picked.push(r);
                    }
                }
            }
            if (!picked.length && rels && rels.length) {
                const r = rels.find((x) => !NOISE.test(x.value));
                if (r) {
                    picked.push(r);
                }
            }
            for (const r of picked) {
                try {
                    const cf = await getObjectFields({ objectName: r.childObjectApiName });
                    const cnames = (cf || []).map((f) => f.value);
                    const ctypeOf = {};
                    (cf || []).forEach((f) => {
                        ctypeOf[f.value] = f.type;
                    });
                    const cchosen = [];
                    for (const p of [
                        'Name',
                        'FirstName',
                        'LastName',
                        'Email',
                        'Title',
                        'StageName',
                        'Amount',
                        'CloseDate',
                        'Quantity',
                        'UnitPrice',
                        'TotalPrice',
                        'Subject',
                        'Status'
                    ]) {
                        if (cchosen.length < childCap && cnames.includes(p)) {
                            cchosen.push(p);
                        }
                    }
                    if (rich) {
                        for (const f of cnames) {
                            if (cchosen.length >= childCap) {
                                break;
                            }
                            if (
                                !cchosen.includes(f) &&
                                !SKIP.test(f) &&
                                !f.endsWith('Id') &&
                                GOOD.test(ctypeOf[f] || '')
                            ) {
                                cchosen.push(f);
                            }
                        }
                    }
                    if (cchosen.length) {
                        parts.push('(SELECT ' + cchosen.join(', ') + ' FROM ' + r.value + ')');
                    }
                } catch (e) {
                    /* skip relationship */
                }
            }
            return parts.join(', ');
        } catch (e) {
            return 'Name';
        }
    }

    /** Wizard logo → the shared {%asset:logo} asset every template can use. */
    async _ensureLogoAsset(templateId) {
        if (!this._logoFile) {
            return;
        }
        try {
            const buffer = await this._logoFile.arrayBuffer();
            const cvRes = await saveHtmlTemplateImage({
                templateId,
                fileName: this._logoFile.name,
                base64Content: bytesToBase64(new Uint8Array(buffer))
            });
            const assets = (await getAssets()) || [];
            let logo = assets.find((a) => a.assetKey === 'logo');
            if (!logo) {
                logo = await createAsset({ name: 'Company Logo', assetKey: 'logo' });
            }
            await addAssetVersion({ assetId: logo.id, contentVersionId: cvRes.contentVersionId });
            this.showToast(
                'Logo saved',
                'Stored as the shared asset {%asset:logo} — your starter header uses it, and every future template can too.',
                'success'
            );
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Logo not saved', msg + ' — you can add it later under Assets.', 'warning');
        } finally {
            this._logoFile = null;
            this.newTemplateLogoName = '';
        }
    }

    /** Word→HTML conversion expectation-setting, shown under the Type picker. */
    get showWordConversionNote() {
        return this.isAuthoringFile && this.newTemplateType === 'Word';
    }

    /** v1.90 HTML @page note only applies when the user brings their own HTML file. */
    get showHtmlPageRuleNote() {
        return this.isCreatingHtmlPdf && this.isAuthoringFile;
    }

    get aiAuthoringPrompt() {
        const shape = extractQueryShape(this.newTemplateQuery, this.newTemplateObject);
        const sel = this.aiSelectedAssetIds;
        const assets = sel === null ? this.wizardAssets : (this.wizardAssets || []).filter((a) => sel.includes(a.id));
        return buildAiPrompt(shape, {
            dataSourceMode: this.dataSourceMode,
            providerFields: (this.providerFields || []).map((f) => f.name || f),
            assets,
            docDescription: this.aiDocDescription
        });
    }

    get editAiPrompt() {
        const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
        return buildAiPrompt(shape, {
            dataSourceMode: this.editTemplateObject === 'FlowJsonData' ? 'flow' : 'record',
            providerFields: (this.providerFields || []).map((f) => f.name || f)
        });
    }

    // --- AI-step field checklist (build your query before the prompt) ---
    async _loadWizardQueryMeta() {
        if (this._wizardQueryMetaFor === this.newTemplateObject + '|' + this.newTemplateQuery) {
            return;
        }
        try {
            const [fields, rels] = await Promise.all([
                getObjectFields({ objectName: this.newTemplateObject }),
                getChildRelationships({ objectName: this.newTemplateObject })
            ]);
            const childFieldsByRel = {};
            const shape = extractQueryShape(this.newTemplateQuery, this.newTemplateObject);
            await Promise.all(
                (shape.children || []).map(async (c) => {
                    const rel = (rels || []).find((r) => r.value === c.relationshipName);
                    if (rel) {
                        try {
                            childFieldsByRel[c.relationshipName] = await getObjectFields({
                                objectName: rel.childObjectApiName
                            });
                        } catch (e) {
                            /* skip */
                        }
                    }
                })
            );
            this._wizardQueryMetaFor = this.newTemplateObject + '|' + this.newTemplateQuery;
            this.wizardQueryMeta = { fields: fields || [], rels: rels || [], childFieldsByRel };
        } catch (e) {
            this.wizardQueryMeta = null;
        }
    }

    get aiQuerySections() {
        return this._buildQuerySections(
            this.newTemplateQuery,
            this.newTemplateObject,
            this.wizardQueryMeta,
            this.aiFieldSearch
        );
    }

    get aiQueryFieldCount() {
        const shape = extractQueryShape(this.newTemplateQuery, this.newTemplateObject);
        let n = (shape.baseFields || []).length + (shape.parentFields || []).length;
        for (const c of shape.children || []) {
            n += (c.fields || []).length;
        }
        return n;
    }

    handleAiDescChange(event) {
        this.aiDocDescription = event.target.value || '';
    }

    handleAiFieldSearch(event) {
        this.aiFieldSearch = event.target.value || '';
    }

    async handleAiQueryFieldToggle(event) {
        const res = await this._applyQueryToggle(
            this.newTemplateQuery,
            this.newTemplateObject,
            this.wizardQueryMeta,
            event.currentTarget.dataset,
            event.currentTarget.checked
        );
        if (res.childFields) {
            this.wizardQueryMeta = {
                ...this.wizardQueryMeta,
                childFieldsByRel: { ...this.wizardQueryMeta.childFieldsByRel, [res.rel]: res.childFields }
            };
        }
        this.newTemplateQuery = res.query;
    }

    handleCopyAiPrompt() {
        this._copyToClipboard(this.aiAuthoringPrompt, 'AI prompt copied — paste it into your AI assistant.');
    }

    handleCopyEditAiPrompt() {
        this._copyToClipboard(this.editAiPrompt, 'AI prompt copied — paste it into your AI assistant.');
    }

    _copyToClipboard(text, successMsg) {
        const fallback = () => {
            const ta = document.createElement('textarea');
            ta.value = text;
            ta.style.position = 'fixed';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.select();
            let ok = false;
            try {
                ok = document.execCommand('copy');
            } catch (e) {
                ok = false;
            }
            document.body.removeChild(ta);
            if (ok) {
                this.showToast('Copied', successMsg, 'success');
            } else {
                this.showToast('Copy failed', 'Select the prompt text and copy it manually.', 'warning');
            }
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(
                () => this.showToast('Copied', successMsg, 'success'),
                () => fallback()
            );
        } else {
            fallback();
        }
    }
    handleOutputFormatChange(event) {
        this.newTemplateOutputFormat = event.detail.value;
    }
    handleNewPageOrientationChange(event) {
        this.newTemplatePageOrientation = event.detail.value;
    }
    handleNewPageSizeChange(event) {
        this.newTemplatePageSize = event.detail.value;
    }
    handleNewPageMarginsChange(event) {
        this.newTemplatePageMargins = event.detail.value;
    }
    handleNewCustomMarginsChange(event) {
        this.newTemplateCustomMargins = event.detail.value;
    }
    handleDescChange(event) {
        this.newTemplateDesc = event.detail.value;
    }

    handleConfigChange(event) {
        // The column builder emits 'ApexProvider' as a sentinel object name when in
        // Apex Provider mode. Don't let it clobber a real SObject API name that the
        // user already set in Step 1's "Base Object (optional)" input — needed for
        // cross-object aggregation use cases (issue #62).
        const incoming = event.detail.objectName;
        const haveRealBase = this.newTemplateObject && this.newTemplateObject !== 'ApexProvider';
        if (!(incoming === 'ApexProvider' && haveRealBase)) {
            this.newTemplateObject = incoming;
        }
        this.newTemplateQuery = event.detail.queryConfig;
        this._updateQueryTree();
    }

    toggleVisualBuilder() {
        this.useVisualBuilder = !this.useVisualBuilder;
    }

    toggleEditVisualBuilder() {
        this.editUseVisualBuilder = !this.editUseVisualBuilder;
    }

    handleEditConfigChange(event) {
        // Mirror handleConfigChange's sentinel guard — see comment there.
        const incoming = event.detail.objectName;
        const haveRealBase = this.editTemplateObject && this.editTemplateObject !== 'ApexProvider';
        if (!(incoming === 'ApexProvider' && haveRealBase)) {
            this.editTemplateObject = incoming;
        }
        this.editTemplateQuery = event.detail.queryConfig;
    }

    get visualBuilderToggleIcon() {
        return this.useVisualBuilder ? 'utility:edit' : 'utility:builder';
    }

    get editVisualBuilderToggleIcon() {
        return this.editUseVisualBuilder ? 'utility:edit' : 'utility:builder';
    }

    // ===== APEX DATA PROVIDER (V4) — wizard + edit modal =====

    toggleApexProvider() {
        this.useApexProvider = !this.useApexProvider;
        if (this.useApexProvider) {
            // Mutually exclusive with the visual builder.
            this.useVisualBuilder = false;
            this._loadProviderStateFromQuery(this.newTemplateQuery);
        } else {
            // Switching off clears the v4 binding so the user starts fresh on
            // the manual/visual paths instead of editing a stale provider config.
            this._clearApexProviderState();
            this.newTemplateQuery = '';
        }
    }

    toggleEditApexProvider() {
        this.editUseApexProvider = !this.editUseApexProvider;
        if (this.editUseApexProvider) {
            this.editUseVisualBuilder = false;
            this._loadProviderStateFromQuery(this.editTemplateQuery);
        } else {
            this._clearApexProviderState();
            this.editTemplateQuery = '';
        }
    }

    _loadProviderStateFromQuery(query) {
        // Auto-detect when an existing template already has a v4 config so the
        // picker shows the bound class on first render.
        try {
            const cfg = query ? JSON.parse(query) : null;
            if (cfg && cfg.v === 4 && cfg.provider) {
                this.selectedProviderClassName = cfg.provider;
                this.providerSearchTerm = cfg.provider;
                this._validateAndLoadProviderFields(cfg.provider);
                return;
            }
        } catch (e) {
            /* not JSON — manual or v1 */
        }
        this._clearApexProviderState();
    }

    _clearApexProviderState() {
        this.selectedProviderClassName = '';
        this.providerSearchTerm = '';
        this.providerOptions = [];
        this.providerFields = [];
        this.showProviderPicker = false;
        this.isValidatingProvider = false;
        this.apexProviderBaseObject = '';
    }

    handleApexProviderBaseObjectChange(event) {
        this.apexProviderBaseObject = (event.detail ? event.detail.value : event.target.value) || '';
    }

    handleApexProviderSearch(event) {
        const term = event.target.value || '';
        this.providerSearchTerm = term;
        if (term.length < 2) {
            this.showProviderPicker = false;
            this.providerOptions = [];
            return;
        }
        this.showProviderPicker = true;
        searchDataProviders({ searchTerm: term })
            .then((data) => {
                this.providerOptions = data || [];
            })
            .catch(() => {
                this.providerOptions = [];
            });
    }

    handleApexProviderSelect(event) {
        const className = event.currentTarget.dataset.value;
        if (!className) {
            return;
        }
        this.providerSearchTerm = className;
        this.showProviderPicker = false;
        this._validateAndLoadProviderFields(className);
    }

    _validateAndLoadProviderFields(className) {
        this.isValidatingProvider = true;
        validateDataProvider({ className })
            .then((result) => {
                this.isValidatingProvider = false;
                if (result && result.valid) {
                    this.selectedProviderClassName = className;
                    this.providerFields = result.fields || [];
                    const v4Config = JSON.stringify({ v: 4, provider: className });
                    // Drive whichever query field is in scope (wizard vs edit modal).
                    if (this._editContext) {
                        this.editTemplateQuery = v4Config;
                    } else {
                        this.newTemplateQuery = v4Config;
                    }
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Provider Connected',
                            message: className + ' — ' + this.providerFields.length + ' fields available',
                            variant: 'success'
                        })
                    );
                } else {
                    this.providerFields = [];
                    this.selectedProviderClassName = '';
                    const msg = result && result.error ? result.error : 'Class is not a valid DocGenDataProvider.';
                    this.dispatchEvent(
                        new ShowToastEvent({ title: 'Invalid Provider', message: msg, variant: 'error' })
                    );
                }
            })
            .catch((err) => {
                this.isValidatingProvider = false;
                const msg =
                    err && err.body && err.body.message
                        ? err.body.message
                        : (err && err.message) || 'Validation failed';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
            });
    }

    handleClearApexProvider() {
        this._clearApexProviderState();
        if (this._editContext) {
            this.editTemplateQuery = '';
        } else {
            this.newTemplateQuery = '';
        }
    }

    get apexProviderToggleLabel() {
        return this.useApexProvider ? 'Switch to manual / visual' : 'Use Apex data provider';
    }

    get editApexProviderToggleLabel() {
        return this.editUseApexProvider ? 'Switch to manual / visual' : 'Use Apex data provider';
    }

    get hasProviderFields() {
        return this.providerFields && this.providerFields.length > 0;
    }

    get providerTagPills() {
        return (this.providerFields || []).map((f) => ({ tag: '{' + f + '}', raw: f }));
    }

    get isProviderConnected() {
        return Boolean(this.selectedProviderClassName) && this.hasProviderFields;
    }

    // ===== Step 1 data-source choice =====

    handleDataSourceModeChange(event) {
        const mode = event.target.value;
        this.dataSourceMode = mode;
        if (mode === 'apex') {
            // Reset record-related state so the wizard's mental model is clean.
            this.newTemplateObject = '';
            this.newTemplateSampleRecordId = '';
            this.sampleRecordData = null;
            // Pre-flip Apex Provider mode so Step 2 lands on the right pane.
            this.useApexProvider = true;
            this.useVisualBuilder = false;
        } else if (mode === 'flow') {
            // JSON-from-Flow: no SOQL, no provider class. Stamp the FlowJsonData
            // sentinel into Base_Object_API__c so the record-page launcher's
            // WHERE Base_Object_API__c = :objectApiName filter naturally excludes
            // these — they're only invokable via DocGenFlowAction.jsonData.
            this.useApexProvider = false;
            this._clearApexProviderState();
            this.newTemplateObject = 'FlowJsonData';
            this.newTemplateSampleRecordId = '';
            this.sampleRecordData = null;
            this.newTemplateQuery = JSON.stringify({ v: 4, source: 'flowJsonData' });
        } else {
            this.useApexProvider = false;
            this._clearApexProviderState();
            // Restore default object so the next "advance to Step 2" doesn't error
            // out before the user re-picks one. Don't carry the FlowJsonData
            // sentinel forward if the user switches back to Record mode.
            if (!this.newTemplateObject || this.newTemplateObject === 'FlowJsonData') {
                this.newTemplateObject = 'Account';
            }
        }
    }

    get dataSourceModeOptions() {
        return [
            { label: 'Salesforce Record (SOQL)', value: 'record' },
            { label: 'Apex Class (Data Provider)', value: 'apex' },
            { label: 'JSON Data (from Flow)', value: 'flow' }
        ];
    }

    get isRecordDataSource() {
        return this.dataSourceMode === 'record';
    }
    get isApexDataSource() {
        return this.dataSourceMode === 'apex';
    }
    get isFlowDataSource() {
        return this.dataSourceMode === 'flow';
    }

    // Edit-modal companion: the modal doesn't have a separate dataSourceMode
    // toggle (since data-source choice is set at creation time), so detect
    // the FlowJsonData sentinel directly off editTemplateObject.
    get isEditFlowDataSource() {
        return this.editTemplateObject === 'FlowJsonData';
    }
    get editBaseObjectDisplay() {
        if (this.editTemplateObject === 'FlowJsonData') return 'JSON Data (from Flow)';
        if (this.editTemplateObject === 'ApexProvider') return 'Apex Data Provider';
        return this.editTemplateObject;
    }

    get readableQueryConfig() {
        return this._formatQueryConfig(this.newTemplateQuery);
    }

    get readableEditQueryConfig() {
        return this._formatQueryConfig(this.editTemplateQuery);
    }

    get isV3Query() {
        const q = this.newTemplateQuery;
        return q && q.trim().startsWith('{') && q.includes('"v":3');
    }

    get isEditV3Query() {
        const q = this.editTemplateQuery;
        return q && q.trim().startsWith('{') && q.includes('"v":3');
    }

    _formatQueryConfig(configStr) {
        if (!configStr) {
            return '';
        }
        try {
            const cfg = JSON.parse(configStr);
            if (cfg.v !== 3 || !cfg.nodes) {
                return configStr;
            }

            const root = cfg.nodes.find((n) => !n.parentNode);
            if (!root) {
                return configStr;
            }

            // Recursively build subqueries — supports any depth
            const buildSubqueries = (parentId) => {
                const children = cfg.nodes.filter((n) => n.parentNode === parentId);
                const subs = [];
                for (const child of children) {
                    const subFields = [...(child.fields || []), ...(child.parentFields || [])];
                    // Recurse: grandchildren become nested subqueries
                    const nestedSubs = buildSubqueries(child.id);
                    subFields.push(...nestedSubs);
                    if (subFields.length === 0) {
                        subFields.push('Id');
                    }
                    let sq = '(SELECT ' + subFields.join(', ') + ' FROM ' + child.relationshipName;
                    if (child.where) {
                        sq += ' WHERE ' + child.where;
                    }
                    if (child.orderBy) {
                        sq += ' ORDER BY ' + child.orderBy;
                    }
                    if (child.limit) {
                        sq += ' LIMIT ' + child.limit;
                    }
                    sq += ')';
                    subs.push(sq);
                }
                return subs;
            };

            const parts = [...(root.fields || []), ...(root.parentFields || []), ...buildSubqueries(root.id)];

            return parts.join(', ');
        } catch {
            return configStr;
        }
    }

    handleNewQueryStringChange(event) {
        this.newTemplateQuery = event.detail ? event.detail.value : event.target.value;
    }

    handleSampleRecordChange(event) {
        this.newTemplateSampleRecordId = event.detail.recordId || '';
        this._loadSampleData();
    }

    _loadSampleData() {
        const recordId = this._activeSampleId;
        const objectName = this._activeObject;
        const query = this._activeQuery;
        if (!recordId || !objectName || !query) {
            this.sampleRecordData = null;
            return;
        }
        previewRecordData({
            recordId: recordId,
            baseObject: objectName,
            queryConfig: query
        })
            .then((data) => {
                this.sampleRecordData = data;
                this._updateQueryTree();
            })
            .catch(() => {
                this.sampleRecordData = null;
            });
    }

    handleObjectSearchInput(event) {
        const term = (event.detail ? event.detail.value : event.target.value) || '';
        this.newTemplateObject = term;
        if (term.length >= 2) {
            if (this.objectOptions.length === 0) {
                getObjectOptions().then((data) => {
                    this.objectOptions = data;
                    this._filterObjects(term);
                });
            } else {
                this._filterObjects(term);
            }
        } else {
            this.showObjectSuggestions = false;
        }
    }

    _filterObjects(term) {
        const t = term.toLowerCase();
        const matches = this.objectOptions.filter(
            (o) => o.label.toLowerCase().includes(t) || o.value.toLowerCase().includes(t)
        );

        // Rank: exact API/label match → standard prefix match → label prefix → API prefix → contains.
        // Surfaces standard Opportunity above payment-processor lookalikes when the user types
        // "opportunity" in an org with 30+ namespaced Opportunity_* custom objects (Sprint NY 2026 feedback).
        const isStandard = (apiName) => !apiName.includes('__');
        const score = (o) => {
            const lbl = o.label.toLowerCase();
            const api = o.value.toLowerCase();
            if (api === t || lbl === t) return 0;
            if (api.startsWith(t) && isStandard(o.value)) return 1;
            if (lbl.startsWith(t) && isStandard(o.value)) return 2;
            if (api.startsWith(t)) return 3;
            if (lbl.startsWith(t)) return 4;
            if (isStandard(o.value)) return 5;
            return 6;
        };
        matches.sort((a, b) => {
            const sa = score(a);
            const sb = score(b);
            if (sa !== sb) return sa - sb;
            return a.label.localeCompare(b.label);
        });

        this.filteredObjectOptions = matches.slice(0, 50).map((o) => ({
            ...o,
            isStandard: !o.value.includes('__')
        }));
        this.showObjectSuggestions = this.filteredObjectOptions.length > 0;
    }

    handleObjectSuggestionClick(event) {
        const apiName = event.currentTarget.dataset.value;
        this.newTemplateObject = apiName;
        this.showObjectSuggestions = false;
        this._loadObjectMetadata(apiName);
    }

    _loadObjectMetadata(objectName) {
        // Load fields, children, and parents in parallel for slash commands
        getObjectFields({ objectName })
            .then((data) => {
                this._allFields = data || [];
            })
            .catch(() => {
                this._allFields = [];
            });
        // #161 — updateable-only list for Signer Inputs writeback targets.
        getUpdateableObjectFields({ objectName })
            .then((data) => {
                this._allUpdateableFields = data || [];
            })
            .catch(() => {
                this._allUpdateableFields = [];
            });
        getChildRelationships({ objectName })
            .then((data) => {
                this._allChildren = data || [];
            })
            .catch(() => {
                this._allChildren = [];
            });
        getParentRelationships({ objectName })
            .then((data) => {
                this._allParents = data || [];
            })
            .catch(() => {
                this._allParents = [];
            });
    }

    // --- Live Query Tree ---
    _updateQueryTree() {
        const q = (this._activeQuery || '').trim();
        if (!q || !this._activeObject) {
            this.queryTreeNodes = [];
            return;
        }
        try {
            const nodes = [];
            const data = this.sampleRecordData || {};
            // V3 JSON: convert to a parsed-like shape so the rest of the
            // tree-builder works unchanged. Filtered-subset slots surface
            // their alias on the loop label so they're distinguishable.
            let parsed;
            if (q.startsWith('{') && q.includes('"v":3')) {
                const cfg = JSON.parse(q);
                const root = (cfg.nodes || []).find((n) => !n.parentNode) || {};
                const buildSubs = (parentId) => {
                    const kids = (cfg.nodes || []).filter((n) => n.parentNode === parentId);
                    return kids.map((k) => ({
                        relationshipName: k.alias || k.relationshipName,
                        fields: [...(k.fields || []), ...(k.parentFields || [])],
                        whereClause: k.where || '',
                        children: buildSubs(k.id)
                    }));
                };
                parsed = {
                    baseFields: root.fields || [],
                    parentFields: root.parentFields || [],
                    subqueries: buildSubs(root.id),
                    warnings: []
                };
            } else {
                parsed = parseSOQLFields(q);
            }
            this.queryWarnings = parsed.warnings.length > 0 ? parsed.warnings : null;
            const directFields = parsed.baseFields;
            const parentFields = parsed.parentFields;

            // Build field display with sample values
            const fieldPills = directFields.map((f) => {
                const val = data[f];
                return { key: f, name: f, sample: val != null ? String(val) : '' };
            });
            const parentPills = parentFields.map((f) => {
                // Resolve dot notation: "Owner.Name" → data.Owner.Name
                const parts = f.split('.');
                let val = data;
                for (const p of parts) {
                    val = val && typeof val === 'object' ? val[p] : undefined;
                }
                return { key: f, name: f, sample: val != null ? String(val) : '' };
            });

            // Flatten child subqueries recursively into a single list with depth
            // so the template can render any nesting level with one for:each
            const flatChildren = [];
            const flattenChildren = (subqueries, depth) => {
                for (let i = 0; i < subqueries.length; i++) {
                    const sq = subqueries[i];
                    const directF = sq.fields.filter((f) => !f.includes('.'));
                    const parentF = sq.fields.filter((f) => f.includes('.'));
                    flatChildren.push({
                        id: 'child_' + flatChildren.length,
                        label: sq.relationshipName,
                        fields: directF,
                        parentFields: parentF,
                        hasParentFields: parentF.length > 0,
                        fieldCount: sq.fields.length,
                        where: sq.whereClause || '',
                        depth,
                        indentStyle:
                            'margin-left: ' +
                            depth * 20 +
                            'px; margin-bottom: 6px; padding: 8px 10px; background: #fff; border: 1px solid #e5e5e5; border-radius: 6px;'
                    });
                    if (sq.children && sq.children.length > 0) {
                        flattenChildren(sq.children, depth + 1);
                    }
                }
            };
            flattenChildren(parsed.subqueries, 0);

            nodes.push({
                id: 'root',
                label: this._activeObject,
                icon: 'standard:account',
                isRoot: true,
                fields: directFields,
                parentFields: parentFields,
                fieldPills: fieldPills,
                parentPills: parentPills,
                flatChildren: flatChildren,
                hasFields: fieldPills.length > 0,
                hasParentFields: parentPills.length > 0,
                hasFlatChildren: flatChildren.length > 0
            });
            this.queryTreeNodes = nodes;
        } catch (err) {
            // eslint-disable-line no-unused-vars
            this.queryTreeNodes = [];
        }
    }

    // --- Edit Handlers ---
    handleEditNameChange(event) {
        this.editTemplateName = event.detail.value;
    }
    handleEditCategoryChange(event) {
        this.editTemplateCategory = event.detail.value;
    }
    handleEditTypeChange(event) {
        this.editTemplateType = event.detail.value;
        if (event.detail.value === 'Excel' && this.editTemplateOutputFormat === 'PDF') {
            this.editTemplateOutputFormat = 'Native';
        }
        if (event.detail.value === 'HTML' || event.detail.value === 'PDF') {
            this.editTemplateOutputFormat = 'PDF';
        }
    }
    handleEditHeaderHtmlChange(event) {
        this.editTemplateHeaderHtml = event.detail.value;
    }
    handleEditFooterHtmlChange(event) {
        this.editTemplateFooterHtml = event.detail.value;
    }
    toggleHeaderHtmlSource() {
        this.showHeaderHtmlSource = !this.showHeaderHtmlSource;
    }
    toggleFooterHtmlSource() {
        this.showFooterHtmlSource = !this.showFooterHtmlSource;
    }
    get headerSourceToggleLabel() {
        return this.showHeaderHtmlSource ? 'Show Editor' : 'Show HTML';
    }
    get footerSourceToggleLabel() {
        return this.showFooterHtmlSource ? 'Show Editor' : 'Show HTML';
    }
    handleEditOutputFormatChange(event) {
        this.editTemplateOutputFormat = event.detail.value;
    }
    handleEditPageOrientationChange(event) {
        this.editTemplatePageOrientation = event.detail.value;
    }
    handleEditPageSizeChange(event) {
        this.editTemplatePageSize = event.detail.value;
    }
    handleEditPageMarginsChange(event) {
        this.editTemplatePageMargins = event.detail.value;
    }
    handleEditCustomMarginsChange(event) {
        this.editTemplateCustomMargins = event.detail.value;
    }
    handleEditDescChange(event) {
        this.editTemplateDesc = event.detail.value;
    }
    handleEditActiveChange(event) {
        this.editTemplateIsActive = event.target.checked;
    }
    handleEditDefaultChange(event) {
        this.editTemplateIsDefault = event.target.checked;
    }
    // 1.47 — runner visibility & sort handlers
    handleEditSortOrderChange(event) {
        this.editTemplateSortOrder = event.detail.value;
    }
    handleEditLockOutputChange(event) {
        this.editTemplateLockOutputFormat = event.target.checked;
    }
    handleEditSpecificRecordIdsChange(event) {
        this.editTemplateSpecificRecordIds = event.detail.value;
    }
    handleEditRequiredPermSetsChange(event) {
        this.editTemplateRequiredPermissionSets = event.detail.value;
    }
    handleEditRecordFilterChange(event) {
        this.editTemplateRecordFilter = event.detail.value;
        this.editTemplateRecordFilterResult = '';
        this.editTemplateRecordFilterResultMessage = '';
    }

    async handleTestRecordFilter() {
        if (!this.editTemplateRecordFilter || !this.editTemplateTestRecordId || !this.editTemplateObject) {
            this.editTemplateRecordFilterResult = 'error';
            this.editTemplateRecordFilterResultMessage =
                'Need Base Object, Sample Test Record Id (set on the template), and a Record Filter clause to test.';
            return;
        }
        this.editTemplateRecordFilterTesting = true;
        this.editTemplateRecordFilterResult = '';
        this.editTemplateRecordFilterResultMessage = '';
        try {
            const res = await testRecordFilter({
                baseObjectApiName: this.editTemplateObject,
                sampleRecordId: this.editTemplateTestRecordId,
                whereClause: this.editTemplateRecordFilter
            });
            if (res.error) {
                this.editTemplateRecordFilterResult = 'error';
                this.editTemplateRecordFilterResultMessage = res.error;
            } else if (res.matched) {
                this.editTemplateRecordFilterResult = 'matched';
                this.editTemplateRecordFilterResultMessage =
                    '✓ Match — this template would appear for the test record.';
            } else {
                this.editTemplateRecordFilterResult = 'nomatch';
                this.editTemplateRecordFilterResultMessage =
                    '✗ No match — the test record does not satisfy this filter.';
            }
        } catch (e) {
            this.editTemplateRecordFilterResult = 'error';
            this.editTemplateRecordFilterResultMessage = e.body && e.body.message ? e.body.message : e.message;
        } finally {
            this.editTemplateRecordFilterTesting = false;
        }
    }

    get recordFilterResultClass() {
        if (this.editTemplateRecordFilterResult === 'matched') return 'slds-text-color_success slds-var-m-top_x-small';
        if (this.editTemplateRecordFilterResult === 'nomatch') return 'slds-text-color_weak slds-var-m-top_x-small';
        if (this.editTemplateRecordFilterResult === 'error') return 'slds-text-color_error slds-var-m-top_x-small';
        return 'slds-hide';
    }

    handleQueryTabActive() {
        // lightning-tab lazy-renders content — sync textarea when query tab first activates
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const ta = this.template.querySelector('.edit-query-textarea');
            if (ta && this.editTemplateQuery && ta.value !== this.editTemplateQuery) {
                ta.value = this.editTemplateQuery;
            }
            this._updateQueryTree();
        }, 50);
    }

    handleManualQueryToggle(event) {
        this.isManualQuery = event.target.checked;
        // Keep editTemplateQuery as-is when toggling. Earlier behavior converted
        // V3→V1 here, which silently dropped filtered-subset alias slots that V1
        // SOQL can't express. Manual textarea uses the readable getter for
        // display when the user wants a V1 view.
    }

    handleQueryStringChange(event) {
        this.editTemplateQuery = event.target.value;
    }

    handleEditDirectQueryEdit(event) {
        this.editTemplateQuery = event.target.value;
        this._updateQueryTree();
        this._updateSuggestions(event.target);
        clearTimeout(this._sampleDebounce);
        this._sampleDebounce = setTimeout(() => {
            this._loadSampleData();
        }, 800);
    }

    handleEditConfigChange(event) {
        // Mirror handleConfigChange's sentinel guard — see comment there.
        const incoming = event.detail.objectName;
        const haveRealBase = this.editTemplateObject && this.editTemplateObject !== 'ApexProvider';
        if (!(incoming === 'ApexProvider' && haveRealBase)) {
            this.editTemplateObject = incoming;
        }
        this.editTemplateQuery = event.detail.queryConfig;
    }

    /**
     * Strips outer SELECT and FROM clauses from a query config string.
     * Delegates to the shared stripOuterSelectFrom utility in docGenUtils.
     */
    _sanitizeQueryConfig(queryConfig) {
        if (!queryConfig) return queryConfig;
        const cleaned = queryConfig.trim();
        if (cleaned.startsWith('{')) return cleaned;
        return stripOuterSelectFrom(cleaned);
    }

    // ============================================================
    // #161 — Signer Inputs (form fields with optional record writeback)
    // ------------------------------------------------------------
    // Rows live as parsed.formFields on the editTemplateQuery JSON:
    //   { key, label, fieldApiName, type, required, writeback, mergeTag,
    //     choices, listOnCertificate }
    // `key` is a stable [A-Za-z0-9_]+ id generated once and NEVER reused after
    // delete; `mergeTag` is `{?<key>}` and never changes when the label is edited.
    // ============================================================

    get signerFieldTypeOptions() {
        return [
            { label: 'Text', value: 'text' },
            { label: 'Number', value: 'number' },
            { label: 'Date', value: 'date' },
            { label: 'Checkbox', value: 'checkbox' },
            { label: 'Picklist', value: 'picklist' }
        ];
    }

    // Capture-or-writeback field pickers, keyed off the edit template object.
    get signerFieldMappedOptions() {
        return [
            { label: '— Not mapped (capture only) —', value: '' },
            ...(this._allFields || []).map((f) => ({ label: f.label, value: f.value }))
        ];
    }
    get signerFieldWritebackOptions() {
        return [
            { label: '— Select a field to write back —', value: '' },
            ...(this._allUpdateableFields || []).map((f) => ({ label: f.label, value: f.value }))
        ];
    }

    // View-model rows for the table template. Picks the right field-picker
    // option set per row (writeback rows must only offer updateable fields).
    get signerFieldRows() {
        return (this.signerFields || []).map((row, index) => ({
            key: row.key,
            index,
            label: row.label || '',
            fieldApiName: row.fieldApiName || '',
            type: row.type || 'text',
            required: !!row.required,
            writeback: !!row.writeback,
            listOnCertificate: !!row.listOnCertificate,
            mergeTag: row.mergeTag || this._buildSignerMergeTag(row.key),
            choicesText: Array.isArray(row.choices) ? row.choices.join(', ') : row.choices || '',
            isPicklist: (row.type || 'text') === 'picklist',
            fieldOptions: row.writeback ? this.signerFieldWritebackOptions : this.signerFieldMappedOptions,
            isFirst: index === 0,
            isLast: index === (this.signerFields || []).length - 1
        }));
    }

    get hasSignerFields() {
        return (this.signerFields || []).length > 0;
    }

    _buildSignerMergeTag(key) {
        return '{?' + key + '}';
    }

    // Stable, collision-free [A-Za-z0-9_]+ key. Slugifies the label as a seed but
    // ALWAYS appends a short unique suffix so renaming the label can never produce
    // a key already in use (and so the merge tag stays unique).
    _generateSignerFieldKey(seedLabel) {
        const existing = new Set((this.signerFields || []).map((f) => f.key));
        const base =
            String(seedLabel || 'field')
                .replace(/[^A-Za-z0-9_]+/g, '_')
                .replace(/^_+|_+$/g, '')
                .slice(0, 30) || 'field';
        let candidate;
        let i = 0;
        do {
            const suffix = Math.random().toString(36).slice(2, 6);
            candidate = (base + '_' + suffix).replace(/__+/g, '_');
            i++;
        } while (existing.has(candidate) && i < 50);
        return candidate;
    }

    // Parse the dedicated Form_Fields_Config__c JSON (shape `{formFields:[...]}`)
    // into signerFields. Independent of Query_Config__c, so it works for EVERY
    // template type (V1 flat-string, V3/V4 JSON, Apex provider) — no gate.
    _hydrateSignerFields() {
        let rows = [];
        const cfg = (this.editFormFieldsConfig || '').trim();
        if (cfg.startsWith('{')) {
            try {
                const parsed = JSON.parse(cfg);
                if (Array.isArray(parsed.formFields)) {
                    rows = parsed.formFields.map((f) => ({
                        key: f.key,
                        label: f.label || '',
                        fieldApiName: f.fieldApiName || '',
                        type: f.type || 'text',
                        required: !!f.required,
                        writeback: !!f.writeback,
                        mergeTag: f.mergeTag || this._buildSignerMergeTag(f.key),
                        choices: Array.isArray(f.choices) ? f.choices : [],
                        listOnCertificate: !!f.listOnCertificate
                    }));
                }
            } catch (e) {
                /* malformed / empty config — no form fields */
            }
        }
        this.signerFields = rows;
    }

    // Serialize the current signerFields into the dedicated Form_Fields_Config__c
    // JSON string. NEVER touches editTemplateQuery — form fields no longer live on
    // Query_Config__c, so this works regardless of the template's query shape.
    _persistSignerFields() {
        const serialized = (this.signerFields || []).map((f) => ({
            key: f.key,
            label: f.label || '',
            fieldApiName: f.fieldApiName || '',
            type: f.type || 'text',
            required: !!f.required,
            writeback: !!f.writeback,
            mergeTag: f.mergeTag || this._buildSignerMergeTag(f.key),
            choices: Array.isArray(f.choices) ? f.choices : [],
            listOnCertificate: !!f.listOnCertificate
        }));
        this.editFormFieldsConfig = JSON.stringify({ formFields: serialized });
    }

    handleAddSignerField() {
        const label = 'New Field';
        const key = this._generateSignerFieldKey(label);
        this.signerFields = [
            ...(this.signerFields || []),
            {
                key,
                label,
                fieldApiName: '',
                type: 'text',
                required: false,
                writeback: false,
                mergeTag: this._buildSignerMergeTag(key),
                choices: [],
                listOnCertificate: false
            }
        ];
        this._persistSignerFields();
    }

    handleRemoveSignerField(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index)) return;
        this.signerFields = (this.signerFields || []).filter((_, i) => i !== index);
        this._persistSignerFields();
    }

    handleMoveSignerFieldUp(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index) || index <= 0) return;
        const rows = [...this.signerFields];
        [rows[index - 1], rows[index]] = [rows[index], rows[index - 1]];
        this.signerFields = rows;
        this._persistSignerFields();
    }

    handleMoveSignerFieldDown(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index) || index >= this.signerFields.length - 1) return;
        const rows = [...this.signerFields];
        [rows[index + 1], rows[index]] = [rows[index], rows[index + 1]];
        this.signerFields = rows;
        this._persistSignerFields();
    }

    // Generic per-row update — never touches key/mergeTag (label edits are safe).
    _updateSignerFieldRow(index, patch) {
        if (Number.isNaN(index)) return;
        this.signerFields = (this.signerFields || []).map((row, i) => (i === index ? { ...row, ...patch } : row));
        this._persistSignerFields();
    }

    handleSignerFieldLabelChange(event) {
        // Label edits must NOT change key/mergeTag.
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), {
            label: event.detail ? event.detail.value : event.target.value
        });
    }

    handleSignerFieldMappedChange(event) {
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), {
            fieldApiName: (event.detail ? event.detail.value : event.target.value) || ''
        });
    }

    handleSignerFieldTypeChange(event) {
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), {
            type: event.detail ? event.detail.value : event.target.value
        });
    }

    handleSignerFieldRequiredChange(event) {
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), {
            required: event.detail ? event.detail.checked : event.target.checked
        });
    }

    handleSignerFieldWritebackChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const writeback = event.detail ? event.detail.checked : event.target.checked;
        // Toggling writeback swaps the field-picker option set; clear the mapped
        // field so a stale (possibly non-updateable) selection can't leak through.
        this._updateSignerFieldRow(index, { writeback, fieldApiName: '' });
    }

    handleSignerFieldChoicesChange(event) {
        const raw = event.detail ? event.detail.value : event.target.value;
        const choices = String(raw || '')
            .split(',')
            .map((s) => s.trim())
            .filter((s) => s.length > 0);
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), { choices });
    }

    handleSignerFieldCertificateChange(event) {
        this._updateSignerFieldRow(Number(event.currentTarget.dataset.index), {
            listOnCertificate: event.detail ? event.detail.checked : event.target.checked
        });
    }

    handleEditTestRecordChange(event) {
        this.editTemplateTestRecordId = event.detail.recordId;
        this._loadSampleData();
    }

    // Generate a flat tag list from the query config for the tags view
    get editTemplateTags() {
        const qc = this.editTemplateQuery;
        if (!qc) return null;

        try {
            // Try JSON v3 / v4
            if (qc.trim().startsWith('{')) {
                const config = JSON.parse(qc);

                // V4 (Apex Data Provider) — fields come from the bound class's
                // getFieldNames(), which we cached in providerFields when the
                // modal opened. The list uses '#Foo'/'/Foo' to mark loop
                // boundaries and 'Foo.Field' for parent / loop-row fields.
                if (config.v === 4 && config.provider) {
                    return this._buildV4TagSections(config.provider, this.providerFields || []);
                }

                if (config.v >= 3 && config.nodes) {
                    const sections = [];
                    for (const node of config.nodes) {
                        const tags = [];
                        if (node.fields) {
                            for (const f of node.fields) {
                                tags.push({ code: '{' + f + '}' });
                            }
                        }
                        if (node.parentFields) {
                            for (const pf of node.parentFields) {
                                tags.push({ code: '{' + pf + '}' });
                            }
                        }
                        const isLoop = !!node.parentNode;
                        // Loop tag uses alias when present (filtered subset
                        // distinguishes itself by alias, not relationshipName).
                        const loopName = node.alias || node.relationshipName;
                        sections.push({
                            name: node.object + (isLoop ? ' (loop' + (node.alias ? ' — ' + node.alias : '') + ')' : ''),
                            isLoop,
                            loopStart: isLoop ? '{#' + loopName + '}' : '',
                            loopEnd: isLoop ? '{/' + loopName + '}' : '',
                            tags
                        });
                    }
                    return sections.length > 0 ? sections : null;
                }
            }

            // V1 / full SOQL: parse using shared nesting-aware parser
            const parsed = parseSOQLFields(qc);
            const sections = [];

            const buildTagSections = (subqueries) => {
                for (const sq of subqueries) {
                    sections.push({
                        name: sq.relationshipName,
                        isLoop: true,
                        loopStart: '{#' + sq.relationshipName + '}',
                        loopEnd: '{/' + sq.relationshipName + '}',
                        tags: sq.fields.filter((f) => f).map((f) => ({ code: '{' + f + '}' }))
                    });
                    if (sq.children && sq.children.length > 0) {
                        buildTagSections(sq.children);
                    }
                }
            };

            const baseFields = [...parsed.baseFields, ...parsed.parentFields];
            buildTagSections(parsed.subqueries);

            if (baseFields.length > 0) {
                sections.unshift({
                    name: this.editTemplateObject || 'Base Fields',
                    isLoop: false,
                    tags: baseFields.map((f) => ({ code: '{' + f + '}' }))
                });
            }

            return sections.length > 0 ? sections : null;
        } catch {
            return null;
        }
    }

    /**
     * Builds Copy-Paste Tags sections for a v4 Apex Data Provider template.
     * Walks the provider's getFieldNames() output and groups by:
     *   - Bare names (e.g. "Name", "Industry") → "Provider fields"
     *   - Dotted names (e.g. "Owner.Name") → grouped by parent → "Owner"
     *   - "#Foo" / "/Foo" markers + "Foo.Field" → loop section "Foo"
     * Falls back gracefully if providerFields hasn't loaded yet.
     */
    _buildV4TagSections(providerName, fields) {
        if (!fields || fields.length === 0) {
            // Provider not yet validated — show a placeholder so the tab isn't
            // empty. The fields populate after _validateAndLoadProviderFields runs.
            return [
                {
                    name: providerName + ' (loading…)',
                    isLoop: false,
                    tags: []
                }
            ];
        }

        const baseTags = []; // Bare field tags
        const parentSections = {}; // 'Owner' → { tags: [...] }
        const loopSections = {}; // 'Contacts' → { tags: [...] }
        const loopOrder = []; // preserve order of first appearance

        // First pass: detect explicit loop boundaries '#Foo' so we know which
        // dotted prefixes are loop-rows vs parent-lookups.
        const declaredLoops = new Set();
        for (const f of fields) {
            if (typeof f !== 'string') {
                continue;
            }
            if (f.startsWith('#')) {
                declaredLoops.add(f.substring(1));
            }
        }

        for (const f of fields) {
            if (typeof f !== 'string' || !f) {
                continue;
            }
            // Loop boundary markers — used only to declare loop sections;
            // emitted as loopStart/loopEnd, not as click-to-copy tags.
            if (f.startsWith('#') || f.startsWith('/')) {
                continue;
            }

            const dotIdx = f.indexOf('.');
            if (dotIdx > 0) {
                const prefix = f.substring(0, dotIdx);
                if (declaredLoops.has(prefix)) {
                    if (!loopSections[prefix]) {
                        loopSections[prefix] = { tags: [] };
                        loopOrder.push(prefix);
                    }
                    // Inside a loop, render as the bare field name (loop scope rewrites it)
                    loopSections[prefix].tags.push({ code: '{' + f.substring(dotIdx + 1) + '}' });
                } else {
                    if (!parentSections[prefix]) {
                        parentSections[prefix] = { tags: [] };
                    }
                    parentSections[prefix].tags.push({ code: '{' + f + '}' });
                }
            } else {
                baseTags.push({ code: '{' + f + '}' });
            }
        }

        const sections = [];
        if (baseTags.length > 0) {
            sections.push({
                name: providerName + ' — fields',
                isLoop: false,
                tags: baseTags
            });
        }
        for (const parent of Object.keys(parentSections)) {
            sections.push({
                name: parent + ' (parent lookup)',
                isLoop: false,
                tags: parentSections[parent].tags
            });
        }
        for (const loop of loopOrder) {
            sections.push({
                name: loop + ' (loop)',
                isLoop: true,
                loopStart: '{#' + loop + '}',
                loopEnd: '{/' + loop + '}',
                tags: loopSections[loop].tags
            });
        }
        return sections.length > 0 ? sections : null;
    }

    async handleCopyEditTag(event) {
        const tag = event.currentTarget.dataset.tag;
        if (!tag) {
            return;
        }
        try {
            await this._copyToClipboard(tag);
            this.dispatchEvent(new ShowToastEvent({ title: 'Copied', message: tag, variant: 'success' }));
        } catch {
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Copy Failed', message: 'Unable to copy to clipboard.', variant: 'error' })
            );
        }
    }

    // Split a string on commas, but only at parentheses depth 0
    _splitTopLevel(str) {
        const tokens = [];
        let depth = 0;
        let current = '';
        for (let i = 0; i < str.length; i++) {
            const ch = str[i];
            if (ch === '(') {
                depth++;
                current += ch;
            } else if (ch === ')') {
                depth--;
                current += ch;
            } else if (ch === ',' && depth === 0) {
                tokens.push(current.trim());
                current = '';
            } else {
                current += ch;
            }
        }
        if (current.trim()) {
            tokens.push(current.trim());
        }
        return tokens;
    }

    _copyToClipboard(text) {
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(text);
        }
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-9999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        try {
            document.execCommand('copy');
        } finally {
            document.body.removeChild(textArea);
        }
        return Promise.resolve();
    }

    handleTitleFormatChange(event) {
        this.editTemplateTitleFormat = event.detail.value;
    }

    // #verification — template-level signer-verification defaults
    get signerVerificationOptions() {
        return [
            { label: 'Inherit (use org default)', value: 'Inherit' },
            { label: 'Required (email PIN)', value: 'Required' },
            { label: 'Off (no verification)', value: 'Off' }
        ];
    }
    get prefillSignerEmailOptions() {
        return [
            { label: 'Inherit (use org default)', value: 'Inherit' },
            { label: 'Yes (auto-send to known email)', value: 'Yes' },
            { label: 'No (signer types email)', value: 'No' }
        ];
    }
    handleSignerVerificationChange(event) {
        this.editTemplateSignerVerification = event.detail.value;
    }

    handleApiNameChange(event) {
        this.editTemplateApiName = (event.detail.value || '').trim();
    }

    handleDefaultEmailMessageChange(event) {
        this.editTemplateDefaultEmailMessage = event.detail.value || '';
    }
    handlePrefillSignerEmailChange(event) {
        this.editTemplatePrefillSignerEmail = event.detail.value;
    }

    get isBuilderDisabled() {
        return this.isManualQuery;
    }

    // --- Options ---
    get typeOptions() {
        return [
            { label: 'Word', value: 'Word' },
            { label: 'PowerPoint', value: 'PowerPoint' },
            { label: 'Excel', value: 'Excel' },
            { label: 'HTML', value: 'HTML' },
            { label: 'PDF', value: 'PDF' }
        ];
    }

    get outputFormatOptions() {
        const type = this.isCreating ? this.newTemplateType : this.editTemplateType;
        if (type === 'Excel') {
            return [{ label: 'Native (.xlsx)', value: 'Native' }];
        }
        if (type === 'HTML' || type === 'PDF') {
            return [{ label: 'PDF', value: 'PDF' }];
        }
        return [
            { label: type === 'PowerPoint' ? 'Native (.pptx)' : 'Native (.docx)', value: 'Native' },
            { label: 'PDF', value: 'PDF' }
        ];
    }

    get acceptedFormats() {
        const type = this.isCreating ? this.newTemplateType : this.editTemplateType;
        if (type === 'PowerPoint') return ['.pptx'];
        if (type === 'Excel') return ['.xlsx'];
        if (type === 'HTML') return ['.html', '.htm', '.zip'];
        if (type === 'PDF') return ['.pdf'];
        return ['.docx'];
    }

    get pageOrientationOptions() {
        return [
            { label: 'Portrait', value: 'Portrait' },
            { label: 'Landscape', value: 'Landscape' }
        ];
    }

    get pageSizeOptions() {
        return [
            { label: 'Letter (8.5 x 11 in)', value: 'Letter' },
            { label: 'Legal (8.5 x 14 in)', value: 'Legal' },
            { label: 'A4 (210 x 297 mm)', value: 'A4' }
        ];
    }

    get pageMarginsOptions() {
        return [
            { label: 'Default for size', value: 'Default' },
            { label: 'From source DOCX margins', value: 'FromSource' },
            { label: 'Narrow (0.5 in)', value: 'Narrow' },
            { label: 'Normal (1.0 in)', value: 'Normal' },
            { label: 'Wide (1.5 in)', value: 'Wide' },
            { label: 'Custom (specify below)', value: 'Custom' }
        ];
    }

    /** Orientation/size/margins only apply to PDF output. Hide for Native/Excel. */
    get showPageOrientation() {
        const fmt = this.isCreating ? this.newTemplateOutputFormat : this.editTemplateOutputFormat;
        return fmt === 'PDF';
    }

    // v1.90 — for the create wizard, hide page-layout fields when Type=HTML.
    // HTML templates almost always declare their own @page CSS, so these fields
    // are a UX trap (engine ignores them, but the wizard pre-fills them with
    // Portrait/Letter/Default and makes users feel they're a required choice).
    // After the template is created and the body is uploaded, the edit modal
    // re-evaluates and shows them only if the uploaded HTML lacks @page.
    get showNewPageLayoutFields() {
        return this.showPageOrientation && this.newTemplateType !== 'HTML';
    }

    get isCreatingHtmlPdf() {
        return this.newTemplateType === 'HTML' && this.newTemplateOutputFormat === 'PDF';
    }

    /** Show Custom Margins text field only when "Custom" preset is selected. */
    get showNewCustomMargins() {
        return this.showPageOrientation && this.newTemplatePageMargins === 'Custom';
    }

    get showEditCustomMargins() {
        return this.showPageOrientation && this.editTemplatePageMargins === 'Custom';
    }

    get isEditTypeHtml() {
        return this.editTemplateType === 'HTML';
    }

    get isEditTypePdf() {
        return this.editTemplateType === 'PDF';
    }

    // v1.90 — page-layout fields are dead inputs when the HTML body owns @page.
    // The engine ignores them and they only confuse authors, so hide them and
    // show an explanatory banner in their place.
    get showEditPageLayoutFields() {
        return this.showPageOrientation && !this.editHtmlBodyOwnsPageRule;
    }

    get showEditHtmlOwnsPageBanner() {
        return this.isEditTypeHtml && this.editHtmlBodyOwnsPageRule;
    }

    // --- Create Logic ---
    async createTemplate() {
        const fields = {};
        fields[NAME_FIELD.fieldApiName] = this.newTemplateName;
        fields[CATEGORY_FIELD.fieldApiName] = this.newTemplateCategory;
        fields[TYPE_FIELD.fieldApiName] = this.newTemplateType;
        fields[OUTPUT_FORMAT_FIELD.fieldApiName] = this.newTemplateOutputFormat;
        // Page setup only meaningful for PDF output. v1.90 — skip for HTML
        // templates: their @page CSS owns page layout, and engine suppresses
        // template-level overrides when source @page is present. Saving the
        // create-wizard defaults would just leave conflicting values that
        // confuse later editors.
        if (this.newTemplateOutputFormat === 'PDF' && this.newTemplateType !== 'HTML') {
            fields[PAGE_ORIENTATION_FIELD.fieldApiName] = this.newTemplatePageOrientation;
            fields[PAGE_SIZE_FIELD.fieldApiName] = this.newTemplatePageSize;
            fields[PAGE_MARGINS_FIELD.fieldApiName] = this.newTemplatePageMargins;
            if (this.newTemplatePageMargins === 'Custom') {
                fields[CUSTOM_MARGINS_FIELD.fieldApiName] = this.newTemplateCustomMargins;
            }
        }
        fields[BASE_OBJECT_FIELD.fieldApiName] = this.newTemplateObject;
        fields[QUERY_CONFIG_FIELD.fieldApiName] = this._sanitizeQueryConfig(this.newTemplateQuery);
        fields[DESC_FIELD.fieldApiName] = this.newTemplateDesc;
        if (this.newTemplateApiName) {
            const clash = (this.templates || []).find(
                (t) => (t[F.ApiName] || '').toLowerCase() === this.newTemplateApiName.toLowerCase()
            );
            if (clash) {
                this.showToast(
                    'API Name already in use',
                    `"${this.newTemplateApiName}" is already used by template "${clash.Name}". API Names must be unique.`,
                    'error'
                );
                return;
            }
            fields[F.ApiName] = this.newTemplateApiName;
        }
        if (this.newTemplateSampleRecordId) {
            fields[TEST_RECORD_FIELD.fieldApiName] = this.newTemplateSampleRecordId;
        }

        // Snapshot authoring-path inputs before resetForm() clears them — the
        // starter body is built and attached after the modal opens.
        const authoringMode = this.newAuthoringMode;
        const starterKey = this.newStarterKey;
        const starterShape =
            authoringMode === 'starter' ? extractQueryShape(this.newTemplateQuery, this.newTemplateObject) : null;
        const aiPastedHtml = (this._aiPastedHtml || '').trim();
        this._aiPastedHtml = null;
        const chosenLogoTag = this._chosenLogoTag;

        try {
            const record = await createRecord({ apiName: DOCGEN_TEMPLATE_OBJECT.objectApiName, fields });
            this.createdTemplateId = record.id;
            this.isCreating = false;
            // Only the file path needs an upload prompt — every other mode
            // lands directly in the designer.
            if (authoringMode === 'file') {
                this.showToast('Success', 'Template Record created. Please upload your document.', 'success');
            }

            const newRow = {
                Id: record.id,
                Name: this.newTemplateName,
                [F.Category]: this.newTemplateCategory,
                [F.Type]: this.newTemplateType,
                [F.OutputFormat]: this.newTemplateOutputFormat,
                [F.PageOrientation]: this.newTemplatePageOrientation,
                [F.PageSize]: this.newTemplatePageSize,
                [F.PageMargins]: this.newTemplatePageMargins,
                [F.CustomMargins]: this.newTemplateCustomMargins,
                [F.BaseObject]: this.newTemplateObject,
                [F.Desc]: this.newTemplateDesc,
                // Must carry the API name into the edit modal — resetForm() clears the
                // wizard value, and an edit modal opened without it would post
                // API_Name__c: '' on the next save, wiping what createRecord just wrote.
                [F.ApiName]: this.newTemplateApiName || null,
                [F.QueryConfig]: this.newTemplateQuery,
                [F.TestRecordId]: this.newTemplateSampleRecordId || null,
                [F.DocTitleFormat]: null,
                ContentDocumentLinks: []
            };

            this.resetForm();
            await refreshApex(this.wiredTemplatesResult);

            this.activeMainTab = 'list';
            this.activeEditTab = 'document';
            this.openEditModal(newRow, 'document');
            if (authoringMode === 'starter') {
                await this._ensureLogoAsset(record.id);
                await this._applyStarterBody(record.id, starterKey, starterShape, chosenLogoTag);
                // Land straight in the full-screen designer with the starter open.
                this.isEditModalOpen = false;
                await this._openDesignerSurface();
            } else if (authoringMode === 'ai') {
                await this._ensureLogoAsset(record.id);
                // AI path: the wizard's paste-back becomes the staged body; if
                // nothing was pasted, the designer opens ready for it.
                if (aiPastedHtml) {
                    await this._applyPastedBody(record.id, aiPastedHtml, newRow.Name);
                }
                this.isEditModalOpen = false;
                await this._openDesignerSurface();
            } else if (authoringMode === 'scratch') {
                // Blank page — the designer seeds a clean sheet to type into.
                this.isEditModalOpen = false;
                await this._openDesignerSurface();
            }
        } catch (error) {
            this.showToast('Error creating record', error.body ? error.body.message : error.message, 'error');
        }
    }

    /**
     * Starter path: build the chosen design with the author's real merge
     * fields and attach it as the template body, so the very first "Save as
     * New Version" click produces a working v1 that renders on Generate.
     */
    async _applyStarterBody(templateId, starterKey, shape, logoTag) {
        try {
            let html = buildStarterHtml(starterKey, shape);
            // Starter bodies carry {%asset:logo} slots; an existing asset picked
            // in the wizard swaps its own merge tag in.
            if (logoTag && logoTag !== '{%asset:logo}') {
                html = html.split('{%asset:logo}').join(logoTag);
            }
            const fileName = (this.selectedStarterLabelFor(starterKey) || 'Starter').replace(/[^\w]+/g, '_') + '.html';
            const bodyResult = await saveHtmlTemplateBody({ templateId, fileName, htmlContent: html });
            this.currentFileId = bodyResult.contentDocumentId;
            this.uploadedContentVersionId = bodyResult.contentVersionId;
            this.uploadedFileName = fileName;
            this._lastUploadedHtmlText = html;
            this.stagedBodySource = 'starter';
            this.htmlEditorDirty = false;
            // Starters declare @page — same handling as an uploaded body that owns it.
            this.editHtmlBodyOwnsPageRule = true;
            this.editTemplatePageOrientation = null;
            this.editTemplatePageSize = null;
            this.editTemplatePageMargins = null;
            this.editTemplateCustomMargins = '';
            // Land the author inside the HTML with the draft loaded.
            this.showHtmlBodyEditor = true;
            this._syncHtmlBodyEditorDom(html);
            this.showToast(
                'Starter design attached',
                'Review the HTML, then click "Save as New Version" to activate it. Download Sample shows it with real data.',
                'success'
            );
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Starter attach failed', msg, 'error');
        }
    }

    selectedStarterLabelFor(key) {
        const s = STARTERS.find((x) => x.key === key);
        return s ? s.label : '';
    }

    /**
     * AI path: the HTML pasted on the wizard's AI step becomes the staged
     * template body, so the designer opens on the finished document.
     */
    async _applyPastedBody(templateId, html, templateName) {
        try {
            const fileName = (templateName || 'AI_Template').replace(/[^\w]+/g, '_') + '.html';
            const bodyResult = await saveHtmlTemplateBody({ templateId, fileName, htmlContent: html });
            this.currentFileId = bodyResult.contentDocumentId;
            this.uploadedContentVersionId = bodyResult.contentVersionId;
            this.uploadedFileName = fileName;
            this._lastUploadedHtmlText = html;
            this.stagedBodySource = 'editor';
            this.htmlEditorDirty = false;
            if (/@page\b/i.test(html)) {
                this.editHtmlBodyOwnsPageRule = true;
                this.editTemplatePageOrientation = null;
                this.editTemplatePageSize = null;
                this.editTemplatePageMargins = null;
                this.editTemplateCustomMargins = '';
            }
            this.showHtmlBodyEditor = true;
            this._syncHtmlBodyEditorDom(html);
            this.showToast(
                'AI design attached',
                'Your pasted HTML is staged — review it, then "Save as New Version" activates it.',
                'success'
            );
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Paste attach failed', msg, 'error');
        }
    }

    // --- Row Action ---
    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            try {
                // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
                await deleteTemplate({ templateId: row.Id });
                this.showToast('Success', 'Template deleted', 'success');
                return refreshApex(this.wiredTemplatesResult);
            } catch (error) {
                this.showToast('Error deleting template', error.body ? error.body.message : error.message, 'error');
            }
        } else if (actionName === 'edit') {
            this.openEditModal(row, 'details');
        } else if (actionName === 'design') {
            if (row[F.Type] === 'HTML') {
                this.openDesignerForRow(row);
            } else {
                this.showToast(
                    'Designer is for HTML templates',
                    row[F.Type] === 'Word'
                        ? 'Open Edit → Document & History → View Converted HTML, and use "Switch to HTML Template" to bring this Word template into the designer.'
                        : 'This template type is file-based — use Edit to manage its document.',
                    'info'
                );
            }
        } else if (actionName === 'view') {
            this.openEditModal(row, 'tags');
        } else if (actionName === 'clone') {
            this.handleCloneTemplate(row);
        } else if (actionName === 'export') {
            this.handleExportTemplate(row);
        }
    }

    async handleCloneTemplate(row) {
        try {
            this.showToast('Cloning', 'Cloning ' + row.Name + '…', 'info');
            // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
            const newId = await cloneTemplate({ templateId: row.Id, newName: row.Name + ' (Copy)' });
            await refreshApex(this.wiredTemplatesResult);
            this.showToast(
                'Template cloned',
                'The copy starts Inactive so it stays out of pickers — rename it and flip it Active when ready.',
                'success'
            );
            const newRow = this.templates.find((t) => t.Id === newId);
            if (newRow) {
                this.openEditModal(newRow, 'details');
            }
        } catch (error) {
            this.showToast('Error cloning template', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleExportTemplate(row) {
        try {
            this.showToast('Exporting', 'Preparing ' + row.Name + '...', 'info');
            const jsonStr = await exportTemplate({ templateId: row.Id });
            const blob = new Blob([jsonStr], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = (row.Name || 'template').replace(/[^a-zA-Z0-9_-]/g, '_') + '.docgen.json';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            this.showToast('Exported', row.Name + ' exported successfully', 'success');
        } catch (error) {
            this.showToast('Export Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    handleImportClick() {
        this.template.querySelector('input[data-id="importFileInput"]').click();
    }

    async handleImportFile(event) {
        const file = event.target.files[0];
        if (!file) return;
        // Reset the input so the same file can be re-imported
        event.target.value = '';

        if (!file.name.endsWith('.json') && !file.name.endsWith('.docgen.json')) {
            this.showToast('Invalid File', 'Please select a .docgen.json file', 'error');
            return;
        }

        try {
            this.showToast('Importing', 'Importing ' + file.name + '...', 'info');
            const jsonStr = await file.text();
            // Basic validation
            const parsed = JSON.parse(jsonStr);
            if (!parsed.template || !parsed.docgenExportVersion) {
                this.showToast('Invalid File', 'This file is not a valid DocGen export.', 'error');
                return;
            }
            // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
            await importTemplate({ jsonData: jsonStr });
            this.showToast('Imported', (parsed.template.Name || 'Template') + ' imported successfully', 'success');
            return refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            this.showToast('Import Error', error.body ? error.body.message : error.message, 'error');
        }
    }

    // --- Edit Modal ---
    openEditModal(row, activeTab) {
        try {
            this._editContext = true;
            this.editTemplateId = row.Id;
            this.editTemplateName = row.Name;
            this.editTemplateCategory = row[F.Category];
            this.editTemplateType = row[F.Type];
            this.editTemplateObject = row[F.BaseObject];
            this.editTemplateOutputFormat = row[F.OutputFormat] || 'Native';
            this.editTemplatePageOrientation = row[F.PageOrientation] || 'Portrait';
            this.editTemplatePageSize = row[F.PageSize] || 'Letter';
            this.editTemplatePageMargins = row[F.PageMargins] || 'Default';
            this.editTemplateCustomMargins = row[F.CustomMargins] || '';
            this.editTemplateDesc = row[F.Desc];
            // Pass the raw stored config to the visual builder. V3 JSON must
            // NOT be flattened to V1 SOQL here — V1 can't represent filtered
            // subsets (multiple subqueries against the same relationship), so
            // flattening would silently drop alias slots. The readable textarea
            // formats V3→V1 at display time via the readableEditQueryConfig getter.
            this.editTemplateQuery = row[F.QueryConfig];
            // #161 — load configured signer form fields from the dedicated
            // Form_Fields_Config__c field (independent of Query_Config__c).
            this.editFormFieldsConfig = row[F.FormFieldsConfig] || '';
            this._hydrateSignerFields();
            // Auto-detect v4 (Apex Data Provider) bindings so admins re-opening
            // a provider-backed template land in the right mode immediately.
            this.editUseApexProvider = false;
            this._clearApexProviderState();
            try {
                const cfg = row[F.QueryConfig] ? JSON.parse(row[F.QueryConfig]) : null;
                if (cfg && cfg.v === 4 && cfg.provider) {
                    this.editUseApexProvider = true;
                    this.editUseVisualBuilder = false;
                    this._validateAndLoadProviderFields(cfg.provider);
                }
            } catch (e) {
                /* not JSON — manual or v1 */
            }
            this.editTemplateTestRecordId = row[F.TestRecordId];
            this.editTemplateTitleFormat = row[F.DocTitleFormat];
            // F.IsActive may be undefined on records created before the field shipped;
            // treat null/undefined as Active to match the server-side OR-NULL filter.
            this.editTemplateIsActive = row[F.IsActive] !== false;
            this.editTemplateIsDefault = row[F.IsDefault] || false;
            this.editTemplateSortOrder = row[F.SortOrder];
            this.editTemplateLockOutputFormat = row[F.LockOutputFormat] || false;
            this.editTemplateSignerVerification = row[F.SignerVerification] || 'Inherit';
            this.editTemplatePrefillSignerEmail = row[F.PrefillSignerEmail] || 'Inherit';
            this.editTemplateApiName = row[F.ApiName] || '';
            this.editTemplateDefaultEmailMessage = row[F.DefaultEmailMessage] || '';
            this.editTemplateSpecificRecordIds = row[F.SpecificRecordIds];
            this.editTemplateRequiredPermissionSets = row[F.RequiredPermSets];
            this.editTemplateRecordFilter = row[F.RecordFilter];
            this.editTemplateRecordFilterResult = '';
            this.editTemplateRecordFilterResultMessage = '';
            this.editTemplateHeaderHtml = row[F.HeaderHtml] || '';
            this.editTemplateFooterHtml = row[F.FooterHtml] || '';
            this.uploadedPdfAcroFormSnapshot = null;
            this.pdfAcroFormSnapshotVersionId = null;
            this.isPdfAcroFormSnapshotLoaded = false;
            this.uploadedPdfAcroFormSnapshotJson = null;
            // Clear any body uploaded for a previously-opened template but never
            // saved — otherwise "Save as New Version" on THIS template silently
            // adopts the other template's file as its body.
            this.uploadedContentVersionId = null;
            this.uploadedFileName = '';
            this.uploadedPdfAcroFormNormalizedBase64 = null;
            // Same staleness trap: the @page-ownership flag belongs to whatever
            // HTML body was last uploaded, not to this template.
            this.editHtmlBodyOwnsPageRule = false;
            // HTML body editor state is per-template too.
            this.showHtmlBodyEditor = false;
            this._lastUploadedHtmlText = null;
            this.isLoadingHtmlBody = false;
            this.isApplyingHtmlBody = false;
            this.stagedBodySource = null;
            this.htmlEditorDirty = false;
            this.showDocxHtmlViewer = false;
            this.docxSnapshotInfo = null;
            this.isLoadingDocxHtml = false;
            this.isSwitchingToHtml = false;
            this.showDocxHtmlPreview = false;
            this.showImagePanel = false;
            this.templateImages = [];
            this.showTagPanel = false;
            this.showHtmlBodyVisual = false;
            this._visualOriginalCode = null;
            this._visualEnteredDom = null;

            let cdLinks = [];
            if (row.ContentDocumentLinks) {
                if (Array.isArray(row.ContentDocumentLinks)) {
                    cdLinks = row.ContentDocumentLinks;
                } else if (row.ContentDocumentLinks.records) {
                    cdLinks = row.ContentDocumentLinks.records;
                }
            }

            if (cdLinks && cdLinks.length > 0) {
                this.currentFileId = cdLinks[0].ContentDocumentId;
            } else {
                this.currentFileId = null;
            }

            if (!this.currentFileId) {
                this.activeEditTab = 'document';
            } else {
                this.activeEditTab = activeTab || 'details';
            }

            this.loadVersions(row.Id);
            if (row[F.Type] === 'PDF') {
                this.loadPdfAcroFormMapping();
            }
            this.isCreating = false;
            this.isEditModalOpen = true;
            this._editContext = true;
            this._loadObjectMetadata(this.editTemplateObject);
            // Initialize query tree + sync textarea after DOM renders
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this._updateQueryTree();
                this._loadSampleData();
                // Native textarea doesn't reliably pick up value from LWC reactivity — set DOM directly
                const ta = this.template.querySelector('.edit-query-textarea');
                if (ta && this.editTemplateQuery) {
                    ta.value = this.editTemplateQuery;
                }
            }, 300);
        } catch (e) {
            this.showToast('Error', 'Failed to open modal: ' + e.message, 'error');
        }
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this._editContext = false;
        this.queryTreeNodes = [];
        this.sampleRecordData = null;
        this.showSuggestions = false;
        this.editUseApexProvider = false;
        this._clearApexProviderState();
    }

    // --- Versions Logic ---
    get hasVersions() {
        return this.versions && this.versions.length > 0;
    }

    get currentVersionLabel() {
        if (this.hasVersions) {
            return this.versions[0].VersionNumber;
        }
        return '';
    }

    loadVersions(templateId) {
        getTemplateVersions({ templateId })
            .then((data) => {
                if (!data) {
                    this.versions = [];
                    this.editTemplateWatermarkCvId = null;
                    return;
                }
                this.versions = data.map((v) => {
                    const isActive = v[F.VerIsActive];
                    return {
                        ...v,
                        // Show the real version record name (e.g. V-0024), not a synthetic index.
                        VersionNumber: v.Name,
                        CreatedByName: v.CreatedBy ? v.CreatedBy.Name : '',
                        isActiveLabel: isActive ? '✓' : '',
                        activeClass: isActive ? 'slds-text-color_success slds-text-title_bold' : '',
                        activateVariant: isActive ? 'neutral' : 'brand',
                        // Namespace-safe disable flag for the Activate/Delete buttons —
                        // raw 'Is_Active__c' keys don't exist on subscriber-org rows
                        // (they're portwoodglobal__-prefixed there).
                        disableAction: !!isActive,
                        bodyCvId: v[F.VerCvId] || '',
                        bodyCvFileName: ''
                    };
                });
                // Sync watermark CV from the active version so the tab shows current state
                const active = data.find((v) => v[F.VerIsActive]);
                this.editTemplateWatermarkCvId = active ? active[F.VerWatermarkCv] || null : null;

                // Enrich with the body ContentVersion's number + filename so the table
                // shows which underlying file each version points at (diagnostic).
                const cvIds = data.map((v) => v[F.VerCvId]).filter(Boolean);
                if (cvIds.length) {
                    getVersionBodyFileInfo({ contentVersionIds: cvIds })
                        .then((info) => {
                            if (!info) {
                                return;
                            }
                            this.versions = this.versions.map((row) => {
                                const meta = info[row[F.VerCvId]];
                                return meta ? { ...row, bodyCvFileName: meta.fileName } : row;
                            });
                        })
                        .catch(() => {
                            // Non-fatal — leave the file columns blank if the lookup fails.
                        });
                }
            })
            .catch(() => {
                this.versions = [];
                this.editTemplateWatermarkCvId = null;
            });
    }

    async handleRestoreVersion(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'restore') {
            try {
                this.isLoadingVersions = true;
                // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
                await activateVersion({ versionId: row.Id });

                this.showToast('Success', 'Version activated.', 'success');

                this.editTemplateQuery = row[F.QueryConfig]; // raw — preserves V3 alias slots
                this.editTemplateCategory = row[F.Category];
                this.editTemplateDesc = row[F.Desc];
                this.editTemplateType = row[F.Type];

                this.loadVersions(this.editTemplateId);
                refreshApex(this.wiredTemplatesResult);
            } catch (error) {
                this.showToast('Error activating version', error.body ? error.body.message : error.message, 'error');
            } finally {
                this.isLoadingVersions = false;
            }
        } else if (action === 'preview') {
            this.handlePreviewVersion(row);
        } else if (action === 'deleteVersion') {
            await this.handleDeleteVersion(row);
        }
    }

    // Issue #83 — Confirm with the user, then delete a non-active version and
    // its associated CVs. The Apex endpoint refuses to delete the active version
    // as a safety guard; the UI also disables the button on the active row.
    async handleDeleteVersion(row) {
        const verName = row.Name || 'this version';
        const ok = window.confirm(
            'Delete ' +
                verName +
                '?\n\n' +
                'This removes the version record AND its template body file plus pre-decomposed parts. ' +
                'Cannot be undone. Activate a different version first if this one is currently active.'
        );
        if (!ok) return;
        try {
            this.isLoadingVersions = true;
            await deleteTemplateVersion({ versionId: row.Id });
            this.showToast('Success', verName + ' deleted.', 'success');
            this.loadVersions(this.editTemplateId);
            refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            this.showToast('Error deleting version', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoadingVersions = false;
        }
    }

    handlePreviewVersion(row) {
        this.previewVersion = row;
        this.isGeneratingPreview = false;
        this.isPreviewModalOpen = true;
    }

    closePreviewModal() {
        this.isPreviewModalOpen = false;
        this.isGeneratingPreview = false;
    }

    handleRestoreFromPreview() {
        const event = {
            detail: {
                action: { name: 'restore' },
                row: this.previewVersion
            }
        };
        this.handleRestoreVersion(event);
        this.closePreviewModal();
    }

    // --- Version Preview Helpers ---

    @track isGeneratingPreview = false;

    get isPreviewVersionActive() {
        return this.previewVersion?.[F.VerIsActive] || false;
    }

    // Namespace-aware truthy check — F.QueryConfig resolves to the namespaced
    // field name in subscriber orgs (e.g. portwoodglobal__Query_Config__c), so
    // the modal must read via this getter rather than `previewVersion.Query_Config__c`.
    get hasPreviewVersionQuery() {
        const v = this.previewVersion?.[F.QueryConfig];
        return typeof v === 'string' && v.trim().length > 0;
    }

    get previewVersionQueryFormatted() {
        const raw = this.previewVersion?.[F.QueryConfig];
        if (!raw) return '';
        // Reuse the main edit UI's V1/V2/V3-aware formatter so V3 JSON trees
        // render as readable SOQL-ish text instead of one giant JSON blob.
        const flattened = this._formatQueryConfig(raw);
        // Apply the same comma/parens line-break sweetening for readability.
        let depth = 0;
        let formatted = '';
        for (let i = 0; i < flattened.length; i++) {
            const ch = flattened[i];
            if (ch === '(') {
                depth++;
                formatted += '\n  (';
            } else if (ch === ')') {
                depth--;
                formatted += ')';
            } else if (ch === ',' && depth === 0) {
                formatted += ',\n';
            } else {
                formatted += ch;
            }
        }
        return formatted.trim();
    }

    get previewGenerateDisabled() {
        return !this.previewVersion?.[F.VerCvId] || !this.editTemplateTestRecordId || this.isGeneratingPreview;
    }

    handlePreviewDownload() {
        const cvId = this.previewVersion?.[F.VerCvId];
        if (cvId) {
            this[NavigationMixin.Navigate](
                {
                    type: 'standard__webPage',
                    attributes: {
                        url: `/sfc/servlet.shepherd/version/download/${cvId}`
                    }
                },
                false
            );
        }
    }

    async handlePreviewGenerate() {
        if (!this.previewVersion?.[F.VerCvId] || !this.editTemplateTestRecordId) {
            this.showToast('Warning', 'Template file and test record are required.', 'warning');
            return;
        }

        this.isGeneratingPreview = true;

        try {
            // Activate this version first so generation uses its file and config
            if (!this.previewVersion[F.VerIsActive]) {
                // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
                await activateVersion({ versionId: this.previewVersion.Id });
                // Sync version config to local edit state
                this.editTemplateQuery = this.previewVersion[F.QueryConfig]; // raw — preserves V3 alias slots
                this.editTemplateCategory = this.previewVersion[F.Category];
                this.editTemplateDesc = this.previewVersion[F.Desc];
                this.editTemplateType = this.previewVersion[F.Type];
                this.loadVersions(this.editTemplateId);
                refreshApex(this.wiredTemplatesResult);
            }

            const previewTemplateType = this.previewVersion[F.Type] || this.editTemplateType;
            const isPPT = ['PowerPoint', 'PPT', 'PPTX'].includes(previewTemplateType);

            if (isPPT || this.editTemplateOutputFormat === 'Native') {
                let result;
                const chartContext = await this._prepareChartsForAdmin(
                    this.editTemplateId,
                    this.editTemplateTestRecordId
                );
                try {
                    result = await this._generateOfficeSample(
                        this.editTemplateId,
                        this.editTemplateTestRecordId,
                        chartContext
                    );
                } finally {
                    await this._cleanupChartsForAdmin(chartContext.cvIds);
                }
                if (!result || !result.base64) {
                    throw new Error('Document generation returned empty result.');
                }
                const docTitle = 'Preview_' + this.previewVersion.VersionNumber + '_' + (result.title || 'Document');
                const ext = this._officeExtensionForType(previewTemplateType);
                this.downloadBase64(result.base64, docTitle + ext, 'application/octet-stream');
                this.showToast(
                    'Success',
                    'Sample document generated for ' + this.previewVersion.VersionNumber,
                    'success'
                );
            } else {
                this.showToast(
                    'Info',
                    'Generating PDF sample for ' + this.previewVersion.VersionNumber + '...',
                    'info'
                );
                let pdfResult;
                if (this._isPdfTemplateType(previewTemplateType)) {
                    pdfResult = await this._generatePdfAcroFormSample(
                        this.editTemplateId,
                        this.editTemplateTestRecordId
                    );
                } else {
                    const chartContext = await this._prepareChartsForAdmin(
                        this.editTemplateId,
                        this.editTemplateTestRecordId
                    );
                    try {
                        pdfResult = await generatePdf({
                            templateId: this.editTemplateId,
                            recordId: this.editTemplateTestRecordId,
                            saveToRecord: false,
                            chartCvMap: chartContext.map
                        });
                    } finally {
                        await this._cleanupChartsForAdmin(chartContext.cvIds);
                    }
                }
                if (!pdfResult || !pdfResult.base64) {
                    throw new Error('PDF generation returned empty result.');
                }
                const pdfTitle = 'Preview_' + this.previewVersion.VersionNumber + '_' + (pdfResult.title || 'Document');
                this.downloadBase64(pdfResult.base64, pdfTitle + '.pdf', 'application/pdf');
                this.showToast('Success', 'PDF sample generated for ' + this.previewVersion.VersionNumber, 'success');
            }
        } catch (error) {
            let msg = 'Unknown error';
            if (error.body && error.body.message) msg = error.body.message;
            else if (error.message) msg = error.message;
            this.showToast('Generation Failed', msg, 'error');
        } finally {
            this.isGeneratingPreview = false;
        }
    }

    // --- Save Logic ---
    async handleSaveOnly() {
        if (!this.editTemplateName || !this.editTemplateType) {
            this.showToast('Error', 'Name and Type are required.', 'error');
            return;
        }
        // #203 — a details-only save does NOT attach a freshly-uploaded body.
        // Say so, loudly, instead of letting the admin believe the new file is
        // live while generation keeps serving the previous version.
        if (this.uploadedContentVersionId) {
            this.showToast(
                'Uploaded file not saved yet',
                'Your uploaded document is not included in a details-only save. Click "Save as New Version" to make it the active body — until then, documents still generate from the previous file.',
                'warning'
            );
        }

        const fields = {
            Id: this.editTemplateId,
            Name: this.editTemplateName,
            Category__c: this.editTemplateCategory,
            Type__c: this.editTemplateType,
            Output_Format__c: this.editTemplateOutputFormat,
            Base_Object_API__c: this.editTemplateObject,
            Description__c: this.editTemplateDesc,
            Query_Config__c: this._sanitizeQueryConfig(this.editTemplateQuery),
            // #161 — Signer Inputs form-field config (dedicated field, not Query_Config__c).
            Form_Fields_Config__c: this.editFormFieldsConfig,
            Test_Record_Id__c: this.editTemplateTestRecordId,
            Document_Title_Format__c: this.editTemplateTitleFormat,
            Is_Active__c: this.editTemplateIsActive,
            Is_Default__c: this.editTemplateIsDefault,
            Sort_Order__c: this.editTemplateSortOrder,
            Lock_Output_Format__c: this.editTemplateLockOutputFormat,
            Specific_Record_Ids__c: this.editTemplateSpecificRecordIds,
            Required_Permission_Sets__c: this.editTemplateRequiredPermissionSets,
            Record_Filter__c: this.editTemplateRecordFilter,
            Header_Html__c: this.editTemplateHeaderHtml,
            Footer_Html__c: this.editTemplateFooterHtml,
            Page_Orientation__c: this.editTemplatePageOrientation,
            Page_Size__c: this.editTemplatePageSize,
            Page_Margins__c: this.editTemplatePageMargins,
            Custom_Margins__c: this.editTemplateCustomMargins,
            Signer_Verification__c: this.editTemplateSignerVerification,
            Prefill_Signer_Email__c: this.editTemplatePrefillSignerEmail,
            API_Name__c: this.editTemplateApiName,
            Default_Email_Message__c: this.editTemplateDefaultEmailMessage
        };
        this.editTemplateQuery = fields['Query_Config__c'];

        try {
            // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
            await saveTemplate({ fields: fields, createVersion: false, contentVersionId: null });
            this.showToast('Success', 'Template Details saved.', 'success');
            return refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            this.showToast('Error saving template', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleSaveAndClose() {
        if (!this.editTemplateName || !this.editTemplateType) {
            this.showToast('Error', 'Name and Type are required.', 'error');
            return;
        }
        // Designer: unapplied visual/source edits fold into the staged body
        // automatically — "Save as New Version" saves what you're looking at,
        // no separate Apply click required.
        if (this.activeMainTab === 'design' && this.htmlEditorDirty && this.editTemplateType === 'HTML') {
            const draft = (this._currentDraftHtml() || '').trim();
            if (draft) {
                try {
                    const base = (this.uploadedFileName || 'template.html').replace(/\.(html?|zip)$/i, '');
                    await this._processAndSaveHtmlBody(this.editTemplateId, draft, base + '.html', null, 'editor');
                    this.htmlEditorDirty = false;
                } catch (err) {
                    const msg =
                        err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
                    this.showToast('Could not stage your edits', msg, 'error');
                    return;
                }
            }
        }

        const fields = {
            Id: this.editTemplateId,
            Name: this.editTemplateName,
            Category__c: this.editTemplateCategory,
            Type__c: this.editTemplateType,
            Output_Format__c: this.editTemplateOutputFormat,
            Base_Object_API__c: this.editTemplateObject,
            Description__c: this.editTemplateDesc,
            Query_Config__c: this._sanitizeQueryConfig(this.editTemplateQuery),
            // #161 — Signer Inputs form-field config (dedicated field, not Query_Config__c).
            Form_Fields_Config__c: this.editFormFieldsConfig,
            Test_Record_Id__c: this.editTemplateTestRecordId,
            Document_Title_Format__c: this.editTemplateTitleFormat,
            Is_Active__c: this.editTemplateIsActive,
            Is_Default__c: this.editTemplateIsDefault,
            Sort_Order__c: this.editTemplateSortOrder,
            Lock_Output_Format__c: this.editTemplateLockOutputFormat,
            Specific_Record_Ids__c: this.editTemplateSpecificRecordIds,
            Required_Permission_Sets__c: this.editTemplateRequiredPermissionSets,
            Record_Filter__c: this.editTemplateRecordFilter,
            Header_Html__c: this.editTemplateHeaderHtml,
            Footer_Html__c: this.editTemplateFooterHtml,
            Page_Orientation__c: this.editTemplatePageOrientation,
            Page_Size__c: this.editTemplatePageSize,
            Page_Margins__c: this.editTemplatePageMargins,
            Custom_Margins__c: this.editTemplateCustomMargins,
            Signer_Verification__c: this.editTemplateSignerVerification,
            Prefill_Signer_Email__c: this.editTemplatePrefillSignerEmail,
            API_Name__c: this.editTemplateApiName,
            Default_Email_Message__c: this.editTemplateDefaultEmailMessage
        };
        this.editTemplateQuery = fields['Query_Config__c'];

        try {
            this._syncPdfAcroFormSnapshotJson();
            const savedPdfSnapshotJson = this.uploadedPdfAcroFormSnapshotJson;
            const templateBodyContentVersionId = this.uploadedContentVersionId;
            // CxSAST: CSRF protection handled by Salesforce Aura/LWC framework
            const versionId = await saveTemplate({
                fields: fields,
                createVersion: true,
                contentVersionId: templateBodyContentVersionId
            });
            if (versionId && savedPdfSnapshotJson) {
                await savePdfAcroFormSnapshot({
                    templateId: this.editTemplateId,
                    versionId,
                    snapshotJson: savedPdfSnapshotJson
                });
            }
            if (
                versionId &&
                this.editTemplateType === 'PDF' &&
                (this.uploadedPdfAcroFormNormalizedBase64 || templateBodyContentVersionId)
            ) {
                await this._queuePdfAcroFormPreparedBody(versionId, templateBodyContentVersionId);
            }
            if (templateBodyContentVersionId) {
                this.showToast('Success', 'New version saved. You can now Generate to test it.', 'success');
            } else if (this.activeMainTab === 'design') {
                // Designer saves auto-stage any edits before reaching here, so
                // "no new file" simply means the body didn't change — say so
                // calmly instead of the sticky re-upload warning (that warning
                // is for the file-upload modal where a stale body surprises).
                this.showToast(
                    'Saved',
                    'Version saved — the document body is unchanged from the previous version.',
                    'success'
                );
            } else {
                // Carry-forward warning (builds on #176's Version History diagnostics):
                // a new version saved WITHOUT re-uploading a body file reuses the prior
                // version's body ContentVersion. That's fine for metadata-only changes,
                // but it surprises authors who edited the document itself — e.g. added
                // {@Signature_…} tags — and expected it to take effect (the "No Signature
                // Placements Found" / stale-body reports). Sticky so it isn't missed.
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Saved — but the body file was reused',
                        message:
                            'This new version kept the PREVIOUS document body because no new file was uploaded. ' +
                            'If you changed the document itself — text, layout, or signature tags — re-upload the ' +
                            "file and save again, or your change won't appear when you generate. Metadata-only " +
                            'changes (name, mapping, title format, page setup) are saved correctly as-is.',
                        variant: 'warning',
                        mode: 'sticky'
                    })
                );
            }
            // Don't close the modal — authors want to immediately test/preview
            // the new version. Clear the just-uploaded CV reference so a follow-up
            // save doesn't double-attach the same file, refresh the version list,
            // and keep PDF authors on the mapping tab so the saved fields remain in view.
            this.uploadedContentVersionId = null;
            this._resetEditFileUploadWidget();
            if (this.editTemplateType === 'PDF' && versionId && savedPdfSnapshotJson) {
                this.pdfAcroFormSnapshotVersionId = versionId;
                this.isPdfAcroFormSnapshotLoaded = true;
                await this.loadPdfAcroFormMapping();
            } else {
                this.uploadedPdfAcroFormSnapshot = null;
                this.uploadedPdfAcroFormSnapshotJson = null;
            }
            if (this.editTemplateId) {
                this.loadVersions(this.editTemplateId);
            }
            this.activeEditTab = this.editTemplateType === 'PDF' ? 'pdfFields' : 'document';
            return refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            this.showToast('Error saving template', error.body ? error.body.message : error.message, 'error');
        }
    }

    // --- Document Generation & Test Logic ---
    get editTemplateTestRecordIdEmpty() {
        return !this.editTemplateTestRecordId;
    }

    get editGenerateSampleDisabled() {
        return (
            !this.editTemplateTestRecordId ||
            this.isLoadingVersions ||
            this.isGeneratingPreview ||
            this.isPreparingPdfAcroFormBody
        );
    }

    get isRealObject() {
        return this.editTemplateObject && this.editTemplateObject !== 'ApexProvider';
    }

    handlePdfAcroFormSearchChange(event) {
        this.pdfAcroFormSearchTerm = event.target.value || '';
    }

    handlePdfAcroFormFilterChange(event) {
        this.pdfAcroFormFilter = event.detail.value || 'all';
    }

    async handleTestGenerate() {
        if (!this.editTemplateTestRecordId) {
            this.showToast('Warning', 'Please select a Test Record ID first.', 'warning');
            return;
        }

        // Auto-heal sample query config
        if (
            this.editTemplateName === 'Sample Quote Template' &&
            this.editTemplateQuery &&
            !this.editTemplateQuery.toLowerCase().includes('quotelineitems')
        ) {
            this.editTemplateQuery +=
                ', (SELECT Product2.Name, Description, Quantity, UnitPrice, TotalPrice FROM QuoteLineItems)';
        }

        // Save first
        await this.handleSaveOnly();

        this.isLoadingVersions = true;

        try {
            const isPPT = ['PowerPoint', 'PPT', 'PPTX'].includes(this.editTemplateType);

            if (isPPT || this.editTemplateOutputFormat === 'Native') {
                // Native DOCX/PPTX download
                let result;
                const chartContext = await this._prepareChartsForAdmin(
                    this.editTemplateId,
                    this.editTemplateTestRecordId
                );
                try {
                    result = await this._generateOfficeSample(
                        this.editTemplateId,
                        this.editTemplateTestRecordId,
                        chartContext
                    );
                } finally {
                    await this._cleanupChartsForAdmin(chartContext.cvIds);
                }

                if (!result || !result.base64) {
                    throw new Error('Document generation returned empty result.');
                }

                const docTitle = 'Sample_' + (result.title || 'Document');
                const ext = this._officeExtensionForType(this.editTemplateType);
                this.downloadBase64(result.base64, docTitle + ext, 'application/octet-stream');
                this.showToast('Success', 'Sample Document Downloaded', 'success');
            } else {
                // PDF generation — same path as bulk
                this.showToast('Info', 'Generating PDF Sample...', 'info');
                let pdfResult;
                if (this._isPdfTemplateType(this.editTemplateType)) {
                    pdfResult = await this._generatePdfAcroFormSample(
                        this.editTemplateId,
                        this.editTemplateTestRecordId
                    );
                } else {
                    const chartContext = await this._prepareChartsForAdmin(
                        this.editTemplateId,
                        this.editTemplateTestRecordId
                    );
                    try {
                        pdfResult = await generatePdf({
                            templateId: this.editTemplateId,
                            recordId: this.editTemplateTestRecordId,
                            saveToRecord: false,
                            chartCvMap: chartContext.map
                        });
                    } finally {
                        await this._cleanupChartsForAdmin(chartContext.cvIds);
                    }
                }

                if (!pdfResult || !pdfResult.base64) {
                    throw new Error('PDF generation returned empty result.');
                }
                const pdfTitle = 'Sample_' + (pdfResult.title || 'Document');
                this.downloadBase64(pdfResult.base64, pdfTitle + '.pdf', 'application/pdf');
                this.showToast('Success', 'PDF Sample Generated', 'success');
            }
        } catch (error) {
            let msg = 'Unknown error';
            if (error.body && error.body.message) {
                msg = error.body.message;
            } else if (error.message) {
                msg = error.message;
            }
            this.showToast('Generation Failed', 'Generation Failed. ' + msg, 'error');
        } finally {
            this.isLoadingVersions = false;
        }
    }

    async _generatePdfAcroFormSample(templateId, recordId) {
        const snapshotResult = await getActivePdfAcroFormSnapshot({ templateId });
        const snapshotJson = snapshotResult && snapshotResult.snapshotJson;
        if (!snapshotJson) {
            throw new Error('PDF AcroForm mapping snapshot is missing. Save the fillable field mapping first.');
        }

        const requestedAt = new Date().toISOString();
        const jobId = await generatePdfAsync({ templateId, recordId });
        this.showToast('PDF generation queued', 'Building the sample PDF server-side...', 'info');
        const result = await this._waitForPdfSampleGeneration(jobId, recordId, requestedAt);
        if (!result || !result.contentVersionId) {
            throw new Error('PDF generation completed, but no generated file was found on the sample record.');
        }
        const base64 = await getContentVersionBase64({ contentVersionId: result.contentVersionId });
        return { base64, title: result.title || 'Document' };
    }

    async _waitForPdfSampleGeneration(jobId, recordId, requestedAt) {
        const maxAttempts = 40;
        for (let attempt = 0; attempt < maxAttempts; attempt++) {
            // eslint-disable-next-line no-await-in-loop
            const result = await getPdfSampleGenerationStatus({
                jobId,
                recordId,
                requestedAt
            });
            if (result && result.jobStatus === 'Failed') {
                throw new Error(result.extendedStatus || 'Server-side PDF generation failed.');
            }
            if (result && result.jobStatus === 'Aborted') {
                throw new Error(result.extendedStatus || 'Server-side PDF generation was aborted.');
            }
            if (result && result.contentVersionId) {
                return result;
            }
            // eslint-disable-next-line no-await-in-loop
            await new Promise((resolve) => setTimeout(resolve, 1500));
        }
        throw new Error('PDF generation is still running. Try Download Sample again in a moment.');
    }

    async _queuePdfAcroFormPreparedBody(versionId, sourceContentVersionId) {
        let base64 = this.uploadedPdfAcroFormNormalizedBase64;
        if (!versionId) {
            return;
        }
        if (!base64 && !sourceContentVersionId) {
            return;
        }
        this.isPreparingPdfAcroFormBody = true;
        this.pdfAcroFormPreparationText = 'Preparing PDF for server-side generation...';
        try {
            if (!base64 && sourceContentVersionId) {
                this.pdfAcroFormPreparationText = 'Rebuilding server-ready PDF body...';
                const uploadedBase64 = await getContentVersionBase64({
                    contentVersionId: sourceContentVersionId
                });
                const snapshot = await decomposePdfAcroFormBase64(uploadedBase64);
                if (snapshot.requiresNormalizedPdf && !snapshot.normalizedPdfBase64) {
                    throw new Error('PDF requires a normalized server-ready body, but normalization did not complete.');
                }
                base64 = snapshot.normalizedPdfBase64 || uploadedBase64;
                this.uploadedPdfAcroFormNormalizedBase64 = snapshot.normalizedPdfBase64 || null;
            }
            if (!base64) {
                throw new Error('Prepared PDF content is empty.');
            }
            const chunkSize = 450000;
            const uploadKey = String(versionId).replace(/[^A-Za-z0-9]/g, '') + '_' + Date.now();
            const chunkVersionIds = [];
            for (let offset = 0, index = 0; offset < base64.length; offset += chunkSize, index++) {
                this.pdfAcroFormPreparationText =
                    'Uploading prepared PDF chunk ' +
                    (index + 1) +
                    ' of ' +
                    Math.ceil(base64.length / chunkSize) +
                    '...';
                const chunk = base64.substring(offset, offset + chunkSize);
                const chunkVersionId = await savePdfAcroFormPreparedBodyChunk({
                    templateId: this.editTemplateId,
                    uploadKey,
                    chunkIndex: index,
                    chunk
                });
                chunkVersionIds.push(chunkVersionId);
            }
            this.pdfAcroFormPreparationText = 'Finalizing server-ready PDF body...';
            const jobId = await finalizePdfAcroFormPreparedBody({
                templateId: this.editTemplateId,
                versionId,
                fileName: this.uploadedFileName || 'template.pdf',
                chunkVersionIds
            });
            await this._waitForPdfAcroFormPreparedBody(versionId, jobId);
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast(
                'PDF preparation queued failed',
                'Template version was saved, but the server-ready PDF body was not prepared yet. ' + msg,
                'warning'
            );
        } finally {
            this.isPreparingPdfAcroFormBody = false;
            this.pdfAcroFormPreparationText = '';
        }
    }

    async _waitForPdfAcroFormPreparedBody(versionId, jobId) {
        const maxAttempts = 24;
        for (let attempt = 0; attempt < maxAttempts; attempt++) {
            this.pdfAcroFormPreparationText = 'Preparing PDF for bulk generation...';
            // eslint-disable-next-line no-await-in-loop
            const status = await getPdfAcroFormPreparedBodyStatus({ versionId, jobId });
            if (status && status.isReady) {
                this.pdfAcroFormPreparationText = 'PDF is ready for generation.';
                return;
            }
            if (status && status.jobStatus === 'Failed') {
                throw new Error(status.extendedStatus || 'PDF preparation failed.');
            }
            // eslint-disable-next-line no-await-in-loop
            await new Promise((resolve) => setTimeout(resolve, 1500));
        }
        throw new Error('PDF preparation is still running. Try Download Sample again in a moment.');
    }

    _isPdfTemplateType(templateType) {
        return String(templateType || '').toLowerCase() === 'pdf';
    }

    _mergePdfAcroFormMappings(freshSnapshot, savedSnapshot) {
        const savedByObjectNumber = new Map();
        const savedByName = new Map();
        (savedSnapshot.fields || []).forEach((field) => {
            if (field.objectNumber != null) {
                savedByObjectNumber.set(String(field.objectNumber), field);
            }
            if (field.name) {
                savedByName.set(field.name, field);
            }
        });
        return {
            ...freshSnapshot,
            normalizedPdfBase64: undefined,
            fields: (freshSnapshot.fields || []).map((field) => {
                const saved = savedByObjectNumber.get(String(field.objectNumber)) || savedByName.get(field.name) || {};
                return {
                    ...field,
                    friendlyLabel: saved.friendlyLabel || field.friendlyLabel || '',
                    mappedPath: saved.mappedPath || field.mappedPath || '',
                    buttonOnValue: saved.buttonOnValue || field.buttonOnValue,
                    buttonOnValues: saved.buttonOnValues || field.buttonOnValues
                };
            })
        };
    }

    _pdfBase64ContainsToken(base64, token) {
        try {
            return atob(base64 || '').includes(token);
        } catch (e) {
            return false;
        }
    }

    _officeExtensionForType(templateType) {
        if (['PowerPoint', 'PPT', 'PPTX'].includes(templateType)) {
            return '.pptx';
        }
        if (templateType === 'Excel') {
            return '.xlsx';
        }
        if (templateType === 'PDF') {
            return '.pdf';
        }
        return '.docx';
    }

    async _generateOfficeSample(templateId, recordId, chartContext) {
        const parts = await generateDocumentParts({
            templateId,
            recordId,
            chartCvMap: chartContext.map
        });
        if (!parts || !parts.allXmlParts) {
            throw new Error('Document generation returned empty result.');
        }

        const allImages = { ...(parts.imageBase64Map || {}) };
        if (parts.imageCvIdMap) {
            const uniqueCvIds = new Map();
            for (const [mediaPath, cvId] of Object.entries(parts.imageCvIdMap)) {
                if (!uniqueCvIds.has(cvId)) {
                    uniqueCvIds.set(cvId, []);
                }
                uniqueCvIds.get(cvId).push(mediaPath);
            }
            for (const [cvId, mediaPaths] of uniqueCvIds) {
                try {
                    // eslint-disable-next-line no-await-in-loop
                    const b64 = await getContentVersionBase64({ contentVersionId: cvId });
                    if (b64) {
                        for (const mediaPath of mediaPaths) {
                            allImages[mediaPath] = b64;
                        }
                    }
                } catch (imgErr) {
                    console.warn('DocGen admin: Failed to fetch image CV ' + cvId, imgErr);
                }
            }
        }

        if (parts.imageUrlMap) {
            for (const [mediaPath, url] of Object.entries(parts.imageUrlMap)) {
                if (!/rtaImage/i.test(url)) continue;
                try {
                    // eslint-disable-next-line no-await-in-loop
                    const pdfB64 = await renderImageAsPdfBase64({ imageUrl: url });
                    if (!pdfB64) continue;
                    // eslint-disable-next-line no-await-in-loop
                    const extracted = await extractFirstImageFromPdfBase64(pdfB64);
                    if (extracted && extracted.base64) {
                        allImages[mediaPath] = extracted.base64;
                        if (extracted.width && extracted.height) {
                            this._updateDocxImageSizeIfNotExplicit(parts, mediaPath, extracted.width, extracted.height);
                        }
                    }
                } catch (urlErr) {
                    console.warn('DocGen admin: rich text image extract failed for ' + url, urlErr);
                }
            }
        }

        const fileBytes = buildDocx(parts.allXmlParts, allImages);
        return {
            base64: this._uint8ArrayToBase64(fileBytes),
            title: parts.title || 'Document'
        };
    }

    _uint8ArrayToBase64(bytes) {
        let binary = '';
        for (let i = 0; i < bytes.length; i++) {
            binary += String.fromCharCode(bytes[i]);
        }
        return btoa(binary);
    }

    _updateDocxImageSizeIfNotExplicit(parts, mediaPath, widthPx, heightPx) {
        if (!parts || !parts.allXmlParts) return;
        const docXml = parts.allXmlParts['word/document.xml'];
        const relsXml = parts.allXmlParts['word/_rels/document.xml.rels'];
        if (!docXml || !relsXml) return;

        const targetName = mediaPath.replace(/^word\//, '');
        const relMatch = relsXml.match(
            new RegExp(
                '<Relationship\\s+Id="([^"]+)"[^>]*?Target="' + targetName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"',
                'i'
            )
        );
        if (!relMatch) return;
        const relId = relMatch[1];

        const blipIdx = docXml.indexOf('r:embed="' + relId + '"');
        if (blipIdx === -1) return;
        const drawStart = docXml.lastIndexOf('<w:drawing', blipIdx);
        const drawEnd = docXml.indexOf('</w:drawing>', blipIdx);
        if (drawStart === -1 || drawEnd === -1) return;

        const drawingXml = docXml.substring(drawStart, drawEnd + '</w:drawing>'.length);
        if (drawingXml.indexOf('DOCGEN_EXPLICIT_SIZE') !== -1) return;

        const cxEmu = widthPx * 9525;
        const cyEmu = heightPx * 9525;
        let updated = drawingXml.replace(
            /<wp:extent\s+cx="\d+"\s+cy="\d+"\s*\/>/,
            '<wp:extent cx="' + cxEmu + '" cy="' + cyEmu + '"/>'
        );
        updated = updated.replace(
            /<a:ext\s+cx="\d+"\s+cy="\d+"\s*\/>/,
            '<a:ext cx="' + cxEmu + '" cy="' + cyEmu + '"/>'
        );
        if (updated !== drawingXml) {
            parts.allXmlParts['word/document.xml'] =
                docXml.substring(0, drawStart) + updated + docXml.substring(drawEnd + '</w:drawing>'.length);
        }
    }

    /**
     * Downloads a base64-encoded file via an anchor element.
     */
    downloadBase64(base64Data, fileName, mimeType) {
        downloadBase64Util(base64Data, fileName, mimeType);
    }

    // --- File Upload ---
    async handleEditUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }
        const file = uploadedFiles[0];

        // 10 MB cap on every DOCX/PPTX template upload. Both the async-decompose
        // Queueable (PDF generation prep) and the server-side merge step in
        // generateDocumentParts (DOCX generation) need to decompress the full
        // ZIP, and Apex async heap (12 MB) can't survive much beyond ~10 MB
        // binary template + per-entry blobs. One uniform rule beats a
        // per-output-format ceiling and matches real-world template sizes
        // (typical DOCX templates are well under 5 MB; 10 MB+ is almost always
        // uncompressed images).
        const TEMPLATE_MAX_BYTES = 10 * 1024 * 1024;
        let uploadedVersionId;
        try {
            uploadedVersionId = file.contentVersionId;
            if (!uploadedVersionId && file.documentId) {
                uploadedVersionId = await getLatestContentVersionId({
                    contentDocumentId: file.documentId
                });
            }
            if (!uploadedVersionId || !String(uploadedVersionId).startsWith('068')) {
                throw new Error('Uploaded file version could not be resolved.');
            }
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Upload scan failed', msg, 'error');
            return;
        }
        try {
            const size = await getContentVersionSize({
                contentVersionId: uploadedVersionId
            });
            if (size > TEMPLATE_MAX_BYTES) {
                await deleteContentVersionDocument({
                    contentVersionId: uploadedVersionId
                });
                this.showToast(
                    'Template too large',
                    'Templates must be 10 MB or smaller (' +
                        (size / 1024 / 1024).toFixed(1) +
                        ' MB uploaded). Almost always the cause is uncompressed images — in Word, right-click an image → Compress Pictures → Email (96 ppi) or Web (150 ppi). A 20 MB template typically drops to 1–2 MB with no visible quality loss.',
                    'error'
                );
                return;
            }
        } catch (err) {
            // eslint-disable-next-line no-console
            console.warn('DocGen size guard failed (continuing):', err);
        }

        this.showToast('Success', 'File Uploaded: ' + file.name, 'success');
        this.currentFileId = file.documentId;
        this.uploadedContentVersionId = uploadedVersionId;
        this.uploadedFileName = file.name;
        this.uploadedPdfAcroFormSnapshot = null;
        this.uploadedPdfAcroFormSnapshotJson = null;
        this.uploadedPdfAcroFormNormalizedBase64 = null;

        if (this.editTemplateType === 'PDF' || (file.name || '').toLowerCase().endsWith('.pdf')) {
            try {
                const base64 = await getContentVersionBase64({
                    contentVersionId: uploadedVersionId
                });
                const snapshot = await decomposePdfAcroFormBase64(base64);
                this.uploadedPdfAcroFormNormalizedBase64 = snapshot.normalizedPdfBase64 || null;
                delete snapshot.normalizedPdfBase64;
                this.uploadedPdfAcroFormSnapshot = snapshot;
                this.pdfAcroFormSnapshotVersionId = null;
                this.isPdfAcroFormSnapshotLoaded = false;
                this._syncPdfAcroFormSnapshotJson();
                const fieldCount = snapshot.fields ? snapshot.fields.length : 0;
                this.showToast(
                    'Fillable fields found',
                    fieldCount + ' fillable field' + (fieldCount === 1 ? '' : 's') + ' decomposed.',
                    'success'
                );
                this.activeEditTab = 'pdfFields';
            } catch (err) {
                const msg = err && err.message ? err.message : 'Unable to decompose fillable fields.';
                this.showToast('Fillable field scan skipped', msg, 'warning');
            }
        }
        this._resetEditFileUploadWidget();
    }

    _resetEditFileUploadWidget() {
        this.showEditFileUpload = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showEditFileUpload = true;
        }, 0);
    }

    _syncPdfAcroFormSnapshotJson() {
        const snapshot = this.uploadedPdfAcroFormSnapshot
            ? {
                  ...this.uploadedPdfAcroFormSnapshot,
                  fields: (this.uploadedPdfAcroFormSnapshot.fields || []).map((field) => ({
                      ...field,
                      body: undefined,
                      widgetBody: undefined,
                      widgets: (field.widgets || []).map((widget) => ({
                          ...widget,
                          body: undefined
                      }))
                  }))
              }
            : null;
        this.uploadedPdfAcroFormSnapshotJson = this.uploadedPdfAcroFormSnapshot
            ? JSON.stringify({
                  ...snapshot,
                  xfaPackets: undefined,
                  normalizedPdfBase64: undefined
              })
            : null;
    }

    async loadPdfAcroFormMapping() {
        if (!this.editTemplateId || this.editTemplateType !== 'PDF') {
            return;
        }
        try {
            const result = await getActivePdfAcroFormSnapshot({ templateId: this.editTemplateId });
            this.pdfAcroFormSnapshotVersionId = result && result.versionId ? result.versionId : null;
            if (result && result.snapshotJson) {
                this.uploadedPdfAcroFormSnapshot = JSON.parse(result.snapshotJson);
                this.isPdfAcroFormSnapshotLoaded = true;
                this._syncPdfAcroFormSnapshotJson();
            } else {
                this.uploadedPdfAcroFormSnapshot = null;
                this.isPdfAcroFormSnapshotLoaded = false;
                this.uploadedPdfAcroFormSnapshotJson = null;
            }
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('PDF mapping load failed', msg, 'warning');
        }
    }

    async handleReloadPdfAcroFormMapping() {
        await this.loadPdfAcroFormMapping();
    }

    async handleSavePdfAcroFormMapping() {
        this._syncPdfAcroFormSnapshotJson();
        if (!this.editTemplateId || !this.hasSavedPdfAcroFormSnapshotTarget || !this.uploadedPdfAcroFormSnapshotJson) {
            this.showToast(
                'PDF mapping is a draft',
                'Save as New Version first, then use Save Mapping for later edits.',
                'warning'
            );
            return;
        }
        this.isSavingPdfAcroFormMapping = true;
        try {
            await savePdfAcroFormSnapshot({
                templateId: this.editTemplateId,
                versionId: this.pdfAcroFormSnapshotVersionId,
                snapshotJson: this.uploadedPdfAcroFormSnapshotJson
            });
            this.isPdfAcroFormSnapshotLoaded = true;
            this.showToast('Saved', 'Fillable field mapping saved.', 'success');
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Error saving PDF mapping', msg, 'error');
        } finally {
            this.isSavingPdfAcroFormMapping = false;
        }
    }

    handlePdfAcroFormMappingChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (!this.hasUploadedPdfAcroFormFields || Number.isNaN(index)) {
            return;
        }
        const fields = this.uploadedPdfAcroFormSnapshot.fields.map((field, i) => {
            if (i !== index) {
                return field;
            }
            return {
                ...field,
                mappedPath: (event.detail.value || '').trim()
            };
        });
        this.uploadedPdfAcroFormSnapshot = {
            ...this.uploadedPdfAcroFormSnapshot,
            fields
        };
        this._syncPdfAcroFormSnapshotJson();
    }

    handlePdfAcroFormFriendlyLabelChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (!this.hasUploadedPdfAcroFormFields || Number.isNaN(index)) {
            return;
        }
        const fields = this.uploadedPdfAcroFormSnapshot.fields.map((field, i) => {
            if (i !== index) {
                return field;
            }
            return {
                ...field,
                friendlyLabel: (event.detail.value || '').trim()
            };
        });
        this.uploadedPdfAcroFormSnapshot = {
            ...this.uploadedPdfAcroFormSnapshot,
            fields
        };
        this._syncPdfAcroFormSnapshotJson();
    }

    handlePdfAcroFormButtonValueChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (!this.hasUploadedPdfAcroFormFields || Number.isNaN(index)) {
            return;
        }
        const fields = this.uploadedPdfAcroFormSnapshot.fields.map((field, i) => {
            if (i !== index) {
                return field;
            }
            return {
                ...field,
                buttonOnValue: (event.detail.value || '').trim() || 'Yes'
            };
        });
        this.uploadedPdfAcroFormSnapshot = {
            ...this.uploadedPdfAcroFormSnapshot,
            fields
        };
        this._syncPdfAcroFormSnapshotJson();
    }

    handleClearPdfAcroFormMappings() {
        if (!this.hasUploadedPdfAcroFormFields) {
            return;
        }
        const fields = this.uploadedPdfAcroFormSnapshot.fields.map((field) => ({
            ...field,
            mappedPath: ''
        }));
        this.uploadedPdfAcroFormSnapshot = {
            ...this.uploadedPdfAcroFormSnapshot,
            fields
        };
        this._syncPdfAcroFormSnapshotJson();
    }

    @track isUploadingHtml = false;

    // v1.90 — true when the HTML source declares an @page rule in any <style> block.
    // Mirrors DocGenService.hasSourcePageRule so the wizard's clear/hide decision
    // matches the engine's suppress decision.
    htmlContainsPageRule(htmlText) {
        if (!htmlText || typeof htmlText !== 'string') {
            return false;
        }
        // Cheap, lowercase substring scan — same approach used server-side.
        return htmlText.toLowerCase().indexOf('@page') !== -1;
    }

    triggerHtmlFilePicker() {
        const input = this.template.querySelector('.docgen-html-file-input');
        if (input) {
            input.click();
        }
    }

    async handleHtmlFileSelected(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        const lower = (file.name || '').toLowerCase();
        if (!lower.endsWith('.html') && !lower.endsWith('.htm') && !lower.endsWith('.zip')) {
            this.showToast('Unsupported file', 'Please choose an .html, .htm, or .zip file.', 'error');
            event.target.value = '';
            return;
        }
        this.isUploadingHtml = true;
        try {
            const templateId = this.editTemplateId;
            let htmlText;
            let imagePaths = [];
            let imageBytes = [];

            if (lower.endsWith('.zip')) {
                const buffer = await file.arrayBuffer();
                const entries = await readZip(buffer);
                const imgExts = new Set(['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tif', 'tiff', 'svg']);
                for (const entry of entries) {
                    const n = entry.name.toLowerCase();
                    if (!htmlText && (n.endsWith('.html') || n.endsWith('.htm'))) {
                        htmlText = new TextDecoder('utf-8').decode(entry.data);
                    } else {
                        const dot = n.lastIndexOf('.');
                        if (dot > 0 && imgExts.has(n.substring(dot + 1))) {
                            imagePaths.push(entry.name);
                            imageBytes.push(entry.data);
                        }
                    }
                }
                if (!htmlText) {
                    throw new Error('Zip contains no .html or .htm file.');
                }
            } else {
                htmlText = await file.text();
            }

            await this._processAndSaveHtmlBody(templateId, htmlText, file.name, { imagePaths, imageBytes });
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Upload Failed', msg, 'error');
        } finally {
            this.isUploadingHtml = false;
            event.target.value = '';
        }
    }

    /**
     * Shared HTML-body pipeline (file upload, paste-back editor, starter):
     * extract inline data: URI images, upload every image part, rewrite
     * <img src> to CV URLs, store the body, and sync the @page-ownership
     * state. Throws on failure — callers own the error toast.
     */
    async _processAndSaveHtmlBody(templateId, htmlText, fileName, zipImages, source) {
        // GUARD: never stage editor-internal artifacts. If a preview-wrapped
        // payload (scoped .dg-pv page), tag pills, or drop markers slip in —
        // e.g. from a stale cached bundle's older code path — unwrap and
        // strip them so the stored body is always clean template HTML.
        htmlText = this._sanitizeStagedHtml(htmlText);
        const imagePaths = (zipImages && zipImages.imagePaths) || [];
        const imageBytes = (zipImages && zipImages.imageBytes) || [];

        // Extract inline data: URI images (common in Notion, ChatGPT, Apple
        // Pages, or any rich-text-paste HTML). Blob.toPdf can't decode
        // data URIs, so each inline image becomes its own ContentVersion
        // with the src rewritten to /sfc/... just like zipped images.
        const dataUriMatches = [];
        const dataUriRe = /src\s*=\s*(["'])(data:image\/([a-zA-Z0-9+.-]+);base64,([A-Za-z0-9+/=\s]+?))\1/g;
        let m;
        while ((m = dataUriRe.exec(htmlText)) !== null) {
            const dataUri = m[2];
            let ext = m[3].toLowerCase();
            if (ext === 'jpeg') {
                ext = 'jpg';
            }
            if (ext === 'svg+xml') {
                ext = 'svg';
            }
            const base64 = m[4].replace(/\s+/g, '');
            dataUriMatches.push({ dataUri, ext, base64 });
        }

        // Upload each image; server returns CV Id + URL per part
        const urlByPath = {};
        for (let i = 0; i < imagePaths.length; i++) {
            const base = imagePaths[i].split('/').pop() || imagePaths[i];
            // eslint-disable-next-line no-await-in-loop
            const imgResult = await saveHtmlTemplateImage({
                templateId,
                fileName: base,
                base64Content: bytesToBase64(imageBytes[i])
            });
            urlByPath[imagePaths[i]] = imgResult.url;
            if (base !== imagePaths[i]) {
                urlByPath[base] = imgResult.url;
            }
        }

        // Upload extracted data: URIs; key by the full data: string so the
        // regex-replace below swaps each original URI for its CV URL.
        const dataUriUrlMap = [];
        for (let i = 0; i < dataUriMatches.length; i++) {
            const d = dataUriMatches[i];
            // eslint-disable-next-line no-await-in-loop
            const imgResult = await saveHtmlTemplateImage({
                templateId,
                fileName: 'inline_' + (i + 1) + '.' + d.ext,
                base64Content: d.base64
            });
            dataUriUrlMap.push({ dataUri: d.dataUri, url: imgResult.url });
        }

        // Rewrite <img src="..."> references client-side
        let rewritten = htmlText;
        for (const path of Object.keys(urlByPath)) {
            const url = urlByPath[path];
            rewritten = rewritten.split('"' + path + '"').join('"' + url + '"');
            rewritten = rewritten.split("'" + path + "'").join("'" + url + "'");
        }
        for (const entry of dataUriUrlMap) {
            rewritten = rewritten.split(entry.dataUri).join(entry.url);
        }
        const totalImages = imagePaths.length + dataUriMatches.length;

        // Save the final HTML body
        const bodyResult = await saveHtmlTemplateBody({
            templateId,
            fileName,
            htmlContent: rewritten
        });

        this.currentFileId = bodyResult.contentDocumentId;
        this.uploadedContentVersionId = bodyResult.contentVersionId;
        this.uploadedFileName = fileName;
        this._lastUploadedHtmlText = rewritten;
        this.stagedBodySource = source || 'file';
        this.htmlEditorDirty = false;
        // Keep the editor in lockstep with whatever just got staged — a file
        // upload while the editor is open must not leave stale HTML showing.
        if (this.showHtmlBodyEditor) {
            this._syncHtmlBodyEditorDom(rewritten);
        }
        const imgMsg =
            totalImages > 0 ? ' (' + totalImages + ' image' + (totalImages === 1 ? '' : 's') + ' extracted)' : '';
        // v1.90 — detect author-declared @page rule; if present, the engine suppresses
        // its own size/margin and the template-level page fields are dead inputs. Hide
        // them and clear in-memory values so a subsequent Save doesn't silently
        // re-introduce conflicting values.
        this.editHtmlBodyOwnsPageRule = this.htmlContainsPageRule(rewritten);
        if (this.editHtmlBodyOwnsPageRule) {
            this.editTemplatePageOrientation = null;
            this.editTemplatePageSize = null;
            this.editTemplatePageMargins = null;
            this.editTemplateCustomMargins = '';
        }
        const pageMsg = this.editHtmlBodyOwnsPageRule
            ? ' Your HTML defines its own @page CSS — template page-layout fields cleared.'
            : '';
        this.showToast(
            source === 'editor' ? 'Editor HTML staged' : 'Uploaded',
            fileName + imgMsg + '.' + pageMsg + ' Click "Save as New Version" to activate.',
            'success'
        );
        return rewritten;
    }

    /**
     * Strip every editor-internal artifact from HTML about to be staged:
     * tag pills back to plain text, drop markers gone, and — if the text is
     * (or contains) a scoped preview page — unwrap .dg-pv and remove the
     * injected preview <style>. Idempotent on clean input.
     */
    _sanitizeStagedHtml(html) {
        if (
            !html ||
            (html.indexOf('data-dg-tag') === -1 &&
                html.indexOf('dg-pv') === -1 &&
                html.indexOf('dg-drop-marker') === -1)
        ) {
            return html;
        }
        try {
            const tpl = document.createElement('template');
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            tpl.innerHTML = html;
            const root = tpl.content;
            for (const marker of root.querySelectorAll('.dg-drop-marker')) {
                marker.remove();
            }
            this._unpillifyTags(root);
            const pv = root.querySelector('div.dg-pv');
            if (pv) {
                // Preview-wrapped payload: keep only the page content, minus
                // the injected scoped stylesheet.
                for (const styleEl of pv.querySelectorAll(':scope > style')) {
                    styleEl.remove();
                }
                // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                const inner = pv.innerHTML.trim();
                // Preserve an original shell if one wrapped the preview; else
                // the content becomes the document body in a minimal shell.
                const bodyRe = /(<body\b[^>]*>)[\s\S]*?(<\/body\s*>)/i;
                const outer = html.replace(/[\s\S]*/, ''); // placeholder, replaced below
                void outer;
                if (bodyRe.test(html) && !/class="dg-pv"/.test(html.split(/<body\b[^>]*>/i)[0] || '')) {
                    return html.replace(bodyRe, (m, open, close) => open + '\n' + inner + '\n' + close);
                }
                return (
                    '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8" />\n<style>\n@page { size: Letter portrait; margin: 0.75in; }\nbody { font-family: Helvetica, Arial, sans-serif; font-size: 10.5pt; color: #1a1a1a; }\n</style>\n</head>\n<body>\n' +
                    inner +
                    '\n</body>\n</html>\n'
                );
            }
            // No pv wrapper — serialize the cleaned fragment back out.
            const container = document.createElement('div');
            container.appendChild(root.cloneNode(true));
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            return container.innerHTML;
        } catch (e) {
            return html;
        }
    }

    // --- HTML body editor (paste-back surface) ---
    get htmlBodyEditorToggleLabel() {
        return this.showHtmlBodyEditor ? 'Hide HTML Editor' : 'Edit HTML';
    }

    /** One-line answer to "what will Save as New Version actually save?" */
    get htmlEditorStatusText() {
        if (this.htmlEditorDirty) {
            return 'Unapplied edits — "Save as New Version" saves them; Reload discards.';
        }
        if (this.stagedBodySource === 'editor') {
            return 'Staged: your editor HTML — "Save as New Version" saves it.';
        }
        if (this.stagedBodySource === 'starter') {
            return 'Staged: starter design (' + this.uploadedFileName + ') — "Save as New Version" saves it.';
        }
        if (this.stagedBodySource === 'file') {
            return (
                'Staged: uploaded file "' + this.uploadedFileName + '" (shown below) — "Save as New Version" saves it.'
            );
        }
        return 'Showing the current saved body — nothing staged yet.';
    }

    get htmlEditorStatusClass() {
        return this.htmlEditorDirty ? 'dg-html-editor-status dg-html-editor-status_dirty' : 'dg-html-editor-status';
    }

    handleHtmlBodyEditorInput() {
        this.htmlEditorDirty = true;
        // Live preview beside the code — debounced so typing stays smooth.
        clearTimeout(this._codePreviewTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._codePreviewTimer = setTimeout(() => this._refreshCodePreview(), 400);
    }

    /** Re-render the side-by-side preview from the code editor's current text. */
    _refreshCodePreview() {
        const host = this.template.querySelector('.dg-code-preview');
        const ta = this.template.querySelector('.dg-html-body-editor');
        if (host && ta) {
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            host.innerHTML = scopeHtmlForInlinePreview(ta.value || '');
            const pv = host.querySelector('.dg-pv');
            if (pv) {
                // The preview sheet mirrors the page setup too.
                this._applyCanvasDimensions(pv);
            }
        }
    }

    get codeSplitClass() {
        return this.showHtmlBodyVisual ? 'dg-code-split slds-hide' : 'dg-code-split';
    }

    // --- Visual | Source segmented switch (persistent header, like any editor) ---
    get visualModeBtnClass() {
        return this.showHtmlBodyVisual
            ? 'dg-fmt-btn dg-fmt-btn_word dg-mode-btn dg-mode-btn_active'
            : 'dg-fmt-btn dg-fmt-btn_word dg-mode-btn';
    }

    get sourceModeBtnClass() {
        return this.showHtmlBodyVisual
            ? 'dg-fmt-btn dg-fmt-btn_word dg-mode-btn'
            : 'dg-fmt-btn dg-fmt-btn_word dg-mode-btn dg-mode-btn_active';
    }

    handleSelectVisualMode() {
        if (!this.showHtmlBodyVisual) {
            const ta = this.template.querySelector('.dg-html-body-editor');
            this._enterVisualMode((ta && ta.value) || '');
        }
    }

    handleSelectSourceMode() {
        if (this.showHtmlBodyVisual) {
            this._exitVisualMode();
        }
    }

    // --- Page setup: size / orientation / margins → @page rule + canvas sheet ---
    get pageSizeChoices() {
        return [
            { key: 'Letter', label: 'Letter' },
            { key: 'Legal', label: 'Legal' },
            { key: 'A4', label: 'A4' }
        ];
    }

    _parsePageSetup(code) {
        const setup = {
            size: 'Letter',
            orient: 'portrait',
            margin: '0.75',
            customW: '8.5',
            customH: '11',
            customMargin: '0.75'
        };
        const m = /@page\s*\{([^}]*)\}/i.exec(code || '');
        if (m) {
            const body = m[1];
            const sm = /size\s*:\s*(letter|legal|a4)\s*(portrait|landscape)?/i.exec(body);
            const cm = /size\s*:\s*([\d.]+)\s*in\s+([\d.]+)\s*in/i.exec(body);
            if (cm) {
                setup.size = 'Custom';
                setup.customW = cm[1];
                setup.customH = cm[2];
            } else if (sm) {
                const raw = sm[1].toLowerCase();
                setup.size = raw === 'a4' ? 'A4' : raw.charAt(0).toUpperCase() + raw.slice(1);
                if (sm[2]) {
                    setup.orient = sm[2].toLowerCase();
                }
            }
            const mm = /margin\s*:\s*([\d.]+)\s*in/i.exec(body);
            if (mm) {
                setup.margin = ['0.5', '0.75', '1'].includes(mm[1]) ? mm[1] : 'custom';
                setup.customMargin = mm[1];
            }
        }
        this.pageSetup = setup;
    }

    get isCustomPageSize() {
        return this.pageSetup.size === 'Custom';
    }

    get isCustomMargin() {
        return this.pageSetup.margin === 'custom';
    }

    handlePageSetupChange(event) {
        const field = event.currentTarget.dataset.field;
        this.pageSetup = { ...this.pageSetup, [field]: event.currentTarget.value };
        this._applyPageSetup();
    }

    _applyPageSetup() {
        const ta = this.template.querySelector('.dg-html-body-editor');
        if (!ta) {
            return;
        }
        const sizePart = this.isCustomPageSize
            ? (parseFloat(this.pageSetup.customW) || 8.5) + 'in ' + (parseFloat(this.pageSetup.customH) || 11) + 'in'
            : this.pageSetup.size + ' ' + this.pageSetup.orient;
        const marginVal = this.isCustomMargin ? parseFloat(this.pageSetup.customMargin) || 0.75 : this.pageSetup.margin;
        const rule = '@page { size: ' + sizePart + '; margin: ' + marginVal + 'in; }';
        let code = ta.value || '';
        if (/@page\s*\{[^}]*\}/i.test(code)) {
            code = code.replace(/@page\s*\{[^}]*\}/i, rule);
        } else if (/<style\b[^>]*>/i.test(code)) {
            code = code.replace(/<style\b[^>]*>/i, (m) => m + '\n        ' + rule);
        } else {
            code = '<style>\n' + rule + '\n</style>\n' + code;
        }
        ta.value = code;
        this._visualOriginalCode = code;
        this.htmlEditorDirty = true;
        this._applyCanvasDimensions();
        this._refreshCodePreview();
    }

    /** Make the on-screen sheet match the page setup (Lucid-style canvas). */
    _applyCanvasDimensions(targetPv) {
        const pvs = [];
        if (targetPv) {
            pvs.push(targetPv);
        } else {
            for (const hostSel of ['.dg-visual-host', '.dg-code-preview']) {
                const host = this.template.querySelector(hostSel);
                const pv = host && host.querySelector('.dg-pv');
                if (pv) {
                    pvs.push(pv);
                }
            }
        }
        if (!pvs.length) {
            return;
        }
        const widths = { Letter: 816, Legal: 816, A4: 794 };
        const heights = { Letter: 1056, Legal: 1344, A4: 1123 };
        let w;
        let h;
        if (this.isCustomPageSize) {
            w = Math.round((parseFloat(this.pageSetup.customW) || 8.5) * 96);
            h = Math.round((parseFloat(this.pageSetup.customH) || 11) * 96);
        } else {
            const landscape = this.pageSetup.orient === 'landscape';
            w = landscape ? heights[this.pageSetup.size] || 1056 : widths[this.pageSetup.size] || 816;
            h = landscape ? widths[this.pageSetup.size] || 816 : heights[this.pageSetup.size] || 1056;
        }
        const marginVal = this.isCustomMargin
            ? parseFloat(this.pageSetup.customMargin) || 0.75
            : parseFloat(this.pageSetup.margin || '0.75');
        const pad = Math.round(marginVal * 96);
        for (const pv of pvs) {
            pv.style.maxWidth = w + 'px';
            pv.style.width = w + 'px';
            pv.style.minHeight = h + 'px';
            pv.style.padding = pad + 'px';
        }
    }

    // --- Format Code + Code ⇄ Preview (shared by the HTML editor and the DOCX viewer) ---
    get docxHtmlPreviewToggleLabel() {
        return this.showDocxHtmlPreview ? 'Show Code' : 'Preview';
    }

    get htmlBodyEditorClass() {
        return this.showHtmlBodyVisual ? 'dg-html-body-editor slds-hide' : 'dg-html-body-editor';
    }

    get visualToggleLabel() {
        return this.showHtmlBodyVisual ? 'Back to Code' : 'Visual';
    }

    /** Designer canvas: same editor classes plus the full-height variant. */
    get designerEditorClass() {
        return this.htmlBodyEditorClass + ' dg-designer-size';
    }

    // --- Visual-mode format bar (alignment, size, colors) ---
    get textColorSwatches() {
        return [
            { key: 'c_black', value: '#1a1a1a', style: 'background: #1a1a1a', title: 'Black text' },
            { key: 'c_navy', value: '#1f3a5f', style: 'background: #1f3a5f', title: 'Navy text' },
            { key: 'c_gray', value: '#666666', style: 'background: #666666', title: 'Gray text' },
            { key: 'c_blue', value: '#1b5e9e', style: 'background: #1b5e9e', title: 'Blue text' },
            { key: 'c_green', value: '#1c7a3d', style: 'background: #1c7a3d', title: 'Green text' },
            { key: 'c_red', value: '#b91c1c', style: 'background: #b91c1c', title: 'Red text' },
            { key: 'c_white', value: '#ffffff', style: 'background: #ffffff; border-color: #999', title: 'White text' }
        ];
    }

    get highlightSwatches() {
        return [
            {
                key: 'h_none',
                value: 'transparent',
                style: 'background: #fff; border-color: #999',
                title: 'No highlight'
            },
            { key: 'h_yellow', value: '#fef3c7', style: 'background: #fef3c7', title: 'Yellow highlight' },
            { key: 'h_blue', value: '#e8f0fb', style: 'background: #e8f0fb', title: 'Blue highlight' },
            { key: 'h_green', value: '#e3f5e9', style: 'background: #e3f5e9', title: 'Green highlight' },
            { key: 'h_gray', value: '#f2f4f7', style: 'background: #f2f4f7', title: 'Gray highlight' },
            { key: 'h_navy', value: '#1f3a5f', style: 'background: #1f3a5f', title: 'Navy fill (use white text)' }
        ];
    }

    /** The PDF engine ships exactly four fonts — the picker offers exactly those. */
    get fontChoices() {
        return [
            {
                key: 'f_helv',
                label: 'Helvetica',
                value: 'Helvetica, Arial, sans-serif',
                style: 'font-family: Helvetica, Arial, sans-serif',
                title: 'Helvetica — clean sans-serif (default)'
            },
            {
                key: 'f_times',
                label: 'Times',
                value: "'Times New Roman', Times, serif",
                style: "font-family: 'Times New Roman', Times, serif",
                title: 'Times — formal serif'
            },
            {
                key: 'f_courier',
                label: 'Courier',
                value: "'Courier New', Courier, monospace",
                style: "font-family: 'Courier New', Courier, monospace",
                title: 'Courier — monospace, great for codes and numbers'
            },
            {
                key: 'f_unicode',
                label: 'Unicode',
                value: "'Arial Unicode MS', Arial, sans-serif",
                style: 'font-family: Arial, sans-serif',
                title: 'Arial Unicode MS — widest character coverage (international text)'
            }
        ];
    }

    /** Keep the page's text selection alive while clicking toolbar controls. */
    handleFmtMouseDown(event) {
        event.preventDefault();
    }

    /** Caret with no selection? Format the word under it — click, color, done. */
    _expandCaretToWord() {
        try {
            const sel = window.getSelection();
            if (!sel || !sel.rangeCount || !sel.isCollapsed || typeof sel.modify !== 'function') {
                return;
            }
            const host = this.template.querySelector('.dg-visual-host');
            const pv = host && host.querySelector('.dg-pv');
            const anchorEl =
                sel.anchorNode && sel.anchorNode.nodeType === 3 ? sel.anchorNode.parentElement : sel.anchorNode;
            if (pv && anchorEl && pv.contains(anchorEl)) {
                sel.modify('move', 'backward', 'word');
                sel.modify('extend', 'forward', 'word');
            }
        } catch (e) {
            /* best effort */
        }
    }

    /** Toolbar breadcrumb: what element is the caret inside? */
    _onSelectionChange = () => {
        if (!this.showHtmlBodyVisual || this.activeMainTab !== 'design') {
            return;
        }
        let node = null;
        try {
            const sel = window.getSelection();
            node = sel && sel.anchorNode;
        } catch (e) {
            return;
        }
        while (node && node.nodeType === 3) {
            node = node.parentNode;
        }
        const host = this.template.querySelector('.dg-visual-host');
        const pv = host && host.querySelector('.dg-pv');
        if (!node || !pv || !pv.contains(node)) {
            this.selectionContextLabel = '';
            return;
        }
        // Stash the live caret so the "/" hotkey recovery can restore it after
        // Lightning's global-search handler steals focus.
        try {
            const sel = window.getSelection();
            if (sel && sel.rangeCount) {
                this._lastCanvasRange = sel.getRangeAt(0).cloneRange();
            }
        } catch (e) {
            /* best effort */
        }
        const names = {
            H1: 'Title',
            H2: 'Heading',
            H3: 'Heading',
            P: 'Paragraph',
            TD: 'Table cell',
            TH: 'Header cell',
            LI: 'List item',
            B: 'Bold text',
            STRONG: 'Bold text',
            I: 'Italic text',
            EM: 'Italic text',
            IMG: 'Image'
        };
        let label = '';
        let el = node;
        while (el && el !== pv) {
            const n = names[el.tagName];
            if (n) {
                label = n;
                break;
            }
            el = el.parentElement;
        }
        this.selectionContextLabel = 'Editing: ' + (label || 'Page');
    };

    // --- Table tools (visual mode): operate on the cell holding the caret ---
    _selectedTableCell() {
        let node = null;
        try {
            const sel = window.getSelection();
            node = sel && sel.anchorNode;
        } catch (e) {
            node = null;
        }
        while (node && node.nodeType === 3) {
            node = node.parentNode;
        }
        const host = this.template.querySelector('.dg-visual-host');
        const pv = host && host.querySelector('.dg-pv');
        if (!node || !pv || !pv.contains(node) || !node.closest) {
            return null;
        }
        const cell = node.closest('td, th');
        return cell && pv.contains(cell) ? cell : null;
    }

    handleTableAction(event) {
        if (!this.showHtmlBodyVisual) {
            return;
        }
        const action = event.currentTarget.dataset.taction;
        const value = event.currentTarget.dataset.value || null;
        const cell = this._selectedTableCell();
        if (!cell) {
            // Fill works everywhere: outside a table it colors the block the
            // caret is in (paragraph, heading, list item, div panel).
            if (action === 'cellFill') {
                const blk = this._selectedBlockElement();
                if (blk) {
                    blk.style.background = value === 'transparent' ? '' : value;
                    if (value !== 'transparent' && !blk.style.padding) {
                        blk.style.padding = '6pt 8pt';
                    }
                    this.htmlEditorDirty = true;
                    return;
                }
            }
            this.showToast(
                'Click inside a table cell first',
                'Put your cursor in the table you want to change, then use the table tools.',
                'info'
            );
            return;
        }
        const row = cell.parentElement;
        const table = cell.closest('table');
        const cellIndex = Array.prototype.indexOf.call(row.children, cell);
        if (action === 'rowBefore') {
            const clone = row.cloneNode(true);
            for (const c of clone.children) {
                c.innerHTML = '&nbsp;';
                c.removeAttribute('rowspan');
            }
            row.insertAdjacentElement('beforebegin', clone);
        } else if (action === 'colBefore') {
            for (const tr of table.rows) {
                const ref = tr.children[Math.min(cellIndex, tr.children.length - 1)];
                if (ref) {
                    const c = ref.cloneNode(false);
                    c.innerHTML = '&nbsp;';
                    c.removeAttribute('colspan');
                    ref.insertAdjacentElement('beforebegin', c);
                }
            }
        } else if (action === 'mergeCells') {
            this._mergeCells(cell, table);
        } else if (action === 'splitCell') {
            this._splitCell(cell, row, table, cellIndex);
        } else if (action === 'tableDel') {
            table.remove();
        } else if (action === 'rowAfter') {
            const clone = row.cloneNode(true);
            for (const c of clone.children) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                c.innerHTML = '&nbsp;';
            }
            row.insertAdjacentElement('afterend', clone);
        } else if (action === 'rowDel') {
            row.remove();
            if (table && !table.querySelector('tr')) {
                table.remove();
            }
        } else if (action === 'colAfter') {
            for (const tr of table.rows) {
                const ref = tr.children[Math.min(cellIndex, tr.children.length - 1)];
                if (ref) {
                    const c = ref.cloneNode(false);
                    // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                    c.innerHTML = '&nbsp;';
                    ref.insertAdjacentElement('afterend', c);
                }
            }
        } else if (action === 'colDel') {
            for (const tr of table.rows) {
                if (tr.children[cellIndex]) {
                    tr.children[cellIndex].remove();
                }
            }
            if (table && !table.querySelector('td, th')) {
                table.remove();
            }
        } else if (action === 'repeatHeader') {
            // {RepeatHeader} in the header row makes it repeat on every PDF
            // page (the v2.9 large-table behavior). Toggle it.
            const headerRow = (table.tHead && table.tHead.rows[0]) || table.rows[0];
            const firstCell = headerRow && headerRow.cells[0];
            if (firstCell) {
                const existing = Array.from(headerRow.querySelectorAll('[data-dg-tag]')).find((pl) =>
                    /repeatheader/i.test(pl.textContent)
                );
                if (existing) {
                    existing.remove();
                    this.showToast('Repeat header off', 'This table header no longer repeats on every page.', 'info');
                } else {
                    firstCell.insertBefore(document.createTextNode('{RepeatHeader}'), firstCell.firstChild);
                    this._pillifyTags(firstCell);
                    this.showToast(
                        'Repeat header on',
                        'The header row now repeats at the top of every PDF page this table spans.',
                        'success'
                    );
                }
                this.htmlEditorDirty = true;
            }
        } else if (action === 'headerRow') {
            for (const c of row.children) {
                c.style.background = '#1f3a5f';
                c.style.color = '#ffffff';
                c.style.fontWeight = 'bold';
            }
        } else if (action === 'cellFill') {
            cell.style.background = value === 'transparent' ? '' : value;
        } else if (action === 'bordersAll') {
            table.style.borderCollapse = 'collapse';
            table.style.border = '1pt solid #444444';
            for (const c of table.querySelectorAll('td, th')) {
                c.style.border = '0.75pt solid #999999';
            }
        } else if (action === 'bordersOutline') {
            table.style.borderCollapse = 'collapse';
            table.style.border = '1pt solid #444444';
            for (const c of table.querySelectorAll('td, th')) {
                c.style.border = 'none';
            }
        } else if (action === 'bordersRows') {
            table.style.borderCollapse = 'collapse';
            table.style.border = 'none';
            for (const c of table.querySelectorAll('td, th')) {
                c.style.border = 'none';
                c.style.borderBottom = '0.75pt solid #cccccc';
            }
        } else if (action === 'bordersNone') {
            table.style.border = 'none';
            for (const c of table.querySelectorAll('td, th')) {
                c.style.border = 'none';
            }
        }
        this.htmlEditorDirty = true;
    }

    // --- Column drag-resize (grab a cell's right edge) ---
    _resizeEdgeCell(event, pv) {
        const cell = event.target && event.target.closest ? event.target.closest('td, th') : null;
        if (!cell || !pv.contains(cell)) {
            return null;
        }
        const rect = cell.getBoundingClientRect();
        return event.clientX >= rect.right - 5 && event.clientX <= rect.right + 5 ? cell : null;
    }

    /** Corner-drag resize for canvas images; asset tags get the new size
     *  written back as {%asset:key:<W>x} (width-only, aspect preserved). */
    _imgResizeHover(event) {
        const img = event.target && event.target.tagName === 'IMG' ? event.target : null;
        if (img) {
            img.style.cursor = 'nwse-resize';
        }
    }

    _imgResizeStart(event, pv) {
        const img = event.target && event.target.tagName === 'IMG' ? event.target : null;
        if (!img || !pv.contains(img)) {
            return false;
        }
        event.preventDefault();
        const startX = event.clientX;
        const startW = img.getBoundingClientRect().width;
        const doc = pv.ownerDocument || document;
        const onMove = (ev) => {
            const w = Math.max(24, Math.round(startW + (ev.clientX - startX)));
            img.style.width = w + 'px';
            img.style.height = 'auto';
            img.style.maxWidth = '';
        };
        const onUp = () => {
            doc.removeEventListener('mousemove', onMove);
            doc.removeEventListener('mouseup', onUp);
            const attr = img.getAttribute('data-dg-tag');
            const m = attr && /^\{%asset:([a-z0-9-]+)/i.exec(attr);
            if (m) {
                const w = Math.round(img.getBoundingClientRect().width);
                img.setAttribute('data-dg-tag', '{%asset:' + m[1] + ':' + w + 'x}');
                img.title = img.getAttribute('data-dg-tag') + ' — drag the corner to resize';
            }
            this.htmlEditorDirty = true;
        };
        doc.addEventListener('mousemove', onMove);
        doc.addEventListener('mouseup', onUp);
        return true;
    }

    _tableResizeHover(event, pv) {
        if (this._colResizing) {
            return;
        }
        const cell = this._resizeEdgeCell(event, pv);
        const hovered = event.target && event.target.closest ? event.target.closest('td, th') : null;
        if (hovered) {
            hovered.style.cursor = cell ? 'col-resize' : '';
        }
    }

    _tableResizeStart(event, pv) {
        const cell = this._resizeEdgeCell(event, pv);
        if (!cell) {
            return;
        }
        event.preventDefault();
        this._colResizing = true;
        const startX = event.clientX;
        const startW = cell.getBoundingClientRect().width;
        const doc = pv.ownerDocument || document;
        // Fixed-layout tables (all Word-converted ones after the auto-fit)
        // read column widths from <colgroup> cols and the FIRST row — writing
        // only the grabbed cell does nothing there. Write all three.
        const table = cell.closest('table');
        const colIdx = Array.prototype.indexOf.call(cell.parentElement.children, cell);
        const colEl = table ? table.querySelectorAll('colgroup col')[colIdx] : null;
        const firstRowCell = table && table.rows.length ? table.rows[0].children[colIdx] : null;
        const onMove = (ev) => {
            const w = Math.max(24, startW + (ev.clientX - startX)) + 'px';
            cell.style.width = w;
            if (colEl) {
                colEl.removeAttribute('width');
                colEl.style.width = w;
            }
            if (firstRowCell && firstRowCell !== cell) {
                firstRowCell.style.width = w;
            }
        };
        const onUp = () => {
            doc.removeEventListener('mousemove', onMove);
            doc.removeEventListener('mouseup', onUp);
            this._colResizing = false;
            this.htmlEditorDirty = true;
        };
        doc.addEventListener('mousemove', onMove);
        doc.addEventListener('mouseup', onUp);
    }

    /**
     * Turn the caret's paragraph into a list item (or back). Enter inside a
     * list adds items natively; toggling a list item lifts it back out as a
     * paragraph. Inside a table cell the list wraps the cell's content.
     */
    _toggleListAtCaret(ordered) {
        const blk = this._selectedBlockElement();
        if (!blk) {
            this.showToast(
                'Click into some text first',
                'Put your cursor in a paragraph, then click the list button.',
                'info'
            );
            return;
        }
        const doc = blk.ownerDocument || document;
        const placeCaret = (el) => {
            try {
                const r = doc.createRange();
                r.selectNodeContents(el);
                r.collapse(false);
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(r);
            } catch (e) {
                /* best effort */
            }
        };
        if (blk.tagName === 'LI') {
            // Toggle OFF: lift this item out of the list as a paragraph.
            const list = blk.parentElement;
            const p = doc.createElement('p');
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            p.innerHTML = blk.innerHTML;
            list.insertAdjacentElement('afterend', p);
            blk.remove();
            if (list && !list.querySelector('li')) {
                list.remove();
            }
            placeCaret(p);
        } else if (blk.tagName === 'TD' || blk.tagName === 'TH') {
            const list = doc.createElement(ordered ? 'ol' : 'ul');
            list.style.margin = '2pt 0 2pt 14pt';
            const li = doc.createElement('li');
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            li.innerHTML = blk.innerHTML && blk.innerHTML.trim() !== '&nbsp;' ? blk.innerHTML : 'List item';
            list.appendChild(li);
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            blk.innerHTML = '';
            blk.appendChild(list);
            placeCaret(li);
        } else {
            const list = doc.createElement(ordered ? 'ol' : 'ul');
            list.style.margin = '6pt 0 6pt 18pt';
            const li = doc.createElement('li');
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            li.innerHTML = blk.innerHTML || 'List item';
            list.appendChild(li);
            blk.replaceWith(list);
            placeCaret(li);
        }
        this.htmlEditorDirty = true;
    }

    /** The block element (p, heading, list item, div, td) holding the caret. */
    _selectedBlockElement() {
        let node = null;
        try {
            const sel = window.getSelection();
            node = sel && sel.anchorNode;
        } catch (e) {
            return null;
        }
        while (node && node.nodeType === 3) {
            node = node.parentNode;
        }
        const host = this.template.querySelector('.dg-visual-host');
        const pv = host && host.querySelector('.dg-pv');
        if (!node || !pv || !pv.contains(node) || !node.closest) {
            return null;
        }
        const blk = node.closest('p, h1, h2, h3, h4, li, div, td, th');
        return blk && pv.contains(blk) && blk !== pv ? blk : null;
    }

    /**
     * Apply formatting to the current selection in the editable page.
     * styleWithCSS makes execCommand emit inline CSS spans — exactly the
     * flat, Flying Saucer-safe styling the PDF engine renders.
     */
    handleFormatAction(event) {
        if (!this.showHtmlBodyVisual) {
            return;
        }
        const cmd = event.currentTarget.dataset.cmd;
        const value = event.currentTarget.dataset.value || null;
        if (!cmd) {
            return;
        }
        // Lists via DOM surgery — LWS quietly breaks execCommand's list
        // commands, and this way numbers/bullets always render.
        if (cmd === 'insertUnorderedList' || cmd === 'insertOrderedList') {
            this._toggleListAtCaret(cmd === 'insertOrderedList');
            return;
        }
        if (
            /^(bold|italic|underline|strikeThrough|superscript|subscript|foreColor|hiliteColor|fontName|fontSize)$/.test(
                cmd
            )
        ) {
            this._expandCaretToWord();
        }
        try {
            document.execCommand('styleWithCSS', false, 'true');
            const ok = document.execCommand(cmd, false, value);
            if (ok) {
                this.htmlEditorDirty = true;
            } else if (cmd !== 'undo' && cmd !== 'redo') {
                this.showToast(
                    'Select some text first',
                    'Highlight text in the page, then click a format button.',
                    'info'
                );
            }
        } catch (e) {
            this.showToast('Formatting unavailable', 'This browser blocked the formatting command.', 'warning');
        }
    }

    /**
     * Custom color pickers: opening the native picker steals focus, so the
     * page selection is snapshotted on mousedown and restored before the
     * chosen color is applied.
     */
    handleColorPickMouseDown() {
        try {
            const sel = window.getSelection();
            this._savedFmtRange = sel && sel.rangeCount ? sel.getRangeAt(0).cloneRange() : null;
        } catch (e) {
            this._savedFmtRange = null;
        }
    }

    handleColorPickChange(event) {
        if (!this.showHtmlBodyVisual) {
            return;
        }
        const cmd = event.currentTarget.dataset.cmd;
        const value = event.currentTarget.value;
        if (this._savedFmtRange) {
            try {
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(this._savedFmtRange);
            } catch (e) {
                /* selection restore is best-effort */
            }
        }
        if (cmd === 'cellFill') {
            const cell = this._selectedTableCell();
            if (cell) {
                cell.style.background = value;
                this.htmlEditorDirty = true;
            } else {
                this.showToast(
                    'Click inside a table cell first',
                    'Put your cursor in a cell, then pick the fill color.',
                    'info'
                );
            }
            return;
        }
        this._expandCaretToWord();
        try {
            document.execCommand('styleWithCSS', false, 'true');
            if (document.execCommand(cmd, false, value)) {
                this.htmlEditorDirty = true;
            }
        } catch (e) {
            /* ignore */
        }
    }

    /**
     * Enter/exit visual (in-place) editing. The template renders through the
     * SAME scoped-preview pipeline the Preview toggle uses — tables, bands,
     * everything — and the rendered page is made contenteditable, so authors
     * edit text exactly where it appears. On exit, only the edited body
     * content is swapped back between the ORIGINAL document's <body> tags:
     * head, styles, and @page are never round-tripped, so structure can't be
     * mangled. Unchanged sessions restore the original code byte-for-byte.
     */
    handleToggleHtmlVisual() {
        if (this.showHtmlBodyVisual) {
            this._exitVisualMode();
            return;
        }
        const ta = this.template.querySelector('.dg-html-body-editor');
        const html = (ta && ta.value) || '';
        if (!html.trim()) {
            this.showToast('Nothing to edit', 'Load or paste a template body first.', 'warning');
            return;
        }
        this._enterVisualMode(html);
    }

    _enterVisualMode(html) {
        this._visualOriginalCode = html;
        this._visualEnteredDom = null; // captured in renderedCallback after mount
        this._parsePageSetup(html);
        this.showHtmlBodyVisual = true;
        // Reuse the preview pipeline, but flag the write as editable so
        // renderedCallback turns the rendered page into an editor.
        const scoped = scopeHtmlForInlinePreview(html);
        this._pendingPreviewWrite = { selector: '.dg-visual-host', html: scoped, editable: true };
    }

    /**
     * Merge tags become atomic pills in the editable page: friendly colored
     * chips (purple fields, green loop/section markers) that read as objects
     * instead of code, and — because they're contenteditable=false — can only
     * be deleted whole, never half-mangled. Walks TEXT nodes only, so tags
     * inside attributes are untouched.
     */
    _pillifyTags(root) {
        const doc = root.ownerDocument || document;
        // Repair pass: flatten any pill-inside-pill layering left behind by
        // older bundles before wrapping anything new.
        let nested = root.querySelectorAll('[data-dg-tag] [data-dg-tag]');
        while (nested.length) {
            for (const inner of nested) {
                inner.replaceWith(doc.createTextNode(inner.textContent));
            }
            nested = root.querySelectorAll('[data-dg-tag] [data-dg-tag]');
        }
        const walker = doc.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        const targets = [];
        while (walker.nextNode()) {
            const node = walker.currentNode;
            const parent = node.parentElement;
            // Never wrap inside <style>, and NEVER inside an existing pill —
            // re-pillifying pill text nests a new layer on every insert.
            // parent === null is a FRAGMENT-ROOT text node (bare tag snippet
            // from a chip) — those must pillify too.
            const blocked = parent && (parent.tagName === 'STYLE' || parent.closest('[data-dg-tag]'));
            if (/\{[^{}]+\}/.test(node.nodeValue) && !blocked) {
                targets.push(node);
            }
        }
        for (const node of targets) {
            const frag = doc.createDocumentFragment();
            for (const part of node.nodeValue.split(/(\{[^{}]+\})/g)) {
                if (/^\{[^{}]+\}$/.test(part)) {
                    const assetImg = this._assetImgFor(part, doc);
                    if (assetImg) {
                        frag.appendChild(assetImg);
                        continue;
                    }
                    const pill = doc.createElement('span');
                    pill.setAttribute('data-dg-tag', 'true');
                    pill.setAttribute('contenteditable', 'false');
                    pill.textContent = part;
                    pill.style.cssText = this._pillStyleFor(part);
                    frag.appendChild(pill);
                } else if (part) {
                    frag.appendChild(doc.createTextNode(part));
                }
            }
            node.parentNode.replaceChild(frag, node);
        }
    }

    _pillStyleFor(tagText) {
        const isStructural = /^[#/:%@*]/.test((tagText || '').charAt(1));
        return isStructural
            ? 'background:#e3f5e9;border:1px solid #9fd6b1;color:#1c7a3d;border-radius:9px;padding:0 6px;font-size:0.9em;white-space:nowrap;cursor:pointer;'
            : 'background:#ede7fd;border:1px solid #c9b8f5;color:#5a3fc4;border-radius:9px;padding:0 6px;font-size:0.9em;white-space:nowrap;cursor:pointer;';
    }

    /**
     * Pill inspector: parse the clicked pill's tag and offer one-click
     * transformations — format suffixes, or re-render the same field as a
     * QR code, barcode, or image.
     */
    _openPillMenu(pill) {
        this._activePill = pill;
        const raw = (pill.textContent || '').trim();
        const inner = raw.replace(/^\{|\}$/g, '');
        const first = inner.charAt(0);
        let field = null;
        if (first === '*' || first === '%') {
            field = inner.slice(1).split(':')[0];
        } else if (!/^[#/:@]/.test(first) && !/^(SUM|AVG|MIN|MAX|COUNT|Chart)\b/i.test(inner)) {
            field = inner.split(':')[0];
        }
        let sections = [];
        if (field) {
            const f = field;
            const opt = (key, label, tag) => ({
                key,
                label,
                tag,
                cls: tag === raw ? 'dg-pill-menu-item dg-pill-menu-item_active' : 'dg-pill-menu-item'
            });
            const cur = (code, sample) => opt('cur_' + code, code + '  ' + sample, '{' + f + ':currency:' + code + '}');
            const dt = (pat, sample) => opt('dt_' + pat, sample, '{' + f + ':' + pat + '}');
            sections = [
                {
                    key: 'text',
                    label: 'Text',
                    options: [
                        opt('plain', 'Plain text', '{' + f + '}'),
                        opt('label', 'Picklist label', '{' + f + ':label}'),
                        opt('checkbox', 'Checkbox [X]/[ ]', '{' + f + ':checkbox}')
                    ]
                },
                {
                    key: 'currency',
                    label: 'Currency',
                    options: [
                        opt(
                            'cur_auto',
                            "Record's currency (multi-currency orgs) — recommended",
                            '{' + f + ':currency:auto}'
                        ),
                        opt('currency', "User's currency — $1,234.00", '{' + f + ':currency}'),
                        cur('USD', '$1,234.56'),
                        cur('EUR', '1.234,56 €'),
                        cur('GBP', '£1,234.56'),
                        cur('JPY', '¥1,235'),
                        cur('CAD', 'CA$1,234.56'),
                        cur('AUD', 'A$1,234.56'),
                        cur('CHF', "CHF 1'234.56"),
                        cur('CNY', '¥1,234.56'),
                        cur('INR', '₹1,23,456.00'),
                        cur('BRL', 'R$ 1.234,56'),
                        cur('MXN', 'MX$1,234.56')
                    ]
                },
                {
                    key: 'dates',
                    label: 'Dates',
                    options: [
                        opt('date_user', "Reader's locale date (auto)", '{' + f + ':date}'),
                        opt('date_gb', 'UK locale — 17/04/2026', '{' + f + ':date:en_GB}'),
                        opt('date_de', 'German locale — 17.04.2026', '{' + f + ':date:de_DE}'),
                        opt('date_fr', 'French locale — 17/04/2026', '{' + f + ':date:fr_FR}'),
                        opt('date_jp', 'Japanese locale — 2026/04/17', '{' + f + ':date:ja_JP}'),
                        opt('date_br', 'Brazilian locale — 17/04/2026', '{' + f + ':date:pt_BR}'),
                        dt('MMMM d, yyyy', 'April 17, 2026 — US long'),
                        dt('MMM d, yyyy', 'Apr 17, 2026'),
                        dt('MM/dd/yyyy', '04/17/2026 — US'),
                        dt('dd/MM/yyyy', '17/04/2026 — UK · EU'),
                        dt('d MMMM yyyy', '17 April 2026 — EU long'),
                        dt('dd.MM.yyyy', '17.04.2026 — DE · CH'),
                        dt('yyyy-MM-dd', '2026-04-17 — ISO'),
                        dt('yyyy年M月d日', '2026年4月17日 — JP'),
                        dt('EEEE, MMMM d, yyyy', 'Friday, April 17, 2026'),
                        dt('MMMM yyyy', 'April 2026 — month only'),
                        dt('MMMM d, yyyy h:mm a', 'April 17, 2026 3:45 PM')
                    ]
                },
                {
                    key: 'numbers',
                    label: 'Numbers',
                    options: [
                        opt('number', 'Number — 1,234', '{' + f + ':number}'),
                        opt('number_eu', 'Number EU — 1.234', '{' + f + ':number:de_DE}'),
                        opt('percent_eu', 'Percent EU — 15,5%', '{' + f + ':percent:de_DE}'),
                        dt('#,##0.00', '1,234.50 — two decimals'),
                        dt('#,##0', '1,235 — whole'),
                        dt('0.00', '1234.50 — no thousands'),
                        opt('percent', 'Percent — 15.5%', '{' + f + ':percent}')
                    ]
                },
                {
                    key: 'other',
                    label: 'Codes & images',
                    options: [
                        opt('qr', 'QR code', '{*' + f + ':qr:200}'),
                        opt('barcode', 'Barcode (Code 128)', '{*' + f + ':code128:300x80}'),
                        opt('barcode39', 'Barcode (Code 39)', '{*' + f + ':code39:300x80}'),
                        opt('image', 'Image field', '{%' + f + '}')
                    ]
                }
            ];
        }
        // Position the menu just under the pill, relative to the canvas column.
        const col = this.template.querySelector('.dg-designer-canvas-col');
        const colRect = col ? col.getBoundingClientRect() : { left: 0, top: 0 };
        const rect = pill.getBoundingClientRect();
        this.pillMenu = {
            tagText: raw,
            sections,
            hasOptions: sections.length > 0,
            posStyle:
                'left: ' + Math.max(0, rect.left - colRect.left) + 'px; top: ' + (rect.bottom - colRect.top + 6) + 'px;'
        };
    }

    handlePillTransform(event) {
        const tag = event.currentTarget.dataset.tag;
        if (this._activePill && tag) {
            this._activePill.textContent = tag;
            this._activePill.style.cssText = this._pillStyleFor(tag);
            this.htmlEditorDirty = true;
        }
        this.pillMenu = null;
    }

    handlePillRemove() {
        if (this._activePill) {
            this._activePill.remove();
            this.htmlEditorDirty = true;
        }
        this.pillMenu = null;
        this._activePill = null;
    }

    handlePillMenuClose() {
        this.pillMenu = null;
    }

    handlePillEdit() {
        if (this._activePill) {
            this._beginPillEdit(this._activePill);
        }
        this.pillMenu = null;
    }

    /**
     * Edit a pill's tag text in place (loop names, conditionals, modifiers —
     * anything). Enter or clicking away commits; braces are auto-completed;
     * an emptied pill removes itself.
     */
    _beginPillEdit(pill) {
        this.pillMenu = null;
        pill.setAttribute('contenteditable', 'true');
        pill.style.borderStyle = 'dashed';
        pill.style.cursor = 'text';
        this._editingPill = pill;
        try {
            const range = document.createRange();
            range.selectNodeContents(pill);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
        } catch (e) {
            /* selection best-effort */
        }
        const finish = () => {
            if (this._editingPill !== pill) {
                return; // already committed (blur + outside-click both fired)
            }
            this._editingPill = null;
            pill.removeEventListener('blur', finish);
            let t = (pill.textContent || '').trim();
            if (!t || t === '{}' || t === '{' || t === '}') {
                pill.remove();
                this.htmlEditorDirty = true;
                return;
            }
            if (!t.startsWith('{')) {
                t = '{' + t;
            }
            if (!t.endsWith('}')) {
                t = t + '}';
            }
            pill.textContent = t;
            pill.setAttribute('contenteditable', 'false');
            pill.style.cssText = this._pillStyleFor(t);
            this.htmlEditorDirty = true;
            // Park the caret AFTER the pill — leaving it inside means the next
            // keystrokes grow the pill instead of typing beside it.
            try {
                const host = this.template.querySelector('.dg-visual-host');
                const pv = host && host.querySelector('.dg-pv');
                const r = document.createRange();
                r.setStartAfter(pill);
                r.collapse(true);
                const s = window.getSelection();
                s.removeAllRanges();
                s.addRange(r);
                if (pv) {
                    pv.focus();
                }
            } catch (e) {
                /* caret parking best-effort */
            }
        };
        this._finishPillEdit = finish;
        pill.addEventListener('blur', finish);
        pill.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' || e.key === 'Escape') {
                e.preventDefault();
                e.stopPropagation();
                finish();
            }
        });
        pill.focus();
    }

    /**
     * Type-to-pill: when typing in the page completes a {tag} in a plain
     * text node, snap it into a pill and put the caret right after it.
     */
    _maybePillifyTyped() {
        try {
            const sel = window.getSelection();
            if (!sel || !sel.rangeCount || !sel.isCollapsed) {
                return;
            }
            const node = sel.anchorNode;
            if (!node || node.nodeType !== 3) {
                return;
            }
            const parent = node.parentElement;
            if (!parent || parent.tagName === 'STYLE' || parent.closest('[data-dg-tag]')) {
                return;
            }
            const host = this.template.querySelector('.dg-visual-host');
            const pv = host && host.querySelector('.dg-pv');
            if (!pv || !pv.contains(node) || !/\{[^{}]+\}/.test(node.nodeValue)) {
                return;
            }
            const doc = node.ownerDocument || document;
            const frag = doc.createDocumentFragment();
            let lastPill = null;
            for (const part of node.nodeValue.split(/(\{[^{}]+\})/g)) {
                if (/^\{[^{}]+\}$/.test(part)) {
                    const pillEl = doc.createElement('span');
                    pillEl.setAttribute('data-dg-tag', 'true');
                    pillEl.setAttribute('contenteditable', 'false');
                    pillEl.textContent = part;
                    pillEl.style.cssText = this._pillStyleFor(part);
                    frag.appendChild(pillEl);
                    lastPill = pillEl;
                } else if (part) {
                    frag.appendChild(doc.createTextNode(part));
                }
            }
            node.parentNode.replaceChild(frag, node);
            if (lastPill) {
                const r = doc.createRange();
                r.setStartAfter(lastPill);
                r.collapse(true);
                sel.removeAllRanges();
                sel.addRange(r);
            }
        } catch (e) {
            /* best effort */
        }
    }

    /** Pills back to plain merge-tag text (exit path). */
    /** WYSIWYG assets: {%asset:key} pills become the real image on canvas.
     *  The true tag lives in data-dg-tag; save round-trips through it. */
    _assetImgFor(tag, doc) {
        const m = /^\{%asset:([a-z0-9-]+)(?::([^}]+))?\}$/i.exec(tag);
        if (!m || !this._assetUrlByKey) {
            return null;
        }
        const url = this._assetUrlByKey[m[1].toLowerCase()];
        if (!url) {
            return null;
        }
        const img = doc.createElement('img');
        img.setAttribute('data-dg-tag', tag);
        img.setAttribute('contenteditable', 'false');
        img.src = url;
        img.style.cssText = 'vertical-align:middle;outline:1px dashed #b8e6c9;outline-offset:2px;cursor:nwse-resize;';
        const size = m[2];
        if (size) {
            const wh = /^(m?)(\d+)(px|%)?x?(m?)(\d*)(px|%)?$/i.exec(size.replace(/\s/g, ''));
            if (wh && wh[2]) {
                img.style.width = wh[2] + (wh[3] === '%' ? '%' : 'px');
                if (wh[5]) {
                    img.style.height = wh[5] + (wh[6] === '%' ? '%' : 'px');
                }
            }
        } else {
            img.style.maxWidth = '220px';
        }
        img.title = tag + ' — drag the corner to resize';
        return img;
    }

    _imagifyAssetPills() {
        try {
            const pv = this._getVisualPv();
            if (!pv) {
                return;
            }
            const doc = pv.ownerDocument || document;
            for (const pill of Array.from(pv.querySelectorAll('span[data-dg-tag]'))) {
                const tag = (pill.textContent || '').trim();
                const img = this._assetImgFor(tag, doc);
                if (img) {
                    pill.replaceWith(img);
                }
            }
        } catch (e) {
            /* best effort */
        }
    }

    _unpillifyTags(root) {
        for (const pill of root.querySelectorAll('[data-dg-tag]')) {
            const attr = pill.getAttribute('data-dg-tag');
            const tag = pill.tagName === 'IMG' && attr && attr.startsWith('{') ? attr : pill.textContent;
            pill.replaceWith((root.ownerDocument || document).createTextNode(tag));
        }
    }

    /** Leave visual mode — lossless when nothing changed. */
    /**
     * The full document as it stands RIGHT NOW — visual-mode edits serialized
     * non-destructively (same clone/unpillify/body-swap as exit, without
     * leaving visual mode), source mode read straight from the textarea.
     */
    _currentDraftHtml() {
        if (this.showHtmlBodyVisual) {
            const host = this.template.querySelector('.dg-visual-host');
            const pv = host && host.querySelector('.dg-pv');
            if (pv && this._visualOriginalCode != null) {
                const clone = pv.cloneNode(true);
                for (const styleEl of clone.querySelectorAll('style')) {
                    styleEl.remove();
                }
                for (const markerEl of clone.querySelectorAll('.dg-drop-marker')) {
                    markerEl.remove();
                }
                this._unpillifyTags(clone);
                // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                const edited = clone.innerHTML.trim();
                const bodyRe = /(<body\b[^>]*>)[\s\S]*?(<\/body\s*>)/i;
                return bodyRe.test(this._visualOriginalCode)
                    ? this._visualOriginalCode.replace(bodyRe, (m, open, close) => open + '\n' + edited + '\n' + close)
                    : edited;
            }
        }
        const ta = this.template.querySelector('.dg-html-body-editor');
        return (ta && ta.value) || this._lastUploadedHtmlText || '';
    }

    // --- Live PDF preview (real Blob.toPdf output in a blob: iframe) ---
    async handlePdfPreview() {
        if (!this.editTemplateTestRecordId) {
            this.showToast(
                'Pick a sample record',
                'PDF preview merges real data — choose a Sample Record in the toolbar first.',
                'warning'
            );
            return;
        }
        const draftHtml = (this._currentDraftHtml() || '').trim();
        if (!draftHtml) {
            this.showToast('Nothing to preview', 'The editor is empty.', 'warning');
            return;
        }
        this.isPdfPreviewLoading = true;
        try {
            const res = await previewDraftPdf({
                templateId: this.editTemplateId,
                recordId: this.editTemplateTestRecordId,
                draftHtml
            });
            if (!res || !res.contentDocumentId) {
                throw new Error('Preview returned no PDF.');
            }
            // LWS forbids blob: iframes, and shepherd URLs force a download —
            // Salesforce's native file-preview overlay is the clean viewer.
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: res.contentDocumentId }
            });
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('PDF preview failed', msg, 'error');
        } finally {
            this.isPdfPreviewLoading = false;
        }
    }

    handleClosePdfPreview() {
        this.pdfPreviewUrl = null;
    }

    get pdfPreviewBtnLabel() {
        return this.isPdfPreviewLoading ? 'Rendering…' : 'PDF Preview';
    }

    _exitVisualMode() {
        const host = this.template.querySelector('.dg-visual-host');
        const pv = host && host.querySelector('.dg-pv');
        const ta = this.template.querySelector('.dg-html-body-editor');
        if (pv && ta && this._visualOriginalCode != null) {
            // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
            const current = pv.innerHTML;
            if (this._visualEnteredDom !== null && current !== this._visualEnteredDom) {
                // Extract the edited content: everything except the scoped
                // <style> the preview pipeline injected, with tag pills
                // unwrapped back to plain merge-tag text.
                const clone = pv.cloneNode(true);
                for (const styleEl of clone.querySelectorAll('style')) {
                    styleEl.remove();
                }
                for (const markerEl of clone.querySelectorAll('.dg-drop-marker')) {
                    markerEl.remove();
                }
                this._unpillifyTags(clone);
                // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
                const edited = clone.innerHTML.trim();
                // Swap ONLY the body content back into the original document —
                // head/styles/@page are untouched by design.
                const bodyRe = /(<body\b[^>]*>)[\s\S]*?(<\/body\s*>)/i;
                let newCode;
                if (bodyRe.test(this._visualOriginalCode)) {
                    newCode = this._visualOriginalCode.replace(
                        bodyRe,
                        (m, open, close) => open + '\n' + edited + '\n' + close
                    );
                } else {
                    // Body-fragment template (no <body> wrapper): the content IS the doc.
                    newCode = edited;
                }
                ta.value = prettyPrintHtml(newCode);
                this.htmlEditorDirty = true;
            } else {
                // Untouched — hand back the original text exactly.
                ta.value = this._visualOriginalCode;
            }
        }
        this.showHtmlBodyVisual = false;
        this._visualOriginalCode = null;
        this._visualEnteredDom = null;
        this.pillMenu = null;
        this._activePill = null;
        // Landing back in Code view — make the side-by-side preview current.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._refreshCodePreview(), 120);
    }

    get docxHtmlEditorClass() {
        return this.showDocxHtmlPreview
            ? 'dg-html-body-editor dg-docx-html-editor slds-hide'
            : 'dg-html-body-editor dg-docx-html-editor';
    }

    handleFormatHtml(event) {
        const isDocx = event.currentTarget.dataset.target === 'docx';
        const ta = this.template.querySelector(isDocx ? '.dg-docx-html-editor' : '.dg-html-body-editor');
        if (!ta || !ta.value || !ta.value.trim()) {
            this.showToast('Nothing to format', 'The editor is empty.', 'warning');
            return;
        }
        ta.value = prettyPrintHtml(ta.value);
        if (!isDocx) {
            // Formatting changes the text that Apply would stage — surface it.
            this.htmlEditorDirty = true;
            this._refreshCodePreview();
        }
    }

    // Preview exists only on the DOCX converted-HTML viewer — the HTML body
    // editor's Visual mode IS the preview (same render, plus editing).
    handleToggleHtmlPreview() {
        this.showDocxHtmlPreview = !this.showDocxHtmlPreview;
        if (this.showDocxHtmlPreview) {
            this._renderHtmlPreview('.dg-docx-preview', '.dg-docx-html-editor');
        }
    }

    /**
     * Render the textarea's HTML into the inline preview div. LWS blocks
     * iframe srcdoc/document.write, so the markup goes in via innerHTML with
     * its CSS scoped to the preview container (see scopeHtmlForInlinePreview).
     * Merge tags show literally — Download Sample remains the real-data path.
     */
    _renderHtmlPreview(hostSelector, taSelector) {
        const ta = this.template.querySelector(taSelector);
        const scoped = scopeHtmlForInlinePreview((ta && ta.value) || '');
        // The host div mounts on the NEXT render cycle (it's behind an
        // if:true the caller just flipped) — renderedCallback completes the
        // write once the node exists.
        this._pendingPreviewWrite = { selector: hostSelector, html: scoped };
        const host = this.template.querySelector(hostSelector);
        if (host) {
            // Already mounted (e.g. re-render of an open preview) — write now.
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            host.innerHTML = scoped;
            this._pendingPreviewWrite = null;
        }
    }

    async toggleHtmlBodyEditor() {
        if (this.showHtmlBodyEditor) {
            this.showHtmlBodyEditor = false;
            this.showHtmlBodyVisual = false;
            this._visualOriginalCode = null;
            this._visualEnteredDom = null;
            return;
        }
        this.showHtmlBodyEditor = true;
        await this._loadBodyIntoEditor();
        // The page, not the code, is the front door: when a body exists,
        // open straight into visual editing. Code stays one click away.
        const body = this._lastUploadedHtmlText;
        if (body && body.trim()) {
            this._enterVisualMode(body);
        }
    }

    /** Reload = show what's actually staged (or saved), discarding unapplied edits. */
    async handleReloadHtmlBodyEditor() {
        // Reload means "discard my edits" — visual edits included.
        this.showHtmlBodyVisual = false;
        await this._loadBodyIntoEditor();
    }

    /** Fill the editor with the staged body, falling back to the stored one. */
    async _loadBodyIntoEditor() {
        if (this._lastUploadedHtmlText != null) {
            this._syncHtmlBodyEditorDom(this._lastUploadedHtmlText);
            this.htmlEditorDirty = false;
            return;
        }
        // No body touched this session — pull the latest stored body.
        this.isLoadingHtmlBody = true;
        try {
            const body = await getHtmlTemplateBody({ templateId: this.editTemplateId });
            this._lastUploadedHtmlText = body || '';
            this._syncHtmlBodyEditorDom(this._lastUploadedHtmlText);
            this.htmlEditorDirty = false;
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Could not load HTML body', msg, 'error');
            this._syncHtmlBodyEditorDom('');
        } finally {
            this.isLoadingHtmlBody = false;
        }
    }

    /** Native textarea doesn't track LWC state — set the DOM after render. */
    _syncHtmlBodyEditorDom(text) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const ta = this.template.querySelector('.dg-html-body-editor');
            if (ta) {
                ta.value = text || '';
            }
            this._refreshCodePreview();
        }, 120);
    }

    // --- DOCX→HTML transparency viewer (Word templates, PDF output) ---
    get showDocxConvertedHtmlSection() {
        return this.editTemplateType === 'Word' && this.editTemplateOutputFormat === 'PDF';
    }

    get docxHtmlViewerToggleLabel() {
        return this.showDocxHtmlViewer ? 'Hide Converted HTML' : 'View Converted HTML';
    }

    get docxViewerStatusText() {
        const info = this.docxSnapshotInfo;
        if (!info) {
            return 'Loading conversion snapshot…';
        }
        if (info.status === 'NoActiveVersion') {
            return 'No active version yet — upload a Word file and "Save as New Version" first.';
        }
        if (!info.html) {
            const st = info.status || 'Pending';
            return (
                'Conversion snapshot not baked yet (status: ' + st + '). Re-save the version, then reopen this viewer.'
            );
        }
        return (
            'Converted HTML from ' +
            (info.versionName || 'the active version') +
            ' — this is exactly what the PDF engine renders from your Word file.'
        );
    }

    async toggleDocxHtmlViewer() {
        if (this.showDocxHtmlViewer) {
            this.showDocxHtmlViewer = false;
            return;
        }
        this.showDocxHtmlViewer = true;
        this.isLoadingDocxHtml = true;
        this.docxSnapshotInfo = null;
        try {
            const info = await getConvertedHtmlSnapshot({ templateId: this.editTemplateId });
            this.docxSnapshotInfo = info || { html: null, status: 'Unknown' };
            this._syncDocxHtmlViewerDom((info && info.html) || '');
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Could not load converted HTML', msg, 'error');
            this.docxSnapshotInfo = { html: null, status: 'Error' };
            this._syncDocxHtmlViewerDom('');
        } finally {
            this.isLoadingDocxHtml = false;
        }
    }

    _syncDocxHtmlViewerDom(text) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const ta = this.template.querySelector('.dg-docx-html-editor');
            if (ta) {
                ta.value = text || '';
            }
        }, 120);
    }

    /**
     * One-way ramp from Word to HTML: the (possibly fine-tuned) converted
     * HTML becomes the template's real body and Type flips to HTML, so edits
     * stick instead of being clobbered by the next DOCX re-decomposition.
     */
    async handleSwitchToHtmlTemplate() {
        const ta = this.template.querySelector('.dg-docx-html-editor');
        const text = ta ? ta.value : '';
        if (!text || !text.trim()) {
            this.showToast('Nothing to convert', 'The converted-HTML view is empty.', 'warning');
            return;
        }
        const proceed = await LightningConfirm.open({
            message:
                "This makes the HTML shown (including your edits) the template's real body and changes the template Type from Word to HTML. " +
                'The Word file stays in Version History, but future edits happen in the HTML editor. Continue?',
            label: 'Switch to HTML Template',
            theme: 'warning'
        });
        if (!proceed) {
            return;
        }
        this.isSwitchingToHtml = true;
        try {
            const fields = { Id: this.editTemplateId };
            fields[TYPE_FIELD.fieldApiName] = 'HTML';
            fields[OUTPUT_FORMAT_FIELD.fieldApiName] = 'PDF';
            await updateRecord({ fields });
            this.editTemplateType = 'HTML';
            this.editTemplateOutputFormat = 'PDF';
            this.showDocxHtmlViewer = false;
            // Stage the tuned HTML as the body through the standard pipeline.
            // Keep the Word file's identity: Sales_Quote.docx → Sales_Quote.html.
            const htmlName =
                ((this.uploadedFileName || this.editTemplateName || 'template').replace(/\.(docx?|html?|zip)$/i, '') ||
                    'template') + '.html';
            await this._processAndSaveHtmlBody(this.editTemplateId, text, htmlName, null, 'editor');
            this.showHtmlBodyEditor = true;
            this._syncHtmlBodyEditorDom(text);
            await refreshApex(this.wiredTemplatesResult);
            this.showToast(
                'Now an HTML template',
                'Your converted HTML is staged — review it in the editor and click "Save as New Version" to activate.',
                'success'
            );
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Switch failed', msg, 'error');
        } finally {
            this.isSwitchingToHtml = false;
        }
    }

    // --- Designer tab (full-screen editing surface) ---
    get designerHasTemplate() {
        return !!this.editTemplateId && this.editTemplateType === 'HTML';
    }

    get designerTitle() {
        return this.editTemplateName || 'Template Designer';
    }

    /** Switch templates without leaving the designer. */
    get designerTemplateOptions() {
        return (this.templates || []).filter((t) => t[F.Type] === 'HTML').map((t) => ({ label: t.Name, value: t.Id }));
    }

    // --- Right-click context menu handlers ---
    /** Type-to-search inside the right-click menu — the full command catalog. */
    handleCtxSearch(event) {
        const q = (event.target.value || '').toLowerCase().trim();
        if (!q) {
            this.ctxMenu = { ...this.ctxMenu, query: '', items: null };
            return;
        }
        const terms = q.split(/\s+/).filter(Boolean);
        const items = this._slashCatalog()
            .filter((o) => {
                const hay = (o.label + ' ' + o.group + ' ' + (o.keywords || '')).toLowerCase();
                return terms.every((t) => hay.includes(t));
            })
            .slice(0, 9);
        this.ctxMenu = { ...this.ctxMenu, query: q, items };
    }

    handleCtxSearchKeydown(event) {
        event.stopPropagation();
        if (event.key === 'Escape') {
            this.ctxMenu = null;
        } else if (event.key === 'Enter' && this.ctxMenu && this.ctxMenu.items && this.ctxMenu.items.length) {
            this._runCtxItem(this.ctxMenu.items[0]);
        }
    }

    handleCtxSearchedItemClick(event) {
        const key = event.currentTarget.dataset.key;
        const item = this.ctxMenu && this.ctxMenu.items ? this.ctxMenu.items.find((o) => o.key === key) : null;
        this._runCtxItem(item);
    }

    _runCtxItem(item) {
        this.ctxMenu = null;
        if (!item) {
            return;
        }
        // Restore the caret captured at right-click (the search box stole focus).
        try {
            const pv = this._getVisualPv();
            if (pv && this._ctxRange) {
                pv.focus();
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(this._ctxRange);
            }
        } catch (e) {
            /* best effort — insert falls back to append */
        }
        if (item.cmd) {
            if (item.cmd === 'ul' || item.cmd === 'ol') {
                this._toggleListAtCaret(item.cmd === 'ol');
            } else if (item.cmd === 'table') {
                this.handleInsertTable();
            } else {
                try {
                    document.execCommand('styleWithCSS', false, false);
                } catch (e) {
                    /* best effort */
                }
                document.execCommand(item.cmd, false, null);
            }
            this.htmlEditorDirty = true;
            return;
        }
        this._insertIntoVisualPage(item.snippet);
    }

    handleCtxClose() {
        this.ctxMenu = null;
    }
    handleCtxFormat(event) {
        this.ctxMenu = null;
        this.handleFormatAction(event);
    }
    handleCtxTable(event) {
        this.ctxMenu = null;
        this.handleTableAction(event);
    }
    handleCtxList(event) {
        const ordered = event.currentTarget.dataset.kind === 'ol';
        this.ctxMenu = null;
        this._toggleListAtCaret(ordered);
    }
    handleCtxInsert() {
        const pt = this._ctxPoint;
        this.ctxMenu = null;
        if (pt) {
            this._openSlashMenuAtPoint(pt.x, pt.y);
        }
    }
    handleCtxDeleteBlock() {
        this.ctxMenu = null;
        const blk = this._selectedBlockElement();
        if (blk) {
            blk.remove();
            this.htmlEditorDirty = true;
        }
    }

    /** Open the insert menu at an arbitrary point (right-click path — no typed
     *  trigger, so executing an item skips trigger-text removal). */
    _openSlashMenuAtPoint(x, y) {
        this._slashQuery = '';
        this._slashCtx = null;
        this._slashSel = 0;
        const col = this.template.querySelector('.dg-designer-canvas-col');
        const colRect = col ? col.getBoundingClientRect() : { left: 0, top: 0 };
        this._renderSlashMenu({ left: x, bottom: y, width: 1, height: 1 }, colRect);
    }

    /** Versions panel: load any version's body into the editor (staged only
     *  when the author saves — loading changes nothing by itself). */
    async handleLoadVersionIntoDesigner(event) {
        const cvId = event.currentTarget.dataset.cvid;
        const verName = event.currentTarget.dataset.ver;
        if (!cvId) {
            return;
        }
        try {
            const b64 = await getContentVersionBase64({ contentVersionId: cvId });
            const bin = atob(b64);
            const bytes = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; i++) {
                bytes[i] = bin.charCodeAt(i);
            }
            const text = new TextDecoder('utf-8').decode(bytes);
            if (!/</.test(text.slice(0, 500))) {
                this.showToast(
                    'Not an HTML body',
                    verName +
                        ' points at a non-HTML file (e.g. the original .docx) — download it from Edit Template instead.',
                    'warning'
                );
                return;
            }
            this.activePanel = null;
            if (this.showHtmlBodyVisual) {
                this._exitVisualMode();
            }
            this._syncHtmlBodyEditorDom(text);
            this._lastUploadedHtmlText = text;
            this.htmlEditorDirty = true;
            this._enterVisualMode(text);
            this.showToast(
                'Loaded ' + verName,
                'This version is now in the editor. Nothing changed yet — Save as New Version creates a NEW version from it.',
                'success'
            );
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Could not load version', msg, 'error');
        }
    }

    // --- Query panel: check a field, it's in the query. ---
    /** V1 flat-string configs only — JSON (V3/V4) configs stay in the modal. */
    get designerQueryEditable() {
        const q = (this.editTemplateQuery || '').trim();
        return !q.startsWith('{') && this.editTemplateObject && this.editTemplateObject !== 'FlowJsonData';
    }

    async _loadDesignerQueryMeta() {
        if (!this.designerQueryEditable || this._queryMetaFor === this.editTemplateObject) {
            return;
        }
        try {
            const [fields, rels] = await Promise.all([
                getObjectFields({ objectName: this.editTemplateObject }),
                getChildRelationships({ objectName: this.editTemplateObject })
            ]);
            const childFieldsByRel = {};
            const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
            await Promise.all(
                (shape.children || []).map(async (c) => {
                    const rel = (rels || []).find((r) => r.value === c.relationshipName);
                    if (rel) {
                        try {
                            childFieldsByRel[c.relationshipName] = await getObjectFields({
                                objectName: rel.childObjectApiName
                            });
                        } catch (e) {
                            /* skip */
                        }
                    }
                })
            );
            this._queryMetaFor = this.editTemplateObject;
            this.designerQueryMeta = { fields: fields || [], rels: rels || [], childFieldsByRel };
        } catch (e) {
            this.designerQueryMeta = null;
        }
    }

    /** Shared: checkbox sections from a describe meta + a V1 query string. */
    _buildQuerySections(query, objectName, meta, search) {
        if (!meta) {
            return [];
        }
        const q = (search || '').toLowerCase().trim();
        const shape = extractQueryShape(query, objectName);
        const baseSet = new Set((shape.baseFields || []).map((f) => f.toLowerCase()));
        const SKIP = /^(Id|IsDeleted|SystemModstamp|CurrencyIsoCode|Jigsaw.*|CleanStatus|PhotoUrl)$/;
        const match = (label, api) => !q || (label + ' ' + api).toLowerCase().includes(q);
        const sections = [];
        sections.push({
            key: 'base',
            label: objectName + ' fields',
            rows: meta.fields
                .filter((f) => !SKIP.test(f.value) && match(f.label, f.value))
                .map((f) => ({
                    key: 'b_' + f.value,
                    label: f.label,
                    api: f.value,
                    checked: baseSet.has(f.value.toLowerCase()),
                    kind: 'base',
                    rel: ''
                }))
        });
        for (const c of shape.children || []) {
            const cf = meta.childFieldsByRel[c.relationshipName] || [];
            const inSet = new Set((c.fields || []).map((f) => f.toLowerCase()));
            sections.push({
                key: 'rel_' + c.relationshipName,
                label: c.relationshipName + ' (child list)',
                rows: cf
                    .filter((f) => !SKIP.test(f.value) && match(f.label, f.value))
                    .map((f) => ({
                        key: 'c_' + c.relationshipName + '_' + f.value,
                        label: f.label,
                        api: f.value,
                        checked: inSet.has(f.value.toLowerCase()),
                        kind: 'child',
                        rel: c.relationshipName
                    }))
            });
        }
        const inQuery = new Set((shape.children || []).map((c) => c.relationshipName));
        const NOISE =
            /Histories|Feeds|Shares|Teams|ContentDocumentLinks|ProcessInstances|ActivityHistories|Emails|Events|Tasks|Notes|Attachments|DuplicateRecord|RecordAction|TopicAssign|Vote/i;
        const addable = meta.rels.filter(
            (r) => !inQuery.has(r.value) && !NOISE.test(r.value) && match(r.label, r.value)
        );
        if (addable.length) {
            sections.push({
                key: 'addrel',
                label: 'Add a child list',
                rows: addable.map((r) => ({
                    key: 'r_' + r.value,
                    label: r.label + ' (' + r.value + ')',
                    api: r.value,
                    checked: false,
                    kind: 'rel',
                    rel: r.value
                }))
            });
        }
        return sections.filter((sec) => sec.rows.length);
    }

    /** Shared: apply a checkbox toggle to a V1 query string. Returns
     *  { query, childFields } — childFields set when a new rel was seeded. */
    async _applyQueryToggle(query, objectName, meta, dataset, on) {
        const { kind, api, rel } = dataset;
        const shape = extractQueryShape(query, objectName);
        const base = [...(shape.baseFields || [])];
        const parents = [...(shape.parentFields || [])];
        let children = (shape.children || []).map((c) => ({ rel: c.relationshipName, fields: [...c.fields] }));
        let childFields = null;
        if (kind === 'base') {
            const idx = base.findIndex((f) => f.toLowerCase() === api.toLowerCase());
            if (on && idx === -1) {
                base.push(api);
            } else if (!on && idx > -1) {
                base.splice(idx, 1);
            }
        } else if (kind === 'child') {
            const c = children.find((x) => x.rel === rel);
            if (c) {
                const idx = c.fields.findIndex((f) => f.toLowerCase() === api.toLowerCase());
                if (on && idx === -1) {
                    c.fields.push(api);
                } else if (!on && idx > -1) {
                    c.fields.splice(idx, 1);
                }
                if (!c.fields.length) {
                    children = children.filter((x) => x !== c);
                }
            }
        } else if (kind === 'rel' && on) {
            let seed = ['Name'];
            try {
                const relMeta = (meta.rels || []).find((r) => r.value === rel);
                if (relMeta) {
                    childFields = (await getObjectFields({ objectName: relMeta.childObjectApiName })) || [];
                    const names = childFields.map((f) => f.value);
                    seed = ['Name', 'FirstName', 'LastName', 'Email', 'Amount', 'StageName', 'Quantity', 'UnitPrice']
                        .filter((f) => names.includes(f))
                        .slice(0, 4);
                    if (!seed.length) {
                        seed = [names.find((n) => n === 'Name') || names[0]].filter(Boolean);
                    }
                }
            } catch (e) {
                /* keep Name seed */
            }
            children.push({ rel, fields: seed });
        }
        if (!base.length) {
            base.push('Name');
        }
        const parts = [[...base, ...parents].join(', ')];
        for (const c of children) {
            parts.push('(SELECT ' + c.fields.join(', ') + ' FROM ' + c.rel + ')');
        }
        return { query: parts.join(', '), childFields, rel };
    }

    /** Sections of checkbox rows driven by describe + the CURRENT query. */
    get designerQuerySections() {
        if (!this.designerQueryEditable) {
            return [];
        }
        return this._buildQuerySections(
            this.editTemplateQuery,
            this.editTemplateObject,
            this.designerQueryMeta,
            this.panelSearch
        );
    }

    /** One click = query updated. Rebuilds the V1 string from the shape. */
    async handleQueryFieldToggle(event) {
        const res = await this._applyQueryToggle(
            this.editTemplateQuery,
            this.editTemplateObject,
            this.designerQueryMeta,
            event.currentTarget.dataset,
            event.currentTarget.checked
        );
        if (res.childFields) {
            this.designerQueryMeta = {
                ...this.designerQueryMeta,
                childFieldsByRel: { ...this.designerQueryMeta.childFieldsByRel, [res.rel]: res.childFields }
            };
        }
        this.editTemplateQuery = res.query;
    }

    get designerQueryFieldCount() {
        const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
        let n = (shape.baseFields || []).length + (shape.parentFields || []).length;
        for (const c of shape.children || []) {
            n += (c.fields || []).length;
        }
        return n;
    }

    // --- Header / Footer panel (repeats on every PDF page) ---
    handleDesignerHeaderChange(event) {
        this.editTemplateHeaderHtml = event.target.value;
        this.htmlEditorDirty = true;
    }
    handleDesignerFooterChange(event) {
        this.editTemplateFooterHtml = event.target.value;
        this.htmlEditorDirty = true;
    }
    handleHfFocus(event) {
        this._lastHfFocus = event.target.dataset.hf;
    }
    handleHfTokenInsert(event) {
        // Token keys, not literal tags — LWC decodes entities in attributes
        // BEFORE expression parsing, so brace literals can't live in markup.
        const TOKS = {
            pagexy: 'Page {PageNumber} of {TotalPages}',
            pagenum: '{PageNumber}',
            pagetotal: '{TotalPages}',
            today: '{Today:MMMM d, yyyy}',
            name: '{Name}'
        };
        const tok = TOKS[event.currentTarget.dataset.tok];
        const which = this._lastHfFocus === 'header' ? 'header' : 'footer';
        const ta = this.template.querySelector(which === 'header' ? '.dg-hf-header' : '.dg-hf-footer');
        if (!ta || !tok) {
            return;
        }
        const st = typeof ta.selectionStart === 'number' ? ta.selectionStart : ta.value.length;
        const en = typeof ta.selectionEnd === 'number' ? ta.selectionEnd : st;
        ta.value = ta.value.slice(0, st) + tok + ta.value.slice(en);
        if (which === 'header') {
            this.editTemplateHeaderHtml = ta.value;
        } else {
            this.editTemplateFooterHtml = ta.value;
        }
        this.htmlEditorDirty = true;
    }

    async handleDesignerTemplateSwitch(event) {
        const id = event.detail.value;
        if (!id || id === this.editTemplateId) {
            return;
        }
        if (this.htmlEditorDirty) {
            const ok = await LightningConfirm.open({
                message: 'Switch templates? Unapplied edits in this editor will be discarded — staged bodies are kept.',
                label: 'Switch template',
                theme: 'warning'
            });
            if (!ok) {
                // Re-render snaps the picker back to the current template.
                this.editTemplateId = this.editTemplateId; // eslint-disable-line no-self-assign
                return;
            }
        }
        const row = (this.templates || []).find((t) => t.Id === id);
        if (!row) {
            return;
        }
        if (this.showHtmlBodyVisual) {
            this._exitVisualMode();
        }
        this.handleClosePdfPreview();
        this.activePanel = null;
        await this.openDesignerForRow(row);
    }

    /** Row action / modal button → full-screen designer for HTML templates. */
    async openDesignerForRow(row) {
        this.openEditModal(row, 'document');
        this.isEditModalOpen = false;
        await this._openDesignerSurface();
    }

    async handleOpenDesignerFromModal() {
        this.isEditModalOpen = false;
        await this._openDesignerSurface();
    }

    async _openDesignerSurface() {
        this.activeMainTab = 'design';
        this.showHtmlBodyEditor = true;
        this.showBlockPanel = true;
        this.showTagPanel = true;
        this.showImagePanel = true;
        await this._loadBodyIntoEditor();
        // Asset library feeds the Images panel + slash menu + tag pills.
        this._loadWizardAssets();
        let body = this._lastUploadedHtmlText;
        if (!body || !body.trim()) {
            // Blank template: seed a clean sheet so click-and-type just works.
            body =
                '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8" />\n<style>\n@page { size: Letter portrait; margin: 0.75in; }\nbody { font-family: Helvetica, Arial, sans-serif; font-size: 10.5pt; color: #1a1a1a; }\n</style>\n</head>\n<body>\n<p>Start typing your document here — or drag in blocks, tags, and images from the rail.</p>\n</body>\n</html>\n';
            this._syncHtmlBodyEditorDom(body);
        }
        this._enterVisualMode(body);
    }

    /** Designer → this template's full edit modal, no list-hunting. */
    handleEditTemplateFromDesigner() {
        if (this.showHtmlBodyVisual) {
            this._exitVisualMode();
        }
        this.handleClosePdfPreview();
        this.activePanel = null;
        this._closeSlashMenu();
        this.activeMainTab = 'list';
        this.activeEditTab = 'document';
        this.isEditModalOpen = true;
    }

    handleCloseDesigner() {
        if (this.showHtmlBodyVisual) {
            this._exitVisualMode();
        }
        this.handleClosePdfPreview();
        this.activePanel = null;
        if (this.htmlEditorDirty || this.stagedBodySource) {
            this.showToast(
                'Heads up',
                this.stagedBodySource
                    ? 'Your staged body is kept — reopen the designer or the template editor to Save as New Version.'
                    : 'Unapplied editor changes were left un-staged.',
                'info'
            );
        }
        this.activeMainTab = 'list';
    }

    // --- Blocks palette (drag-in layout pieces) ---
    get blockPaletteSections() {
        const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
        const sections = buildBlockPalette(shape);
        return [
            {
                key: 'sections',
                label: 'Sections',
                hint: 'Flexipage-style equal columns — up to 12, like a page layout.',
                items: SECTION_COLUMN_PRESETS.map((n) => ({
                    key: 'seccols' + n,
                    label: n + ' columns',
                    title: n + ' equal-width columns section',
                    snippet: columnsSectionSnippet(n)
                }))
            },
            ...sections
        ];
    }

    // --- Floating searchable panels (replace the fixed right rail) ---
    get showFloatPanel() {
        return !!this.activePanel;
    }
    get isPanelInsert() {
        return this.activePanel === 'insert';
    }
    get isPanelTags() {
        return this.activePanel === 'tags';
    }
    get isPanelImages() {
        return this.activePanel === 'images';
    }
    get isPanelWatermark() {
        return this.activePanel === 'watermark';
    }
    get isPanelHf() {
        return this.activePanel === 'hf';
    }
    get isPanelVersions() {
        return this.activePanel === 'versions';
    }
    get isPanelQuery() {
        return this.activePanel === 'query';
    }
    get showPanelSearch() {
        return !this.isPanelWatermark && !this.isPanelHf && !this.isPanelVersions;
    }
    get floatPanelTitle() {
        return {
            insert: 'Insert blocks',
            tags: 'Merge tags',
            images: 'Image assets',
            watermark: 'Watermark',
            hf: 'Header & Footer',
            versions: 'Version history',
            query: 'Query fields'
        }[this.activePanel];
    }
    get panelSearchPlaceholder() {
        return this.activePanel === 'tags' ? 'Search fields, loops, charts…' : 'Search…';
    }

    handlePanelToggle(event) {
        const p = event.currentTarget.dataset.panel;
        this.activePanel = this.activePanel === p ? null : p;
        this.panelSearch = '';
        this._focusPanelSearch = !!this.activePanel;
        if (this.activePanel === 'images') {
            this._loadWizardAssets();
        }
        if (this.activePanel === 'versions' && this.editTemplateId) {
            this.loadVersions(this.editTemplateId);
        }
        if (this.activePanel === 'query') {
            this._loadDesignerQueryMeta();
        }
    }
    handlePanelClose() {
        this.activePanel = null;
    }
    handlePanelSearch(event) {
        this.panelSearch = event.target.value || '';
    }

    _filterSections(sections) {
        const q = (this.panelSearch || '').toLowerCase().trim();
        if (!q) {
            return sections;
        }
        return sections
            .map((s) => ({
                ...s,
                items: s.items.filter((it) =>
                    (it.label + ' ' + (it.title || '') + ' ' + s.label).toLowerCase().includes(q)
                )
            }))
            .filter((s) => s.items.length);
    }
    get filteredBlockSections() {
        return this._filterSections(this.blockPaletteSections);
    }
    get filteredTagSections() {
        return this._filterSections(this.tagPaletteSections);
    }
    get filteredTemplateImages() {
        const q = (this.panelSearch || '').toLowerCase().trim();
        const imgs = this.templateImages || [];
        return q ? imgs.filter((i) => (i.fileName || '').toLowerCase().includes(q)) : imgs;
    }
    get hasFilteredTemplateImages() {
        return this.filteredTemplateImages.length > 0;
    }
    /** Asset library entries for the designer panel — searchable by name/key. */
    get filteredAssets() {
        const q = (this.panelSearch || '').toLowerCase().trim();
        const assets = this.wizardAssets || [];
        return q
            ? assets.filter((a) => (a.name + ' ' + a.assetKey + ' ' + a.mergeTag).toLowerCase().includes(q))
            : assets;
    }
    get hasFilteredAssets() {
        return this.filteredAssets.length > 0;
    }

    // --- Notion-style slash-command menu ---
    /** EVERY command, flattened and searchable by plain-language intent —
     *  "close tag", "start loop", "money", "bold" all find their thing. */
    _slashCatalog() {
        const out = [];
        let i = 0;
        const add = (label, group, item) => out.push({ key: 's' + i++, label, group, ...item });
        // Plain-language loop + conditional entries, built from the real query.
        const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
        for (const c of shape.children || []) {
            add(`Start loop — repeat for each ${c.relationshipName}`, 'Loops', {
                snippet: '{#' + c.relationshipName + '}',
                keywords: 'start open begin loop repeat each every child rows for'
            });
            add(`Close loop — end of ${c.relationshipName}`, 'Loops', {
                snippet: '{/' + c.relationshipName + '}',
                keywords: 'close end stop finish loop tag slash'
            });
        }
        add('Show only when… (start of if)', 'Conditionals', {
            snippet: '{#FieldName}',
            keywords: 'if condition conditional when show only start open hide'
        });
        add('Otherwise… (else)', 'Conditionals', {
            snippet: '{:else}',
            keywords: 'else otherwise fallback condition'
        });
        add('End of condition (close the if)', 'Conditionals', {
            snippet: '{/FieldName}',
            keywords: 'close end if condition tag finish stop'
        });
        // Editor commands — the format bar, searchable from the keyboard.
        const CMDS = [
            ['Bold text', 'bold', 'bold strong heavy thick'],
            ['Italic text', 'italic', 'italic slant emphasis'],
            ['Underline text', 'underline', 'underline'],
            ['Strikethrough text', 'strikeThrough', 'strike strikethrough cross out'],
            ['Bulleted list', 'ul', 'bullet bulleted list dots points unordered'],
            ['Numbered list', 'ol', 'number numbered list ordered steps 123'],
            ['Align left', 'justifyLeft', 'align left'],
            ['Align center', 'justifyCenter', 'align center middle'],
            ['Align right', 'justifyRight', 'align right'],
            ['Clear formatting', 'removeFormat', 'clear remove formatting plain reset'],
            ['Insert table (3 columns)', 'table', 'table grid columns rows insert']
        ];
        for (const [label, cmd, keywords] of CMDS) {
            add(label, 'Formatting', { cmd, keywords });
        }
        for (const sec of this.blockPaletteSections) {
            for (const it of sec.items) {
                add(it.label, sec.label, { snippet: it.snippet, keywords: it.title || '' });
            }
        }
        for (const sec of this.tagPaletteSections) {
            for (const it of sec.items) {
                add(it.label, sec.label, { snippet: it.snippet, keywords: (it.title || '') + ' merge tag field' });
            }
        }
        for (const a of this.wizardAssets || []) {
            add(a.name, 'Image assets', { snippet: a.mergeTag, keywords: 'image picture logo asset photo' });
        }
        return out;
    }

    _maybeOpenSlashMenu() {
        try {
            const sel = window.getSelection();
            if (!sel || !sel.rangeCount || !sel.isCollapsed) {
                this._closeSlashMenu();
                return;
            }
            const node = sel.anchorNode;
            if (!node || node.nodeType !== 3) {
                this._closeSlashMenu();
                return;
            }
            const host = this.template.querySelector('.dg-visual-host');
            const pv = host && host.querySelector('.dg-pv');
            if (!pv || !pv.contains(node) || (node.parentElement && node.parentElement.closest('[data-dg-tag]'))) {
                this._closeSlashMenu();
                return;
            }
            const upto = node.nodeValue.slice(0, sel.anchorOffset);
            // Trigger keys: ` or [ — "/" belongs to Lightning global search.
            const m = upto.match(/(^|[\s ])[`[]([\w -]{0,30})$/);
            if (!m) {
                this._closeSlashMenu();
                return;
            }
            const query = m[2] || '';
            if (!this.slashMenu || this._slashQuery !== query) {
                this._slashSel = 0;
            }
            this._slashQuery = query;
            this._slashCtx = { node, slashIndex: upto.length - query.length - 1 };
            const range = sel.getRangeAt(0).cloneRange();
            let rect = range.getBoundingClientRect();
            if (!rect || (!rect.width && !rect.height)) {
                rect = (node.parentElement || pv).getBoundingClientRect();
            }
            const col = this.template.querySelector('.dg-designer-canvas-col');
            const colRect = col ? col.getBoundingClientRect() : { left: 0, top: 0 };
            this._renderSlashMenu(rect, colRect);
        } catch (e) {
            // Surface failures IN the menu — console output from LWS contexts
            // is unreliable, silent closes hide real bugs.
            this.slashMenu = {
                query: '',
                hasItems: false,
                posStyle: 'left: 40px; top: 40px;',
                items: [],
                errorMsg: (e && e.message) || String(e)
            };
        }
    }

    _renderSlashMenu(rect, colRect) {
        const q = (this._slashQuery || '').toLowerCase().trim();
        const all = this._slashCatalog();
        // Every word of the query must match somewhere in label/group/keywords
        // — so "close loop", "start loop", "end if" all find their command.
        const terms = q.split(/\s+/).filter(Boolean);
        const scored = terms.length
            ? all.filter((o) => {
                  const hay = (o.label + ' ' + o.group + ' ' + (o.keywords || '')).toLowerCase();
                  return terms.every((t) => hay.includes(t));
              })
            : all;
        const items = scored.slice(0, 10);
        if (this._slashSel >= items.length) {
            this._slashSel = Math.max(0, items.length - 1);
        }
        const posStyle = rect
            ? 'left: ' + Math.max(0, rect.left - colRect.left) + 'px; top: ' + (rect.bottom - colRect.top + 6) + 'px;'
            : this.slashMenu
              ? this.slashMenu.posStyle
              : '';
        this.slashMenu = {
            query: this._slashQuery,
            hasItems: items.length > 0,
            posStyle,
            items: items.map((o, idx) => ({
                ...o,
                itemClass: idx === this._slashSel ? 'dg-slash-item dg-slash-item_active' : 'dg-slash-item'
            }))
        };
    }

    _closeSlashMenu() {
        if (this.slashMenu) {
            this.slashMenu = null;
            this._slashCtx = null;
            this._slashSel = 0;
        }
    }

    /** Keyboard driving for the open slash menu; returns true when consumed. */
    _slashMenuKeydown(e) {
        if (!this.slashMenu) {
            return false;
        }
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            const n = this.slashMenu.items.length;
            if (n) {
                this._slashSel = (this._slashSel + (e.key === 'ArrowDown' ? 1 : n - 1)) % n;
                this._renderSlashMenu(null, null);
            }
            return true;
        }
        if (e.key === 'Enter' || e.key === 'Tab') {
            e.preventDefault();
            this._executeSlashItem(this.slashMenu.items[this._slashSel]);
            return true;
        }
        if (e.key === 'Escape') {
            e.preventDefault();
            this._closeSlashMenu();
            return true;
        }
        return false;
    }

    handleSlashItemClick(event) {
        const key = event.currentTarget.dataset.key;
        const item = this.slashMenu && this.slashMenu.items.find((o) => o.key === key);
        this._executeSlashItem(item);
    }

    handleSlashMenuClose() {
        this._closeSlashMenu();
    }

    /** Remove the typed "/query" trigger text, then insert the chosen thing there. */
    _executeSlashItem(item) {
        const ctx = this._slashCtx;
        this._closeSlashMenu();
        if (!item) {
            return;
        }
        try {
            if (ctx && ctx.node && ctx.node.parentNode) {
                const sel = window.getSelection();
                const end =
                    sel && sel.rangeCount && sel.anchorNode === ctx.node ? sel.anchorOffset : ctx.node.nodeValue.length;
                const r = document.createRange();
                r.setStart(ctx.node, Math.max(0, ctx.slashIndex));
                r.setEnd(ctx.node, Math.min(end, ctx.node.nodeValue.length));
                r.deleteContents();
                const s = window.getSelection();
                s.removeAllRanges();
                s.addRange(r);
            }
        } catch (e) {
            /* insertion falls back to caret/append */
        }
        // Formatting commands act at the caret instead of inserting markup.
        if (item.cmd) {
            if (item.cmd === 'ul' || item.cmd === 'ol') {
                this._toggleListAtCaret(item.cmd === 'ol');
            } else if (item.cmd === 'table') {
                this.handleInsertTable();
            } else {
                try {
                    document.execCommand('styleWithCSS', false, false);
                } catch (e) {
                    /* best effort */
                }
                document.execCommand(item.cmd, false, null);
            }
            this.htmlEditorDirty = true;
            return;
        }
        this._insertIntoVisualPage(item.snippet);
    }

    // --- Tags palette (Insert Tags without memorizing syntax) ---
    get tagPanelToggleLabel() {
        return this.showTagPanel ? 'Hide Tags' : 'Insert Tags';
    }

    get tagPaletteSections() {
        const shape = extractQueryShape(this.editTemplateQuery, this.editTemplateObject);
        const sections = buildTagPalette(shape);
        // Signer form fields ({?key}) configured on the Signer Inputs tab.
        try {
            const cfg = (this.editFormFieldsConfig || '').trim();
            if (cfg.startsWith('{')) {
                const parsed = JSON.parse(cfg);
                if (Array.isArray(parsed.formFields) && parsed.formFields.length) {
                    sections.push({
                        key: 'formfields',
                        label: 'Signer form fields',
                        hint: 'Filled in by the signer during e-signing. Configure keys under Edit Template → Signer Inputs.',
                        items: parsed.formFields.map((ff) => ({
                            key: 'ff_' + ff.key,
                            label: ff.label || ff.key,
                            snippet: '{?' + ff.key + '}',
                            title:
                                '{?' +
                                ff.key +
                                "} — the signer's answer. Add a default with {?" +
                                ff.key +
                                '|fallback}.'
                        }))
                    });
                }
            }
        } catch (e) {
            /* malformed config — skip */
        }
        return sections;
    }

    toggleTagPanel() {
        this.showTagPanel = !this.showTagPanel;
    }

    handleInsertTagSnippet(event) {
        // A completed mouse-drag suppresses the click that follows it.
        if (this._suppressChipClick) {
            this._suppressChipClick = false;
            return;
        }
        const snippet = event.currentTarget.dataset.snippet;
        const isBlock = event.currentTarget.dataset.kind === 'block';
        if (!snippet) {
            return;
        }
        if (this.showHtmlBodyVisual) {
            this._insertIntoVisualPage(snippet);
            this.showToast(
                isBlock ? 'Block added' : 'Tag inserted',
                isBlock
                    ? 'Added at the end of the document — click into it to edit, or drag chips from the rail to drop them exactly where you point.'
                    : 'Added at the end of the document — move it where you need it.',
                'success'
            );
            return;
        }
        if (this._insertAtEditorCursor(snippet)) {
            this.showToast(
                isBlock ? 'Block added' : 'Tag inserted',
                snippet.length > 60
                    ? (isBlock ? 'Block' : 'Loop table') + ' inserted at your cursor.'
                    : snippet + ' inserted at your cursor.',
                'success'
            );
        }
    }

    /**
     * Insert markup into the editable visual page — at the caret when there
     * is one (chips keep it alive via mousedown-preventDefault), otherwise
     * appended at the end.
     */
    _insertIntoVisualPage(markup) {
        const host = this.template.querySelector('.dg-visual-host');
        const pv = host && host.querySelector('.dg-pv');
        if (!pv) {
            return;
        }
        const doc = pv.ownerDocument || document;
        const tpl = doc.createElement('template');
        // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
        tpl.innerHTML = markup;
        this._pillifyTags(tpl.content);
        // Capture BEFORE insertion — insertNode empties the fragment.
        const firstEl = tpl.content.firstElementChild;
        let inserted = false;
        try {
            const sel = window.getSelection();
            if (sel && sel.rangeCount) {
                const range = sel.getRangeAt(0);
                let node = range.startContainer;
                const el = node.nodeType === 3 ? node.parentElement : node;
                if (el && pv.contains(el) && !el.closest('[data-dg-tag]')) {
                    range.collapse(true);
                    range.insertNode(tpl.content);
                    inserted = true;
                }
            }
        } catch (e) {
            inserted = false;
        }
        if (!inserted) {
            pv.appendChild(tpl.content);
        }
        // Never make the user hunt for what they just added.
        if (firstEl && firstEl.scrollIntoView) {
            try {
                firstEl.scrollIntoView({ block: 'center', behavior: 'smooth' });
            } catch (e) {
                /* best effort */
            }
        }
        this.htmlEditorDirty = true;
    }

    /**
     * Merge cells: with a selection spanning multiple cells, merges the whole
     * rectangle (top-left keeps colspan/rowspan + everyone's content); with a
     * collapsed selection, merges the current cell with the one to its right.
     * Uniform grids assumed — pre-merged regions inside the rectangle are
     * flattened into it.
     */
    _mergeCells(cell, table) {
        const sel = window.getSelection();
        let a = cell;
        let f = cell;
        try {
            if (sel && sel.anchorNode && sel.focusNode) {
                const an = sel.anchorNode.nodeType === 3 ? sel.anchorNode.parentElement : sel.anchorNode;
                const fn = sel.focusNode.nodeType === 3 ? sel.focusNode.parentElement : sel.focusNode;
                const ac = an && an.closest ? an.closest('td, th') : null;
                const fc = fn && fn.closest ? fn.closest('td, th') : null;
                if (ac && fc && table.contains(ac) && table.contains(fc)) {
                    a = ac;
                    f = fc;
                }
            }
        } catch (e) {
            /* selection best-effort */
        }
        if (a === f) {
            const nxt = a.nextElementSibling;
            if (!nxt) {
                this.showToast(
                    'Nothing to merge',
                    'Select across the cells you want to merge (click the first, shift-click the last), or put the caret in a cell that has a neighbor to its right.',
                    'info'
                );
                return;
            }
            if ((nxt.textContent || '').trim()) {
                a.innerHTML = a.innerHTML + ' ' + nxt.innerHTML;
            }
            a.colSpan = (a.colSpan || 1) + (nxt.colSpan || 1);
            nxt.remove();
            this.htmlEditorDirty = true;
            return;
        }
        const rows = Array.from(table.rows);
        const r1 = Math.min(rows.indexOf(a.parentElement), rows.indexOf(f.parentElement));
        const r2 = Math.max(rows.indexOf(a.parentElement), rows.indexOf(f.parentElement));
        const c1 = Math.min(a.cellIndex, f.cellIndex);
        const c2 = Math.max(a.cellIndex, f.cellIndex);
        const keep = rows[r1].children[c1];
        let extra = '';
        for (let r = r1; r <= r2; r++) {
            for (let c = c2; c >= c1; c--) {
                const el = rows[r] && rows[r].children[c];
                if (!el || el === keep) {
                    continue;
                }
                if ((el.textContent || '').trim()) {
                    extra += ' ' + el.innerHTML;
                }
                el.remove();
            }
        }
        if (extra) {
            keep.innerHTML = keep.innerHTML + extra;
        }
        keep.colSpan = c2 - c1 + 1;
        keep.rowSpan = r2 - r1 + 1;
        this.htmlEditorDirty = true;
    }

    /** Split a merged cell back into its grid cells (empties added). */
    _splitCell(cell, row, table, cellIndex) {
        const cs = cell.colSpan || 1;
        const rs = cell.rowSpan || 1;
        if (cs === 1 && rs === 1) {
            this.showToast('Not a merged cell', 'Split only applies to cells that were merged.', 'info');
            return;
        }
        const doc = cell.ownerDocument || document;
        const mkCell = () => {
            const c = doc.createElement(cell.tagName.toLowerCase());
            const style = cell.getAttribute('style');
            if (style) {
                c.setAttribute('style', style);
            }
            c.innerHTML = '&nbsp;';
            return c;
        };
        cell.removeAttribute('colspan');
        cell.removeAttribute('rowspan');
        for (let i = 1; i < cs; i++) {
            cell.insertAdjacentElement('afterend', mkCell());
        }
        if (rs > 1) {
            const rows = Array.from(table.rows);
            const rIdx = rows.indexOf(row);
            for (let r = rIdx + 1; r < rIdx + rs && r < rows.length; r++) {
                const ref = rows[r].children[Math.min(cellIndex, rows[r].children.length - 1)];
                for (let i = 0; i < cs; i++) {
                    const c = mkCell();
                    if (ref) {
                        ref.insertAdjacentElement('beforebegin', c);
                    } else {
                        rows[r].appendChild(c);
                    }
                }
            }
        }
        this.htmlEditorDirty = true;
    }

    /** Table group's "+ Table": a styled 3-column data table at the caret. */
    handleInsertTable() {
        const th = 'background: #1f3a5f; color: #ffffff; text-align: left; padding: 5pt 7pt; font-size: 9.5pt';
        const cell = 'padding: 5pt 7pt; border-bottom: 0.75pt solid #dddddd';
        const snippet =
            '\n<table style="width: 100%; border-collapse: collapse">' +
            '<thead><tr>' +
            '<th style="' +
            th +
            '">Column 1</th><th style="' +
            th +
            '">Column 2</th><th style="' +
            th +
            '">Column 3</th>' +
            '</tr></thead><tbody>' +
            '<tr><td style="' +
            cell +
            '">&nbsp;</td><td style="' +
            cell +
            '">&nbsp;</td><td style="' +
            cell +
            '">&nbsp;</td></tr>' +
            '<tr><td style="' +
            cell +
            '">&nbsp;</td><td style="' +
            cell +
            '">&nbsp;</td><td style="' +
            cell +
            '">&nbsp;</td></tr>' +
            '</tbody></table>\n';
        if (this.showHtmlBodyVisual) {
            this._insertIntoVisualPage(snippet);
        } else {
            this._insertAtEditorCursor(snippet);
        }
        this.showToast(
            'Table added',
            'Drag a cell edge to resize columns; use the Table tools for rows, columns, and borders.',
            'success'
        );
    }

    /** Purple insertion caret that tracks the pointer while dragging. */
    _showDropMarker(event, pv) {
        let marker = pv.querySelector('.dg-drop-marker');
        if (!marker) {
            marker = document.createElement('span');
            marker.className = 'dg-drop-marker';
            marker.setAttribute('contenteditable', 'false');
            marker.style.cssText =
                'position: absolute; width: 3px; background: #7c3aed; pointer-events: none; z-index: 99; border-radius: 2px; box-shadow: 0 0 4px rgba(124, 58, 237, 0.7);';
            pv.style.position = 'relative';
            pv.appendChild(marker);
        }
        let rect = null;
        try {
            const range = document.caretRangeFromPoint(event.clientX, event.clientY);
            if (range && pv.contains(range.startContainer)) {
                const rects = range.getClientRects();
                rect = rects && rects.length ? rects[0] : null;
                if (!rect) {
                    const el =
                        range.startContainer.nodeType === 3 ? range.startContainer.parentElement : range.startContainer;
                    rect = el ? el.getBoundingClientRect() : null;
                }
            }
        } catch (e) {
            rect = null;
        }
        if (rect) {
            const pvRect = pv.getBoundingClientRect();
            marker.style.left = rect.left - pvRect.left + 'px';
            marker.style.top = rect.top - pvRect.top + 'px';
            marker.style.height = (rect.height || 16) + 'px';
            marker.style.display = 'block';
        } else {
            marker.style.display = 'none';
        }
        pv.style.boxShadow = '0 0 0 3px rgba(124, 58, 237, 0.35)';
    }

    _hideDropMarker(pv) {
        const marker = pv.querySelector('.dg-drop-marker');
        if (marker) {
            marker.remove();
        }
        pv.style.boxShadow = '';
    }

    /** Drop a dragged tag chip / image thumbnail at the pointed-at spot. */
    _handleVisualDrop(event, pv) {
        event.preventDefault();
        this._hideDropMarker(pv);
        // Internal chip/thumbnail drags carry their payload in component state
        // (_dragSnippet) — dataTransfer doesn't survive LWS reliably. External
        // drops (text dragged from elsewhere) still read dataTransfer.
        let text = this._dragSnippet;
        this._dragSnippet = null;
        if (!text) {
            try {
                text = event.dataTransfer && event.dataTransfer.getData('text/plain');
            } catch (e) {
                text = null;
            }
        }
        if (!text) {
            return;
        }
        const doc = pv.ownerDocument || document;
        const tpl = doc.createElement('template');
        // eslint-disable-next-line @lwc/lwc/no-inner-html -- deliberate manual-DOM canvas write; content passes _sanitizeStagedHtml / scopeHtmlForInlinePreview
        tpl.innerHTML = text;
        this._pillifyTags(tpl.content);
        let range = null;
        try {
            if (doc.caretRangeFromPoint) {
                range = doc.caretRangeFromPoint(event.clientX, event.clientY);
            } else if (doc.caretPositionFromPoint) {
                const p = doc.caretPositionFromPoint(event.clientX, event.clientY);
                if (p) {
                    range = doc.createRange();
                    range.setStart(p.offsetNode, p.offset);
                }
            }
        } catch (e) {
            range = null;
        }
        // Only honor drop points inside the page; otherwise append at the end.
        if (range && pv.contains(range.startContainer)) {
            range.collapse(true);
            range.insertNode(tpl.content);
        } else {
            pv.appendChild(tpl.content);
        }
        this.htmlEditorDirty = true;
    }

    /** Tag chips and image thumbnails are draggable onto the visual page.
     *  Payload rides in _dragSnippet (LWS-proof); dataTransfer is set too for
     *  drops outside the canvas (e.g. into the Source textarea). */
    // --- Mouse-driven chip drag (HTML5 DnD does not survive LWS + manual DOM) ---
    // mousedown arms it; 7px of movement starts it (a ghost chip follows the
    // cursor and the purple drop caret tracks the pointer); mouseup over the
    // page inserts at that exact point. A no-movement mouseup stays a click.
    handleChipDragMouseDown(event) {
        // preventDefault keeps the canvas caret alive (same job the old
        // handleFmtMouseDown did on these chips).
        event.preventDefault();
        const snippet = event.currentTarget.dataset.snippet;
        if (!snippet) {
            return;
        }
        this._pointerDrag = {
            snippet,
            label: (event.currentTarget.textContent || 'Insert').trim().slice(0, 40),
            startX: event.clientX,
            startY: event.clientY,
            started: false,
            ghost: null
        };
        this._onPointerDragMove = (e) => this._pointerDragMove(e);
        this._onPointerDragUp = (e) => this._pointerDragUp(e);
        document.addEventListener('mousemove', this._onPointerDragMove, true);
        document.addEventListener('mouseup', this._onPointerDragUp, true);
    }

    _getVisualPv() {
        const host = this.template.querySelector('.dg-visual-host');
        return host && host.querySelector('.dg-pv');
    }

    _pointerDragMove(e) {
        const d = this._pointerDrag;
        if (!d) {
            return;
        }
        if (!d.started) {
            if (Math.abs(e.clientX - d.startX) + Math.abs(e.clientY - d.startY) < 7) {
                return;
            }
            d.started = true;
            const g = document.createElement('div');
            g.className = 'dg-drag-ghost';
            g.textContent = d.label;
            document.body.appendChild(g);
            d.ghost = g;
        }
        d.ghost.style.left = e.clientX + 14 + 'px';
        d.ghost.style.top = e.clientY + 10 + 'px';
        const pv = this._getVisualPv();
        if (pv) {
            const r = pv.getBoundingClientRect();
            const over = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
            if (over) {
                this._showDropMarker(e, pv);
            } else {
                this._hideDropMarker(pv);
            }
        }
        e.preventDefault();
    }

    _pointerDragUp(e) {
        const d = this._pointerDrag;
        this._pointerDrag = null;
        document.removeEventListener('mousemove', this._onPointerDragMove, true);
        document.removeEventListener('mouseup', this._onPointerDragUp, true);
        if (!d || !d.started) {
            return; // plain click — the chip's onclick inserts at the caret
        }
        if (d.ghost) {
            d.ghost.remove();
        }
        // The drag consumed this gesture — swallow the click that follows a
        // mouseup back over the chip, or it would double-insert.
        this._suppressChipClick = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._suppressChipClick = false;
        }, 250);
        const pv = this._getVisualPv();
        if (!pv) {
            return;
        }
        this._hideDropMarker(pv);
        const r = pv.getBoundingClientRect();
        const over = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
        if (!over) {
            return;
        }
        // Document-context DOM insertion silently no-ops under LWS, so this
        // capture-phase listener only STAGES the drop; the pv's own mouseup
        // listener (proven context — see renderedCallback) performs it. The
        // timeout is a safety net if that listener never fires.
        this._pendingDropInsert = { snippet: d.snippet, x: e.clientX, y: e.clientY };
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._performPendingDropInsert(), 250);
    }

    /** Executes a staged chip drop: caret to the drop point, then the same
     *  insert the chip's click handler uses. Idempotent — first caller wins. */
    _performPendingDropInsert() {
        const drop = this._pendingDropInsert;
        if (!drop) {
            return;
        }
        this._pendingDropInsert = null;
        const pv = this._getVisualPv();
        if (!pv) {
            return;
        }
        try {
            let range = null;
            if (document.caretRangeFromPoint) {
                range = document.caretRangeFromPoint(drop.x, drop.y);
            } else if (document.caretPositionFromPoint) {
                const pos = document.caretPositionFromPoint(drop.x, drop.y);
                if (pos) {
                    range = document.createRange();
                    range.setStart(pos.offsetNode, pos.offset);
                }
            }
            if (range && pv.contains(range.startContainer)) {
                range.collapse(true);
                const s = window.getSelection();
                s.removeAllRanges();
                s.addRange(range);
                pv.focus();
            }
        } catch (err) {
            /* caret placement best-effort — insert falls back to append */
        }
        this._insertIntoVisualPage(drop.snippet);
    }

    handleTagDragStart(event) {
        const snippet = event.currentTarget.dataset.snippet;
        this._dragSnippet = snippet || null;
        if (snippet && event.dataTransfer) {
            try {
                event.dataTransfer.setData('text/plain', snippet);
                event.dataTransfer.effectAllowed = 'copy';
            } catch (e) {
                /* dataTransfer best-effort */
            }
        }
    }

    handleImageDragStart(event) {
        const { url, name } = event.currentTarget.dataset;
        const snippet = url ? '<img src="' + url + '" alt="' + (name || 'image') + '" style="width: 180px" />' : null;
        this._dragSnippet = snippet;
        if (snippet && event.dataTransfer) {
            try {
                event.dataTransfer.setData('text/plain', snippet);
                event.dataTransfer.effectAllowed = 'copy';
            } catch (e) {
                /* dataTransfer best-effort */
            }
        }
    }

    /** Splice text into the code textarea at the cursor (or before </body>). */
    _insertAtEditorCursor(text) {
        const ta = this.template.querySelector('.dg-html-body-editor');
        if (!ta) {
            return false;
        }
        let start = typeof ta.selectionStart === 'number' ? ta.selectionStart : ta.value.length;
        let end = typeof ta.selectionEnd === 'number' ? ta.selectionEnd : start;
        if (start === end && (start === 0 || start === ta.value.length)) {
            const bodyClose = ta.value.search(/<\/body\s*>/i);
            if (bodyClose > -1) {
                start = bodyClose;
                end = bodyClose;
            }
        }
        ta.value = ta.value.slice(0, start) + text + ta.value.slice(end);
        const pos = start + text.length;
        try {
            ta.focus();
            ta.setSelectionRange(pos, pos);
        } catch (e) {
            /* focus/selection is best-effort */
        }
        this.htmlEditorDirty = true;
        return true;
    }

    // --- Images panel (Add Image without knowing shepherd URLs) ---
    get imagePanelToggleLabel() {
        return this.showImagePanel ? 'Hide Images' : 'Add Image';
    }

    get hasTemplateImages() {
        return (this.templateImages || []).length > 0;
    }

    async toggleImagePanel() {
        this.showImagePanel = !this.showImagePanel;
        if (this.showImagePanel) {
            await this._loadTemplateImages();
        }
    }

    async _loadTemplateImages() {
        this.isLoadingTemplateImages = true;
        try {
            this.templateImages = (await listHtmlTemplateImages({ templateId: this.editTemplateId })) || [];
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Could not load images', msg, 'error');
            this.templateImages = [];
        } finally {
            this.isLoadingTemplateImages = false;
        }
    }

    triggerInsertImagePicker() {
        const input = this.template.querySelector('.dg-insert-image-input');
        if (input) {
            input.click();
        }
    }

    async handleInsertImageSelected(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        // SVG excluded on purpose — the PDF engine silently drops it.
        if (!/\.(png|jpe?g|gif|bmp)$/i.test(file.name)) {
            this.showToast(
                'Unsupported image',
                'Use .png, .jpg, .gif, or .bmp — SVG does not render in PDF output.',
                'error'
            );
            event.target.value = '';
            return;
        }
        this.isUploadingInsertImage = true;
        try {
            const buffer = await file.arrayBuffer();
            const result = await saveHtmlTemplateImage({
                templateId: this.editTemplateId,
                fileName: file.name,
                base64Content: bytesToBase64(new Uint8Array(buffer))
            });
            this._insertImageSnippet(result.url, result.fileName);
            await this._loadTemplateImages();
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Image upload failed', msg, 'error');
        } finally {
            this.isUploadingInsertImage = false;
            event.target.value = '';
        }
    }

    handleInsertExistingImage(event) {
        const { url, name } = event.currentTarget.dataset;
        this._insertImageSnippet(url, name);
    }

    /** Drop a ready-made, PDF-safe <img> tag at the editor cursor. */
    _insertImageSnippet(url, name) {
        const snippet = '<img src="' + url + '" alt="' + (name || 'image') + '" style="width: 180px" />';
        // Visual mode: insert into the editable rendered page directly.
        if (this.showHtmlBodyVisual) {
            this._insertIntoVisualPage('<p>' + snippet + '</p>');
            this.showToast(
                'Image inserted',
                'Added at the end of the document — cut/paste it where you want it, or fine-tune in Code.',
                'success'
            );
            return;
        }
        if (this._insertAtEditorCursor(snippet)) {
            this.showToast(
                'Image inserted',
                'A PDF-safe <img> tag was placed at your cursor — adjust the width, then click "Apply Editor HTML".',
                'success'
            );
        }
    }

    async handleApplyHtmlBody() {
        // Serialize the CURRENT view non-destructively — Apply must never kick
        // the author out of Visual mode.
        const text = (this._currentDraftHtml() || '').trim();
        if (!text) {
            this.showToast('Nothing to apply', 'Paste or edit HTML in the editor first.', 'warning');
            return;
        }
        this.isApplyingHtmlBody = true;
        try {
            const base = (this.uploadedFileName || 'template.html').replace(/\.(html?|zip)$/i, '');
            await this._processAndSaveHtmlBody(this.editTemplateId, text, base + '.html', null, 'editor');
            this.htmlEditorDirty = false;
            if (this.showHtmlBodyVisual) {
                // Staged text is the new baseline: Source view and the
                // visual round-trip both work from what was just staged.
                this._visualOriginalCode = text;
                const ta = this.template.querySelector('.dg-html-body-editor');
                if (ta) {
                    ta.value = text;
                }
            }
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || String(err);
            this.showToast('Apply failed', msg, 'error');
        } finally {
            this.isApplyingHtmlBody = false;
        }
    }

    downloadTemplate() {
        if (this.currentFileId) {
            this[NavigationMixin.Navigate](
                {
                    type: 'standard__webPage',
                    attributes: {
                        url: `/sfc/servlet.shepherd/document/download/${this.currentFileId}`
                    }
                },
                false
            );
        }
    }

    resetForm() {
        this.uploadedFileName = '';
        this.uploadedContentVersionId = null;
        this.uploadedPdfAcroFormSnapshot = null;
        this.uploadedPdfAcroFormSnapshotJson = null;
        this._resetEditFileUploadWidget();
        this.currentWizardStep = '1';
        this.newTemplateName = '';
        this.newTemplateApiName = '';
        this._newApiNameEdited = false;
        this.newTemplateCategory = '';
        // Excel leaves Output Format = 'Native'; without this reset the next
        // wizard open shows Type=Excel with a forced-invalid 'PDF' format.
        // Default path is "I Have an Existing File" — most admins arrive with
        // a document in hand; the design/AI/scratch cards sit right beside it.
        this.newAuthoringMode = 'file';
        this.newStarterKey = 'report';
        this._logoFile = null;
        this.newTemplateLogoName = '';
        this.isAutoCreating = false;
        this.showAdvancedOptions = false;
        this.newTemplateLogoChoice = 'none';
        this.newTemplateType = 'Word';
        this.newTemplateDesc = '';
        this.newTemplateQuery = '';
        this.newTemplateOutputFormat = 'PDF';
        this.newTemplatePageOrientation = 'Portrait';
        this.newTemplatePageSize = 'Letter';
        this.newTemplatePageMargins = 'Default';
        this.newTemplateCustomMargins = '';
        this.newTemplateObject = 'Account';
        this.createdTemplateId = null;
        this.isCreating = true;
        this._editContext = false;
        this.useApexProvider = false;
        this.dataSourceMode = 'record';
        this._clearApexProviderState();
        this.queryTreeNodes = [];
        this.builderTab = 'fields';
        this.builderSearchTerm = '';
        this.newTemplateSampleRecordId = '';
        this.sampleRecordData = null;
        this._allFields = [];
        this._allChildren = [];
        this._allParents = [];
        return refreshApex(this.wiredTemplatesResult);
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

    // ===== Watermark / background image tab =====

    get editTemplateOutputIsPdf() {
        return this.editTemplateOutputFormat === 'PDF';
    }

    get watermarkPreviewUrl() {
        return this.editTemplateWatermarkCvId
            ? '/sfc/servlet.shepherd/version/download/' + this.editTemplateWatermarkCvId
            : null;
    }

    async handleWatermarkFileSelected(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        if (!file.type || !file.type.startsWith('image/')) {
            this.showToast('Unsupported file', 'Please choose an image file (PNG, JPEG, GIF).', 'error');
            event.target.value = '';
            return;
        }
        const active = (this.versions || []).find((v) => v[F.VerIsActive]);
        if (!active) {
            this.showToast(
                'No active version',
                'Save the template first so a version exists, then upload the watermark.',
                'warning'
            );
            event.target.value = '';
            return;
        }
        this.isUploadingWatermark = true;
        try {
            const reader = new FileReader();
            const base64 = await new Promise((resolve, reject) => {
                reader.onload = () => {
                    const dataUrl = reader.result;
                    const commaIdx = dataUrl.indexOf(',');
                    resolve(commaIdx > -1 ? dataUrl.substring(commaIdx + 1) : null);
                };
                reader.onerror = () => reject(new Error('FileReader failed'));
                reader.readAsDataURL(file);
            });
            const newCvId = await saveWatermarkImage({
                versionId: active.Id,
                fileName: file.name,
                base64Data: base64
            });
            this.editTemplateWatermarkCvId = newCvId;
            this.showToast('Success', 'Watermark uploaded.', 'success');
        } catch (err) {
            const msg =
                err && err.body && err.body.message ? err.body.message : (err && err.message) || 'Upload failed';
            this.showToast('Watermark upload failed', msg, 'error');
        } finally {
            this.isUploadingWatermark = false;
            event.target.value = '';
        }
    }

    async handleClearWatermark() {
        const active = (this.versions || []).find((v) => v[F.VerIsActive]);
        if (!active) {
            return;
        }
        this.isUploadingWatermark = true;
        try {
            await clearWatermarkImage({ versionId: active.Id });
            this.editTemplateWatermarkCvId = null;
            this.showToast('Removed', 'Watermark cleared.', 'success');
        } catch (err) {
            const msg = err && err.body && err.body.message ? err.body.message : (err && err.message) || 'Clear failed';
            this.showToast('Clear failed', msg, 'error');
        } finally {
            this.isUploadingWatermark = false;
        }
    }

    // ─── Chart pipeline helpers ────────────────────────────────────────────
    // Inlined here (rather than imported from c/docGenUtils) for the same
    // reason docGenRunner inlines them — cross-bundle export resolution can
    // serve a stale module proxy after the util gains a new export.

    _rasterizeSvgToPng(svgString, width, height, scale = 4) {
        return new Promise((resolve, reject) => {
            const blob = new Blob([svgString], { type: 'image/svg+xml' });
            const url = URL.createObjectURL(blob);
            const img = new Image();
            img.onload = () => {
                try {
                    const canvas = document.createElement('canvas');
                    canvas.width = width * scale;
                    canvas.height = height * scale;
                    const ctx = canvas.getContext('2d');
                    ctx.imageSmoothingEnabled = true;
                    ctx.imageSmoothingQuality = 'high';
                    ctx.fillStyle = '#ffffff';
                    ctx.fillRect(0, 0, canvas.width, canvas.height);
                    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                    URL.revokeObjectURL(url);
                    resolve(canvas.toDataURL('image/png').split(',')[1]);
                } catch (err) {
                    URL.revokeObjectURL(url);
                    reject(err);
                }
            };
            img.onerror = (err) => {
                URL.revokeObjectURL(url);
                reject(err instanceof Error ? err : new Error('SVG image load failed'));
            };
            img.src = url;
        });
    }

    async _prepareChartsForAdmin(templateId, recordId) {
        try {
            const requests = await prepareChartImages({ templateId, recordId });
            if (!Array.isArray(requests) || requests.length === 0) {
                return { map: {}, cvIds: [] };
            }
            const map = {};
            const cvIds = [];
            for (const req of requests) {
                try {
                    // eslint-disable-next-line no-await-in-loop
                    const pngBase64 = await this._rasterizeSvgToPng(req.svgString, req.width, req.height);
                    // eslint-disable-next-line no-await-in-loop
                    const cvId = await uploadChartImage({
                        recordId,
                        signature: req.signature,
                        base64Png: pngBase64
                    });
                    if (cvId) {
                        map[req.signature] = cvId + '|' + req.width + 'x' + req.height;
                        cvIds.push(cvId);
                    }
                } catch (chartErr) {
                    console.warn('DocGen admin: chart prep failed for signature ' + req.signature, chartErr);
                }
            }
            return { map, cvIds };
        } catch (e) {
            console.warn('DocGen admin: prepareChartImages failed; charts will text-fallback', e);
            return { map: {}, cvIds: [] };
        }
    }

    async _cleanupChartsForAdmin(cvIds) {
        if (!Array.isArray(cvIds) || cvIds.length === 0) {
            return;
        }
        try {
            await deleteChartImages({ cvIds });
        } catch (cleanupErr) {
            console.warn('DocGen admin: chart CV cleanup failed', cleanupErr);
        }
    }
}
