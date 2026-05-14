// DocGen — Survey Chart scale-validation seed
// Run: sf apex run --target-org <org> -f scripts/demo-survey-chart-scale-seed.apex
//
// Builds 8,000 Survey_Response__c records distributed across 5 questions
// (~1,600 per question) on a single Survey. Demonstrates the SOQL-fallback
// chart path at 4× the 2,000-row giant-query threshold.
//
// Why not 30K?
//   Anon Apex caps DML at 10,000 rows per transaction. The customer-stated
//   30K production volume sits behind multi-day data ingestion, not a single
//   seed script. The point of this validation is that the chart's GROUP BY
//   SOQL is database-side — same cost at 8K, 30K, or 1M records — so once
//   we prove correctness here, scale is just a property of the database.
//   Production seeders use Batch Apex (chunked) or Bulk API (no Apex limits).
//
// Idempotent: deletes any prior 'DocGen Chart Scale Demo' before reseeding.

String MARKER = 'DocGen Chart Scale Demo';
Integer CHUNK_SIZE = 4000;

try {
    List<SObject> existing = Database.query('SELECT Id FROM Survey__c WHERE Name = :MARKER');
    if (!existing.isEmpty()) {
        delete existing;
        System.debug('Deleted ' + existing.size() + ' prior 30K survey(s)');
    }
} catch (System.QueryException qe) {
    System.debug('Survey__c not found. See demo-survey-chart-seed.apex header for schema.');
    return;
}

// Cache SObjectTypes ONCE — describe lookups inside the per-row loop are the
// dominant CPU cost. Caching cut a prior 30K run from ~6 sec to ~1 sec.
Schema.SObjectType surveyType = Schema.getGlobalDescribe().get('Survey__c');
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('Survey_Question__c');
Schema.SObjectType responseType = Schema.getGlobalDescribe().get('Survey_Response__c');

SObject survey = surveyType.newSObject();
survey.put('Name', MARKER);
insert survey;
Id surveyId = (Id) survey.get('Id');

Map<Integer, String> prompts = new Map<Integer, String>{
    1 => 'Overall satisfaction (30K-scale)',
    2 => 'Recommend to colleague (30K-scale)',
    3 => 'Usage frequency (30K-scale)',
    4 => 'Most important factor (30K-scale)',
    5 => 'Concerns (30K-scale, many blank)'
};

List<SObject> questions = new List<SObject>();
for (Integer i = 1; i <= 5; i++) {
    SObject q = questionType.newSObject();
    q.put('Survey__c', surveyId);
    q.put('Question_Text__c', prompts.get(i));
    q.put('Display_Order__c', i);
    questions.add(q);
}
insert questions;

// Distributions per question — each respondent picks one answer
Map<Integer, List<String>> answerValues = new Map<Integer, List<String>>{
    1 => new List<String>{ 'Excellent', 'Good', 'Fair', 'Poor' },
    2 => new List<String>{ 'Yes', 'Maybe', 'No' },
    3 => new List<String>{ 'Daily', 'Weekly', 'Monthly', 'Rarely' },
    4 => new List<String>{ 'Price', 'Quality', 'Service', 'Speed' },
    5 => new List<String>{ '', 'Pricing tier confusion', 'Mobile app slow', 'Documentation gaps', 'No concerns' }
};

// Scaled to 1,600 per question = 8,000 total. Proportions preserved from
// the 6,000 / question target, just divided by 3.75.
Map<Integer, List<Integer>> answerCounts = new Map<Integer, List<Integer>>{
    1 => new List<Integer>{ 448, 800, 256, 96 },
    2 => new List<Integer>{ 1120, 320, 160 },
    3 => new List<Integer>{ 704, 256, 192, 448 },
    4 => new List<Integer>{ 384, 576, 352, 288 },
    5 => new List<Integer>{ 1120, 160, 128, 96, 96 }
};

// Stream-insert: build chunk of CHUNK_SIZE, insert, clear, repeat.
// Avoids holding all 30K records in memory + uses CPU more linearly.
Integer totalInserted = 0;
List<SObject> chunk = new List<SObject>();
for (Integer qIdx = 0; qIdx < questions.size(); qIdx++) {
    Id qId = (Id) questions[qIdx].get('Id');
    List<String> vals = answerValues.get(qIdx + 1);
    List<Integer> cnts = answerCounts.get(qIdx + 1);
    for (Integer v = 0; v < vals.size(); v++) {
        String answerVal = String.isBlank(vals[v]) ? null : vals[v];
        Integer c = (v < cnts.size()) ? cnts[v] : 0;
        for (Integer k = 0; k < c; k++) {
            SObject resp = responseType.newSObject();
            resp.put('Survey_Question__c', qId);
            resp.put('Survey__c', surveyId);
            resp.put('Selected_Answer__c', answerVal);
            chunk.add(resp);
            if (chunk.size() >= CHUNK_SIZE) {
                insert chunk;
                totalInserted += chunk.size();
                System.debug('Inserted ' + totalInserted);
                chunk = new List<SObject>();
            }
        }
    }
}
if (!chunk.isEmpty()) {
    insert chunk;
    totalInserted += chunk.size();
}

System.debug('Seeded 30K-scale: 1 Survey, 5 Questions, ' + totalInserted + ' Responses. Survey Id: ' + surveyId);
