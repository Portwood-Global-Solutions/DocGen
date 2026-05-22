/**
 * Issue #66 — loads Classic Approval history for a record and exposes it as a
 * standard DocGen merge-data list, so template authors can use:
 *
 *   {#Approvals}
 *     {ActorName} ({ActorTitle}) — {StepStatus} — {CreatedDate}
 *     Comments: {Comments}
 *   {/Approvals}
 *
 * The list aggregates ProcessInstanceStep rows across ALL ProcessInstances on
 * the record (records can be submitted, rejected, and resubmitted), sorted
 * earliest-first. Includes the initial "Started" step (submission) and each
 * subsequent approval/rejection. Pending steps (ProcessInstanceWorkitem) are
 * NOT included — only steps that have been acted on.
 *
 * Trigger: this helper runs only when the template's Query_Config__c includes
 * the token `Approvals` as a standalone word (case-sensitive, like other merge
 * keys). That opt-in design avoids accidental name collision with a custom
 * `Approvals__c` field on the host object and prevents one SOQL per generation
 * on templates that don't need approval history.
 *
 * Schema notes (see issue #67 prior art): ProcessInstanceStep is NOT
 * standalone-queryable. It must be accessed via the parent ProcessInstance's
 * Steps relationship subquery, which this class does.
 */
public with sharing class DocGenApprovalHistory {
    private static final Pattern APPROVALS_TOKEN = Pattern.compile('(?i)(^|[^A-Za-z_])Approvals([^A-Za-z_]|$)');

    /**
     * Returns true when the template's Query_Config__c opts in to approval
     * history by mentioning `Approvals` as a standalone token. Case-insensitive
     * to be forgiving; word-boundary so `MyApprovalsList` won't false-positive.
     */
    public static Boolean queryConfigMentionsApprovals(String queryConfig) {
        if (String.isBlank(queryConfig)) {
            return false;
        }
        return APPROVALS_TOKEN.matcher(queryConfig).find();
    }

    /**
     * Loads approval history for the record. Returns a data-map-shaped result:
     *   { 'records' => List<Map<String, Object>>, 'totalSize' => Integer }
     * Each row in `records` carries one step's fields. Safe to inject directly
     * into the merge data map at the key `Approvals`.
     */
    public static Map<String, Object> load(Id recordId) {
        List<Object> rows = new List<Object>();
        if (recordId == null) {
            return new Map<String, Object>{ 'records' => rows, 'totalSize' => 0 };
        }
        try {
            // v2.0.1 — per-field FLS enforcement on SOQL reads (the "Apex SOQL
            // USER_MODE Missing" finding category). DocGenFlsGuard.assertAccessible
            // calls Schema.SObjectField.getDescribe().isAccessible() on every field
            // the SELECT lists; throws DocGenException with the offending field name
            // before any query runs. SYSTEM_MODE on the SOQL sidesteps the
            // package-build @TestSetup FLS-propagation issue documented in
            // DocGenFlsGuard.cls.
            DocGenFlsGuard.assertAccessible(
                ProcessInstance.sObjectType,
                new Set<String>{ 'Status', 'CreatedDate', 'SubmittedById', 'TargetObjectId' }
            );
            /* code-analyzer-suppress ApexFlsViolation */
            List<ProcessInstance> instances = [
                SELECT
                    Id,
                    Status,
                    CreatedDate,
                    SubmittedBy.Name,
                    SubmittedBy.Title,
                    (
                        SELECT
                            Id,
                            StepStatus,
                            ActorId,
                            Actor.Name,
                            Actor.Title,
                            Actor.Email,
                            OriginalActorId,
                            OriginalActor.Name,
                            Comments,
                            CreatedDate
                        FROM Steps
                        ORDER BY CreatedDate ASC
                    )
                FROM ProcessInstance
                WHERE TargetObjectId = :recordId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
            ];

            for (ProcessInstance pi : instances) {
                String submittedByName = pi.SubmittedBy != null ? pi.SubmittedBy.Name : '';
                String submittedByTitle = pi.SubmittedBy != null &&
                    pi.SubmittedBy.Title != null
                    ? pi.SubmittedBy.Title
                    : '';
                for (ProcessInstanceStep step : pi.Steps) {
                    String actorName = step.Actor != null && step.Actor.Name != null ? step.Actor.Name : '';
                    String actorTitle = step.Actor != null && step.Actor.Title != null ? step.Actor.Title : '';
                    String actorEmail = step.Actor != null && step.Actor.Email != null ? step.Actor.Email : '';
                    String origActorName = step.OriginalActor != null &&
                        step.OriginalActor.Name != null
                        ? step.OriginalActor.Name
                        : '';
                    String comments = step.Comments != null ? step.Comments : '';
                    rows.add(
                        new Map<String, Object>{
                            'ActorName' => actorName,
                            'ActorTitle' => actorTitle,
                            'ActorEmail' => actorEmail,
                            'OriginalActorName' => origActorName,
                            'StepStatus' => step.StepStatus,
                            'Comments' => comments,
                            'CreatedDate' => step.CreatedDate,
                            'ProcessStatus' => pi.Status,
                            'SubmittedByName' => submittedByName,
                            'SubmittedByTitle' => submittedByTitle
                        }
                    );
                }
            }
        } catch (Exception e) {
            // Best-effort. If ProcessInstance access is restricted or the
            // record's object doesn't support approvals, return empty rather
            // than blowing up document generation.
            System.debug(LoggingLevel.WARN, 'DocGenApprovalHistory.load failed: ' + e.getMessage());
        }
        return new Map<String, Object>{ 'records' => rows, 'totalSize' => rows.size() };
    }
}
