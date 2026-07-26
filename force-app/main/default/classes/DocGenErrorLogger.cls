public without sharing class DocGenErrorLogger { // NOPMD AvoidPublicWithoutSharing — logging must survive caller sharing/FLS failures
    @TestVisible
    private static Boolean forceFailureForTest = false;

    public class Entry {
        public String severity = 'Error';
        public String context;
        public String operation;
        public Exception cause;
        public String message;
        public String additionalInfo;
        public Id templateId;
        public String recordId;
        public Id jobId;
        public String flowInterviewGuid;
    }

    /**
     * DEGRADATION BUFFER.
     *
     * The events worth recording most — an image that could not be resolved, a
     * chart that came back empty, a snapshot that fell back — happen INSIDE
     * per-row loops. Inserting one row per occurrence would spend the 150-DML
     * limit on diagnostics and break generation that currently works, so
     * warnings are buffered, de-duplicated and written in a single DML by
     * flush().
     *
     * Deduplicated by context+operation+message: 2,000 rows each skipping the
     * same broken image is ONE fact, and 2,000 identical log rows would bury it.
     * The occurrence count is kept and reported instead.
     */
    private static final Integer MAX_BUFFERED = 25;
    private static Map<String, Entry> buffered = new Map<String, Entry>();
    private static Map<String, Integer> bufferedCounts = new Map<String, Integer>();

    /**
     * Record a SUCCESSFUL-BUT-DEGRADED outcome: the operation continued with a
     * fallback, so the caller sees no error, but the document is not what the
     * author asked for. This is DocGen's characteristic failure — output that is
     * wrong rather than absent — and until now it left no trace at all.
     *
     * Never throws, never inserts on its own. Call flush() at the end of the
     * transaction to persist.
     */
    public static void warn(String context, String operation, String message, Id templateId, String recordId) {
        try {
            String key = context + '|' + operation + '|' + message;
            if (bufferedCounts.containsKey(key)) {
                bufferedCounts.put(key, bufferedCounts.get(key) + 1);
                return;
            }
            if (buffered.size() >= MAX_BUFFERED) {
                return; // a pathological template must not turn into unbounded logging
            }
            Entry e = new Entry();
            e.severity = 'Warning';
            e.context = context;
            e.operation = operation;
            e.message = message;
            e.templateId = templateId;
            e.recordId = recordId;
            buffered.put(key, e);
            bufferedCounts.put(key, 1);
        } catch (Exception ignored) {
            // Diagnostics must never be able to break the thing they observe.
            String noop = ignored.getMessage(); // NOPMD UnusedLocalVariable
        }
    }

    public static void warn(String context, String operation, String message) {
        warn(context, operation, message, null, null);
    }

    /** Persist everything buffered this transaction. Safe to call more than once. */
    public static void flush() {
        try {
            if (buffered.isEmpty()) {
                return;
            }
            List<DocGen_Error_Log__c> rows = new List<DocGen_Error_Log__c>();
            for (String key : buffered.keySet()) {
                Entry e = buffered.get(key);
                Integer n = bufferedCounts.get(key);
                if (n != null && n > 1) {
                    // The count is the useful part: "1 image failed" and "every
                    // image failed" are different problems with the same message.
                    e.additionalInfo = 'occurrences=' + n;
                }
                rows.add(buildRow(e));
            }
            buffered = new Map<String, Entry>();
            bufferedCounts = new Map<String, Integer>();
            /* code-analyzer-suppress ApexFlsViolation */
            Database.insert(rows, false); // internal diagnostics; partial success is fine
        } catch (Exception ignored) {
            String noop = ignored.getMessage(); // NOPMD UnusedLocalVariable
        }
    }

    @TestVisible
    private static Integer bufferedCount() {
        return buffered.size();
    }

    public static void log(String context, Exception cause) {
        Entry entry = new Entry();
        entry.context = context;
        entry.cause = cause;
        log(entry);
    }

    public static void logTemplatePickerFailure(Exception cause, String objectApiName, String recordId) {
        Entry entry = new Entry();
        entry.context = 'DocGenController';
        entry.operation = 'Load templates for runner';
        entry.cause = cause;
        entry.recordId = recordId;
        entry.additionalInfo = 'objectApiName=' + safeValue(objectApiName);
        log(entry);
    }

    public static void logBulkFlowFailure(Exception cause, Id templateId, String effectiveCondition, String jobLabel) {
        Entry entry = new Entry();
        entry.context = 'DocGenBulkFlowAction';
        entry.operation = 'Generate Bulk Documents';
        entry.cause = cause;
        entry.templateId = templateId;
        entry.additionalInfo =
            'jobLabel=' +
            safeValue(jobLabel) +
            '\ncondition=' +
            truncate(safeValue(effectiveCondition), 4000);
        log(entry);
    }

    public static void log(Entry entry) {
        try {
            if (forceFailureForTest) {
                throw new DocGenException('Forced logger failure');
            }
            if (entry == null) {
                return;
            }

            /* code-analyzer-suppress ApexFlsViolation */
            Database.insert(buildRow(entry), false); // internal diagnostics; never require caller create-FLS on log fields
        } catch (Exception ignored) {
            String noop = ignored.getMessage(); // NOPMD UnusedLocalVariable
        }
    }

    /** One place that maps an Entry onto the object, shared by log() and flush(). */
    private static DocGen_Error_Log__c buildRow(Entry entry) {
        Exception cause = entry.cause;
        String message = String.isNotBlank(entry.message) ? entry.message : cause == null ? null : cause.getMessage();
        return new DocGen_Error_Log__c(
            Severity__c = normalizeSeverity(entry.severity),
            Context__c = truncate(entry.context, 255),
            Operation__c = truncate(entry.operation, 255),
            Exception_Type__c = truncate(simpleExceptionType(cause), 255),
            Message__c = truncate(message, 32768),
            Stack_Trace__c = truncate(cause == null ? null : cause.getStackTraceString(), 32768),
            Additional_Info__c = truncate(entry.additionalInfo, 32768),
            User_Id__c = truncate(String.valueOf(UserInfo.getUserId()), 18),
            Template_Id__c = truncate(idToString(entry.templateId), 18),
            Record_Id__c = truncate(entry.recordId, 18),
            Job_Id__c = truncate(idToString(entry.jobId), 18),
            Flow_Interview_Guid__c = truncate(entry.flowInterviewGuid, 255)
        );
    }

    private static String normalizeSeverity(String value) {
        if (value == 'Warning' || value == 'Info') {
            return value;
        }
        return 'Error';
    }

    private static String idToString(Id value) {
        return value == null ? null : String.valueOf(value);
    }

    private static String safeValue(String value) {
        return String.isBlank(value) ? '' : value;
    }

    private static String simpleExceptionType(Exception cause) {
        if (cause == null) {
            return null;
        }
        String typeName = cause.getTypeName();
        return typeName != null && typeName.contains('.') ? typeName.substringAfterLast('.') : typeName;
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || maxLength == null || maxLength <= 0 || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
