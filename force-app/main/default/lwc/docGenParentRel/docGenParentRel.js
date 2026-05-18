import { LightningElement, api, track } from 'lwc';

/**
 * Recursive renderer for a single parent-lookup relationship in the visual
 * query builder. Self-references for nested lookups so chains like
 * Account.Parent.Parent.OwnerId can be authored entirely in the UI.
 *
 * Owns no data of its own — every action dispatches a composed event up to
 * docGenTreeBuilder, identifying the leaf by `nodePath` (the host tree node)
 * and `chainPath` (dotted parent chain from the host node, e.g.
 * "Owner.Manager").
 *
 * Cap: 5 hops total (SOQL native limit). Beyond depth 5 the "+ chain through
 * another lookup" affordance disables.
 */
const MAX_PARENT_CHAIN_HOPS = 5;

export default class DocGenParentRel extends LightningElement {
    @api parentRel; // { value, chainPath, displayLabel, label, targetObject, icon, expanded, fields, parentRels }
    @api nodePath; // host tree node path (e.g. "root" or "root.child:Contacts")
    @api globalSearch = '';

    @track _fieldSearch = '';
    @track _chainPickerOpen = false;
    @track _chainPickerSearch = '';

    // ── Derived getters ─────────────────────────────────────────
    get chainPath() {
        return this.parentRel ? this.parentRel.chainPath || this.parentRel.value : '';
    }

    get chainDepth() {
        // Number of dots + 1 == hop count (e.g. "Owner" = 1, "Owner.Manager" = 2).
        const cp = this.chainPath;
        if (!cp) return 1;
        return cp.split('.').length;
    }

    get canChainDeeper() {
        return this.chainDepth < MAX_PARENT_CHAIN_HOPS;
    }

    get displayLabel() {
        return this.parentRel ? this.parentRel.displayLabel || this.parentRel.value : '';
    }

    get value() {
        return this.parentRel ? this.parentRel.value : '';
    }

    get icon() {
        if (!this.parentRel) return 'utility:chevronright';
        return this.parentRel.expanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get removeLabel() {
        return 'Remove parent lookup ' + (this.displayLabel || this.value);
    }

    get fieldSearchAriaLabel() {
        return 'Search fields on ' + (this.displayLabel || this.value);
    }

    get expanded() {
        return !!(this.parentRel && this.parentRel.expanded);
    }

    get selectedFields() {
        if (!this.parentRel || !this.parentRel.fields) return [];
        const prLabel = this.displayLabel || this.value;
        const cp = this.chainPath;
        const prefix = cp.split('.').join(' › ');
        return this.parentRel.fields
            .filter((f) => f.checked)
            .map((f) => ({
                ...f,
                key: cp + '.' + f.apiName,
                fullPath: cp + '.' + f.apiName,
                chainPrefix: prefix,
                removeLabel: 'Remove ' + prLabel + ' ' + (f.displayLabel || f.apiName)
            }));
    }

    get hasSelectedFields() {
        return this.selectedFields.length > 0;
    }

    get pickerFields() {
        if (!this.parentRel || !this.parentRel.fields) return [];
        const s = (this._fieldSearch || this.globalSearch || '').toLowerCase();
        const all = this.parentRel.fields;
        const filtered = s
            ? all.filter(
                  (f) =>
                      (f.displayLabel && f.displayLabel.toLowerCase().includes(s)) ||
                      (f.apiName && f.apiName.toLowerCase().includes(s))
              )
            : all;
        return s ? filtered : filtered.slice(0, 200);
    }

    get fieldSearchValue() {
        return this._fieldSearch;
    }

    // Nested parent rels — render only those expanded (or with selections
    // deeper down). The remainder are surfaced through the chain picker.
    get activeNestedParentRels() {
        if (!this.parentRel || !this.parentRel.parentRels) return [];
        return this.parentRel.parentRels.filter((np) => np.expanded || this._hasAnyCheckedDeep(np));
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

    get nestedAvailableParentRels() {
        if (!this.parentRel || !this.parentRel.parentRels) return [];
        const s = (this._chainPickerSearch || '').toLowerCase();
        const filtered = this.parentRel.parentRels
            .filter((np) => !np.expanded)
            .filter(
                (np) =>
                    !s ||
                    (np.displayLabel && np.displayLabel.toLowerCase().includes(s)) ||
                    (np.value && np.value.toLowerCase().includes(s))
            );
        return s ? filtered : filtered.slice(0, 100);
    }

    get showChainPicker() {
        return this._chainPickerOpen;
    }

    get chainPickerSearchValue() {
        return this._chainPickerSearch;
    }

    get chainPickerId() {
        return 'dgpr-cp-' + (this.chainPath || 'root').replace(/[^A-Za-z0-9_-]/g, '-');
    }

    // ── Event handlers ──────────────────────────────────────────
    handleExpandToggle() {
        this._dispatch('expandparent', { chainPath: this.chainPath });
    }

    handleRemove(event) {
        event.preventDefault();
        event.stopPropagation();
        this._dispatch('removeparent', { chainPath: this.chainPath });
    }

    handleFieldSearch(event) {
        this._fieldSearch = (event.target.value || '').toLowerCase();
    }

    handleFieldToggle(event) {
        const apiName = event.currentTarget.dataset.api;
        this._dispatch('parentfieldtoggle', { chainPath: this.chainPath, fieldName: apiName });
    }

    handleRemoveSelectedField(event) {
        const apiName = event.currentTarget.dataset.api;
        this._dispatch('parentfieldtoggle', { chainPath: this.chainPath, fieldName: apiName });
    }

    toggleChainPicker() {
        if (!this.canChainDeeper) return;
        this._chainPickerOpen = !this._chainPickerOpen;
        this._chainPickerSearch = '';
    }

    handleChainPickerSearch(event) {
        this._chainPickerSearch = (event.target.value || '').toLowerCase();
    }

    handlePickNestedParent(event) {
        const value = event.currentTarget.dataset.rel;
        this._chainPickerOpen = false;
        // Expanding a nested pr uses the same path: chainPath of THIS rel
        // suffixed with the new segment.
        const nestedChain = this.chainPath + '.' + value;
        this._dispatch('expandparent', { chainPath: nestedChain });
    }

    // Nested events bubble from <c-doc-gen-parent-rel> children — handlers
    // are no-ops; events are already `composed: true` and propagate to the
    // host tree node and on up to the builder.
    handleNestedExpand() {}
    handleNestedFieldToggle() {}
    handleNestedRemove() {}

    _dispatch(name, detailExtra) {
        this.dispatchEvent(
            new CustomEvent(name, {
                bubbles: true,
                composed: true, // NOPMD — composed required for recursive parent-rel events
                detail: { path: this.nodePath, ...detailExtra }
            })
        );
    }
}
