// ============================================================================
// Portwood DocGen DEMO — Seed 02: Events + Attendees
//   Powers: event ticket (QR), attendee badge, event program, attendee roster.
// Idempotent: clears all Demo_Event__c / Demo_Attendee__c then re-inserts.
// ============================================================================
delete [SELECT Id FROM Demo_Attendee__c];
delete [SELECT Id FROM Demo_Event__c];

Date today = Date.today();

Demo_Event__c summit = new Demo_Event__c(
    Name = 'Portwood Summit 2026',
    Event_Date__c = today.addDays(30), End_Date__c = today.addDays(32),
    Venue__c = 'Moscone West', Address__c = '800 Howard St',
    City__c = 'San Francisco', State__c = 'CA', Postal_Code__c = '94103',
    Organizer__c = 'Portwood Global Solutions', Contact_Email__c = 'events@portwood.dev',
    Capacity__c = 1200, Registration_URL__c = 'https://summit.portwood.dev/register',
    Description__c = 'The annual conference for document automation on Salesforce. Three days of sessions, hands-on labs, and the partner expo.');

Demo_Event__c gala = new Demo_Event__c(
    Name = 'Riverside Conservation Gala 2026',
    Event_Date__c = today.addDays(21), End_Date__c = today.addDays(21),
    Venue__c = 'The Portland Art Museum', Address__c = '1219 SW Park Ave',
    City__c = 'Portland', State__c = 'OR', Postal_Code__c = '97205',
    Organizer__c = 'Rivers Alliance Foundation', Contact_Email__c = 'gala@riversalliance.org',
    Capacity__c = 300, Registration_URL__c = 'https://riversalliance.org/gala',
    Description__c = 'An evening of dinner and giving in support of river restoration across the Pacific Northwest.');

insert new List<Demo_Event__c>{ summit, gala };

// Attendee builder: name|email|company|title|type|seat|amount
List<Demo_Attendee__c> atts = new List<Demo_Attendee__c>();
Integer code = 1;
List<List<String>> summitAtt = new List<List<String>>{
    new List<String>{'Dana Whitfield','dana.whitfield@northwindtraders.com','Northwind Traders','VP of Operations','VIP','A-12','1499'},
    new List<String>{'Marcus Reyes','marcus.reyes@northwindtraders.com','Northwind Traders','Procurement Manager','General Admission','C-44','799'},
    new List<String>{'Priya Anand','priya.anand@summitcomponents.com','Summit Components','CFO','VIP','A-08','1499'},
    new List<String>{'Sofia Marino','sofia.marino@brightpath.io','BrightPath','Solutions Architect','Speaker','S-02','0'},
    new List<String>{'Jamal Carter','jamal.carter@helix.dev','Helix Systems','Engineering Lead','General Admission','D-15','799'},
    new List<String>{'Wei Chen','wei.chen@apexgrid.com','ApexGrid','Salesforce Admin','General Admission','D-16','799'},
    new List<String>{'Olivia Park','olivia.park@northstar.org','Northstar','Program Director','VIP','A-09','1499'},
    new List<String>{'Diego Ramos','diego.ramos@summitcomponents.com','Summit Components','IT Manager','General Admission','C-45','799'},
    new List<String>{'Hannah Goldberg','hannah.g@meridian.co','Meridian','RevOps Lead','Speaker','S-03','0'},
    new List<String>{'Tom Becker','tom.becker@fieldworks.io','FieldWorks','Founder','Sponsor','SP-01','5000'},
    new List<String>{'Aisha Khan','aisha.khan@lumen.app','Lumen','Product Manager','General Admission','D-17','799'},
    new List<String>{'Greg Olsen','greg.olsen@portwood.dev','Portwood Global','Event Staff','Staff','-','0'}
};
for (List<String> a : summitAtt) {
    atts.add(new Demo_Attendee__c(Name=a[0], Event__c=summit.Id, Email__c=a[1], Company__c=a[2],
        Title__c=a[3], Ticket_Type__c=a[4], Seat__c=a[5], Amount_Paid__c=Decimal.valueOf(a[6]),
        Ticket_Code__c='PSUMMIT26-' + String.valueOf(code++).leftPad(5,'0'),
        Checked_In__c=false));
}
List<List<String>> galaAtt = new List<List<String>>{
    new List<String>{'Evelyn Brooks','evelyn.brooks@riversalliance.org','Rivers Alliance','Development Director','Staff','-','0'},
    new List<String>{'Robert Vance','robert.vance@vancefoundation.org','Vance Family Foundation','Trustee','VIP','T-01','2500'},
    new List<String>{'Maria Santos','maria.santos@gmail.com','Individual Donor','Patron','VIP','T-02','1000'},
    new List<String>{'James Liu','james.liu@evergreen.com','Evergreen Capital','Partner','Sponsor','SP-01','10000'},
    new List<String>{'Nina Patel','nina.patel@gmail.com','Individual Donor','Supporter','General Admission','G-21','250'},
    new List<String>{'Carlos Mendez','carlos.m@riopartners.com','Rio Partners','Principal','VIP','T-03','1000'},
    new List<String>{'Grace Kim','grace.kim@gmail.com','Individual Donor','Supporter','General Admission','G-22','250'},
    new List<String>{'Daniel Foster','dan.foster@summitbank.com','Summit Bank','Community Relations','Sponsor','SP-02','5000'}
};
code = 1;
for (List<String> a : galaAtt) {
    atts.add(new Demo_Attendee__c(Name=a[0], Event__c=gala.Id, Email__c=a[1], Company__c=a[2],
        Title__c=a[3], Ticket_Type__c=a[4], Seat__c=a[5], Amount_Paid__c=Decimal.valueOf(a[6]),
        Ticket_Code__c='GALA26-' + String.valueOf(code++).leftPad(5,'0'),
        Checked_In__c=false));
}
insert atts;

System.debug('SEED-02 EVENTS DONE');
System.debug('Portwood Summit 2026: ' + summit.Id + '  attendees=' + summitAtt.size());
System.debug('Riverside Gala 2026: ' + gala.Id + '  attendees=' + galaAtt.size());
