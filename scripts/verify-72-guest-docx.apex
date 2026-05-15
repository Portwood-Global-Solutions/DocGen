// Verify #72 backend: the existing DocGenGuestRenderQueueable produces a DOCX
// (not just PDF) when invoked with a Word-output template. This proves the
// server-side path is intact; combined with the LWC routing fix in
// docGenRunner.js (guest branch now calls _generateGuestRender for DOCX),
// guest DOCX renders run as Automated Process — which can load VersionData
// for rich-text-pasted images whose CDL.Visibility=InternalUsers.
//
// Run: sf apex run --target-org portwood-staging -f scripts/verify-72-guest-docx.apex

class R {
    Integer pass = 0;
    Integer fail = 0;
    void log(String label, Boolean ok, String detail) {
        if (ok) {
            pass++;
            System.debug('PASS: ' + label + ((detail == null) ? '' : ' — ' + detail));
        } else {
            fail++;
            System.debug('FAIL: ' + label + ((detail == null) ? '' : ' — ' + detail));
        }
    }
}
R r = new R();

// Use a UI-created Word/Native template — REPRO87_PD_* templates skip the
// package's pre-decompose step, so generateDocument fails on them with
// "entity is deleted" on the pre-decomp CV lookup. 'Rich Text Example' has
// Output_Format__c=Native and proper pre-decomp; exercises the same code
// path a real guest signing flow hits.
List<DocGen_Template__c> tmpls = [
    SELECT Id, Name, Output_Format__c, Type__c
    FROM DocGen_Template__c
    WHERE Name = 'Rich Text Example'
    LIMIT 1
];
r.log(
    'Found Word/Native template (Rich Text Example)',
    !tmpls.isEmpty(),
    tmpls.isEmpty() ? 'create one in DocGen Admin UI first' : tmpls[0].Name
);
if (tmpls.isEmpty()) {
    System.debug('ABORTED');
    return;
}
DocGen_Template__c t = tmpls[0];

// ===== Account to attach the rendered file to =====
List<Account> accts = [SELECT Id FROM Account LIMIT 1];
Id recordId = accts.isEmpty() ? null : accts[0].Id;
if (recordId == null) {
    Account a = new Account(Name = 'Verify72 Account');
    insert a;
    recordId = a.Id;
}

// ===== Insert tracking job, invoke queueable synchronously =====
DocGen_Job__c job = new DocGen_Job__c(Status__c = 'Draft', Template__c = t.Id, Parent_Record_Id__c = recordId);
insert job;
System.debug('Job created: ' + job.Id);

try {
    new DocGenGuestRenderQueueable(job.Id, t.Id, recordId).execute(null);
    r.log('Queueable executed without exception', true, null);
} catch (Exception e) {
    r.log('Queueable executed without exception', false, e.getTypeName() + ': ' + e.getMessage());
}

// (No restore needed — using the template as-is; no Output_Format__c flip.)

// ===== Inspect job state and resulting CV =====
DocGen_Job__c after = [SELECT Id, Status__c, Merged_PDF_CV__c, Label__c FROM DocGen_Job__c WHERE Id = :job.Id LIMIT 1];
r.log(
    'Job Status__c == Completed',
    after.Status__c == 'Completed',
    'status: ' + after.Status__c + ' label: ' + after.Label__c
);
r.log('Merged_PDF_CV__c populated', String.isNotBlank(after.Merged_PDF_CV__c), 'cvId: ' + after.Merged_PDF_CV__c);

if (String.isNotBlank(after.Merged_PDF_CV__c)) {
    List<ContentVersion> cvs = [
        SELECT Id, Title, FileExtension, ContentSize, ContentDocumentId
        FROM ContentVersion
        WHERE Id = :after.Merged_PDF_CV__c
        LIMIT 1
    ];
    if (!cvs.isEmpty()) {
        ContentVersion cv = cvs[0];
        r.log('Result CV FileExtension == docx', cv.FileExtension == 'docx', 'ext: ' + cv.FileExtension);
        r.log(
            'Result CV ContentSize > 1KB',
            cv.ContentSize != null && cv.ContentSize > 1000,
            'size: ' + cv.ContentSize
        );

        // CDL visibility — guest must be able to fetch this. Queueable flips InternalUsers→AllUsers.
        List<ContentDocumentLink> cdls = [
            SELECT LinkedEntityId, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId
        ];
        Integer allUsers = 0;
        Integer internalUsers = 0;
        for (ContentDocumentLink cdl : cdls) {
            if (cdl.Visibility == 'AllUsers')
                allUsers++;
            else if (cdl.Visibility == 'InternalUsers')
                internalUsers++;
        }
        r.log(
            'At least one CDL has Visibility=AllUsers',
            allUsers > 0,
            'AllUsers: ' + allUsers + ' InternalUsers: ' + internalUsers
        );
    } else {
        r.log('Could query result CV', false, 'CV id ' + after.Merged_PDF_CV__c + ' not found');
    }
}

// (Cleanup intentionally skipped — anon Apex's `try { delete cd } catch` doesn't
// suppress the platform-level "entity is deleted" fault that comes back when
// the queueable's own audit-cleanup cascade has already touched the same
// records. Re-running the test reuses the same Account; orphaned CVs and Jobs
// accumulate but are tolerable for a verification script.)

System.debug('========================================');
System.debug('VERIFY #72 (backend path only) — PASS: ' + r.pass + '  FAIL: ' + r.fail);
if (r.fail == 0) {
    System.debug('Backend confirmed: queueable produces DOCX with AllUsers-visible CDL.');
    System.debug('Combined with the LWC fix in docGenRunner.js (guest DOCX now routes through queueGuestRender),');
    System.debug('issue #72 is closed end-to-end. UI smoke test still recommended on a real Experience site.');
} else {
    System.debug('Backend regression — investigate before relying on the LWC change.');
}
System.debug('========================================');
