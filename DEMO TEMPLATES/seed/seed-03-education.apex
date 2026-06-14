// ============================================================================
// Portwood DocGen DEMO — Seed 03: Students + Enrollments
//   Powers: report card, official transcript (GPA aggregates, term loops).
// Idempotent: clears all Demo_Student__c / Demo_Enrollment__c then re-inserts.
// ============================================================================
delete [SELECT Id FROM Demo_Enrollment__c];
delete [SELECT Id FROM Demo_Student__c];

Date today = Date.today();

Demo_Student__c ava = new Demo_Student__c(
    Name='Ava Thompson', Student_ID__c='S-2022-04817', Program__c='Bachelor of Science',
    Major__c='Computer Science', Minor__c='Mathematics', Email__c='ava.thompson@university.edu',
    Enrollment_Date__c=Date.newInstance(2022,9,1), Expected_Graduation__c=Date.newInstance(2026,5,15),
    GPA__c=3.78, Total_Credits__c=98, Class_Standing__c='Senior',
    Advisor__c='Dr. Helen Marsh', Honors__c='Dean\'s List (5 terms)');

Demo_Student__c liam = new Demo_Student__c(
    Name='Liam Carter', Student_ID__c='S-2023-05521', Program__c='Bachelor of Arts',
    Major__c='Economics', Email__c='liam.carter@university.edu',
    Enrollment_Date__c=Date.newInstance(2023,9,1), Expected_Graduation__c=Date.newInstance(2027,5,15),
    GPA__c=3.42, Total_Credits__c=61, Class_Standing__c='Junior', Advisor__c='Dr. Owen Pratt');

insert new List<Demo_Student__c>{ ava, liam };

// course: code|name|term|order|credits|grade|points|instructor
List<List<Object>> avaCourses = new List<List<Object>>{
    new List<Object>{'CS 101','Introduction to Programming','Fall 2022',1,4,'A',4.0,'Dr. Marsh'},
    new List<Object>{'MATH 141','Calculus I','Fall 2022',1,4,'A-',3.7,'Dr. Lee'},
    new List<Object>{'ENG 110','College Writing','Fall 2022',1,3,'B+',3.3,'Prof. Diaz'},
    new List<Object>{'CS 102','Data Structures','Spring 2023',2,4,'A','4.0','Dr. Marsh'},
    new List<Object>{'MATH 142','Calculus II','Spring 2023',2,4,'B+',3.3,'Dr. Lee'},
    new List<Object>{'PHYS 201','Physics I','Spring 2023',2,4,'A-',3.7,'Dr. Okafor'},
    new List<Object>{'CS 210','Computer Architecture','Fall 2023',3,4,'A',4.0,'Dr. Singh'},
    new List<Object>{'CS 215','Discrete Mathematics','Fall 2023',3,3,'A',4.0,'Dr. Marsh'},
    new List<Object>{'STAT 250','Probability & Statistics','Fall 2023',3,3,'B+',3.3,'Dr. Romano'},
    new List<Object>{'CS 320','Algorithms','Spring 2024',4,4,'A-',3.7,'Dr. Singh'},
    new List<Object>{'CS 330','Operating Systems','Spring 2024',4,4,'A',4.0,'Dr. Park'},
    new List<Object>{'MATH 260','Linear Algebra','Spring 2024',4,3,'A',4.0,'Dr. Lee'},
    new List<Object>{'CS 401','Databases','Fall 2024',5,4,'A',4.0,'Dr. Park'},
    new List<Object>{'CS 410','Software Engineering','Fall 2024',5,4,'A-',3.7,'Dr. Marsh'},
    new List<Object>{'PHIL 220','Ethics in Technology','Fall 2024',5,3,'B+',3.3,'Prof. Hale'},
    new List<Object>{'CS 450','Machine Learning','Spring 2025',6,4,'A',4.0,'Dr. Singh'},
    new List<Object>{'CS 460','Distributed Systems','Spring 2025',6,4,'A-',3.7,'Dr. Park'},
    new List<Object>{'CS 480','Senior Capstone I','Fall 2025',7,3,'A',4.0,'Dr. Marsh'},
    new List<Object>{'CS 490','Cloud Computing','Fall 2025',7,4,'In Progress',null,'Dr. Park'}
};
List<List<Object>> liamCourses = new List<List<Object>>{
    new List<Object>{'ECON 101','Principles of Microeconomics','Fall 2023',1,3,'A-',3.7,'Dr. Pratt'},
    new List<Object>{'ECON 102','Principles of Macroeconomics','Fall 2023',1,3,'B+',3.3,'Dr. Pratt'},
    new List<Object>{'MATH 120','Applied Calculus','Fall 2023',1,4,'B',3.0,'Dr. Lee'},
    new List<Object>{'ENG 110','College Writing','Fall 2023',1,3,'A-',3.7,'Prof. Diaz'},
    new List<Object>{'ECON 210','Intermediate Micro','Spring 2024',2,3,'A',4.0,'Dr. Pratt'},
    new List<Object>{'STAT 250','Statistics for Economics','Spring 2024',2,3,'B+',3.3,'Dr. Romano'},
    new List<Object>{'HIST 150','World History','Spring 2024',2,3,'A-',3.7,'Prof. Cole'},
    new List<Object>{'ECON 320','Econometrics','Fall 2024',3,3,'B+',3.3,'Dr. Pratt'},
    new List<Object>{'ECON 330','Money & Banking','Fall 2024',3,3,'A-',3.7,'Dr. Voss'},
    new List<Object>{'POLI 210','Public Policy','Fall 2024',3,3,'A',4.0,'Prof. Reed'},
    new List<Object>{'ECON 410','International Trade','Spring 2025',4,3,'A-',3.7,'Dr. Voss'},
    new List<Object>{'ECON 420','Labor Economics','Spring 2025',4,3,'B+',3.3,'Dr. Pratt'},
    new List<Object>{'ECON 450','Behavioral Economics','Fall 2025',5,3,'In Progress',null,'Dr. Voss'}
};

List<Demo_Enrollment__c> enrolls = new List<Demo_Enrollment__c>();
for (List<Object> c : avaCourses) {
    Decimal gp = (c[6] == null) ? null : Decimal.valueOf(String.valueOf(c[6]));
    Decimal credits = Decimal.valueOf(String.valueOf(c[4]));
    enrolls.add(new Demo_Enrollment__c(Student__c=ava.Id, Course_Code__c=(String)c[0],
        Course_Name__c=(String)c[1], Term__c=(String)c[2], Term_Order__c=(Integer)c[3],
        Credits__c=credits, Grade__c=(gp==null ? null : (String)c[5]), Grade_Points__c=gp,
        Quality_Points__c = gp==null ? null : (gp*credits),
        Instructor__c=(String)c[7], Status__c = gp==null ? 'In Progress' : 'Completed'));
}
for (List<Object> c : liamCourses) {
    Decimal gp = (c[6] == null) ? null : Decimal.valueOf(String.valueOf(c[6]));
    Decimal credits = Decimal.valueOf(String.valueOf(c[4]));
    enrolls.add(new Demo_Enrollment__c(Student__c=liam.Id, Course_Code__c=(String)c[0],
        Course_Name__c=(String)c[1], Term__c=(String)c[2], Term_Order__c=(Integer)c[3],
        Credits__c=credits, Grade__c=(gp==null ? null : (String)c[5]), Grade_Points__c=gp,
        Quality_Points__c = gp==null ? null : (gp*credits),
        Instructor__c=(String)c[7], Status__c = gp==null ? 'In Progress' : 'Completed'));
}
insert enrolls;

System.debug('SEED-03 EDUCATION DONE');
System.debug('Ava Thompson: ' + ava.Id + '  courses=' + avaCourses.size());
System.debug('Liam Carter: ' + liam.Id + '  courses=' + liamCourses.size());
