// DocGen — Survey Chart end-to-end verification (run AFTER demo-survey-chart-seed.apex)
// Run: sf apex run --target-org <org> -f scripts/demo-survey-chart-verify.apex
//
// Queries the seeded Survey, builds the parent + nested data map exactly the way
// DocGenDataRetriever would shape it for the template engine, then runs the
// {#ChartBucket} aggregation against a chart-only template snippet via
// processXmlForTest. Asserts that the expected bucket values appear in the output.
//
// This is faster than a full PDF render and gives a clear diagnostic when the
// chart aggregation isn't behaving against live SObject data.

Integer pass = 0;
Integer fail = 0;

try {
    List<SObject> surveys = Database.query(
        'SELECT Id, Name, ' +
            '(SELECT Id, Question_Text__c, Display_Order__c, ' +
            '(SELECT Id, Selected_Answer__c FROM Survey_Responses__r) ' +
            'FROM Survey_Questions__r ORDER BY Display_Order__c) ' +
            'FROM Survey__c WHERE Name = \'DocGen Chart Demo\' LIMIT 1'
    );
    if (surveys.isEmpty()) {
        System.debug('ERROR: No seed Survey found. Run demo-survey-chart-seed.apex first.');
        return;
    }
    SObject survey = surveys[0];
    List<SObject> questions = (List<SObject>) survey.getSObjects('Survey_Questions__r');
    System.debug('Loaded Survey "' + survey.get('Name') + '" with ' + questions.size() + ' questions');

    // Build the data map shape DocGen's template engine expects. For inline (non-
    // giant-query) data, each parent field is a top-level key and each child
    // relationship is a Map containing a 'records' list of child maps.
    Map<String, Object> surveyData = new Map<String, Object>{ 'Name' => survey.get('Name') };
    List<Object> questionRecords = new List<Object>();
    Integer totalResponses = 0;
    for (SObject q : questions) {
        Map<String, Object> qMap = new Map<String, Object>{
            'Question_Text__c' => q.get('Question_Text__c'),
            'Display_Order__c' => q.get('Display_Order__c')
        };
        List<SObject> responses = (List<SObject>) q.getSObjects('Survey_Responses__r');
        List<Object> respRecords = new List<Object>();
        for (SObject r : responses) {
            respRecords.add(new Map<String, Object>{ 'Selected_Answer__c' => r.get('Selected_Answer__c') });
        }
        qMap.put('Survey_Responses__r', new Map<String, Object>{ 'records' => respRecords });
        questionRecords.add(qMap);
        totalResponses += responses.size();
    }
    surveyData.put('Survey_Questions__r', new Map<String, Object>{ 'records' => questionRecords });
    System.debug('Built data map: ' + questionRecords.size() + ' questions, ' + totalResponses + ' total responses');

    // Run the chart against a focused template snippet that mirrors the
    // per-question chart block from SurveyChartExample.html.
    String tmpl =
        '<doc>{#Survey_Questions__r}<q>{Display_Order__c}.{Question_Text__c}|' +
        '{#ChartBucket:Survey_Responses__r:Selected_Answer__c}[{key_label}={count}/{percent}%]{/ChartBucket}' +
        '</q>{/Survey_Questions__r}</doc>';
    String result = DocGenService.processXmlForTest(tmpl, surveyData);
    System.debug('---OUTPUT---');
    System.debug(result.left(2000)); // truncate for log readability
    System.debug('---END---');

    // Q1 had 14 Excellent / 25 Good / 8 Fair / 3 Poor → Good leads at 50.0%
    if (result.contains('[Good=25/50.0%]')) {
        pass++;
        System.debug('Q1 GOOD AT 50.0%: PASS');
    } else {
        fail++;
        System.debug('Q1 GOOD AT 50.0%: FAIL');
    }
    if (result.contains('[Excellent=14/28.0%]')) {
        pass++;
        System.debug('Q1 EXCELLENT AT 28.0%: PASS');
    } else {
        fail++;
        System.debug('Q1 EXCELLENT AT 28.0%: FAIL');
    }
    // Q2: 35 Yes / 10 Maybe / 5 No → Yes at 70%
    if (result.contains('[Yes=35/70.0%]')) {
        pass++;
        System.debug('Q2 YES AT 70.0%: PASS');
    } else {
        fail++;
        System.debug('Q2 YES AT 70.0%: FAIL');
    }
    // Q5: 35 blank → Not Specified bucket at 70%
    if (result.contains('[Not Specified=35/70.0%]')) {
        pass++;
        System.debug('Q5 NOT SPECIFIED AT 70.0%: PASS');
    } else {
        fail++;
        System.debug('Q5 NOT SPECIFIED AT 70.0%: FAIL');
    }
    // Descending order check: in Q1, Good (25) must appear BEFORE Excellent (14)
    Integer goodIdx = result.indexOf('[Good=25');
    Integer excIdx = result.indexOf('[Excellent=14');
    if (goodIdx > -1 && excIdx > goodIdx) {
        pass++;
        System.debug('Q1 DESCENDING ORDER: PASS');
    } else {
        fail++;
        System.debug('Q1 DESCENDING ORDER: FAIL (Good@' + goodIdx + ' Excellent@' + excIdx + ')');
    }
} catch (Exception e) {
    fail++;
    System.debug('VERIFY: FAIL — ' + e.getMessage() + '\n' + e.getStackTraceString());
}

System.debug('========================================');
System.debug(
    'CHART VERIFY — PASS: ' + pass + '  FAIL: ' + fail + (fail == 0 ? '  ALL CHECKS PASSED' : '  FAILURES DETECTED')
);
System.debug('========================================');
