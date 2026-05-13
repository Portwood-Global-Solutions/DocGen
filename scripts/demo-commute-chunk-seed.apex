// DocGen — Commute Survey 30K chunk seed (append-only)
// Run: sf apex run --target-org <org> -f scripts/demo-commute-chunk-seed.apex
//
// Inserts ONE chunk of 6,000 Survey_Response__c records against the survey
// `DocGen Chart Demo 30K Commute`. Idempotent on Survey + Question parents
// (finds existing or creates). Pure-append on responses — call repeatedly
// to accumulate. The companion `build-30k-commute.sh` invokes this 5 times
// to reach 30,000 rows.
//
// Chunk shape per call: 6,000 responses, ~60% Marina / ~40% Bayshore,
// realistic Mode distribution (60% Drive Alone, 25% Telework, etc.) with
// multi-select Reasons populated on Drive Alone respondents.
//
// CPU budget per call: ~2-3 seconds. DML budget: 6,000 rows (under 10K).
// 5 invocations × 6,000 rows = 30,000 responses total.

String MARKER = 'DocGen Chart Demo 30K Commute';
Integer ROWS_PER_CHUNK = 6000;

// Cache SObjectTypes once — per-row describe lookups would blow CPU at 6K rows.
Schema.SObjectType surveyType = Schema.getGlobalDescribe().get('Survey__c');
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('Survey_Question__c');
Schema.SObjectType responseType = Schema.getGlobalDescribe().get('Survey_Response__c');

if (surveyType == null || questionType == null || responseType == null) {
    System.debug('ERROR: Required objects not deployed. Deploy demo-schema/ first.');
    return;
}

// Find-or-create the parent Survey.
Id surveyId;
List<SObject> existing = Database.query('SELECT Id FROM Survey__c WHERE Name = :MARKER LIMIT 1');
if (existing.isEmpty()) {
    SObject s = surveyType.newSObject();
    s.put('Name', MARKER);
    insert s;
    surveyId = (Id) s.get('Id');
    System.debug('Created Survey: ' + surveyId);
} else {
    surveyId = (Id) existing[0].get('Id');
    System.debug('Reusing Survey: ' + surveyId);
}

// Find-or-create the placeholder Question. We use a single placeholder since
// the commute template aggregates responses directly via the Survey lookup,
// not per-question.
Id placeholderQId;
List<SObject> qs = Database.query('SELECT Id FROM Survey_Question__c WHERE Survey__c = :surveyId LIMIT 1');
if (qs.isEmpty()) {
    SObject q = questionType.newSObject();
    q.put('Survey__c', surveyId);
    q.put('Question_Text__c', 'Commute Survey (single response per row)');
    q.put('Display_Order__c', 1);
    insert q;
    placeholderQId = (Id) q.get('Id');
    System.debug('Created placeholder Question: ' + placeholderQId);
} else {
    placeholderQId = (Id) qs[0].get('Id');
}

// Mode + Location distribution per chunk. Marina ~58%, Bayshore ~42%.
// Per-location Mode percentages mirror the 425-row commute screenshot:
//   Marina: DA 59% / Telework 36% / PT 2% / Carpool 0.4% / Bike 1% / DayOff 1%
//   Bayshore: DA 69% / Telework 11% / PT 11% / Bike 2% / DayOff 8%

// Counts that sum to ROWS_PER_CHUNK across both locations.
// Marina (3,500): DA 2058, Telework 1274, PT 84, Carpool 14, Bike 28, DayOff 42
// Bayshore (2,500): DA 1715, Telework 275, PT 275, Bike 42, DayOff 193

Map<String, Map<String, Integer>> modeCounts = new Map<String, Map<String, Integer>>{
    '8000 Marina' => new Map<String, Integer>{
        'Drive Alone' => 2058,
        'Telework' => 1274,
        'Public Transit' => 84,
        'Carpool' => 14,
        'Bike' => 28,
        'Day Off' => 42
    },
    '3260 Bayshore' => new Map<String, Integer>{
        'Drive Alone' => 1715,
        'Telework' => 275,
        'Public Transit' => 275,
        'Bike' => 42,
        'Day Off' => 193
    }
};

// Reasons (multi-select) — applied to Drive Alone respondents only, scaled to
// ~32% Marina DA fill-rate (matching original 47/147 ratio) and ~25%
// Bayshore DA fill-rate (matching original 30/120). Each filling respondent
// gets a deterministic offset-shifted subset of reasons so pick counts hit
// realistic target percentages.
List<String> reasonValues = new List<String>{
    'Cost/free parking',
    'Need car for work',
    'Schedule flexibility',
    'Personal/comfort',
    'Transit not available',
    'Other',
    'Driving is faster'
};
List<Integer> reasonOffsets = new List<Integer>{ 0, 11, 19, 23, 29, 31, 37 };

// Per-location: fill_rate × DA_count = filled respondents per chunk.
//   Marina:  2058 DA × 32% ≈ 658 filling Reasons
//   Bayshore: 1715 DA × 25% ≈ 429 filling Reasons
Map<String, Integer> reasonsFilledPerLoc = new Map<String, Integer>{ '8000 Marina' => 658, '3260 Bayshore' => 429 };
// Per-location, per-reason target pick counts (scaled by ~14× from
// 47-respondent original distribution to ~658-respondent chunk scale).
Map<String, List<Integer>> reasonTargets = new Map<String, List<Integer>>{
    '8000 Marina' => new List<Integer>{ 98, 168, 350, 196, 322, 336, 462 },
    '3260 Bayshore' => new List<Integer>{ 100, 129, 100, 257, 215, 215, 357 }
};

// Stream-insert: build chunk, insert at boundary, free memory.
Integer CHUNK_INSERT_SIZE = 6000; // single insert per call — within 10K DML cap
List<SObject> batch = new List<SObject>();
Integer totalAdded = 0;

for (String loc : modeCounts.keySet()) {
    Map<String, Integer> modes = modeCounts.get(loc);
    Integer driveAloneIdx = 0;
    Integer fillTarget = reasonsFilledPerLoc.get(loc);
    List<Integer> targs = reasonTargets.get(loc);

    for (String mode : modes.keySet()) {
        Integer count = modes.get(mode);
        for (Integer i = 0; i < count; i++) {
            SObject resp = responseType.newSObject();
            resp.put('Survey_Question__c', placeholderQId);
            resp.put('Survey__c', surveyId);
            resp.put('Selected_Answer__c', mode);
            resp.put('Mode__c', mode);
            resp.put('Location__c', loc);
            if (mode == 'Drive Alone' && driveAloneIdx < fillTarget) {
                List<String> picks = new List<String>();
                for (Integer r = 0; r < reasonValues.size(); r++) {
                    Integer shifted = Math.mod(driveAloneIdx + reasonOffsets.get(r), fillTarget);
                    if (shifted < targs.get(r)) {
                        picks.add(reasonValues.get(r));
                    }
                }
                resp.put('Reasons__c', String.join(picks, ';'));
                driveAloneIdx++;
            }
            batch.add(resp);
        }
    }
}

insert batch;
totalAdded = batch.size();

// Report current total for this survey so the orchestrator can show progress.
Integer currentTotal = [SELECT COUNT() FROM Survey_Response__c WHERE Survey__c = :surveyId];
System.debug('Added ' + totalAdded + ' responses. Total now: ' + currentTotal);
