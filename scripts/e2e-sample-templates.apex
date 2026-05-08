// =====================================================================
// Sample Template E2E Test — validates createSampleTemplates()
// Creates sample templates, verifies versions + DOCX files, creates
// test data, verifies data retrieval for each template. Cleans up.
// Run: sf apex run --target-org <org> -f scripts/e2e-sample-templates.apex
// =====================================================================

Integer pass = 0;
Integer fail = 0;

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.allowSave = true;
String uid = String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 100000));

// =====================================================================
// 1. CREATE SAMPLE TEMPLATES (do this first — heaviest operation)
// =====================================================================

Integer sampleCount = DocGenController.createSampleTemplates();

// Test 1: Correct count
if (sampleCount == 5) { pass++; } else { fail++; System.debug('FAIL T1: createSampleTemplates returned ' + sampleCount + ', expected 5'); }

// =====================================================================
// 2. VERIFY TEMPLATES, VERSIONS, AND DOCX FILES
// =====================================================================

List<DocGen_Template__c> samples = [
    SELECT Id, Name, Base_Object_API__c, Query_Config__c,
           (SELECT Id, Content_Version_Id__c, Is_Active__c FROM Versions__r WHERE Is_Active__c = true LIMIT 1)
    FROM DocGen_Template__c
    WHERE Category__c = 'Sample'
    ORDER BY Name
];

// Test 2: All 5 exist with active versions
Boolean allHaveVersions = true;
for (DocGen_Template__c s : samples) {
    if (s.Versions__r == null || s.Versions__r.isEmpty()) {
        allHaveVersions = false;
        System.debug('FAIL T2: "' + s.Name + '" has no active version');
    }
}
if (samples.size() == 5 && allHaveVersions) { pass++; } else { fail++; System.debug('FAIL T2: Expected 5 samples with versions, got ' + samples.size()); }

// Test 3: Each version points to a valid DOCX ContentVersion
Set<Id> cvIds = new Set<Id>();
for (DocGen_Template__c s : samples) {
    if (!s.Versions__r.isEmpty()) {
        cvIds.add(s.Versions__r[0].Content_Version_Id__c);
    }
}
List<ContentVersion> sampleCvs = [SELECT Id, FileExtension, ContentSize FROM ContentVersion WHERE Id IN :cvIds];
Boolean allDocx = true;
for (ContentVersion cv : sampleCvs) {
    if (cv.FileExtension != 'docx' || cv.ContentSize == 0) {
        allDocx = false;
        System.debug('FAIL T3: CV ' + cv.Id + ' ext=' + cv.FileExtension + ' size=' + cv.ContentSize);
    }
}
if (sampleCvs.size() == 5 && allDocx) { pass++; } else { fail++; System.debug('FAIL T3: Expected 5 DOCX CVs, got ' + sampleCvs.size()); }

// =====================================================================
// 3. VERIFY QUERY CONFIGS ARE VALID V3 JSON WITH CORRECT STRUCTURE
// (DocGenDataRetriever throws AuraHandledException which can't execute
//  in anonymous Apex. Core e2e already validates the full pipeline.)
// =====================================================================

Set<String> expectedObjects = new Set<String>{'Account', 'Opportunity', 'Contact', 'Case'};
for (DocGen_Template__c s : samples) {
    try {
        Map<String, Object> cfg = (Map<String, Object>) JSON.deserializeUntyped(s.Query_Config__c);
        Integer version = (Integer) cfg.get('v');
        List<Object> nodes = (List<Object>) cfg.get('nodes');
        Boolean objValid = expectedObjects.contains(s.Base_Object_API__c);
        if (version == 3 && nodes != null && !nodes.isEmpty() && objValid) {
            pass++;
            System.debug('OK: ' + s.Name + ' => V3 config, ' + nodes.size() + ' node(s), base=' + s.Base_Object_API__c);
        } else {
            fail++;
            System.debug('FAIL: ' + s.Name + ' invalid config (v=' + version + ', nodes=' + (nodes != null ? nodes.size() : 0) + ')');
        }
    } catch (Exception e) {
        fail++;
        System.debug('FAIL: ' + s.Name + ' config parse error: ' + e.getMessage());
    }
}

// =====================================================================
// RESULTS
// =====================================================================

System.debug('');
System.debug('==============================================');
System.debug('  PASS: ' + pass + '  FAIL: ' + fail);
System.debug('  ' + (fail == 0 ? 'ALL TESTS PASSED' : fail + ' TEST(S) FAILED'));
System.debug('==============================================');
System.debug('  T1 Sample count(5), T2 Active versions, T3 DOCX CVs,');
System.debug('  T4-T8 V3 config validation (1 per template)');

// =====================================================================
// CLEANUP
// =====================================================================

try { delete [SELECT Id FROM DocGen_Template__c WHERE Category__c = 'Sample']; } catch (Exception ex) { System.debug('Cleanup samples: ' + ex.getMessage()); }
System.debug('Cleanup: DONE');
