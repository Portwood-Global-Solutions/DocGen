import { LightningElement, api, track } from 'lwc';

/**
 * Recursive tree node for the visual query builder.
 * Renders: selected field pills, field picker dropdown,
 * parent lookup folders, child relationship folders.
 * Same component used at every depth level.
 */
export default class DocGenTreeNode extends LightningElement {
    @api nodeData; // { path, objectLabel, objectName, fields[], parentRels[], childRels[], isChild, whereClause, orderBy, limitAmount }
    @api depth = 0;
    @api globalSearch = '';

    @track _pickerOpen = false;
    @track _pickerSearch = '';
    // Sort rows the user has added but not yet chosen a field for. These can't live
    // in the ORDER BY clause string — an empty column serializes to nothing — so
    // they're held as local UI state until a field is picked.
    _blankSortRows = 0;

    // ── Field picker ────────────────────────────────────────────
    togglePicker() {
        this._pickerOpen = !this._pickerOpen;
        this._pickerSearch = '';
    }

    handlePickerSearch(event) {
        this._pickerSearch = (event.target.value || '').toLowerCase();
    }

    get showPicker() {
        // Auto-open picker when global search matches fields in this node
        if (this._pickerOpen) return true;
        if (this.globalSearch && this.nodeData && this.nodeData.fields) {
            const gs = this.globalSearch;
            return this.nodeData.fields.some(
                (f) => f.displayLabel.toLowerCase().includes(gs) || f.apiName.toLowerCase().includes(gs)
            );
        }
        return false;
    }

    get pickerFields() {
        if (!this.nodeData || !this.nodeData.fields) return [];
        const s = this._pickerSearch || this.globalSearch || '';
        const filtered = this.nodeData.fields.filter(
            (f) => !s || f.displayLabel.toLowerCase().includes(s) || f.apiName.toLowerCase().includes(s)
        );
        // Cap exists to protect the DOM when there's no search; once the user
        // is actively filtering, show every match so nothing is hidden.
        return s ? filtered : filtered.slice(0, 200);
    }

    handlePickerToggleField(event) {
        const apiName = event.currentTarget.dataset.api;
        this.dispatchEvent(
            new CustomEvent('fieldtoggle', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, fieldName: apiName }
            })
        );
    }

    // ── Remove pill ─────────────────────────────────────────────
    handleRemoveField(event) {
        const apiName = event.currentTarget.dataset.api;
        this.dispatchEvent(
            new CustomEvent('fieldtoggle', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, fieldName: apiName }
            })
        );
    }

    // ── Parent lookup expand (from the + parent lookup picker) ───
    // Dispatched as chainPath = relName so docGenTreeBuilder's
    // handleNodeExpandParent uniformly walks the parent chain.
    handleExpandParent(event) {
        const relName = event.currentTarget.dataset.rel;
        this.dispatchEvent(
            new CustomEvent('expandparent', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, chainPath: relName }
            })
        );
    }

    // ── Remove relationship ─────────────────────────────────────
    handleRemoveChild(event) {
        event.preventDefault();
        event.stopPropagation();
        const relName = event.currentTarget.dataset.rel;
        this.dispatchEvent(
            new CustomEvent('removechild', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, relName }
            })
        );
    }

    // ── Child expand ────────────────────────────────────────────
    handleExpandChild(event) {
        const relName = event.currentTarget.dataset.rel;
        this.dispatchEvent(
            new CustomEvent('expandchild', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, relName }
            })
        );
    }

    // ── Clause changes ──────────────────────────────────────────
    handleAliasChange(event) {
        // Strip non-identifier chars to keep merge tags valid ([A-Za-z0-9_]+)
        const cleaned = (event.target.value || '').trim().replace(/[^A-Za-z0-9_]/g, '');
        this.dispatchEvent(
            new CustomEvent('clausechange', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, field: 'alias', value: cleaned }
            })
        );
    }
    handleWhereChange(event) {
        this.dispatchEvent(
            new CustomEvent('clausechange', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, field: 'whereClause', value: event.target.value }
            })
        );
    }
    // ── Multi-column sort ───────────────────────────────────────
    // Storage stays a single SOQL ORDER BY clause string ("Amount DESC, Name ASC").
    // Every Apex consumer already splits that on commas, so multi-column needs no
    // schema change — only an editor that can express more than one column. These
    // handlers parse the clause into rows, mutate one row, and re-serialize.

    handleSortFieldChange(event) {
        const rows = this._sortRowsRaw();
        const i = parseInt(event.target.dataset.index, 10);
        if (i >= rows.length) {
            rows.push({ field: event.detail.value, direction: 'ASC' });
            if (this._blankSortRows > 0) this._blankSortRows -= 1;
        } else {
            rows[i].field = event.detail.value;
        }
        this._emitOrderBy(this._serializeSortRows(rows));
    }

    handleSortDirectionChange(event) {
        const rows = this._sortRowsRaw();
        const i = parseInt(event.target.dataset.index, 10);
        // Direction on a not-yet-chosen column has nothing to attach to; ignore it
        // rather than emitting a clause the user didn't ask for.
        if (i >= rows.length) return;
        rows[i].direction = event.detail.value;
        this._emitOrderBy(this._serializeSortRows(rows));
    }

    handleAddSort() {
        this._blankSortRows += 1;
    }

    handleRemoveSort(event) {
        const rows = this._sortRowsRaw();
        const i = parseInt(event.target.dataset.index, 10);
        if (i >= rows.length) {
            if (this._blankSortRows > 0) this._blankSortRows -= 1;
            return;
        }
        rows.splice(i, 1);
        this._emitOrderBy(this._serializeSortRows(rows));
    }

    handleMoveSortUp(event) {
        const rows = this._sortRowsRaw();
        const i = parseInt(event.target.dataset.index, 10);
        if (i > 0 && i < rows.length) {
            [rows[i - 1], rows[i]] = [rows[i], rows[i - 1]];
            this._emitOrderBy(this._serializeSortRows(rows));
        }
    }

    _emitOrderBy(value) {
        this.dispatchEvent(
            new CustomEvent('clausechange', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, field: 'orderBy', value }
            })
        );
    }

    /**
     * Splits the stored clause into {field, direction} pairs.
     *
     * Anything after the field token is kept verbatim as the direction so clauses
     * the picker can't model (e.g. "NULLS LAST") survive an edit to a sibling row
     * instead of being silently dropped.
     */
    _sortRowsRaw() {
        const clause = this.nodeData && this.nodeData.orderBy ? this.nodeData.orderBy : '';
        if (!clause.trim()) return [];
        return clause
            .split(',')
            .map((part) => part.trim())
            .filter((part) => part)
            .map((part) => {
                const tokens = part.split(/\s+/);
                return {
                    field: tokens[0],
                    direction: tokens.slice(1).join(' ').toUpperCase() || 'ASC'
                };
            });
    }

    _serializeSortRows(rows) {
        return rows
            .filter((r) => r.field)
            .map((r) => `${r.field} ${r.direction || 'ASC'}`.trim())
            .join(', ');
    }
    handleLimitChange(event) {
        this.dispatchEvent(
            new CustomEvent('clausechange', {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive tree node events
                detail: { path: this.nodeData.path, field: 'limitAmount', value: event.target.value }
            })
        );
    }

    // ── Multi-column sort getters ───────────────────────────────

    get sortDirectionOptions() {
        return [
            { label: 'A → Z', value: 'ASC' },
            { label: 'Z → A', value: 'DESC' },
            { label: 'A → Z, blanks last', value: 'ASC NULLS LAST' },
            { label: 'Z → A, blanks last', value: 'DESC NULLS LAST' }
        ];
    }

    /**
     * Every field on this node, whether or not it's selected for output — you can
     * legitimately sort by a column you don't render.
     */
    get sortFieldOptions() {
        if (!this.nodeData || !this.nodeData.fields) return [];
        return this.nodeData.fields
            .map((f) => ({ label: f.displayLabel || f.apiName, value: f.apiName }))
            .sort((a, b) => a.label.localeCompare(b.label));
    }

    get sortRows() {
        const options = this.sortFieldOptions;
        const known = new Set(options.map((o) => o.value));
        const rows = this._sortRowsRaw();
        for (let n = 0; n < this._blankSortRows; n++) {
            rows.push({ field: '', direction: 'ASC' });
        }
        const directions = this.sortDirectionOptions.map((d) => d.value);
        return rows.map((r, i) => {
            // A hand-authored clause may reference a relationship field (Product2.Name)
            // or a field not in this node's list. Surface it as its own option rather
            // than letting the combobox render blank and lose it on the next save.
            const fieldOptions =
                known.has(r.field) || !r.field ? options : [{ label: r.field, value: r.field }, ...options];
            const directionOptions = directions.includes(r.direction)
                ? this.sortDirectionOptions
                : [{ label: r.direction, value: r.direction }, ...this.sortDirectionOptions];
            return {
                key: `sort-${i}`,
                index: i,
                field: r.field,
                direction: r.direction,
                fieldOptions,
                directionOptions,
                isFirst: i === 0,
                positionLabel: i === 0 ? 'Sort by' : 'then by',
                removeLabel: `Remove sort column ${i + 1}`,
                moveUpLabel: `Move sort column ${i + 1} earlier`
            };
        });
    }

    get hasSortRows() {
        return this.sortRows.length > 0;
    }

    // ── Template getters ────────────────────────────────────────
    get selectedFields() {
        if (!this.nodeData || !this.nodeData.fields) return [];
        return this.nodeData.fields
            .filter((f) => f.checked)
            .map((f) => ({
                ...f,
                removeLabel: 'Remove field ' + (f.displayLabel || f.apiName)
            }));
    }

    get hasSelectedFields() {
        return this.selectedFields.length > 0;
    }

    get selectedFieldCount() {
        return this.selectedFields.length;
    }

    get parentRels() {
        if (!this.nodeData || !this.nodeData.parentRels) return [];
        return this.nodeData.parentRels;
    }

    get childRels() {
        if (!this.nodeData || !this.nodeData.childRels) return [];
        return this.nodeData.childRels;
    }

    get isChild() {
        return this.nodeData && this.nodeData.isChild;
    }

    get indentStyle() {
        const px = this.depth > 0 ? 16 : 0;
        return 'padding-left: ' + px + 'px;';
    }

    // ── A11y identifiers + labels ───────────────────────────────
    // path strings can contain dots and colons (e.g. "Account.child:Contacts");
    // sanitize for use as DOM ids referenced by aria-controls / aria-labelledby.
    get _safePath() {
        const p = this.nodeData && this.nodeData.path ? this.nodeData.path : 'root';
        return p.replace(/[^A-Za-z0-9_-]/g, '-');
    }
    get headingId() {
        return 'dgt-h-' + this._safePath;
    }
    get fieldPickerId() {
        return 'dgt-fp-' + this._safePath;
    }
    get relPickerId() {
        return 'dgt-rp-' + this._safePath;
    }
    get parentPickerId() {
        return 'dgt-pp-' + this._safePath;
    }
    get nodeAccessibleHeading() {
        if (!this.nodeData) return '';
        const obj = this.nodeData.objectLabel || this.nodeData.objectName || 'Object';
        const cnt = this.selectedFields.length;
        const depth = this.depth || 0;
        const parts = [obj + ' fields'];
        if (depth > 0) parts.push('depth ' + depth);
        if (cnt > 0) parts.push(cnt + ' selected');
        return parts.join(', ');
    }

    get nodeAlias() {
        return this.nodeData ? this.nodeData.alias || '' : '';
    }
    get nodeWhereClause() {
        return this.nodeData ? this.nodeData.whereClause || '' : '';
    }
    get nodeOrderBy() {
        return this.nodeData ? this.nodeData.orderBy || '' : '';
    }
    get nodeLimitAmount() {
        return this.nodeData ? this.nodeData.limitAmount || '' : '';
    }

    // Host path passed down to <c-doc-gen-parent-rel>. The recursive parent
    // component identifies leaves by `chainPath` relative to this nodePath.
    get nodePathForChildren() {
        return this.nodeData ? this.nodeData.path : '';
    }

    // Surface parent rels for the template. Multi-hop rendering happens
    // inside <c-doc-gen-parent-rel> — this just filters by global search and
    // by selection state. Recursion-aware: a parent with no own selections
    // but selections deeper down still renders.
    get parentRelsList() {
        if (!this.nodeData || !this.nodeData.parentRels) return [];
        const gs = this.globalSearch;
        return this.nodeData.parentRels.filter(
            (pr) => !gs || pr.expanded || this._matchesSearch(pr, gs) || this._hasAnyCheckedDeep(pr)
        );
    }

    _hasAnyCheckedDeep(pr) {
        if (!pr) return false;
        if (pr.fields && pr.fields.some((f) => f.checked)) return true;
        if (pr.parentRels) {
            for (const np of pr.parentRels) {
                if (this._hasAnyCheckedDeep(np)) return true;
            }
        }
        return false;
    }

    // Bubble passthroughs — events from <c-doc-gen-parent-rel> are
    // composed: true and already reach docGenTreeBuilder. Handlers exist so
    // the LWC compiler doesn't warn about unbound listeners.
    handleParentRelExpandBubble() {}
    handleParentRelFieldToggleBubble() {}
    handleParentRelRemoveBubble() {}

    // ── Relationship pickers ───────────────────────────────────
    @track _relPickerOpen = false;
    @track _relPickerSearch = '';
    @track _parentRelPickerOpen = false;
    @track _parentRelPickerSearch = '';

    toggleRelPicker() {
        this._relPickerOpen = !this._relPickerOpen;
        this._relPickerSearch = '';
        this._parentRelPickerOpen = false;
    }

    toggleParentPicker() {
        this._parentRelPickerOpen = !this._parentRelPickerOpen;
        this._parentRelPickerSearch = '';
        this._relPickerOpen = false;
    }

    handleRelPickerSearch(event) {
        this._relPickerSearch = (event.target.value || '').toLowerCase();
    }

    handleParentRelPickerSearch(event) {
        this._parentRelPickerSearch = (event.target.value || '').toLowerCase();
    }

    get showRelPicker() {
        return this._relPickerOpen;
    }
    get showParentPicker() {
        return this._parentRelPickerOpen;
    }

    get filteredChildRels() {
        if (!this.nodeData || !this.nodeData.childRels) return [];
        const s = this._relPickerSearch;
        // Dedupe by relationship value so each appears once in the picker.
        // We always show every relationship (even ones already expanded) —
        // clicking again creates a filtered-subset slot rather than toggling
        // the existing one.
        const seen = new Set();
        const filtered = this.nodeData.childRels
            .filter((cr) => {
                if (seen.has(cr.value)) return false;
                seen.add(cr.value);
                return true;
            })
            .filter((cr) => !s || cr.displayLabel.toLowerCase().includes(s) || cr.value.toLowerCase().includes(s));
        // Cap protects the DOM when unfiltered; with a search term the user
        // is actively narrowing, so show every match.
        return s ? filtered : filtered.slice(0, 100);
    }

    get filteredParentRels() {
        if (!this.nodeData || !this.nodeData.parentRels) return [];
        const s = this._parentRelPickerSearch;
        const filtered = this.nodeData.parentRels
            .filter((pr) => !pr.expanded)
            .filter((pr) => !s || pr.displayLabel.toLowerCase().includes(s) || pr.value.toLowerCase().includes(s));
        return s ? filtered : filtered.slice(0, 100);
    }

    handleExpandChildFromPicker(event) {
        this._relPickerOpen = false;
        this.handleExpandChild(event);
    }

    handleExpandParentFromPicker(event) {
        this._parentRelPickerOpen = false;
        this.handleExpandParent(event);
    }

    // Active rels (expanded or with any selection deeper down)
    get activeParentRels() {
        return this.parentRelsList.filter((pr) => pr.expanded || this._hasAnyCheckedDeep(pr));
    }

    get activeChildRels() {
        if (!this.nodeData || !this.nodeData.childRels) return [];
        return this.nodeData.childRels.filter((cr) => cr.expanded);
    }

    _matchesSearch(rel, search) {
        return (
            (rel.displayLabel && rel.displayLabel.toLowerCase().includes(search)) ||
            (rel.value && rel.value.toLowerCase().includes(search)) ||
            (rel.label && rel.label.toLowerCase().includes(search))
        );
    }

    // Child rel data for template — filtered by global search.
    // Each rendered entry gets a unique `slotKey` (= _slotKey for filtered
    // subsets, else cr.value) used as the LWC list key and as the data-rel
    // discriminator for slot-aware operations like remove.
    get childRels() {
        if (!this.nodeData || !this.nodeData.childRels) return [];
        const gs = this.globalSearch;
        return this.nodeData.childRels
            .filter((cr) => !gs || cr.expanded || this._matchesSearch(cr, gs))
            .map((cr) => {
                const count = cr.nodeData ? this._countNodeFields(cr.nodeData) : 0;
                const crLabel = cr.displayLabel || cr.value;
                return {
                    ...cr,
                    slotKey: cr._slotKey || cr.value,
                    hasSelectedCount: count > 0,
                    selectedCount: count,
                    nextDepth: parseInt(this.depth, 10) + 1,
                    icon: cr.expanded ? 'utility:chevrondown' : 'utility:chevronright',
                    removeLabel: 'Remove related list ' + crLabel
                };
            });
    }

    _countNodeFields(nd) {
        if (!nd) return 0;
        let c = 0;
        if (nd.fields) {
            for (const f of nd.fields) {
                if (f.checked) c++;
            }
        }
        if (nd.parentRels) {
            for (const pr of nd.parentRels) {
                c += this._countParentRelFields(pr);
            }
        }
        return c;
    }

    _countParentRelFields(pr) {
        let c = 0;
        if (!pr) return 0;
        if (pr.fields) {
            for (const f of pr.fields) {
                if (f.checked) c++;
            }
        }
        if (pr.parentRels) {
            for (const np of pr.parentRels) {
                c += this._countParentRelFields(np);
            }
        }
        return c;
    }

    // Bubble handlers (events from nested child nodes just pass through via composed)
    handleChildFieldBubble() {}
    handleChildParentFieldBubble() {}
    handleChildExpandBubble() {}
    handleChildParentExpandBubble() {}
    handleChildClauseBubble() {}
    handleChildRemoveChildBubble() {}
    handleChildRemoveParentBubble() {}

    // Hover effect
    _hoverIn(event) {
        event.currentTarget.style.backgroundColor = '#f5f5f5';
    }
    _hoverOut(event) {
        event.currentTarget.style.backgroundColor = '';
    }
}
