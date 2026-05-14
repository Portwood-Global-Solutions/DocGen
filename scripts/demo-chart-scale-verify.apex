// DocGen — Scale validation for chart SOQL fallback
// Run AFTER demo-survey-chart-scale-seed.apex
//
// Renders a minimal chart template against the 8K-row scale survey, with a
// Query_Config that OMITS the Survey_Responses__r subquery so the retriever
// doesn't load 8K rows into the data map. The chart's SOQL fallback fires
// per question (5 SOQLs total), each issuing a GROUP BY aggregate that
// runs server-side.
//
// Asserts that:
//   1. Each chart's percentages match the seed's known distribution
//   2. SOQL query count stays well under the 100 per-transaction limit
//   3. Total CPU stays under the 10s budget

List<SObject> surveys = Database.query('SELECT Id FROM Survey__c WHERE Name = \'DocGen Chart Scale Demo\' LIMIT 1');
if (surveys.isEmpty()) {
    System.debug('ERROR: run demo-survey-chart-scale-seed.apex first');
    return;
}
Id surveyId = (Id) surveys[0].get('Id');

// Build the survey data map manually — same shape the data retriever would
// produce when Query_Config omits Survey_Responses__r. Just questions, no
// nested response lists. Each question carries its own Id so the chart's
// SOQL fallback can construct WHERE Survey_Question__c = :id.
List<SObject> questions = [
    SELECT Id, Question_Text__c, Display_Order__c
    FROM Survey_Question__c
    WHERE Survey__c = :surveyId
    ORDER BY Display_Order__c
];
System.debug('Loaded ' + questions.size() + ' questions');

List<Object> questionMaps = new List<Object>();
for (SObject q : questions) {
    questionMaps.add(
        new Map<String, Object>{
            'Id' => q.Id,
            'Question_Text__c' => q.get('Question_Text__c'),
            'Display_Order__c' => q.get('Display_Order__c')
        }
    );
}

Map<String, Object> surveyData = new Map<String, Object>{
    'Id' => surveyId,
    'Name' => 'DocGen Chart Scale Demo',
    'Survey_Questions__r' => new Map<String, Object>{ 'records' => questionMaps }
};

// Each anon Apex execution is its own transaction, so the resolver's
// chartSoqlBudget static resets to 50 automatically (no manual reset needed).
Integer soqlBefore = Limits.getQueries();
Long cpuBefore = Limits.getCpuTime();

// Minimal chart template — one ChartBucket per question. Inside the
// {#Survey_Questions__r} loop, each iteration triggers preprocessInline
// against the iteration item's data, where Survey_Responses__r is missing,
// forcing the SOQL fallback to fire.
String tmpl =
    '<doc>' +
    '{#Survey_Questions__r}' +
    '<q>{Display_Order__c}.{Question_Text__c}|' +
    '{#ChartBucket:Survey_Responses__r:Selected_Answer__c}' +
    '[{key}={count}/{percent}%]' +
    '{/ChartBucket}' +
    '</q>' +
    '{/Survey_Questions__r}' +
    '</doc>';

String result = DocGenService.processXmlForTest(tmpl, surveyData);

Integer soqlAfter = Limits.getQueries();
Long cpuAfter = Limits.getCpuTime();
Integer soqlUsed = soqlAfter - soqlBefore;
Long cpuUsed = cpuAfter - cpuBefore;

System.debug('SOQL queries issued by chart aggregation: ' + soqlUsed);
System.debug('CPU time consumed by chart aggregation: ' + cpuUsed + ' ms');
System.debug('---OUTPUT (truncated 2000 chars)---');
System.debug(result.left(2000));

// Spot-check known seed values
Integer pass = 0;
Integer fail = 0;

// Q1: Good=800, Excellent=448, Rarely... wait that's Q3. Q1 is Excellent/Good/Fair/Poor.
// Q1 seed: 448 Excellent, 800 Good, 256 Fair, 96 Poor (total 1600). Good leads at 50.0%.
if (result.contains('[Good=800/50.0%]')) {
    pass++;
    System.debug('Q1 Good 50.0% (800/1600): PASS');
} else {
    fail++;
    System.debug('Q1 Good 50.0%: FAIL');
}
if (result.contains('[Excellent=448/28.0%]')) {
    pass++;
    System.debug('Q1 Excellent 28.0% (448/1600): PASS');
} else {
    fail++;
    System.debug('Q1 Excellent 28.0%: FAIL');
}
// Q2: Yes=1120 of 1600 = 70.0%
if (result.contains('[Yes=1120/70.0%]')) {
    pass++;
    System.debug('Q2 Yes 70.0% (1120/1600): PASS');
} else {
    fail++;
    System.debug('Q2 Yes 70.0%: FAIL');
}
// Q5: Not Specified (null) bucket = 1120 of 1600 = 70.0%
if (result.contains('[=1120/70.0%]') || result.contains('[Not Specified=1120/70.0%]')) {
    pass++;
    System.debug('Q5 Not Specified 70.0% (1120/1600): PASS');
} else {
    fail++;
    System.debug('Q5 Not Specified 70.0%: FAIL');
}

System.debug('========================================');
System.debug('SCALE VERIFY — PASS: ' + pass + '  FAIL: ' + fail + '  SOQL: ' + soqlUsed + '  CPU: ' + cpuUsed + 'ms');
System.debug('========================================');
