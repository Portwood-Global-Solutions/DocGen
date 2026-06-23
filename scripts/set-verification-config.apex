// #verification — quick config helper for testing the configurable signer-verification
// feature on a scratch/dev org. Edit the values below, then run with:
//   sf apex run --target-org docgen-test --file scripts/set-verification-config.apex
// After configuring, mint signing links from the DocGen runner (Signatures tab) for the
// templates you set, or via the existing seed scripts, and open them to verify behavior.

// ---- 1. Org default (DocGen Settings) -------------------------------------------------
Boolean SET_ORG_DEFAULT = true;
Boolean ORG_REQUIRE_VERIFICATION = true; // false = signers skip the email PIN by default
Boolean ORG_PREFILL_EMAIL = false; // true = auto-send code to the known address

if (SET_ORG_DEFAULT) {
    DocGen_Settings__c s = DocGen_Settings__c.getOrgDefaults();
    if (s == null || s.Id == null) {
        s = new DocGen_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
    }
    s.Signature_Skip_Email_Verification__c = !ORG_REQUIRE_VERIFICATION; // stored inverted (skip = !require)
    s.Signature_Prefill_Signer_Email__c = ORG_PREFILL_EMAIL;
    upsert s;
    System.debug('Org default → require=' + ORG_REQUIRE_VERIFICATION + ' prefill=' + ORG_PREFILL_EMAIL);
}

// ---- 2. Per-template defaults ---------------------------------------------------------
// Map of Template Name → Signer_Verification__c ('Inherit' | 'Required' | 'Off')
// and optional Prefill_Signer_Email__c ('Inherit' | 'Yes' | 'No').
Map<String, String> TEMPLATE_VERIFICATION = new Map<String, String>{};
// 'My Waiver Template' => 'Off',
// 'NDA Template' => 'Required'
Map<String, String> TEMPLATE_PREFILL = new Map<String, String>{};
// 'My Waiver Template' => 'Yes'

if (!TEMPLATE_VERIFICATION.isEmpty() || !TEMPLATE_PREFILL.isEmpty()) {
    Set<String> names = new Set<String>();
    names.addAll(TEMPLATE_VERIFICATION.keySet());
    names.addAll(TEMPLATE_PREFILL.keySet());
    List<DocGen_Template__c> tpls = [SELECT Id, Name FROM DocGen_Template__c WHERE Name IN :names];
    for (DocGen_Template__c t : tpls) {
        if (TEMPLATE_VERIFICATION.containsKey(t.Name)) {
            t.Signer_Verification__c = TEMPLATE_VERIFICATION.get(t.Name);
        }
        if (TEMPLATE_PREFILL.containsKey(t.Name)) {
            t.Prefill_Signer_Email__c = TEMPLATE_PREFILL.get(t.Name);
        }
    }
    update tpls;
    System.debug('Updated ' + tpls.size() + ' template(s).');
}

// ---- 3. Show current config -----------------------------------------------------------
DocGen_Settings__c cur = DocGen_Settings__c.getOrgDefaults();
System.debug(
    'CURRENT ORG: require=' +
        (cur == null ? true : !cur.Signature_Skip_Email_Verification__c) +
        ' prefill=' +
        (cur == null ? false : cur.Signature_Prefill_Signer_Email__c)
);
for (DocGen_Template__c t : [
    SELECT Name, Signer_Verification__c, Prefill_Signer_Email__c
    FROM DocGen_Template__c
    ORDER BY Name
    LIMIT 50
]) {
    System.debug(
        '  TEMPLATE "' +
            t.Name +
            '": verification=' +
            t.Signer_Verification__c +
            ' prefill=' +
            t.Prefill_Signer_Email__c
    );
}
