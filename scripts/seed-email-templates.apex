// #193 — seed the default brandable email templates into a source-deployed org.
// The package post-install handler (DocGenEmailTemplateInstall) does this
// automatically on install/upgrade, but it does NOT fire on a plain source
// deploy to a scratch/dev org — run this once after deploying to docgen-test.
Integer created = DocGenEmailTemplateInstall.seedDefaults();
System.debug('DocGen: seeded ' + created + ' default email template(s).');
for (DocGen_Email_Template__c t : [SELECT Name, Type__c, Is_Active__c FROM DocGen_Email_Template__c ORDER BY Type__c]) {
    System.debug('  • ' + t.Type__c + ' → "' + t.Name + '" (active=' + t.Is_Active__c + ')');
}
