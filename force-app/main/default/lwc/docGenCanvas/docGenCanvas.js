import { LightningElement, api, track } from 'lwc';
import getHtmlTemplateBody from '@salesforce/apex/DocGenController.getHtmlTemplateBody';
import saveHtmlTemplateBody from '@salesforce/apex/DocGenController.saveHtmlTemplateBody';
import generatePdf from '@salesforce/apex/DocGenController.generatePdf';
import { extractQueryShape } from 'c/docGenAuthoringKit';
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
    suggestTotals
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

    @track doc = blankDocument();
    @track selectedId = null;
    @track zoom = 1;
    @track activeTool = 'select';
    @track isSaving = false;
    @track statusText = '';
    // Alignment guides for the box being dragged. Cleared on mouseup.
    @track guides = [];

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
        return this.doc.artboards.map((board, idx) => ({
            id: board.id,
            index: idx + 1,
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
                // Tables are edited through the panel, not by typing into cells — the
                // cells hold merge tags, and free-typing into them would desynchronise
                // the column model from what actually serializes.
                editable: b.kind !== 'table',
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

    async loadBody() {
        if (this._loaded || !this.templateId) {
            return;
        }
        this._loaded = true;
        try {
            const html = await getHtmlTemplateBody({ templateId: this.templateId });
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
        const byId = new Map();
        for (const board of this.doc.artboards) {
            for (const b of board.boxes) byId.set(b.id, b);
        }
        // Tables render from the SAME code that serializes them, so the artboard
        // cannot drift from the PDF.
        for (const el of this.template.querySelectorAll('.dg-cbox-table')) {
            const model = byId.get(el.dataset.id);
            if (!model || model.kind !== 'table') continue;
            const want = tablePreviewHtml(model);
            if (el.innerHTML !== want) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                el.innerHTML = want;
            }
        }
        // Text lives in a real <textarea>. Never write into the one being typed in —
        // assigning value moves the caret to the end on every keystroke.
        for (const el of this.template.querySelectorAll('.dg-cbox-text')) {
            const model = byId.get(el.dataset.id);
            if (!model) continue;
            if (this.template.activeElement !== el && el.value !== (model.text || '')) {
                el.value = model.text || '';
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
    handleBoxInput(event) {
        const id = event.currentTarget.dataset.id;
        this.applyToBox(id, { text: event.currentTarget.value });
    }

    /**
     * Keeps keystrokes inside the box.
     *
     * Lightning binds single-key global shortcuts ("/" for search, others) on window
     * capture. A <textarea> is already exempt from those, which is the main reason text
     * editing here is a textarea and not a contenteditable — the flow designer, which
     * uses contenteditable, has to detect focus being STOLEN to the search box and
     * steal it back afterwards, because LWS never delivers the window-capture listener
     * that would let it be prevented. Stopping propagation as well costs nothing and
     * covers any component above us that binds its own document-level keys.
     */
    handleBoxKeydown(event) {
        event.stopPropagation();
    }

    handleModeToggle() {
        const box = this.selectedBox;
        if (!box) return;
        this.applyToBox(box.id, { mode: box.mode === 'flow' ? 'pinned' : 'flow' });
        this.statusText =
            box.mode === 'flow'
                ? 'Pinned — lands exactly here, does not repeat on continuation pages'
                : 'Flows — content can grow and spill onto following pages';
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

    async handleSave() {
        if (!this.templateId) {
            this.statusText = 'No template id — cannot save';
            return;
        }
        this.isSaving = true;
        try {
            const html = serialize(this.doc, this.geo);
            await saveHtmlTemplateBody({
                templateId: this.templateId,
                fileName: 'canvas.html',
                htmlContent: html
            });
            this.statusText = 'Saved';
            this.dispatchEvent(new CustomEvent('saved', { detail: { html } }));
        } catch (e) {
            this.statusText = 'Save failed: ' + (e.body ? e.body.message : e.message);
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
