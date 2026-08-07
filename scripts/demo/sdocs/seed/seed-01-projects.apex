// ============================================================================
// SDocs-replacement demo — accounts, client contacts, and three projects.
//
// Idempotent: deletes anything it previously created (matched on Project_Code__c
// / the demo account names) before re-inserting, so it can be re-run mid-demo to
// undo whatever got clicked.
//
// Signer emails use gmail plus-addressing on purpose. A signature demo whose
// email never arrives is not a demo, and every client contact here routes to a
// real inbox the presenter controls.
// ============================================================================

String SIGNER_INBOX = 'davemoudy'; // -> davemoudy+meridian@gmail.com etc.

// ── clean ───────────────────────────────────────────────────────────────────
delete [SELECT Id FROM Demo_Project__c WHERE Project_Code__c LIKE 'P-2%'];
delete [
    SELECT Id
    FROM Account
    WHERE Name IN ('Meridian Health Systems', 'Northwind Logistics Group', 'Cascade Energy Partners')
];

// ── accounts ────────────────────────────────────────────────────────────────
List<Account> accts = new List<Account>{
    new Account(
        Name = 'Meridian Health Systems',
        BillingStreet = '1400 Harborview Parkway, Suite 900',
        BillingCity = 'Seattle',
        BillingState = 'WA',
        BillingPostalCode = '98101',
        Phone = '(206) 555-0142',
        Industry = 'Healthcare',
        Website = 'meridianhealth.example.com'
    ),
    new Account(
        Name = 'Northwind Logistics Group',
        BillingStreet = '8820 Interstate Commerce Drive',
        BillingCity = 'Columbus',
        BillingState = 'OH',
        BillingPostalCode = '43219',
        Phone = '(614) 555-0188',
        Industry = 'Transportation',
        Website = 'northwindlogistics.example.com'
    ),
    new Account(
        Name = 'Cascade Energy Partners',
        BillingStreet = '2100 Summit Ridge Road',
        BillingCity = 'Denver',
        BillingState = 'CO',
        BillingPostalCode = '80202',
        Phone = '(303) 555-0119',
        Industry = 'Energy',
        Website = 'cascadeenergy.example.com'
    )
};
insert accts;
Map<String, Id> acct = new Map<String, Id>();
for (Account a : accts) {
    acct.put(a.Name, a.Id);
}

// ── client contacts (the signers) ───────────────────────────────────────────
List<Contact> cons = new List<Contact>{
    new Contact(
        FirstName = 'Dana',
        LastName = 'Whitfield',
        Title = 'VP, Clinical Systems',
        Email = SIGNER_INBOX + '+meridian@gmail.com',
        Phone = '(206) 555-0143',
        AccountId = acct.get('Meridian Health Systems')
    ),
    new Contact(
        FirstName = 'Marcus',
        LastName = 'Ellery',
        Title = 'Director of Operations',
        Email = SIGNER_INBOX + '+northwind@gmail.com',
        Phone = '(614) 555-0189',
        AccountId = acct.get('Northwind Logistics Group')
    ),
    new Contact(
        FirstName = 'Priya',
        LastName = 'Raghunathan',
        Title = 'Chief Information Officer',
        Email = SIGNER_INBOX + '+cascade@gmail.com',
        Phone = '(303) 555-0120',
        AccountId = acct.get('Cascade Energy Partners')
    )
};
insert cons;
Map<String, Id> con = new Map<String, Id>();
for (Contact c : cons) {
    con.put(c.LastName, c.Id);
}

// ── projects ────────────────────────────────────────────────────────────────
Date today = Date.today();
List<Demo_Project__c> projs = new List<Demo_Project__c>{
    new Demo_Project__c(
        Name = 'Patient Portal Modernization',
        Project_Code__c = 'P-2041',
        Client__c = acct.get('Meridian Health Systems'),
        Client_Contact__c = con.get('Whitfield'),
        Client_Signer_Title__c = 'VP, Clinical Systems',
        Project_Manager__c = 'Alan Reyes',
        PM_Email__c = SIGNER_INBOX + '+pm@gmail.com',
        Status__c = 'In Flight',
        Phase__c = 'Phase 3 — User Acceptance',
        Start_Date__c = today.addDays(-214),
        Target_Completion__c = today.addDays(21),
        Contract_Value__c = 486000,
        Percent_Complete__c = 88,
        Scope_Summary__c = 'Replacement of the legacy patient portal with a Salesforce Experience Cloud site covering ' +
            'appointment self-scheduling, secure messaging, results release, and billing. Includes HL7 v2 and FHIR R4 ' +
            'integration to the Epic instance, migration of 240,000 historical patient profiles, and accessibility ' +
            'conformance to WCAG 2.1 AA.',
        Approval_Statement__c = 'Meridian Health Systems confirms that the deliverables listed in this document have ' +
            'been reviewed against the agreed acceptance criteria and are accepted as complete. Approval authorizes ' +
            'final milestone invoicing and starts the 30-day warranty period.'
    ),
    new Demo_Project__c(
        Name = 'Warehouse Automation Rollout',
        Project_Code__c = 'P-2088',
        Client__c = acct.get('Northwind Logistics Group'),
        Client_Contact__c = con.get('Ellery'),
        Client_Signer_Title__c = 'Director of Operations',
        Project_Manager__c = 'Alan Reyes',
        PM_Email__c = SIGNER_INBOX + '+pm@gmail.com',
        Status__c = 'In Flight',
        Phase__c = 'Phase 2 — Site Deployment',
        Start_Date__c = today.addDays(-96),
        Target_Completion__c = today.addDays(74),
        Contract_Value__c = 312500,
        Percent_Complete__c = 54,
        Scope_Summary__c = 'Deployment of automated pick-and-pack orchestration across four regional distribution ' +
            'centers, including WMS integration, mobile scanning for 180 floor devices, and a real-time throughput ' +
            'dashboard for regional operations leadership.',
        Approval_Statement__c = 'Northwind Logistics Group approves the phase deliverables described in this document ' +
            'and authorizes the project team to proceed to the next deployment wave.'
    ),
    new Demo_Project__c(
        Name = 'Field Service Mobility',
        Project_Code__c = 'P-2103',
        Client__c = acct.get('Cascade Energy Partners'),
        Client_Contact__c = con.get('Raghunathan'),
        Client_Signer_Title__c = 'Chief Information Officer',
        Project_Manager__c = 'Jordan Pike',
        PM_Email__c = SIGNER_INBOX + '+pm@gmail.com',
        Status__c = 'In Flight',
        Phase__c = 'Phase 1 — Discovery Sign-off',
        Start_Date__c = today.addDays(-38),
        Target_Completion__c = today.addDays(142),
        Contract_Value__c = 178000,
        Percent_Complete__c = 22,
        Scope_Summary__c = 'Field Service Lightning implementation for 140 field technicians covering scheduling ' +
            'optimization, offline work order capture, and parts consumption tracking against the existing ERP.',
        Approval_Statement__c = 'Cascade Energy Partners approves the discovery findings and solution design ' +
            'described in this document as the baseline for the build phase.'
    )
};
insert projs;
Map<String, Id> proj = new Map<String, Id>();
for (Demo_Project__c p : projs) {
    proj.put(p.Project_Code__c, p.Id);
}

System.debug('SEED-01 accounts=' + accts.size() + ' contacts=' + cons.size() + ' projects=' + projs.size());
for (Demo_Project__c p : projs) {
    System.debug('SEED-01 PROJECT ' + p.Project_Code__c + ' -> ' + p.Id);
}
