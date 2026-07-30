// DocGen — sample data for a permission-test scratch org.
//
// Run: sf apex run --target-org docgen-permtest -f scripts/seed-permission-test-data.apex
// (scripts/setup-permission-test-org.sh runs this automatically.)
//
// Separate from setup-permission-test-org.apex on purpose: User and
// PermissionSetAssignment are SETUP objects, and DML on those cannot share a
// transaction with Account/Contact — Salesforce throws MIXED_DML_OPERATION.
//
// Accounts + Contacts specifically: both are available to the Salesforce Platform
// license, so the restricted tester can exercise a real parent/child template.
// Opportunity, Case and Lead are NOT visible to a Platform user, so a template
// built on those would fail for reasons that have nothing to do with DocGen.
//
// Idempotent: re-running does not duplicate the data.

Integer existing = [SELECT COUNT() FROM Account WHERE Name LIKE 'DocGen Test Account%'];
if (existing == 0) {
    List<Account> accs = new List<Account>();
    for (Integer i = 1; i <= 3; i++) {
        accs.add(new Account(Name = 'DocGen Test Account ' + i, Industry = 'Technology'));
    }
    insert accs;

    List<Contact> cons = new List<Contact>();
    for (Account a : accs) {
        for (Integer j = 1; j <= 4; j++) {
            cons.add(
                new Contact(
                    FirstName = 'Test',
                    LastName = 'Contact ' + j,
                    AccountId = a.Id,
                    Email = 'contact' + j + '@example.com'
                )
            );
        }
    }
    insert cons;
}

System.debug(
    'SEED RESULT >> accounts=' +
        [SELECT COUNT() FROM Account WHERE Name LIKE 'DocGen Test Account%'] +
        ' contacts=' +
        [SELECT COUNT() FROM Contact WHERE Account.Name LIKE 'DocGen Test Account%'] +
        ' >> ALL GOOD'
);
