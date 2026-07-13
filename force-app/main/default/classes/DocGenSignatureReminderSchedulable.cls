/**
 * Schedulable class that sends reminder emails to pending signers.
 * Runs on a schedule (e.g., hourly) and checks each pending signer against the
 * org-wide reminder schedule (DocGen_Settings__c.Signature_Reminder_Schedule__c,
 * CSV of hour offsets after send, e.g. "24,72,168"). A blank schedule falls back
 * to the legacy single reminder driven by Signature_Reminder_Hours__c.
 *
 * Per-signer progress is tracked in Reminders_Sent__c (count of schedule entries
 * consumed). Missed offsets — e.g. the job was paused for a week — collapse into
 * ONE catch-up reminder rather than a burst: reminders are nags, not an audit
 * trail, and bursting risks the org's daily email limit.
 *
 * Schedule via: System.schedule('DocGen Signature Reminders', '0 0 * * * ?', new DocGenSignatureReminderSchedulable());
 */
public with sharing class DocGenSignatureReminderSchedulable implements Schedulable {
    // Test-injectable threshold override — allows tests to bypass CreatedDate filtering
    @TestVisible
    private static DateTime testThresholdOverride = null;

    public void execute(SchedulableContext ctx) {
        DocGen_Settings__c settings = DocGen_Settings__c.getOrgDefaults();

        // Check if reminders are enabled
        if (settings.Signature_Reminder_Enabled__c != true)
            return;

        List<Integer> offsets = parseSchedule(settings);
        if (offsets.isEmpty())
            return;

        DateTime threshold = testThresholdOverride != null ? testThresholdOverride : System.now().addHours(-offsets[0]);

        // Pending signers old enough for the first offset who haven't consumed the
        // whole schedule yet. Legacy signers reminded before Reminders_Sent__c
        // existed have it null — they're seeded from Reminder_Sent_At__c below.
        // v2.0.1 — per-field FLS enforcement on SOQL reads (the "Apex SOQL
        // USER_MODE Missing" finding category). DocGenFlsGuard.assertAccessible
        // calls Schema.SObjectField.getDescribe().isAccessible() on every field
        // the SELECT lists; throws DocGenException with the offending field name
        // before any query runs. SYSTEM_MODE on the SOQL sidesteps the
        // package-build @TestSetup FLS-propagation issue documented in
        // DocGenFlsGuard.cls.
        DocGenFlsGuard.assertAccessible(
            DocGen_Signer__c.sObjectType,
            new Set<String>{
                'Signer_Name__c',
                'Signer_Email__c',
                'Role_Name__c',
                'Secure_Token__c',
                'Contact__c',
                'Reminder_Sent_At__c',
                'Reminders_Sent__c',
                'CreatedDate',
                'Signature_Request__c',
                'Status__c'
            }
        );
        DocGenFlsGuard.assertAccessible(
            DocGen_Signature_Request__c.sObjectType,
            new Set<String>{ 'Status__c', 'Expires_At__c', 'Render_Data_Snapshot__c', 'Source_Document_Id__c' }
        );
        Integer scheduleSize = offsets.size();
        /* code-analyzer-suppress ApexFlsViolation, DatabaseOperationsMustUseWithSharing */
        List<DocGen_Signer__c> pendingSigners = [
            SELECT
                Id,
                Signer_Name__c,
                Signer_Email__c,
                Role_Name__c,
                Secure_Token__c,
                Contact__c,
                Reminder_Sent_At__c,
                Reminders_Sent__c,
                CreatedDate,
                Signature_Request__c,
                Signature_Request__r.Status__c,
                Signature_Request__r.Expires_At__c,
                Signature_Request__r.Render_Data_Snapshot__c,
                Signature_Request__r.Source_Document_Id__c,
                Signature_Request__r.Template__c,
                Signature_Request__r.Template__r.Name
            FROM DocGen_Signer__c
            WHERE
                Status__c IN ('Pending', 'Viewed')
                AND CreatedDate < :threshold
                AND (Reminders_Sent__c = NULL
                OR Reminders_Sent__c < :scheduleSize)
                AND Signature_Request__r.Status__c NOT IN ('Signed', 'Cancelled', 'Declined')
            WITH SYSTEM_MODE
            LIMIT 200
        ]; // NOPMD ApexCRUDViolation - package-internal custom object; CRUD controlled by DocGen permission sets

        if (pendingSigners.isEmpty())
            return;

        String siteUrl = DocGenSignatureSenderController.getSiteBaseUrl();

        List<DocGenSignatureEmailService.SignerEmail> emailList = new List<DocGenSignatureEmailService.SignerEmail>();
        List<DocGen_Signer__c> signersToUpdate = new List<DocGen_Signer__c>();
        for (DocGen_Signer__c s : pendingSigners) {
            // Skip expired signing windows (stamped Expires_At__c, or legacy 48h)
            if (DocGenSignatureExpiry.isExpired(s.Signature_Request__r.Expires_At__c, s.CreatedDate))
                continue;

            Integer dueCount = countDueOffsets(offsets, s.CreatedDate);
            // Tests inject testThresholdOverride to make just-created signers due.
            if (testThresholdOverride != null && dueCount == 0)
                dueCount = 1;
            // Legacy seed: reminded once before Reminders_Sent__c existed.
            Integer sentCount = s.Reminders_Sent__c != null
                ? Integer.valueOf(s.Reminders_Sent__c)
                : (s.Reminder_Sent_At__c != null ? 1 : 0);
            if (dueCount <= sentCount)
                continue;

            // Guided-PDF requests must be reminded with the PDF signing page, the
            // classic typed-name flow with the legacy page (same routing as resend).
            String sigPagePath = DocGenSignatureSenderController.resolveSigningPath(s.Signature_Request__r);
            String sigUrl = siteUrl + sigPagePath + '?token=' + s.Secure_Token__c;

            emailList.add(
                new DocGenSignatureEmailService.SignerEmail(
                    s.Signer_Name__c,
                    s.Signer_Email__c,
                    s.Role_Name__c,
                    sigUrl,
                    s.Contact__c
                )
            );

            s.Reminder_Sent_At__c = System.now();
            s.Reminders_Sent__c = dueCount;
            signersToUpdate.add(s);
        }

        if (!emailList.isEmpty()) {
            DocGenSignatureEmailService.sendSignatureReminderEmails(
                emailList,
                'Document awaiting your signature',
                null
            );

            // v2.0.1 — per-field FLS enforcement (Checkmarx "FLS Update").
            DocGenFlsGuard.assertUpdateable(
                signersToUpdate,
                new Set<String>{ 'Reminder_Sent_At__c', 'Reminders_Sent__c' }
            );
            /* code-analyzer-suppress ApexFlsViolation, DatabaseOperationsMustUseWithSharing */
            Database.update(signersToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * Sorted hour offsets from Signature_Reminder_Schedule__c ("24,72,168").
     * Blank or unparseable → single-entry legacy schedule from
     * Signature_Reminder_Hours__c (exactly the pre-schedule behavior: at most
     * one reminder ever). Entries clamp to 1–8760 (a year); max 10.
     */
    @TestVisible
    private static List<Integer> parseSchedule(DocGen_Settings__c settings) {
        List<Integer> offsets = new List<Integer>();
        String csv = settings.Signature_Reminder_Schedule__c;
        if (String.isNotBlank(csv)) {
            for (String part : csv.split(',')) {
                String trimmed = part.trim();
                if (trimmed.isNumeric()) {
                    Integer hours = Integer.valueOf(trimmed);
                    if (hours >= 1 && hours <= 8760) {
                        offsets.add(hours);
                    }
                }
            }
        }
        if (offsets.isEmpty()) {
            Integer legacyHours = settings.Signature_Reminder_Hours__c != null
                ? Integer.valueOf(settings.Signature_Reminder_Hours__c)
                : 24;
            if (legacyHours > 0) {
                offsets.add(legacyHours);
            }
        }
        offsets.sort();
        while (offsets.size() > 10) {
            offsets.remove(offsets.size() - 1);
        }
        return offsets;
    }

    /** How many schedule offsets have elapsed since the signer was created. */
    private static Integer countDueOffsets(List<Integer> offsets, Datetime createdDate) {
        Long elapsedHours = (System.now().getTime() - createdDate.getTime()) / (1000 * 60 * 60);
        Integer due = 0;
        for (Integer offsetHours : offsets) {
            if (elapsedHours >= offsetHours) {
                due++;
            }
        }
        return due;
    }
}
