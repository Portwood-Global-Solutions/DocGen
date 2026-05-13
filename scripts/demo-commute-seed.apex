// DocGen — Commute Survey demo seed
// Run: sf apex run --target-org <org> -f scripts/demo-commute-seed.apex
//
// Reproduces the commute-survey shape from the customer's reference screenshot:
//   - 425 total responses: 250 at "8000 Marina", 175 at "3260 Bayshore"
//   - Mode distribution per location matching the screenshot's Mode Split table
//   - Drive Alone respondents: 47 Marina + 30 Bayshore have Reasons__c filled
//     (multi-select, semicolon-separated). The rest have NULL Reasons —
//     simulating partial-fill on the optional "why drive alone?" question.
//
// Demonstrates v1.91 chart features end-to-end:
//   - groupBy=Location__c    cross-tab pivot (Mode Split chart)
//   - where=Mode__c='...'    filtered subset (Reasons section)
//   - split=;                multi-select (Reasons multi-pick math)
//
// Idempotent: deletes any prior 'Commute Survey Demo' before reseeding.

String MARKER = 'Commute Survey Demo';

try {
    List<SObject> existing = Database.query('SELECT Id FROM Survey__c WHERE Name = :MARKER');
    if (!existing.isEmpty()) {
        delete existing;
        System.debug('Deleted ' + existing.size() + ' prior commute survey(s)');
    }
} catch (System.QueryException qe) {
    System.debug('Survey__c not found in this org. See demo-survey-chart-seed.apex header for schema.');
    return;
}

SObject survey = Schema.getGlobalDescribe().get('Survey__c').newSObject();
survey.put('Name', MARKER);
insert survey;
Id surveyId = (Id) survey.get('Id');
System.debug('Created Commute Survey: ' + surveyId);

// Commute templates don't need Survey_Question__c rows for the chart — Mode,
// Location, and Reasons live directly on Survey_Response__c. But the response
// is master-detail to a Survey_Question__c, so we create one placeholder.
SObject placeholder = Schema.getGlobalDescribe().get('Survey_Question__c').newSObject();
placeholder.put('Survey__c', surveyId);
placeholder.put('Question_Text__c', 'Commute Survey (single response per row)');
placeholder.put('Display_Order__c', 1);
insert placeholder;
Id placeholderQId = (Id) placeholder.get('Id');

// Mode distribution per location — exact match to the screenshot.
Map<String, Map<String, Integer>> modeCounts = new Map<String, Map<String, Integer>>{
    '8000 Marina' => new Map<String, Integer>{
        'Drive Alone' => 147,
        'Telework' => 91,
        'Public Transit' => 6,
        'Carpool' => 1,
        'Bike' => 2,
        'Day Off' => 3
    },
    '3260 Bayshore' => new Map<String, Integer>{
        'Drive Alone' => 120,
        'Telework' => 19,
        'Public Transit' => 19,
        'Bike' => 3,
        'Day Off' => 14
    }
};

// Reasons distribution for Drive Alone respondents who filled the Reasons
// field — per location, per reason, target pick count.
//
// Screenshot percents → target counts (% × denominator):
//   8000 Marina (denom=47):  Cost=7, Car=12, Schedule=25, Personal=14,
//                            TransitNo=23, Other=24, Faster=33
//   3260 Bayshore (denom=30): Cost=7, Car=9, Schedule=7, Personal=18,
//                             TransitNo=15, Other=15, Faster=25
//
// We seed 47 Marina + 30 Bayshore "answered Reasons" respondents (the rest
// of the Drive Alone respondents get NULL Reasons). For each respondent i in
// 0..denom-1, include reason R if i < target_count_R. Resulting per-reason
// totals match the screenshot's pick counts exactly.

// Short reason codes to fit a 255-char Text field even when all 7 are picked.
// For production use, recommend customers define Reasons as a Multi-Select
// Picklist with proper labels — the chart's `{key_label}` will then render the
// long-form text automatically.
List<String> reasonValues = new List<String>{
    'Cost/free parking',
    'Need car for work',
    'Schedule flexibility',
    'Personal/comfort',
    'Transit not available',
    'Other',
    'Driving is faster'
};

Map<String, List<Integer>> reasonTargets = new Map<String, List<Integer>>{
    '8000 Marina' => new List<Integer>{ 7, 12, 25, 14, 23, 24, 33 },
    '3260 Bayshore' => new List<Integer>{ 7, 9, 7, 18, 15, 15, 25 }
};

Map<String, Integer> reasonsFilledRespondents = new Map<String, Integer>{ '8000 Marina' => 47, '3260 Bayshore' => 30 };

// Offset-shifted assignment: each reason has a UNIQUE offset (prime numbers),
// so the predicate `(i + offset) mod N < target` picks DIFFERENT subsets of
// respondents for different reasons. Each reason still hits its exact target
// count; combos vary realistically across respondents.
List<Integer> reasonOffsets = new List<Integer>{ 0, 11, 19, 23, 29, 31, 37 };

// Build all 425 Survey_Response__c records
List<SObject> allResponses = new List<SObject>();

for (String loc : modeCounts.keySet()) {
    Map<String, Integer> modes = modeCounts.get(loc);
    Integer driveAloneFilled = 0;
    Integer driveAloneFilledTarget = reasonsFilledRespondents.get(loc);
    List<Integer> reasonTargs = reasonTargets.get(loc);

    for (String mode : modes.keySet()) {
        Integer count = modes.get(mode);
        for (Integer i = 0; i < count; i++) {
            SObject resp = Schema.getGlobalDescribe().get('Survey_Response__c').newSObject();
            resp.put('Survey_Question__c', placeholderQId);
            resp.put('Survey__c', surveyId);
            resp.put('Selected_Answer__c', mode);
            resp.put('Mode__c', mode);
            resp.put('Location__c', loc);

            // Drive Alone respondents fill Reasons up to the per-location
            // budget; the remainder get NULL Reasons (simulating skipped
            // question, matches the screenshot's partial-fill semantics).
            if (mode == 'Drive Alone' && driveAloneFilled < driveAloneFilledTarget) {
                Integer idx = driveAloneFilled;
                List<String> picks = new List<String>();
                for (Integer r = 0; r < reasonValues.size(); r++) {
                    // Offset-shifted predicate: pick this reason if the
                    // shifted respondent index falls within the target count.
                    // Different offsets per reason → varied combos per
                    // respondent while still hitting exact target totals.
                    Integer shifted = Math.mod(idx + reasonOffsets.get(r), driveAloneFilledTarget);
                    if (shifted < reasonTargs.get(r)) {
                        picks.add(reasonValues.get(r));
                    }
                }
                resp.put('Reasons__c', String.join(picks, ';'));
                driveAloneFilled++;
            }
            allResponses.add(resp);
        }
    }
}

System.debug('Built ' + allResponses.size() + ' response records');

// Insert in chunks of 9000 to stay under the 10K-row DML governor.
Integer chunkSize = 9000;
for (Integer start = 0; start < allResponses.size(); start += chunkSize) {
    Integer endIdx = Math.min(start + chunkSize, allResponses.size());
    List<SObject> chunk = new List<SObject>();
    for (Integer i = start; i < endIdx; i++) {
        chunk.add(allResponses[i]);
    }
    insert chunk;
}

System.debug('Seeded Commute Survey ' + surveyId + ' with ' + allResponses.size() + ' responses');
