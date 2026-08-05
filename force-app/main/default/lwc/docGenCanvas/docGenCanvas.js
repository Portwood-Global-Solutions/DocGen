import { LightningElement, api, track } from 'lwc';
import getHtmlTemplateBody from '@salesforce/apex/DocGenController.getHtmlTemplateBody';
import saveHtmlTemplateBody from '@salesforce/apex/DocGenController.saveHtmlTemplateBody';
import {
    blankDocument,
    newTextBox,
    newArtboard,
    pageGeometry,
    serialize,
    deserialize,
    clampBox,
    inToPx,
    pxToIn
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
                style:
                    'position:absolute;left:' +
                    inToPx(b.x, this.zoom) +
                    'px;top:' +
                    inToPx(b.y, this.zoom) +
                    'px;width:' +
                    inToPx(b.w, this.zoom) +
                    'px;min-height:' +
                    inToPx(b.h, this.zoom) +
                    'px;',
                cls: b.id === this.selectedId ? 'dg-cbox dg-cbox_selected' : 'dg-cbox',
                isSelected: b.id === this.selectedId,
                readout: b.x.toFixed(2) + 'in, ' + b.y.toFixed(2) + 'in · ' + b.w.toFixed(2) + 'in',
                modeLabel: b.mode === 'flow' ? 'Flows' : 'Pinned'
            }))
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
        for (const el of this.template.querySelectorAll('.dg-cbox-body')) {
            const model = byId.get(el.dataset.id);
            if (!model) continue;
            const isFocused = this.template.activeElement === el;
            if (!isFocused && el.innerHTML !== model.html) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                el.innerHTML = model.html;
            }
        }
    }

    handleToolSelect(event) {
        this.activeTool = event.currentTarget.dataset.tool;
    }

    /** Click the artboard with the Text tool armed to place a box where you clicked. */
    handleBoardClick(event) {
        if (this.activeTool !== 'text') {
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
        const box = clampBox(newTextBox(x, y, 2.5, 0.4), this.geo);
        target.boxes = [...target.boxes, box];
        this.doc = { ...this.doc };
        this.selectedId = box.id;
        this.activeTool = 'select';
        this.statusText = 'Text box placed';
    }

    handleBoxMouseDown(event) {
        // Let the inner editor own its own clicks — dragging from inside the text
        // would fight text selection.
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
        }
        this.applyToBox(d.id, next);
    }

    onDragEnd() {
        window.removeEventListener('mousemove', this._onMove, true);
        window.removeEventListener('mouseup', this._onUp, true);
        this._drag = null;
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
        this.applyToBox(id, { html: event.currentTarget.innerHTML });
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
