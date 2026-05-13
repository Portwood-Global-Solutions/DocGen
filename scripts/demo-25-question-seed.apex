// DocGen — 25-question Employee Engagement Survey seed
// Run: sf apex run --target-org <org> -f scripts/demo-25-question-seed.apex
//
// Builds a Survey with 25 varied questions, each with realistic answer
// distributions (skewed in believable ways — not uniform random). Total
// responses ~3,000-3,500 spread across the questions so the demo PDF shows
// real variance from chart to chart.
//
// Idempotent: if "Employee Engagement 2026" already exists, deletes and
// recreates it for a clean seed.

String SURVEY_NAME = 'Employee Engagement 2026';

Schema.SObjectType surveyType = Schema.getGlobalDescribe().get('Survey__c');
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('Survey_Question__c');
Schema.SObjectType responseType = Schema.getGlobalDescribe().get('Survey_Response__c');

if (surveyType == null || questionType == null || responseType == null) {
    System.debug('ERROR: deploy demo-schema/ first.');
    return;
}

// Idempotent: delete prior seed
List<SObject> existing = Database.query('SELECT Id FROM Survey__c WHERE Name = :SURVEY_NAME');
if (!existing.isEmpty()) {
    delete existing;
    System.debug('Deleted prior survey');
}

SObject survey = surveyType.newSObject();
survey.put('Name', SURVEY_NAME);
insert survey;
Id surveyId = (Id) survey.get('Id');

// ===== 25 questions, each with a distribution shape =====
// Each entry: { 'text', 'order', 'answers' => Map<value,count> }
// Counts hand-tuned to be believable, not uniform; total per question varies
// 100-200 so different charts have different visual densities.

List<Map<String, Object>> questionsSpec = new List<Map<String, Object>>{
    new Map<String, Object>{
        'text' => 'How satisfied are you with your current role?',
        'order' => 1,
        'answers' => new Map<String, Integer>{
            'Very Satisfied' => 42,
            'Satisfied' => 78,
            'Neutral' => 31,
            'Dissatisfied' => 14,
            'Very Dissatisfied' => 5
        }
    },
    new Map<String, Object>{
        'text' => 'How would you rate your work-life balance?',
        'order' => 2,
        'answers' => new Map<String, Integer>{
            'Excellent' => 28,
            'Good' => 64,
            'Fair' => 53,
            'Poor' => 19,
            'Very Poor' => 6
        }
    },
    new Map<String, Object>{
        'text' => 'Do you feel your contributions are recognized?',
        'order' => 3,
        'answers' => new Map<String, Integer>{
            'Always' => 22,
            'Often' => 71,
            'Sometimes' => 58,
            'Rarely' => 17,
            'Never' => 4
        }
    },
    new Map<String, Object>{
        'text' => 'How likely are you to recommend us as an employer?',
        'order' => 4,
        'answers' => new Map<String, Integer>{
            'Extremely Likely (10)' => 35,
            'Very Likely (9)' => 41,
            'Likely (8)' => 38,
            'Neutral (7)' => 22,
            'Unlikely (6)' => 14,
            'Very Unlikely (5 or less)' => 11
        }
    },
    new Map<String, Object>{
        'text' => 'How effective is communication from leadership?',
        'order' => 5,
        'answers' => new Map<String, Integer>{
            'Very Effective' => 18,
            'Effective' => 52,
            'Somewhat Effective' => 49,
            'Ineffective' => 23,
            'Very Ineffective' => 8
        }
    },
    new Map<String, Object>{
        'text' => 'Are growth opportunities clearly available to you?',
        'order' => 6,
        'answers' => new Map<String, Integer>{ 'Yes' => 87, 'Somewhat' => 51, 'No' => 28 }
    },
    new Map<String, Object>{
        'text' => 'How would you describe team collaboration?',
        'order' => 7,
        'answers' => new Map<String, Integer>{
            'Highly Collaborative' => 56,
            'Mostly Collaborative' => 78,
            'Sometimes Siloed' => 32,
            'Mostly Siloed' => 9
        }
    },
    new Map<String, Object>{
        'text' => 'Do you have the tools you need to do your job well?',
        'order' => 8,
        'answers' => new Map<String, Integer>{
            'Strongly Agree' => 41,
            'Agree' => 89,
            'Neutral' => 24,
            'Disagree' => 17,
            'Strongly Disagree' => 5
        }
    },
    new Map<String, Object>{
        'text' => 'How often do you experience burnout?',
        'order' => 9,
        'answers' => new Map<String, Integer>{
            'Never' => 19,
            'Rarely' => 47,
            'Sometimes' => 71,
            'Often' => 24,
            'Always' => 8
        }
    },
    new Map<String, Object>{
        'text' => 'How would you rate your direct manager?',
        'order' => 10,
        'answers' => new Map<String, Integer>{
            'Outstanding' => 38,
            'Good' => 82,
            'Average' => 31,
            'Below Average' => 12,
            'Poor' => 5
        }
    },
    new Map<String, Object>{
        'text' => 'Is feedback delivered in a timely manner?',
        'order' => 11,
        'answers' => new Map<String, Integer>{
            'Always' => 28,
            'Usually' => 64,
            'Sometimes' => 52,
            'Rarely' => 18,
            'Never' => 6
        }
    },
    new Map<String, Object>{
        'text' => 'How clear is your career path here?',
        'order' => 12,
        'answers' => new Map<String, Integer>{
            'Very Clear' => 22,
            'Somewhat Clear' => 68,
            'Unclear' => 53,
            'Very Unclear' => 17
        }
    },
    new Map<String, Object>{
        'text' => 'Do you feel psychologically safe sharing ideas?',
        'order' => 13,
        'answers' => new Map<String, Integer>{
            'Always' => 51,
            'Most of the time' => 73,
            'Sometimes' => 28,
            'Rarely' => 11
        }
    },
    new Map<String, Object>{
        'text' => 'How would you rate company benefits?',
        'order' => 14,
        'answers' => new Map<String, Integer>{
            'Excellent' => 34,
            'Above Average' => 58,
            'Average' => 47,
            'Below Average' => 19,
            'Poor' => 7
        }
    },
    new Map<String, Object>{
        'text' => 'Are meetings a productive use of your time?',
        'order' => 15,
        'answers' => new Map<String, Integer>{
            'Yes, mostly' => 39,
            'Mixed' => 86,
            'No, mostly not' => 41,
            'Almost never' => 8
        }
    },
    new Map<String, Object>{
        'text' => 'How well does the team handle conflict?',
        'order' => 16,
        'answers' => new Map<String, Integer>{
            'Very Well' => 28,
            'Well' => 64,
            'Okay' => 41,
            'Poorly' => 14,
            'Very Poorly' => 4
        }
    },
    new Map<String, Object>{
        'text' => 'How often do you receive recognition?',
        'order' => 17,
        'answers' => new Map<String, Integer>{
            'Weekly' => 18,
            'Monthly' => 41,
            'Quarterly' => 62,
            'Annually' => 31,
            'Never' => 9
        }
    },
    new Map<String, Object>{
        'text' => 'Do you feel diversity is genuinely valued?',
        'order' => 18,
        'answers' => new Map<String, Integer>{
            'Strongly Agree' => 47,
            'Agree' => 71,
            'Neutral' => 32,
            'Disagree' => 11,
            'Strongly Disagree' => 3
        }
    },
    new Map<String, Object>{
        'text' => 'How clear are organizational priorities to you?',
        'order' => 19,
        'answers' => new Map<String, Integer>{
            'Very Clear' => 19,
            'Clear' => 51,
            'Somewhat Clear' => 68,
            'Unclear' => 22,
            'Very Unclear' => 7
        }
    },
    new Map<String, Object>{
        'text' => 'Do internal processes help or hinder your work?',
        'order' => 20,
        'answers' => new Map<String, Integer>{
            'Strongly Help' => 17,
            'Help' => 58,
            'Neutral' => 41,
            'Hinder' => 38,
            'Strongly Hinder' => 11
        }
    },
    new Map<String, Object>{
        'text' => 'How would you rate onboarding for new hires?',
        'order' => 21,
        'answers' => new Map<String, Integer>{
            'Excellent' => 24,
            'Good' => 58,
            'Average' => 48,
            'Below Average' => 22,
            'Poor' => 6
        }
    },
    new Map<String, Object>{
        'text' => 'Do you feel fairly compensated for your work?',
        'order' => 22,
        'answers' => new Map<String, Integer>{
            'Strongly Agree' => 18,
            'Agree' => 52,
            'Neutral' => 41,
            'Disagree' => 38,
            'Strongly Disagree' => 14
        }
    },
    new Map<String, Object>{
        'text' => 'How often do you collaborate cross-functionally?',
        'order' => 23,
        'answers' => new Map<String, Integer>{
            'Daily' => 58,
            'Weekly' => 71,
            'Monthly' => 24,
            'Rarely' => 11,
            'Never' => 4
        }
    },
    new Map<String, Object>{
        'text' => 'Are remote/hybrid policies working for you?',
        'order' => 24,
        'answers' => new Map<String, Integer>{
            'Working Very Well' => 67,
            'Working' => 52,
            'Mixed' => 28,
            'Not Working' => 14,
            'Not Applicable' => 9
        }
    },
    new Map<String, Object>{
        'text' => 'Overall, how engaged do you feel in your work?',
        'order' => 25,
        'answers' => new Map<String, Integer>{
            'Highly Engaged' => 51,
            'Engaged' => 78,
            'Somewhat Engaged' => 38,
            'Disengaged' => 12,
            'Highly Disengaged' => 4
        }
    }
};

// ===== Insert all 25 questions =====
List<SObject> questions = new List<SObject>();
for (Map<String, Object> qSpec : questionsSpec) {
    SObject q = questionType.newSObject();
    q.put('Survey__c', surveyId);
    q.put('Question_Text__c', (String) qSpec.get('text'));
    q.put('Display_Order__c', (Integer) qSpec.get('order'));
    questions.add(q);
}
insert questions;

// Pair each questionsSpec entry with the inserted question Id (preserve order)
List<Id> questionIds = new List<Id>();
for (SObject q : questions) {
    questionIds.add((Id) q.get('Id'));
}

// ===== Department dimension =====
// Each response is assigned a Department so the cross-tab pivot charts
// (groupBy=Department__c) have a meaningful comparison axis.
//
// Departments are NOT evenly distributed across answers — each question
// has a per-department skew encoded below. Engineering tends to report
// more burnout, Sales more comp dissatisfaction, etc. Charts then show
// genuine departmental contrast rather than uniform noise.
//
// Distribution shape: for each (question, answer) bucket, the per-dept
// percentages sum to ~100. Multiply by the answer count to get per-dept
// row count, then floor/round and absorb rounding into the last dept.

List<String> departments = new List<String>{ 'Engineering', 'Sales', 'Marketing', 'Support', 'Operations' };

// Per-question department skews keyed by display order. Each value is the
// percentage of this question's responses that come from that department.
// When a question isn't listed, even 20/20/20/20/20 split is used.
//
// Format: orderNum => List<Integer> percentage for [Eng, Sales, Mkt, Sup, Ops]
Map<Integer, List<Integer>> deptSkews = new Map<Integer, List<Integer>>{
    1 => new List<Integer>{ 22, 25, 18, 20, 15 }, // Satisfaction
    2 => new List<Integer>{ 28, 18, 20, 17, 17 }, // Work-life balance (Eng skews here)
    4 => new List<Integer>{ 18, 30, 22, 15, 15 }, // eNPS — Sales/Marketing happier
    9 => new List<Integer>{ 32, 22, 18, 14, 14 }, // Burnout — Eng + Sales overrepresented
    10 => new List<Integer>{ 18, 25, 20, 22, 15 }, // Manager rating
    13 => new List<Integer>{ 22, 14, 24, 22, 18 }, // Psych safety
    22 => new List<Integer>{ 22, 32, 18, 14, 14 }, // Compensation — Sales overrepresented
    25 => new List<Integer>{ 24, 24, 20, 18, 14 } // Engagement overall
};
List<Integer> evenSplit = new List<Integer>{ 20, 20, 20, 20, 20 };

// ===== Build responses for each question (chunked DML) =====
List<SObject> responseBuffer = new List<SObject>();
Integer DML_CHUNK = 8000; // stay under 10K DML rows-per-transaction governor
Integer totalInserted = 0;

for (Integer qIdx = 0; qIdx < questionsSpec.size(); qIdx++) {
    Id qId = questionIds[qIdx];
    Integer orderNum = (Integer) questionsSpec[qIdx].get('order');
    Map<String, Integer> answers = (Map<String, Integer>) questionsSpec[qIdx].get('answers');
    List<Integer> skew = deptSkews.containsKey(orderNum) ? deptSkews.get(orderNum) : evenSplit;

    for (String answer : answers.keySet()) {
        Integer cnt = answers.get(answer);

        // Split the per-answer count across departments per the skew.
        // Last department absorbs rounding so totals match exactly.
        List<Integer> perDept = new List<Integer>();
        Integer running = 0;
        for (Integer d = 0; d < departments.size() - 1; d++) {
            Integer share = (cnt * skew[d]) / 100;
            perDept.add(share);
            running += share;
        }
        perDept.add(cnt - running); // absorb rounding remainder

        for (Integer d = 0; d < departments.size(); d++) {
            Integer dCount = perDept[d];
            for (Integer i = 0; i < dCount; i++) {
                SObject r = responseType.newSObject();
                r.put('Survey_Question__c', qId);
                r.put('Survey__c', surveyId);
                r.put('Selected_Answer__c', answer);
                r.put('Department__c', departments[d]);
                responseBuffer.add(r);

                if (responseBuffer.size() >= DML_CHUNK) {
                    insert responseBuffer;
                    totalInserted += responseBuffer.size();
                    responseBuffer.clear();
                }
            }
        }
    }
}
if (!responseBuffer.isEmpty()) {
    insert responseBuffer;
    totalInserted += responseBuffer.size();
}

System.debug('Seeded Survey: ' + surveyId);
System.debug('Total Questions: ' + questionsSpec.size());
System.debug('Total Responses: ' + totalInserted);
System.debug('SURVEY_ID:' + surveyId);
