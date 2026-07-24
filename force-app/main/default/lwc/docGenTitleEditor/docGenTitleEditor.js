import { LightningElement, api, track } from 'lwc';

/**
 * #237 — built-in tokens DocGenService.generateDocTitle resolves that are NOT
 * SObject fields, so they never appear in the Query Config and were previously
 * undiscoverable. See DocGenService.cls:8719-8728.
 *
 * The formatted variants are listed first deliberately: a bare {Now} falls through
 * to String.valueOf(), which renders a DateTime in GMT, while any format suffix goes
 * through DateTime.format() and uses the running user's timezone.
 */
const BUILT_IN_TOKENS = [
    'Today:yyyy-MM-dd',
    'Today:MMMM d, yyyy',
    'Today:MM-dd-yyyy',
    'Today',
    'Now:yyyy-MM-dd HH-mm',
    'Now:h:mm a',
    'Now',
    'RunningUser.Name',
    'RunningUser.Email',
    'RunningUser.Alias'
];

export default class DocGenTitleEditor extends LightningElement {
    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val;
    }
    @track _value = '';

    @api queryConfig = '';

    @track showSuggestions = false;
    @track suggestions = [];

    // Internal state for tokenizer
    cursorPos = 0;

    handleInput(event) {
        this._value = event.detail.value;
        this.notifyChange();

        // Simple Logic: check if the last token being typed starts with {
        // We find the last '{' before cursor.
        // Actually, lightning-input doesn't give cursor position easily in onchange event detail,
        // but we can try to guess or use basic substring.
        // Better: Use the Input Element to get cursor.

        // Note: LWC lightning-input doesn't expose selectionStart directly easily in all versions,
        // but usually we can check value logic.
        // Let's assume user is typing at end or we check the whole string for an open brace without close brace at the end?

        // Robust strategy: Check if value ends with `{` or `{partial`.
        // We will regex search for `\{[a-zA-Z0-9_\.]*$`

        const text = this._value;
        const match = text.match(/\{([a-zA-Z0-9_.]*$)/);

        if (match) {
            const keys = this.parseFields();
            const term = match[1].toLowerCase();

            this.suggestions = keys.filter((k) => k.toLowerCase().includes(term));
            this.showSuggestions = true;
        } else {
            this.showSuggestions = false;
        }
    }

    handleFocus() {
        // Optional: show suggestions if cursor at end of { ?
    }

    handleBlur() {
        // Delay hide to allow click
        // But mousedown on dropdown prevents blur usually if we handle it right.
        // We'll use a timeout or check relatedTarget.
        setTimeout(() => {
            this.showSuggestions = false;
        }, 200);
    }

    handleDropdownMouseDown(event) {
        // Prevent blur
        event.preventDefault();
    }

    handleSelectSuggestion(event) {
        const fieldName = event.currentTarget.dataset.value;

        // Replace the last match
        // We know it ends with `{partial`
        const text = this._value;
        const lastBraceIndex = text.lastIndexOf('{');
        if (lastBraceIndex >= 0) {
            const prefix = text.substring(0, lastBraceIndex);
            // We replace everything after last brace
            this._value = prefix + '{' + fieldName + '}';
            this.notifyChange();
        }

        this.showSuggestions = false;

        // Refocus (though we might have lost it)
        // this.template.querySelector('lightning-input').focus();
        // focus() might fail if not rendered or timing.
    }

    notifyChange() {
        this.dispatchEvent(
            new CustomEvent('change', {
                detail: { value: this._value }
            })
        );
    }

    parseFields() {
        // #237 — built-ins first: they are always valid regardless of Query Config,
        // and they are the ones authors did not know existed.
        const builtIns = [...BUILT_IN_TOKENS];
        if (!this.queryConfig) return builtIns;

        // Basic parser: Split by comma, ignore subqueries `(SELECT ...)`
        // 1. Remove subqueries
        const clean = this.queryConfig.replace(/\(SELECT.*?\)/gi, '');

        // 2. Split
        const tokens = clean.split(',');

        // 3. Trim and Filter
        const fields = tokens.map((t) => t.trim()).filter((t) => t && !t.startsWith('(')); // Double check

        return builtIns.concat(fields);
    }

    /** One-click example formats, shown under the input. */
    get exampleChips() {
        return [
            { key: 'ex1', value: '{Name}_{Today:yyyy-MM-dd}' },
            { key: 'ex2', value: 'Invoice_{Name}_{Today:MMMM d, yyyy}' },
            { key: 'ex3', value: '{Name} - signed {Now:yyyy-MM-dd HH-mm}' }
        ];
    }

    handleExampleClick(event) {
        this._value = event.currentTarget.dataset.value;
        this.notifyChange();
        this.showSuggestions = false;
    }

    get hasSuggestions() {
        return this.suggestions && this.suggestions.length > 0;
    }
}
