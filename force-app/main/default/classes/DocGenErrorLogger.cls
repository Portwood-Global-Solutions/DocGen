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

            Exception cause = entry.cause;
            String message = String.isNotBlank(entry.message)
                ? entry.message
                : cause == null ? null : cause.getMessage();

            DocGen_Error_Log__c row = new DocGen_Error_Log__c(
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
            /* code-analyzer-suppress ApexFlsViolation */
            Database.insert(row, false); // internal diagnostics; never require caller create-FLS on log fields
        } catch (Exception ignored) {
            String noop = ignored.getMessage(); // NOPMD UnusedLocalVariable
        }
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
