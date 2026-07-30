// DocGen — seed a permission-test scratch org: two non-admin users, their
// permission sets, login passwords, and enough data to exercise the UI.
//
// Normally run via scripts/setup-permission-test-org.sh, which creates the org and
// substitutes the password placeholder. To run standalone, replace
// __DOCGEN_TEST_PASSWORD__ with a real password first.
//
// WHY NON-ADMIN USERS: a System Administrator has implicit access to every Apex
// class, so an LWC whose @salesforce/apex import points at a class missing from the
// permission set still loads for an admin and renders blank for everyone else. That
// class of bug is ONLY reproducible as a user whose access comes entirely from the
// DocGen permission sets — which is what these two users are for. Testing as
// yourself proves nothing.
//
// Idempotent: safe to re-run against the same org.

String pw = '__DOCGEN_TEST_PASSWORD__';
String orgSuffix = '.docgenperm';
Integer created = 0, assigned = 0, problems = 0;

// Profile + permission set pairing. The admin-side tester deliberately sits on the
// Standard User profile, NOT System Administrator — that is the whole point.
Map<String, Map<String, String>> plan = new Map<String, Map<String, String>>{
    'dgadmin' => new Map<String, String>{
        'profile' => 'Standard User', // Salesforce license
        'permSet' => 'DocGen_Admin',
        'last' => 'AdminTester',
        'alias' => 'dgadm'
    },
    'dguser' => new Map<String, String>{
        'profile' => 'Standard Platform User', // Salesforce Platform license
        'permSet' => 'DocGen_User',
        'last' => 'UserTester',
        'alias' => 'dgusr'
    }
};

Map<String, Id> profileIds = new Map<String, Id>();
for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN ('Standard User', 'Standard Platform User')]) {
    profileIds.put(p.Name, p.Id);
}
Map<String, Id> permSetIds = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('DocGen_Admin', 'DocGen_User')]) {
    permSetIds.put(ps.Name, ps.Id);
}
if (permSetIds.size() < 2) {
    System.debug('SETUP: FAIL — DocGen permission sets not found. Deploy force-app before running this.');
}

String adminUsername = [SELECT Username FROM User WHERE Id = :UserInfo.getUserId()].Username;
String emailDomain = adminUsername.substringAfter('@');
List<User> toInsert = new List<User>();
Map<String, String> usernameByKey = new Map<String, String>();

for (String key : plan.keySet()) {
    Map<String, String> cfg = plan.get(key);
    String username = key + orgSuffix + '@' + emailDomain;
    usernameByKey.put(key, username);

    if (profileIds.get(cfg.get('profile')) == null) {
        problems++;
        System.debug('SETUP: FAIL — profile not found: ' + cfg.get('profile'));
        continue;
    }
    if (![SELECT Id FROM User WHERE Username = :username LIMIT 1].isEmpty()) {
        continue; // already exists — re-run
    }
    toInsert.add(
        new User(
            Username = username,
            Email = 'davemoudy@gmail.com',
            FirstName = 'DocGen',
            LastName = cfg.get('last'),
            Alias = cfg.get('alias'),
            ProfileId = profileIds.get(cfg.get('profile')),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        )
    );
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    created = toInsert.size();
}

Map<String, Id> userIdByUsername = new Map<String, Id>();
for (User u : [SELECT Id, Username FROM User WHERE Username IN :usernameByKey.values()]) {
    userIdByUsername.put(u.Username, u.Id);
}

Set<String> alreadyAssigned = new Set<String>();
for (PermissionSetAssignment psa : [
    SELECT AssigneeId, PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :userIdByUsername.values()
]) {
    alreadyAssigned.add(psa.AssigneeId + '|' + psa.PermissionSetId);
}

List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
for (String key : plan.keySet()) {
    Id uid = userIdByUsername.get(usernameByKey.get(key));
    Id psid = permSetIds.get(plan.get(key).get('permSet'));
    if (uid == null || psid == null) {
        problems++;
        System.debug('SETUP: FAIL — cannot assign ' + plan.get(key).get('permSet') + ' for ' + key);
        continue;
    }
    if (!alreadyAssigned.contains(uid + '|' + psid)) {
        psas.add(new PermissionSetAssignment(AssigneeId = uid, PermissionSetId = psid));
    }
}
if (!psas.isEmpty()) {
    insert psas;
    assigned = psas.size();
}

// Passwords. Requires the EnableSetPasswordInApi feature, which the scratch org
// definition supplies — `sf org generate password` can't reach these users because
// they were created through Apex and are not in the CLI's auth store.
if (pw != '__DOCGEN_TEST' + '_PASSWORD__') {
    for (Id uid : userIdByUsername.values()) {
        try {
            System.setPassword(uid, pw);
        } catch (Exception e) {
            // "invalid repeated password" means the user already has exactly this
            // password — which is the desired end state, so a re-run should not fail.
            // Anything else is a real problem.
            if (!e.getMessage().containsIgnoreCase('repeated password')) {
                problems++;
                System.debug('SETUP: FAIL — setPassword: ' + e.getMessage());
            }
        }
    }
} else {
    problems++;
    System.debug('SETUP: FAIL — password placeholder was not substituted; run via setup-permission-test-org.sh');
}

// Sample data is deliberately NOT created here — User and PermissionSetAssignment
// are setup objects, and mixing them with Account/Contact DML in one transaction
// throws MIXED_DML_OPERATION. seed-permission-test-data.apex runs separately.

for (String key : plan.keySet()) {
    System.debug(
        'SETUP USER >> ' +
            usernameByKey.get(key) +
            ' >> profile=' +
            plan.get(key).get('profile') +
            ' >> permSet=' +
            plan.get(key).get('permSet')
    );
}
System.debug(
    'SETUP RESULT >> created=' +
        created +
        ' assigned=' +
        assigned +
        ' problems=' +
        problems +
        (problems == 0 ? ' >> ALL GOOD' : ' >> PROBLEMS')
);
