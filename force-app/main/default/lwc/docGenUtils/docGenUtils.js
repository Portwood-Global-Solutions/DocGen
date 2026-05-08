/**
 * Shared utility functions for DocGen LWC components.
 * Consolidates duplicated logic (download, filter parsing) into one module.
 */

/**
 * Downloads a base64-encoded file via a temporary anchor element.
 *
 * @param {string} base64Data - The base64-encoded file content
 * @param {string} fileName   - The download filename (including extension)
 * @param {string} mimeType   - The MIME type (e.g. 'application/pdf')
 */
export function downloadBase64(base64Data, fileName, mimeType) {
    const binaryString = atob(base64Data);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    const blob = new Blob([bytes], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

/**
 * Converts a Query_Config__c JSON's report filters or bulkWhereClause
 * into a SOQL WHERE clause string.
 *
 * @param {string} queryConfigJson - Raw Query_Config__c value (JSON string)
 * @returns {string|null} The WHERE clause, or null if none could be derived
 */
export function extractWhereClause(queryConfigJson) {
    if (!queryConfigJson) return null;

    try {
        const config = JSON.parse(queryConfigJson);

        if (config.bulkWhereClause) {
            return config.bulkWhereClause;
        }

        if (config.reportFilters && config.reportFilters.length > 0) {
            const DATE_LITERALS = [
                'TODAY','YESTERDAY','TOMORROW',
                'LAST_WEEK','THIS_WEEK','NEXT_WEEK',
                'LAST_MONTH','THIS_MONTH','NEXT_MONTH',
                'LAST_QUARTER','THIS_QUARTER','NEXT_QUARTER',
                'LAST_YEAR','THIS_YEAR','NEXT_YEAR',
                'LAST_90_DAYS','NEXT_90_DAYS'
            ];

            const parts = config.reportFilters.map(f => {
                if (f.operator === 'LIKE') {
                    return f.field + " LIKE '%" + f.value + "%'";
                }
                if (f.operator === 'IN' || f.operator === 'NOT IN') {
                    const vals = f.value.split(',').map(v => "'" + v.trim() + "'").join(', ');
                    return f.field + ' ' + f.operator + ' (' + vals + ')';
                }

                let v = f.value.trim();
                const upper = v.toUpperCase();

                // Date-only value on a datetime field: append time component
                const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(v);
                const isDateTimeField = f.field &&
                    (f.field.toLowerCase().includes('date') || f.field.toLowerCase().includes('time')) &&
                    !f.field.toLowerCase().endsWith('__c');
                if (isDateOnly && isDateTimeField) {
                    v = v + 'T00:00:00Z';
                }

                if (
                    DATE_LITERALS.includes(upper) ||
                    upper.startsWith('LAST_N_') ||
                    upper.startsWith('NEXT_N_') ||
                    /^\d+\.?\d*$/.test(v) ||
                    /^\d{4}-\d{2}-\d{2}/.test(v) ||
                    upper === 'TRUE' ||
                    upper === 'FALSE' ||
                    upper === 'NULL'
                ) {
                    return f.field + ' ' + f.operator + ' ' + v;
                }

                return f.field + " " + f.operator + " '" + f.value + "'";
            });

            return parts.join(' AND ');
        }
    } catch {
        // Not JSON or malformed — that's fine
    }

    return null;
}
