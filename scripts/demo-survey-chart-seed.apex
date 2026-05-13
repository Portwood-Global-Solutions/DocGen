// DocGen — Survey Chart demo seed script
// Run: sf apex run --target-org <org> -f scripts/demo-survey-chart-seed.apex
//
// Creates one Survey with 5 Questions and 50 Responses each, with realistic answer
// distributions, so you can demo the {#ChartBucket} tag against a SalesforceDocGen
// template without setting up survey data by hand. Idempotent — deletes any
// existing seed rows tagged with the marker `DocGen Chart Demo` before inserting.
//
// REQUIRED SCHEMA (your org must have these objects/fields, with these exact API
// names, or you must adapt the script). All custom; the package does NOT ship them.
//
//   Survey__c
//     - Name (standard)
//
//   Survey_Question__c
//     - Survey__c (Master-Detail or Lookup to Survey__c)
//     - Question_Text__c (Text)
//     - Display_Order__c (Number)
//
//   Survey_Response__c
//     - Survey_Question__c (Master-Detail or Lookup to Survey_Question__c)
//     - Selected_Answer__c (Text or Picklist)
//
// And on Survey_Question__c, the child relationship name to Survey_Response__c must
// be `Survey_Responses__r` (default for `Survey_Response__c` field; rename if yours
// differs and update the matching template).

String MARKER = 'DocGen Chart Demo';

// ----- Cleanup any prior demo data -----
try {
    List<SObject> existingSurveys = Database.query('SELECT Id FROM Survey__c WHERE Name = :MARKER');
    if (!existingSurveys.isEmpty()) {
        delete existingSurveys; // cascade deletes Questions + Responses via master-detail
        System.debug('Deleted ' + existingSurveys.size() + ' prior demo Survey(s)');
    }
} catch (System.QueryException qe) {
    System.debug('Survey__c not found in this org. See script header for required schema.');
    return;
}

// ----- Insert the Survey -----
SObject survey = Schema.getGlobalDescribe().get('Survey__c').newSObject();
survey.put('Name', MARKER);
insert survey;
Id surveyId = (Id) survey.get('Id');
System.debug('Created Survey: ' + surveyId);

// ----- Insert 5 Questions -----
Map<Integer, String> prompts = new Map<Integer, String>{
    1 => 'How satisfied are you overall?',
    2 => 'Would you recommend us to a colleague?',
    3 => 'How often do you use our product?',
    4 => 'Which factor matters most to you?',
    5 => 'Any concerns? (free text — many leave blank)'
};

List<SObject> questions = new List<SObject>();
for (Integer i = 1; i <= 5; i++) {
    SObject q = Schema.getGlobalDescribe().get('Survey_Question__c').newSObject();
    q.put('Survey__c', surveyId);
    q.put('Question_Text__c', prompts.get(i));
    q.put('Display_Order__c', i);
    questions.add(q);
}
insert questions;

// ----- Insert 50 Responses per question with realistic distributions -----
// Distributions chosen to show off chart variety:
//   Q1 — heavy lean to "Good" (skewed)            14 / 25 / 8 / 3 = 50
//   Q2 — strong "Yes" with small detractor tail   35 / 10 / 5 = 50
//   Q3 — bimodal usage frequency                  22 / 8 / 6 / 14 = 50
//   Q4 — fairly even across 4 options             12 / 18 / 11 / 9 = 50
//   Q5 — 70% blank, 30% diverse free text         35 / 5 / 4 / 3 / 3 = 50
//        (demonstrates "Not Specified" bucket)

Map<Integer, List<String>> answerValues = new Map<Integer, List<String>>{
    1 => new List<String>{ 'Excellent', 'Good', 'Fair', 'Poor' },
    2 => new List<String>{ 'Yes', 'Maybe', 'No' },
    3 => new List<String>{ 'Daily', 'Weekly', 'Monthly', 'Rarely' },
    4 => new List<String>{ 'Price', 'Quality', 'Service', 'Speed' },
    5 => new List<String>{ '', 'Pricing tier confusion', 'Mobile app slow', 'Documentation gaps', 'No concerns' }
};

Map<Integer, List<Integer>> answerCounts = new Map<Integer, List<Integer>>{
    1 => new List<Integer>{ 14, 25, 8, 3 },
    2 => new List<Integer>{ 35, 10, 5 },
    3 => new List<Integer>{ 22, 8, 6, 14 },
    4 => new List<Integer>{ 12, 18, 11, 9 },
    5 => new List<Integer>{ 35, 5, 4, 3, 3 }
};

List<SObject> responses = new List<SObject>();
for (Integer qIdx = 0; qIdx < questions.size(); qIdx++) {
    Id qId = (Id) questions[qIdx].get('Id');
    Integer qNum = qIdx + 1;
    List<String> vals = answerValues.get(qNum);
    List<Integer> cnts = answerCounts.get(qNum);
    for (Integer v = 0; v < vals.size(); v++) {
        Integer c = (v < cnts.size()) ? cnts[v] : 0;
        for (Integer k = 0; k < c; k++) {
            SObject resp = Schema.getGlobalDescribe().get('Survey_Response__c').newSObject();
            resp.put('Survey_Question__c', qId);
            resp.put('Selected_Answer__c', String.isBlank(vals[v]) ? null : vals[v]);
            responses.add(resp);
        }
    }
}
insert responses;

System.debug(
    'Seeded: 1 Survey, ' + questions.size() + ' Questions, ' + responses.size() + ' Responses. Survey Id: ' + surveyId
);
System.debug('Generate a PDF from Survey ' + surveyId + ' using template SurveyChartExample.html to see the charts.');
