// ============================================================================
// SDocs-replacement demo — the three related lists that make a document
// "dynamic": milestones, deliverables, change orders.
//
// P-2041 (Meridian) is the showcase record and carries the fullest set — it is
// the one the acceptance certificate is generated from. The other two are
// populated enough that picking a different project on stage does not produce
// an embarrassingly empty table.
//
// Re-runnable: children are deleted by parent first.
// ============================================================================

Map<String, Id> proj = new Map<String, Id>();
for (Demo_Project__c p : [SELECT Id, Project_Code__c FROM Demo_Project__c WHERE Project_Code__c LIKE 'P-2%']) {
    proj.put(p.Project_Code__c, p.Id);
}
Set<Id> pids = new Set<Id>(proj.values());
delete [SELECT Id FROM Demo_Project_Milestone__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Demo_Project_Deliverable__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Demo_Change_Order__c WHERE Project__c IN :pids];

Date t = Date.today();
List<Demo_Project_Milestone__c> ms = new List<Demo_Project_Milestone__c>();
List<Demo_Project_Deliverable__c> ds = new List<Demo_Project_Deliverable__c>();
List<Demo_Change_Order__c> cs = new List<Demo_Change_Order__c>();

// ── P-2041 Meridian — Patient Portal Modernization ──────────────────────────
Id m = proj.get('P-2041');
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Discovery & Solution Design',
        Sequence__c = 1,
        Due_Date__c = t.addDays(-186),
        Completed_Date__c = t.addDays(-188),
        Status__c = 'Accepted',
        Value__c = 68000,
        Acceptance_Criteria__c = 'Signed solution design document, integration architecture, and data migration plan.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Experience Cloud Site Build',
        Sequence__c = 2,
        Due_Date__c = t.addDays(-124),
        Completed_Date__c = t.addDays(-121),
        Status__c = 'Accepted',
        Value__c = 122000,
        Acceptance_Criteria__c = 'Portal site deployed to UAT with self-scheduling, secure messaging, and results release.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Epic HL7 / FHIR Integration',
        Sequence__c = 3,
        Due_Date__c = t.addDays(-72),
        Completed_Date__c = t.addDays(-66),
        Status__c = 'Accepted',
        Value__c = 108000,
        Acceptance_Criteria__c = 'Bi-directional appointment, results, and demographics interfaces passing the agreed 40-case test script.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Historical Data Migration',
        Sequence__c = 4,
        Due_Date__c = t.addDays(-30),
        Completed_Date__c = t.addDays(-27),
        Status__c = 'Accepted',
        Value__c = 74000,
        Acceptance_Criteria__c = '240,000 patient profiles migrated with a reconciliation report at 99.98% match or better.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Accessibility & Security Review',
        Sequence__c = 5,
        Due_Date__c = t.addDays(-9),
        Completed_Date__c = t.addDays(-7),
        Status__c = 'Complete',
        Value__c = 46000,
        Acceptance_Criteria__c = 'WCAG 2.1 AA conformance report and penetration test with no open high findings.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = m,
        Name = 'Go-Live & Hypercare',
        Sequence__c = 6,
        Due_Date__c = t.addDays(21),
        Status__c = 'In Progress',
        Value__c = 68000,
        Acceptance_Criteria__c = 'Production cutover complete and two weeks of hypercare with no severity-1 incidents open.'
    )
);

ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'Solution Design Document v2.1',
        Sequence__c = 1,
        Category__c = 'Documentation',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-188),
        Accepted_By__c = 'Dana Whitfield',
        Description__c = 'End-to-end architecture, data model, and integration specification for the modernized portal.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'Experience Cloud Site Configuration',
        Sequence__c = 2,
        Category__c = 'Configuration',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-121),
        Accepted_By__c = 'Dana Whitfield',
        Description__c = 'Branded portal with self-scheduling, secure messaging, results release, and billing views.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'Epic HL7 v2 Interface Suite',
        Sequence__c = 3,
        Category__c = 'Integration',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-66),
        Accepted_By__c = 'Ravi Menon',
        Description__c = 'ADT, SIU, and ORU interfaces with error queue, replay tooling, and monitoring dashboard.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'FHIR R4 Patient Access API',
        Sequence__c = 4,
        Category__c = 'Integration',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-58),
        Accepted_By__c = 'Ravi Menon',
        Description__c = 'Patient, Appointment, and DiagnosticReport resources exposed for third-party app access.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'Patient Profile Migration & Reconciliation',
        Sequence__c = 5,
        Category__c = 'Data Migration',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-27),
        Accepted_By__c = 'Dana Whitfield',
        Description__c = '240,112 profiles migrated; reconciliation report shows 99.99% field-level match.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'WCAG 2.1 AA Conformance Report',
        Sequence__c = 6,
        Category__c = 'Report',
        Status__c = 'Delivered',
        Delivered_Date__c = t.addDays(-7),
        Description__c = 'Independent accessibility audit covering all patient-facing pages and flows.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = m,
        Name = 'Administrator & Front-Desk Training',
        Sequence__c = 7,
        Category__c = 'Training',
        Status__c = 'In Review',
        Delivered_Date__c = t.addDays(-4),
        Description__c = 'Four sessions delivered to 62 staff, with recordings and a quick-reference guide.'
    )
);

cs.add(
    new Demo_Change_Order__c(
        Project__c = m,
        Request_Date__c = t.addDays(-140),
        Requested_By__c = 'Dana Whitfield',
        Amount__c = 34000,
        Schedule_Impact_Days__c = 14,
        Status__c = 'Approved',
        Description__c = 'Add Spanish and Vietnamese localization to all patient-facing portal pages and notifications.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = m,
        Request_Date__c = t.addDays(-84),
        Requested_By__c = 'Ravi Menon',
        Amount__c = 18500,
        Schedule_Impact_Days__c = 7,
        Status__c = 'Approved',
        Description__c = 'Extend the FHIR interface to include the Immunization resource for the state registry feed.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = m,
        Request_Date__c = t.addDays(-40),
        Requested_By__c = 'Dana Whitfield',
        Amount__c = 12000,
        Schedule_Impact_Days__c = 0,
        Status__c = 'Approved',
        Description__c = 'Additional hypercare coverage for two weekend cutover windows.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = m,
        Request_Date__c = t.addDays(-12),
        Requested_By__c = 'Alan Reyes',
        Amount__c = 22000,
        Schedule_Impact_Days__c = 21,
        Status__c = 'Requested',
        Description__c = 'Native mobile wrapper for the portal, deferred to a follow-on phase pending client decision.'
    )
);

// ── P-2088 Northwind — Warehouse Automation Rollout ─────────────────────────
Id n = proj.get('P-2088');
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = n,
        Name = 'Process Assessment & Site Survey',
        Sequence__c = 1,
        Due_Date__c = t.addDays(-72),
        Completed_Date__c = t.addDays(-74),
        Status__c = 'Accepted',
        Value__c = 42000,
        Acceptance_Criteria__c = 'Signed survey report for all four distribution centers.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = n,
        Name = 'WMS Integration Build',
        Sequence__c = 2,
        Due_Date__c = t.addDays(-24),
        Completed_Date__c = t.addDays(-19),
        Status__c = 'Accepted',
        Value__c = 96000,
        Acceptance_Criteria__c = 'Order, inventory, and shipment interfaces certified against the WMS test harness.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = n,
        Name = 'Columbus DC Pilot',
        Sequence__c = 3,
        Due_Date__c = t.addDays(6),
        Status__c = 'In Progress',
        Value__c = 68000,
        Acceptance_Criteria__c = 'Two weeks of live picking at target throughput with no unplanned downtime.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = n,
        Name = 'Regional Rollout — 3 Sites',
        Sequence__c = 4,
        Due_Date__c = t.addDays(74),
        Status__c = 'Not Started',
        Value__c = 106500,
        Acceptance_Criteria__c = 'All remaining sites live with floor devices provisioned and staff trained.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = n,
        Name = 'Site Survey Report — 4 DCs',
        Sequence__c = 1,
        Category__c = 'Report',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-74),
        Accepted_By__c = 'Marcus Ellery',
        Description__c = 'Floor layout, network coverage, and device placement plan per distribution center.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = n,
        Name = 'WMS Order Orchestration Interfaces',
        Sequence__c = 2,
        Category__c = 'Integration',
        Status__c = 'Accepted',
        Delivered_Date__c = t.addDays(-19),
        Accepted_By__c = 'Marcus Ellery',
        Description__c = 'Real-time pick, pack, and ship messaging with retry and dead-letter handling.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = n,
        Name = 'Throughput Dashboard',
        Sequence__c = 3,
        Category__c = 'Report',
        Status__c = 'In Review',
        Delivered_Date__c = t.addDays(-5),
        Description__c = 'Live picks-per-hour, exception rate, and device health by site.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = n,
        Name = 'Mobile Scanning Configuration — 180 Devices',
        Sequence__c = 4,
        Category__c = 'Configuration',
        Status__c = 'Pending',
        Description__c = 'Device enrollment, scanning profiles, and offline behavior for floor handhelds.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = n,
        Request_Date__c = t.addDays(-52),
        Requested_By__c = 'Marcus Ellery',
        Amount__c = 27500,
        Schedule_Impact_Days__c = 10,
        Status__c = 'Approved',
        Description__c = 'Add returns processing to the pilot scope after a peak-season volume review.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = n,
        Request_Date__c = t.addDays(-8),
        Requested_By__c = 'Alan Reyes',
        Amount__c = 9800,
        Schedule_Impact_Days__c = 4,
        Status__c = 'Requested',
        Description__c = 'Additional network hardening at the Columbus DC identified during the pilot.'
    )
);

// ── P-2103 Cascade — Field Service Mobility ─────────────────────────────────
Id c = proj.get('P-2103');
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = c,
        Name = 'Discovery & Current-State Assessment',
        Sequence__c = 1,
        Due_Date__c = t.addDays(-5),
        Completed_Date__c = t.addDays(-6),
        Status__c = 'Complete',
        Value__c = 38000,
        Acceptance_Criteria__c = 'Current-state process map, gap analysis, and prioritized backlog.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = c,
        Name = 'Solution Design Sign-off',
        Sequence__c = 2,
        Due_Date__c = t.addDays(16),
        Status__c = 'In Progress',
        Value__c = 32000,
        Acceptance_Criteria__c = 'Approved scheduling policy, offline design, and parts tracking model.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = c,
        Name = 'Build & Technician Pilot',
        Sequence__c = 3,
        Due_Date__c = t.addDays(88),
        Status__c = 'Not Started',
        Value__c = 62000,
        Acceptance_Criteria__c = '20 technicians live for three weeks with offline capture verified in the field.'
    )
);
ms.add(
    new Demo_Project_Milestone__c(
        Project__c = c,
        Name = 'Full Rollout — 140 Technicians',
        Sequence__c = 4,
        Due_Date__c = t.addDays(142),
        Status__c = 'Not Started',
        Value__c = 46000,
        Acceptance_Criteria__c = 'All technicians provisioned, trained, and dispatching from the new scheduler.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = c,
        Name = 'Current-State Process Map',
        Sequence__c = 1,
        Category__c = 'Documentation',
        Status__c = 'Delivered',
        Delivered_Date__c = t.addDays(-6),
        Description__c = 'Dispatch, work order, and parts consumption flows as operated today.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = c,
        Name = 'Scheduling Optimization Policy Design',
        Sequence__c = 2,
        Category__c = 'Documentation',
        Status__c = 'In Review',
        Delivered_Date__c = t.addDays(-2),
        Description__c = 'Objectives, work rules, and service territory model for the optimization engine.'
    )
);
ds.add(
    new Demo_Project_Deliverable__c(
        Project__c = c,
        Name = 'ERP Parts Consumption Interface Spec',
        Sequence__c = 3,
        Category__c = 'Integration',
        Status__c = 'Pending',
        Description__c = 'Field-level mapping and reconciliation rules for parts drawn against work orders.'
    )
);
cs.add(
    new Demo_Change_Order__c(
        Project__c = c,
        Request_Date__c = t.addDays(-3),
        Requested_By__c = 'Priya Raghunathan',
        Amount__c = 15400,
        Schedule_Impact_Days__c = 12,
        Status__c = 'Requested',
        Description__c = 'Add crew-based scheduling for two-technician jobs, out of the original single-resource scope.'
    )
);

insert ms;
insert ds;
insert cs;
System.debug('SEED-02 milestones=' + ms.size() + ' deliverables=' + ds.size() + ' changeOrders=' + cs.size());
