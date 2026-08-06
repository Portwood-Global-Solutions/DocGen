import { LightningElement, api, track } from 'lwc';
import getHtmlTemplateBody from '@salesforce/apex/DocGenController.getHtmlTemplateBody';
import saveAndPublishHtmlBody from '@salesforce/apex/DocGenController.saveAndPublishHtmlBody';
import generatePdf from '@salesforce/apex/DocGenController.generatePdf';
import getTemplateVersions from '@salesforce/apex/DocGenController.getTemplateVersions';
import getVersionBody from '@salesforce/apex/DocGenController.getVersionBody';
import activateVersion from '@salesforce/apex/DocGenController.activateVersion';
import { extractQueryShape } from 'c/docGenAuthoringKit';
import { updateRecord } from 'lightning/uiRecordApi';
import ID_FIELD from '@salesforce/schema/DocGen_Template__c.Id';
import QUERY_FIELD from '@salesforce/schema/DocGen_Template__c.Query_Config__c';
import {
    blankDocument,
    newTextBox,
    newArtboard,
    pageGeometry,
    serialize,
    deserialize,
    clampBox,
    inToPx,
    pxToIn,
    FONT_CHOICES,
    DEFAULT_STYLE,
    newTableBox,
    tablePreviewHtml,
    snapBox,
    suggestTotals,
    buildQueryConfig,
    sanitizeInline
} from './canvasModel';

/**
 * Canvas editor — a Canva-style artboard for Portwood's Canvas template type.
 *
 * DELIBERATELY NET NEW, not a mode inside docGenAdmin. That component is ~15k lines
 * built on treating a contenteditable DOM as the document, which is what produced the
 * Lightning Web Security bug class (missing replaceWith, cloneNode dropping nodes)
 * that only reproduces in a namespaced install. Here the scene graph in canvasModel is
 * the document and the DOM is a disposable projection of it, so there is nothing to
 * read back and nothing for LWS to distort.
 *
 * SLICE ONE: place, move, resize and type into text boxes; save; reload. No formatting
 * panel, no images, no merge-tag rail yet — those hang off the same model once the
 * geometry is trustworthy. The one thing that must be exactly right first is that a
 * box at 2.4in x 3.1in on screen is at 2.4in x 3.1in in the PDF.
 */
export default class DocGenCanvas extends LightningElement {
    @api recordId;
    @api templateId;
    @api pageSize = 'Letter';
    @api orientation = 'Portrait';
    @api queryConfig;
    @api baseObject;
    @api sampleRecordId;

    @track doc = blankDocument();
    @track selectedId = null;
    @track zoom = 1;
    @track activeTool = 'select';
    @track isSaving = false;
    @track statusText = '';
    // Alignment guides for the box being dragged. Cleared on mouseup.
    @track guides = [];
    @track previewUrl = null;
    @track isPreviewing = false;
    @track queryDraft = null;
    @track saveError = null;
    @track versions = [];
    @track activeVersionId = null;

    _loaded = false;
    // Live drag state. Kept off @track on purpose: it changes on every mousemove and
    // re-rendering the whole board 60 times a second would make dragging feel awful.
    _drag = null;

    get geo() {
        return pageGeometry(this.pageSize, this.orientation);
    }

    get boardStyle() {
        return (
            'width:' +
            inToPx(this.geo.w, this.zoom) +
            'px;height:' +
            inToPx(this.geo.h, this.zoom) +
            'px;position:relative;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,0.18);'
        );
    }

    /**
     * Boxes projected to screen pixels. The model stays in inches; nothing here ever
     * writes back a pixel value, so zoom can never drift the document.
     */
    get renderedBoards() {
        const canDelete = (this.doc.artboards || []).length > 1;
        return this.doc.artboards.map((board, idx) => ({
            id: board.id,
            index: idx + 1,
            canDelete,
            boxes: board.boxes.map((b) => ({
                ...b,
                // The on-screen box carries the SAME styling the serializer will emit.
                // If the canvas showed 11pt sans and the PDF rendered 12pt serif, the
                // whole premise of this editor would be false — so both read the one
                // style object rather than each having their own idea of it.
                style:
                    'position:absolute;left:' +
                    inToPx(b.x, this.zoom) +
                    'px;top:' +
                    inToPx(b.y, this.zoom) +
                    'px;width:' +
                    inToPx(b.w, this.zoom) +
                    'px;min-height:' +
                    inToPx(b.h, this.zoom) +
                    'px;' +
                    this.screenStyle(b),
                cls: b.id === this.selectedId ? 'dg-cbox dg-cbox_selected' : 'dg-cbox',
                isSelected: b.id === this.selectedId,
                // NOTHING is edited on the artboard now — text through the panel's
                // rich-text editor, tables through the column editor. The artboard is a
                // faithful preview you arrange, which is what makes it trustworthy.
                readout: b.x.toFixed(2) + 'in, ' + b.y.toFixed(2) + 'in · ' + b.w.toFixed(2) + 'in',
                modeLabel: b.mode === 'flow' ? 'Flows' : 'Pinned'
            }))
        }));
    }

    /**
     * Box styling in SCREEN units. Point sizes scale by zoom so 11pt at 200% looks
     * twice as big, matching every design tool — the model still stores points.
     */
    screenStyle(b) {
        const st = { ...DEFAULT_STYLE, ...(b.style || {}) };
        const z = this.zoom || 1;
        let css =
            'font-family:' +
            st.font +
            ';font-size:' +
            (st.size * z).toFixed(2) +
            'pt;color:' +
            st.color +
            ';text-align:' +
            st.align +
            ';padding:' +
            (st.padding * z).toFixed(2) +
            'pt;';
        if (st.bold) css += 'font-weight:bold;';
        if (st.italic) css += 'font-style:italic;';
        if (st.underline) css += 'text-decoration:underline;';
        if (st.fill) css += 'background:' + st.fill + ';';
        if (st.borderWidth > 0) css += 'border:' + (st.borderWidth * z).toFixed(2) + 'pt solid ' + st.borderColor + ';';
        return css;
    }

    get toolTableClass() {
        return this.activeTool === 'table' ? 'dg-tool dg-tool_active' : 'dg-tool';
    }

    get selectedIsTable() {
        const b = this.selectedBox;
        return !!b && b.kind === 'table';
    }

    get selTableRel() {
        return ((this.selectedBox || {}).table || {}).relationship || '';
    }

    get selTableHeader() {
        return !!((this.selectedBox || {}).table || {}).showHeader;
    }

    get selTableColumns() {
        const t = (this.selectedBox || {}).table || {};
        return (t.columns || []).map((c, i) => ({ ...c, idx: i, num: i + 1 }));
    }

    _patchTable(patch) {
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        this.applyToBox(box.id, { table: { ...box.table, ...patch } });
    }

    handleTableRelChange(event) {
        this._patchTable({ relationship: (event.target.value || '').trim() });
    }

    handleTableHeaderToggle(event) {
        this._patchTable({ showHeader: event.target.checked });
    }

    handleColumnChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const key = event.currentTarget.dataset.key;
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        const columns = box.table.columns.map((c, i) => (i === idx ? { ...c, [key]: event.target.value } : c));
        this._patchTable({ columns });
    }

    get selTableHeaderFill() {
        return ((this.selectedBox || {}).table || {}).headerFill || '#eeeeee';
    }
    get selTableHeaderBold() {
        return !!((this.selectedBox || {}).table || {}).headerBold;
    }
    get selTableGridColor() {
        return ((this.selectedBox || {}).table || {}).gridColor || '#999999';
    }
    get selTableGridWidth() {
        const t = (this.selectedBox || {}).table || {};
        return t.gridWidth == null ? 0.5 : t.gridWidth;
    }
    get selTableCellPadding() {
        const t = (this.selectedBox || {}).table || {};
        return t.cellPadding == null ? 3 : t.cellPadding;
    }
    get selTableTotals() {
        return !!(((this.selectedBox || {}).table || {}).totals || {}).enabled;
    }
    get selTableRows() {
        const t = (this.selectedBox || {}).table || {};
        return (t.rows || []).map((cells, i) => ({
            idx: i,
            num: i + 1,
            text: cells.join(' | ')
        }));
    }

    handleTableStyleChange(event) {
        const key = event.currentTarget.dataset.key;
        const raw = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const val = event.target.type === 'number' ? parseFloat(raw) : raw;
        this._patchTable({ [key]: val });
    }

    handleAddRow() {
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        this._patchTable({ rows: [...(box.table.rows || []), box.table.columns.map(() => '')] });
    }

    handleRowChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        // Pipe-separated so a whole row is editable in one field — a cell-per-input grid
        // in a 260px panel is unusable, and rows here are short by nature.
        const cells = String(event.target.value || '')
            .split('|')
            .map((v) => v.trim());
        const rows = (box.table.rows || []).map((r, i) => (i === idx ? cells : r));
        this._patchTable({ rows });
    }

    handleRemoveRow(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        this._patchTable({ rows: (box.table.rows || []).filter((r, i) => i !== idx) });
    }

    handleTotalsToggle(event) {
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        const on = event.target.checked;
        const existing = (box.table.totals || {}).cells || [];
        this._patchTable({
            totals: {
                enabled: on,
                // Suggest {SUM:Rel.Field} per column on first enable, then leave the
                // author's edits alone.
                cells: existing.length ? existing : suggestTotals(box.table)
            }
        });
    }

    handleTotalsCellChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        const cells = [...((box.table.totals || {}).cells || [])];
        cells[idx] = event.target.value;
        this._patchTable({ totals: { ...box.table.totals, cells } });
    }

    get selTableTotalsCells() {
        const t = (this.selectedBox || {}).table || {};
        const cells = (t.totals || {}).cells || [];
        return (t.columns || []).map((c, i) => ({ idx: i, label: c.label, value: cells[i] || '' }));
    }

    handleAddColumn() {
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') return;
        this._patchTable({
            columns: [...box.table.columns, { label: 'Column ' + (box.table.columns.length + 1), tag: '', width: '' }]
        });
    }

    handleRemoveColumn(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const box = this.selectedBox;
        if (!box || box.kind !== 'table' || box.table.columns.length <= 1) return;
        this._patchTable({ columns: box.table.columns.filter((c, i) => i !== idx) });
    }

    // Placeholders that LOOK like merge tags have to come from getters: LWC parses a
    // leading "{" in an attribute as a template expression, so placeholder="{Field}"
    // compiles as a binding to a property called Field and renders empty.
    get tagPlaceholder() {
        return '{Field}';
    }

    get totalsPlaceholder() {
        return '{SUM:Rel.Field}';
    }

    /** What the template's Query Config currently exposes, for the field picker. */
    get querySpace() {
        return extractQueryShape(this.queryConfig, this.baseObject);
    }

    get relationshipOptions() {
        return (this.querySpace.children || []).map((c) => ({
            label: c.relationshipName || c.alias,
            value: c.relationshipName || c.alias
        }));
    }

    /**
     * Fields offered for the CURRENT selection: a table offers its relationship's
     * fields, a text box offers the record's own and its parents'. Clicking one is the
     * whole point — nobody should be typing {Name} from memory and finding out at
     * render time whether they got it right.
     */
    get pickableFields() {
        const shape = this.querySpace;
        const box = this.selectedBox;
        if (box && box.kind === 'table') {
            const rel = (box.table || {}).relationship;
            const child = (shape.children || []).find((c) => (c.relationshipName || c.alias) === rel);
            return ((child && child.fields) || []).map((f) => ({ key: rel + f, label: f, tag: '{' + f + '}' }));
        }
        return [...(shape.baseFields || []), ...(shape.parentFields || [])].map((f) => ({
            key: f,
            label: f,
            tag: '{' + f + '}'
        }));
    }

    get hasPickableFields() {
        return this.pickableFields.length > 0;
    }

    /**
     * True when the table points at a relationship the Query Config does not contain.
     *
     * This used to fail in silence: the field list simply came back empty with no
     * explanation, and the author was left to guess whether they had mistyped the
     * relationship or the query was missing it. Both are fixable in one click — the
     * dropdown only offers real relationships, and "Update the template's query" adds
     * whatever the canvas actually uses.
     */
    get relationshipMissingFromQuery() {
        const box = this.selectedBox;
        if (!box || box.kind !== 'table') {
            return false;
        }
        const rel = (box.table || {}).relationship;
        if (!rel) {
            return false;
        }
        return !(this.querySpace.children || []).some((c) => (c.relationshipName || c.alias) === rel);
    }

    get relationshipChoices() {
        const opts = this.relationshipOptions;
        return [{ label: '— none (fixed table) —', value: '' }, ...opts];
    }

    get hasRelationshipChoices() {
        return this.relationshipOptions.length > 0;
    }

    handleRelPick(event) {
        this._patchTable({ relationship: event.detail.value });
    }

    handlePickField(event) {
        const tag = event.currentTarget.dataset.tag;
        const label = event.currentTarget.dataset.label;
        const box = this.selectedBox;
        if (!box) {
            return;
        }
        if (box.kind === 'table') {
            this._patchTable({
                columns: [...(box.table.columns || []), { label, tag, width: '' }]
            });
            this.statusText = 'Column added: ' + label;
        } else {
            const sep = box.text && !/\s$/.test(box.text) ? ' ' : '';
            this.applyToBox(box.id, { text: (box.text || '') + sep + tag });
            this.statusText = 'Inserted ' + tag;
        }
    }

    /**
     * Preview saves FIRST, then generates.
     *
     * Previewing an unsaved canvas would show the last saved state and quietly imply
     * the edits were fine — the worst possible outcome for a button whose entire job
     * is telling you the truth about what will print.
     */
    async handlePreview() {
        if (!this.templateId) {
            return;
        }
        if (!this.sampleRecordId) {
            this.statusText = 'Set a Sample Record on the template to preview with real data';
            return;
        }
        this.isPreviewing = true;
        this.statusText = 'Saving, then generating…';
        // Open the tab NOW, synchronously inside the click, and point it at the PDF
        // once it exists. Opening after the await is what trips popup blockers — the
        // flow designer works around that by making you click Preview twice, and one
        // click is better. about:blank is explicitly allowed by LWS.
        const win = window.open('', '_blank');
        try {
            await this.handleSave();
            if (!this._saveOk) {
                // Generating anyway would render the LAST SAVED body and present it as
                // a preview of what is on screen — the most misleading thing this
                // button could do. The save banner already says what went wrong.
                this.statusText = '';
                if (win) win.close();
                return;
            }
            const res = await generatePdf({
                templateId: this.templateId,
                recordId: this.sampleRecordId,
                saveToRecord: false,
                chartCvMap: null
            });
            if (!res || !res.base64) {
                this.statusText = 'Preview did not return a document';
                if (win) win.close();
                return;
            }
            const bytes = atob(res.base64);
            const arr = new Uint8Array(bytes.length);
            for (let i = 0; i < bytes.length; i++) arr[i] = bytes.charCodeAt(i);
            if (this.previewUrl) {
                URL.revokeObjectURL(this.previewUrl);
            }
            // A blob URL in an <iframe src> is blocked outright by Lightning Web
            // Security — "HTMLIFrameElement.src supports http://, https:// schemes,
            // relative urls and about:blank". window.open with the same URL is fine,
            // which is why the preview is a tab rather than a panel.
            this.previewUrl = URL.createObjectURL(new Blob([arr], { type: 'application/pdf' }));
            if (win) {
                win.location = this.previewUrl;
            }
            this.statusText = 'Preview of ' + (res.title || 'document') + ' opened in a new tab';
        } catch (e) {
            this.statusText = 'Preview failed: ' + (e.body ? e.body.message : e.message);
            if (win) win.close();
        } finally {
            this.isPreviewing = false;
        }
    }

    handleDismissError() {
        this.saveError = null;
    }

    handleClosePreview() {
        if (this.previewUrl) {
            URL.revokeObjectURL(this.previewUrl);
        }
        this.previewUrl = null;
    }

    get hasPreview() {
        return !!this.previewUrl;
    }

    /** Editing the query in place — the canvas is where you find out it is wrong. */
    get queryText() {
        return this.queryDraft == null ? this.queryConfig || '' : this.queryDraft;
    }

    handleQueryEdit(event) {
        this.queryDraft = event.target.value;
    }

    handleUseGenerated() {
        this.queryDraft = this.generatedQuery;
    }

    async handleSaveQuery() {
        if (!this.templateId) {
            return;
        }
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.templateId;
            fields[QUERY_FIELD.fieldApiName] = this.queryText;
            await updateRecord({ fields });
            this.statusText = 'Query saved';
            this.dispatchEvent(new CustomEvent('queryupdated', { detail: { query: this.queryText } }));
        } catch (e) {
            this.statusText = 'Could not save the query: ' + (e.body ? e.body.message : e.message);
        }
    }

    /** Hands off to the host, which owns the template's full edit surface. */
    handleEditTemplate() {
        this.dispatchEvent(new CustomEvent('edittemplate', { bubbles: true, composed: true }));
    }

    get generatedQuery() {
        return buildQueryConfig(this.doc);
    }

    get queryDiffers() {
        return (this.queryConfig || '').trim() !== this.generatedQuery.trim();
    }

    /**
     * Writes the derived Query Config back to the template.
     *
     * Explicitly a button, never automatic. A generated query that silently replaced a
     * hand-tuned WHERE or ORDER BY would be a worse bug than the blank-tag problem it
     * solves, so the author sees what it will become and chooses.
     */
    async handleApplyQuery() {
        if (!this.templateId) {
            return;
        }
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.templateId;
            fields[QUERY_FIELD.fieldApiName] = this.generatedQuery;
            await updateRecord({ fields });
            this.statusText = 'Query updated from the canvas';
            this.dispatchEvent(new CustomEvent('queryupdated', { detail: { query: this.generatedQuery } }));
        } catch (e) {
            this.statusText = 'Could not update the query: ' + (e.body ? e.body.message : e.message);
        }
    }

    get fontOptions() {
        return FONT_CHOICES;
    }

    get selectedStyle() {
        return { ...DEFAULT_STYLE, ...((this.selectedBox || {}).style || {}) };
    }

    get selFont() {
        return this.selectedStyle.font;
    }
    get selSize() {
        return this.selectedStyle.size;
    }
    get selColor() {
        return this.selectedStyle.color;
    }
    get selFill() {
        return this.selectedStyle.fill || '#ffffff';
    }
    get selPadding() {
        return this.selectedStyle.padding;
    }
    get selBorderWidth() {
        return this.selectedStyle.borderWidth;
    }
    get selBorderColor() {
        return this.selectedStyle.borderColor;
    }
    get boldClass() {
        return this.selectedStyle.bold ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }
    get italicClass() {
        return this.selectedStyle.italic ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }
    get underlineClass() {
        return this.selectedStyle.underline ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }
    get alignLeftClass() {
        return this.selectedStyle.align === 'left' ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }
    get alignCenterClass() {
        return this.selectedStyle.align === 'center' ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }
    get alignRightClass() {
        return this.selectedStyle.align === 'right' ? 'dg-sbtn dg-sbtn_on' : 'dg-sbtn';
    }

    /** One entry point for every style change — keeps the patch shape in one place. */
    _patchStyle(patch) {
        const box = this.selectedBox;
        if (!box) return;
        this.applyToBox(box.id, { style: { ...DEFAULT_STYLE, ...(box.style || {}), ...patch } });
    }

    handleStyleToggle(event) {
        const key = event.currentTarget.dataset.key;
        this._patchStyle({ [key]: !this.selectedStyle[key] });
    }

    handleAlign(event) {
        this._patchStyle({ align: event.currentTarget.dataset.align });
    }

    handleFontChange(event) {
        this._patchStyle({ font: event.detail.value });
    }

    handleNumChange(event) {
        const key = event.currentTarget.dataset.key;
        const n = parseFloat(event.target.value);
        if (!isNaN(n)) this._patchStyle({ [key]: n });
    }

    handleColorChange(event) {
        this._patchStyle({ [event.currentTarget.dataset.key]: event.target.value });
    }

    handleClearFill() {
        this._patchStyle({ fill: '' });
    }

    get renderedGuides() {
        return this.guides.map((g, i) => ({
            key: g.axis + i,
            style:
                g.axis === 'v'
                    ? 'position:absolute;top:0;bottom:0;left:' + inToPx(g.at, this.zoom) + 'px;width:1px;'
                    : 'position:absolute;left:0;right:0;top:' + inToPx(g.at, this.zoom) + 'px;height:1px;'
        }));
    }

    get selectedBox() {
        for (const board of this.doc.artboards) {
            const hit = board.boxes.find((b) => b.id === this.selectedId);
            if (hit) return hit;
        }
        return null;
    }

    get hasSelection() {
        return !!this.selectedBox;
    }

    get selectedIsFlow() {
        const b = this.selectedBox;
        return !!b && b.mode === 'flow';
    }

    get zoomPercent() {
        return Math.round(this.zoom * 100) + '%';
    }

    get toolSelectClass() {
        return this.activeTool === 'select' ? 'dg-tool dg-tool_active' : 'dg-tool';
    }

    get toolTextClass() {
        return this.activeTool === 'text' ? 'dg-tool dg-tool_active' : 'dg-tool';
    }

    async connectedCallback() {
        await this.loadBody();
    }

    /**
     * Versions, newest first, with the active one marked.
     *
     * The canvas reads and writes the ACTIVE VERSION's body. Reading the loose
     * docgen_html_body_* CV while generation read the version's is exactly how a
     * template came to show five boxes on screen and render two, with nothing
     * reporting a problem — so the editor now looks at the same bytes the renderer
     * does, by construction rather than by convention.
     */
    async loadVersions() {
        if (!this.templateId) {
            return;
        }
        try {
            const rows = (await getTemplateVersions({ templateId: this.templateId })) || [];
            this.versions = rows.map((v) => {
                const isActive = v.Is_Active__c === true || v.portwoodglobal__Is_Active__c === true;
                const when = v.CreatedDate ? new Date(v.CreatedDate).toLocaleString() : '';
                return {
                    label: (isActive ? '★ ' : '') + (v.Name || 'Version') + (when ? ' · ' + when : ''),
                    value: v.Id,
                    isActive
                };
            });
            const active = this.versions.find((v) => v.isActive);
            this.activeVersionId = active ? active.value : (this.versions[0] || {}).value || null;
        } catch (e) {
            this.versions = [];
        }
    }

    get versionOptions() {
        return this.versions.map((v) => ({ label: v.label, value: v.value }));
    }

    get hasVersions() {
        return this.versions.length > 0;
    }

    /**
     * Switching version makes it active AND reloads the canvas from it, so the editor,
     * the preview and the generated document all agree immediately. Activating without
     * reloading would leave the canvas showing one version while everything downstream
     * used another — the same divergence in a new costume.
     */
    async handleVersionChange(event) {
        const id = event.detail.value;
        this.activeVersionId = id;
        try {
            await activateVersion({ versionId: id });
            const html = await getVersionBody({ versionId: id });
            const parsed = deserialize(html);
            this.doc = parsed || blankDocument();
            this.selectedId = null;
            this.statusText = parsed ? 'Loaded that version' : 'That version has no canvas content';
            await this.loadVersions();
        } catch (e) {
            this.saveError = 'Could not switch version — ' + (e.body ? e.body.message : e.message);
        }
    }

    async loadBody() {
        if (this._loaded || !this.templateId) {
            return;
        }
        this._loaded = true;
        await this.loadVersions();
        try {
            const html = this.activeVersionId
                ? await getVersionBody({ versionId: this.activeVersionId })
                : await getHtmlTemplateBody({ templateId: this.templateId });
            const parsed = deserialize(html);
            if (parsed) {
                this.doc = parsed;
                this.statusText = 'Loaded';
            } else {
                // Distinguishing "nothing stored yet" from "stored but not canvas-shaped"
                // matters: silently showing a blank artboard over a real body is how the
                // first save wipes it.
                this.doc = blankDocument();
                this.statusText = html ? 'Existing body is not canvas-shaped — starting a new artboard' : 'New canvas';
            }
        } catch (e) {
            this.doc = blankDocument();
            this.statusText = 'Could not load the saved body: ' + (e.body ? e.body.message : e.message);
        }
    }

    /**
     * Seeds each text box's contenteditable body from the model.
     *
     * contenteditable cannot be data-bound: re-rendering it on every keystroke
     * destroys the caret. So the body is lwc:dom="manual" and written here — but ONLY
     * when it actually differs and is not the element being typed into. Writing
     * innerHTML into the focused box would move the caret to the start on every
     * character, which is the same class of bug as the designer's insert caret landing
     * to the left of the tag.
     */
    renderedCallback() {
        // Re-sync the property inputs whenever the SELECTION changes.
        //
        // These are plain <input> elements holding values that come from getters. When
        // you click from one box to another, LWC reuses the same elements, and an
        // input the user has typed into keeps the DOM value it had — so the panel
        // showed the previous box's numbers. Keying off the selected id makes the
        // hand-off explicit instead of relying on the diff to notice.
        if (this._syncedFor !== this.selectedId) {
            this._syncedFor = this.selectedId;
            const st = this.selectedStyle;
            const map = {
                size: st.size,
                borderWidth: st.borderWidth,
                borderColor: st.borderColor,
                color: st.color,
                fill: st.fill || '#ffffff',
                padding: st.padding
            };
            for (const el of this.template.querySelectorAll('[data-key]')) {
                const want = map[el.dataset.key];
                if (want !== undefined && el.value !== String(want)) {
                    el.value = want;
                }
            }
        }
        const byId = new Map();
        for (const board of this.doc.artboards) {
            for (const b of board.boxes) byId.set(b.id, b);
        }
        // Every box renders read-only from the SAME code that serializes it, so the
        // artboard cannot drift from the PDF.
        for (const el of this.template.querySelectorAll('.dg-cbox-body')) {
            const model = byId.get(el.dataset.id);
            if (!model) continue;
            const want =
                model.kind === 'table' ? tablePreviewHtml(model) : model.html != null ? model.html : model.text || '';
            if (el.innerHTML !== want) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                el.innerHTML = want;
            }
        }
    }

    handleToolSelect(event) {
        this.activeTool = event.currentTarget.dataset.tool;
    }

    /** Click the artboard with the Text tool armed to place a box where you clicked. */
    handleBoardClick(event) {
        if (this.activeTool !== 'text' && this.activeTool !== 'table') {
            if (event.target.classList.contains('dg-board')) {
                this.selectedId = null;
            }
            return;
        }
        const board = event.currentTarget;
        const rect = board.getBoundingClientRect();
        const x = pxToIn(event.clientX - rect.left, this.zoom);
        const y = pxToIn(event.clientY - rect.top, this.zoom);
        const boardId = board.dataset.boardId;
        const target = this.doc.artboards.find((b) => b.id === boardId);
        if (!target) return;
        const box = clampBox(
            this.activeTool === 'table'
                ? newTableBox(x, y, Math.min(6.5, this.geo.w - x - 0.2))
                : newTextBox(x, y, 2.5, 0.4),
            this.geo
        );
        target.boxes = [...target.boxes, box];
        this.doc = { ...this.doc };
        this.selectedId = box.id;
        this.activeTool = 'select';
        this.statusText = this.activeTool === 'table' ? 'Table placed' : 'Text box placed';
    }

    handleBoxMouseDown(event) {
        // Let the inner editor own its own clicks — dragging from inside the text
        // would fight text selection.
        // Let the textarea own its own clicks — dragging from inside the text would
        // fight text selection and caret placement.
        if (event.target.classList.contains('dg-cbox-body')) {
            this.selectedId = event.currentTarget.dataset.id;
            return;
        }
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        this.selectedId = id;
        const handle = event.target.dataset.handle || null;
        const box = this.selectedBox;
        if (!box) return;
        this._drag = {
            id,
            handle,
            startX: event.clientX,
            startY: event.clientY,
            origin: { x: box.x, y: box.y, w: box.w, h: box.h }
        };
        this._onMove = (e) => this.onDragMove(e);
        this._onUp = () => this.onDragEnd();
        window.addEventListener('mousemove', this._onMove, true);
        window.addEventListener('mouseup', this._onUp, true);
    }

    onDragMove(e) {
        const d = this._drag;
        if (!d) return;
        const dx = pxToIn(e.clientX - d.startX, this.zoom);
        const dy = pxToIn(e.clientY - d.startY, this.zoom);
        const next = { ...d.origin };
        if (d.handle === 'se') {
            next.w = Math.max(0.3, d.origin.w + dx);
            next.h = Math.max(0.2, d.origin.h + dy);
        } else if (d.handle === 'e') {
            next.w = Math.max(0.3, d.origin.w + dx);
        } else if (d.handle === 's') {
            next.h = Math.max(0.2, d.origin.h + dy);
        } else {
            next.x = d.origin.x + dx;
            next.y = d.origin.y + dy;
            // Snap only when MOVING. Snapping a resize would fight the author trying to
            // set an exact width, which is the one thing this editor promises.
            const others = [];
            for (const board of this.doc.artboards) {
                for (const b of board.boxes) {
                    if (b.id !== d.id) others.push(b);
                }
            }
            const snapped = snapBox({ ...next, w: d.origin.w, h: d.origin.h }, others, this.geo);
            next.x = snapped.x;
            next.y = snapped.y;
            this.guides = snapped.guides;
        }
        this.applyToBox(d.id, next);
    }

    onDragEnd() {
        window.removeEventListener('mousemove', this._onMove, true);
        window.removeEventListener('mouseup', this._onUp, true);
        this._drag = null;
        this.guides = [];
    }

    applyToBox(id, patch) {
        const geo = this.geo;
        this.doc = {
            ...this.doc,
            artboards: this.doc.artboards.map((board) => ({
                ...board,
                boxes: board.boxes.map((b) => (b.id === id ? clampBox({ ...b, ...patch }, geo) : b))
            }))
        };
    }

    /**
     * Commits the text box's own contenteditable content back to the model.
     *
     * This is the ONE place a DOM read feeds the document, and it is scoped to a
     * single box — the browser's contenteditable restructuring cannot escape it, so
     * it cannot corrupt the document the way reading back a whole canvas can.
     */
    // The selection-mark toolbar that used to live here is gone with the textarea.
    // Formatting is now the rich-text editor's job, which does it against a real
    // selection instead of by wrapping the text in markers the author could see.

    /** Content for the panel editor — the selected box's markup. */
    get richTextValue() {
        const box = this.selectedBox;
        if (!box || box.kind === 'table') {
            return '';
        }
        return box.html != null ? box.html : box.text || '';
    }

    get canEditRichText() {
        const box = this.selectedBox;
        return !!box && box.kind !== 'table';
    }

    /**
     * The box's content is authored HERE, not on the artboard.
     *
     * Moving editing into the panel removes three problems at once.
     * lightning-input-rich-text is a real Salesforce input, so Lightning's "/" hotkey
     * leaves it alone — no document-capture interceptor, no focus recovery, neither of
     * which I could make work reliably on the artboard. The artboard can then render
     * the formatted result read-only, so what you see is finally what prints. And the
     * value is read off a supported base component instead of scraped out of a
     * contenteditable, which is the exact thing LWS keeps distorting in docGenAdmin.
     *
     * Sanitised on the way in: the editor emits more than the PDF engine honours.
     */
    handleRichTextChange(event) {
        const box = this.selectedBox;
        if (!box) {
            return;
        }
        this.applyToBox(box.id, { html: sanitizeInline(event.target.value) });
    }

    // The "/" workaround that used to live here is gone. Nothing is typed on the
    // artboard any more; text is authored in the panel's rich-text editor, which
    // Lightning already exempts from its global hotkeys, so the problem that needed an
    // interceptor and a focus recovery simply does not arise on this surface.

    handleModeToggle() {
        const box = this.selectedBox;
        if (!box) return;
        this.applyToBox(box.id, { mode: box.mode === 'flow' ? 'pinned' : 'flow' });
        this.statusText =
            box.mode === 'flow'
                ? 'Pinned — lands exactly here, does not repeat on continuation pages'
                : 'Flows — content can grow and spill onto following pages';
    }

    /**
     * Removes a page and everything on it.
     *
     * Refuses to remove the last one: a document with no artboard has nowhere to put a
     * box, and the canvas would render an empty void with no way back except reload.
     * Confirmed when the page has content, because this is the only destructive action
     * in the editor and there is no undo yet.
     */
    handleDeleteArtboard(event) {
        const id = event.currentTarget.dataset.boardId;
        const boards = this.doc.artboards || [];
        if (boards.length <= 1) {
            this.statusText = 'A document needs at least one page';
            return;
        }
        const board = boards.find((b) => b.id === id);
        const count = board ? (board.boxes || []).length : 0;
        if (count > 0) {
            // eslint-disable-next-line no-alert
            const ok = window.confirm(
                'Delete this page and the ' + count + (count === 1 ? ' box' : ' boxes') + ' on it?'
            );
            if (!ok) {
                return;
            }
        }
        this.doc = { ...this.doc, artboards: boards.filter((b) => b.id !== id) };
        if (board && (board.boxes || []).some((b) => b.id === this.selectedId)) {
            this.selectedId = null;
        }
        this.statusText = 'Page deleted';
    }

    handleAddArtboard() {
        this.doc = { ...this.doc, artboards: [...this.doc.artboards, newArtboard()] };
        this.statusText = 'Page added';
    }

    handleDelete() {
        if (!this.selectedId) return;
        this.doc = {
            ...this.doc,
            artboards: this.doc.artboards.map((b) => ({
                ...b,
                boxes: b.boxes.filter((x) => x.id !== this.selectedId)
            }))
        };
        this.selectedId = null;
    }

    handleZoom(event) {
        const dir = event.currentTarget.dataset.dir;
        const next = dir === 'in' ? this.zoom + 0.1 : this.zoom - 0.1;
        this.zoom = Math.min(2, Math.max(0.4, Math.round(next * 10) / 10));
    }

    get boxCount() {
        return (this.doc.artboards || []).reduce((n, b) => n + (b.boxes || []).length, 0);
    }

    async handleSave() {
        if (!this.templateId) {
            this.saveError = 'No template id — cannot save.';
            this._saveOk = false;
            return;
        }
        // Catch the empty case HERE, with an explanation. The server refuses to
        // overwrite a real body with an empty one — a guard that exists because a read
        // failure once destroyed someone's document — but it can only tell you after
        // the round trip, and only in a status line. If the canvas has no boxes, the
        // likely cause is that it opened without loading them, and saving would be the
        // destructive move.
        if (this.boxCount === 0) {
            this._saveOk = false;
            this.saveError =
                'Nothing to save — this canvas has no boxes. If the template had content, it did not load: ' +
                'close and reopen it rather than saving over it.';
            return;
        }
        this.saveError = null;
        this._saveOk = false;
        this.isSaving = true;
        try {
            const html = serialize(this.doc, this.geo);
            await saveAndPublishHtmlBody({
                templateId: this.templateId,
                fileName: 'canvas.html',
                htmlContent: html
            });
            this.statusText = 'Saved';
            this._saveOk = true;
            // Saving repoints the active version, so the list's timestamps are stale.
            await this.loadVersions();
            this.dispatchEvent(new CustomEvent('saved', { detail: { html } }));
        } catch (e) {
            // Surfaced as a banner, not a status line: a save that silently did not
            // happen is the single worst thing this editor can do.
            this.saveError = 'Save failed — ' + (e.body ? e.body.message : e.message);
            this.statusText = '';
            this._saveOk = false;
        } finally {
            this.isSaving = false;
        }
    }

    /** Exposed so a host or a test can read exactly what would be stored. */
    @api
    getSerializedHtml() {
        return serialize(this.doc, this.geo);
    }
}
