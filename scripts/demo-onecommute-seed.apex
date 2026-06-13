// OneCommute custom-object demo seed data.
// Run after deploying demos/onecommute/force-app.
// Run: sf apex run --target-org <org> -f scripts/demo-onecommute-seed.apex

String siteName = 'OneCommute Demo - 925 NorthPoint Parkway';
String templateName = 'OneCommute Demo PowerPoint Chart Report';

Schema.SObjectType siteType = Schema.getGlobalDescribe().get('OneCommute_Site__c');
Schema.SObjectType employerType = Schema.getGlobalDescribe().get('OneCommute_Employer__c');
Schema.SObjectType responseType = Schema.getGlobalDescribe().get('OneCommute_Survey_Response__c');
Schema.SObjectType tripType = Schema.getGlobalDescribe().get('OneCommute_Trip_Count__c');

if (siteType == null || employerType == null || responseType == null || tripType == null) {
    System.assert(false, 'OneCommute demo objects are not deployed.');
}

List<SObject> oldSites = Database.query('SELECT Id FROM OneCommute_Site__c WHERE Name = :siteName');
if (!oldSites.isEmpty()) {
    Set<Id> siteIds = new Set<Id>();
    for (SObject s : oldSites) {
        siteIds.add((Id) s.get('Id'));
    }
    delete Database.query('SELECT Id FROM OneCommute_Survey_Response__c WHERE Site__c IN :siteIds');
    delete Database.query('SELECT Id FROM OneCommute_Trip_Count__c WHERE Site__c IN :siteIds');
    delete Database.query('SELECT Id FROM OneCommute_Employer__c WHERE Site__c IN :siteIds');
    delete oldSites;
}

List<DocGen_Template__c> oldTemplates = [SELECT Id FROM DocGen_Template__c WHERE Name = :templateName];
if (!oldTemplates.isEmpty()) {
    Set<Id> templateIds = new Set<Id>();
    for (DocGen_Template__c t : oldTemplates) {
        templateIds.add(t.Id);
    }
    delete [SELECT Id FROM DocGen_Template_Version__c WHERE Template__c IN :templateIds];
    delete oldTemplates;
}

SObject site = siteType.newSObject();
site.put('Name', siteName);
site.put('Client_Name__c', 'OneCommute');
site.put('Address__c', '925 NorthPoint Parkway');
site.put('City__c', 'Alpharetta');
site.put('State__c', 'GA');
site.put('Postal_Code__c', '30004');
site.put('Report_Month__c', 'November');
site.put('Reporting_Year__c', 2025);
site.put('Total_Employees__c', 958);
site.put('Alt_Mode_Target__c', 35.0);
site.put('Alt_Mode_Rate__c', 48.6);
site.put(
    'Summary__c',
    'OneCommute manages commuter survey, employer outreach, ordinance compliance, and mobility analytics data in one Salesforce-native operating system for TDM teams.'
);
insert site;
Id siteId = (Id) site.get('Id');

List<String> employerNames = new List<String>{
    'Bluegrain Sandwich Market',
    'CytomX Therapeutics',
    'Denali',
    'Foundry & Lux - Cafe Bon Appetit',
    'Frontier',
    'Healthpeak - The Cove',
    'Kardigan',
    'Marea Therapeutics',
    'Maze Therapeutics',
    'Nura Bio',
    'Pfizer',
    'Surrozen',
    'Sutro BioPharma',
    'Tenaya Therapeutics',
    'YogaSix Oyster Point'
};
List<Integer> employeeCounts = new List<Integer>{ 5, 68, 326, 24, 26, 5, 15, 24, 108, 20, 105, 41, 75, 78, 8 };
List<Integer> responseCounts = new List<Integer>{ 1, 60, 230, 20, 12, 2, 11, 11, 85, 17, 94, 28, 38, 45, 7 };

List<SObject> employers = new List<SObject>();
for (Integer i = 0; i < employerNames.size(); i++) {
    SObject employer = employerType.newSObject();
    employer.put('Name', employerNames[i]);
    employer.put('Site__c', siteId);
    employer.put('Employee_Count__c', employeeCounts[i]);
    employer.put('Response_Count__c', responseCounts[i]);
    employers.add(employer);
}
insert employers;

List<String> commuteModes = new List<String>{
    'Drive Alone',
    'Teleworked',
    'Public transit/private shuttle',
    'Carpool',
    'Biked/scooter/e-bike',
    'Taxi/Uber/Lyft',
    'Motorcycle',
    'Walk/Jog/skateboard',
    'Vanpool',
    'Did not work this day'
};
List<Integer> commuteWeights = new List<Integer>{ 305, 201, 90, 26, 9, 5, 3, 1, 1, 49 };

List<String> alternativeChoices = new List<String>{
    'Public/Private Transit',
    'Carpool',
    'Bicycle/scooter/e-bike',
    'Vanpool',
    'Telework/Work remotely',
    'Walk/jog'
};
List<Integer> alternativeWeights = new List<Integer>{ 364, 213, 105, 87, 81, 24 };

List<String> shuttleChoices = new List<String>{
    'FREE Oyster Point SSF Ferry Shuttle',
    'FREE Genentech SSF Caltrain Station Shuttle',
    'FREE Oyster Point SSF BART Shuttle',
    'FREE Oyster Point SSF Caltrain Shuttle',
    'FREE Genentech Glen Park BART Shuttle'
};
List<Integer> shuttleWeights = new List<Integer>{ 94, 160, 171, 195, 239 };

List<String> resourceChoices = new List<String>{
    'FREE Guaranteed Ride Home Program',
    'FREE Try Transit $25 Clipper Card',
    'Transit information',
    '$100 yearly carpool reward',
    'Carpool matching tool/assistance',
    '$500 monthly vanpool subsidy',
    '$100 yearly bike-to-work reward',
    'Secure on-site bicycle parking',
    'Trip planning assistance',
    '$100 yearly vanpool reward'
};
List<Integer> resourceWeights = new List<Integer>{ 340, 279, 241, 133, 141, 90, 90, 80, 65, 57 };
List<String> years = new List<String>{ '2023', '2024', '2025' };

List<String> commutePool = new List<String>();
for (Integer i = 0; i < commuteModes.size(); i++) {
    for (Integer j = 0; j < commuteWeights[i]; j++) {
        commutePool.add(commuteModes[i]);
    }
}
List<String> alternativePool = new List<String>();
for (Integer i = 0; i < alternativeChoices.size(); i++) {
    for (Integer j = 0; j < alternativeWeights[i]; j++) {
        alternativePool.add(alternativeChoices[i]);
    }
}
List<String> shuttlePool = new List<String>();
for (Integer i = 0; i < shuttleChoices.size(); i++) {
    for (Integer j = 0; j < shuttleWeights[i]; j++) {
        shuttlePool.add(shuttleChoices[i]);
    }
}
List<String> resourcePool = new List<String>();
for (Integer i = 0; i < resourceChoices.size(); i++) {
    for (Integer j = 0; j < resourceWeights[i]; j++) {
        resourcePool.add(resourceChoices[i]);
    }
}

List<SObject> responses = new List<SObject>();
Integer responseSeed = 0;
for (Integer e = 0; e < employers.size(); e++) {
    for (Integer i = 0; i < responseCounts[e]; i++) {
        String resource = resourcePool[Math.mod(responseSeed * 7, resourcePool.size())];
        String secondResource = resourcePool[Math.mod(responseSeed * 11, resourcePool.size())];
        SObject response = responseType.newSObject();
        response.put('Site__c', siteId);
        response.put('Employer__c', (Id) employers[e].get('Id'));
        response.put('Commute_Mode__c', commutePool[Math.mod(responseSeed, commutePool.size())]);
        response.put('Alternative_Mode__c', alternativePool[Math.mod(responseSeed * 3, alternativePool.size())]);
        response.put('Shuttle_Interest__c', shuttlePool[Math.mod(responseSeed * 5, shuttlePool.size())]);
        response.put('Resource_Interest__c', resource);
        response.put('Resource_Interests__c', resource == secondResource ? resource : resource + ';' + secondResource);
        response.put('Survey_Year__c', years[Math.mod(responseSeed, years.size())]);
        responses.add(response);
        responseSeed++;
    }
}
insert responses;

List<SObject> trips = new List<SObject>();
List<String> tripNames = new List<String>{
    'Parking Garage EB',
    'Parking Garage WB',
    'Driveway 2 EB',
    'Driveway 2 WB',
    'Driveway 3 EB',
    'Driveway 3 WB'
};
List<String> locations = new List<String>{
    'Parking Garage',
    'Parking Garage',
    'Driveway 2',
    'Driveway 2',
    'Driveway 3',
    'Driveway 3'
};
List<String> directions = new List<String>{ 'EB', 'WB', 'EB', 'WB', 'EB', 'WB' };
List<Integer> daily = new List<Integer>{ 81, 80, 264, 502, 245, 255 };
List<Integer> midweek = new List<Integer>{ 85, 84, 272, 534, 235, 248 };
List<Integer> amPeak = new List<Integer>{ 6, 24, 21, 75, 19, 23 };
List<Integer> pmPeak = new List<Integer>{ 17, 7, 33, 39, 26, 24 };
for (Integer i = 0; i < tripNames.size(); i++) {
    SObject trip = tripType.newSObject();
    trip.put('Name', tripNames[i]);
    trip.put('Site__c', siteId);
    trip.put('Location__c', locations[i]);
    trip.put('Direction__c', directions[i]);
    trip.put('Daily_Average__c', daily[i]);
    trip.put('Midweek_Average__c', midweek[i]);
    trip.put('AM_Peak__c', amPeak[i]);
    trip.put('PM_Peak__c', pmPeak[i]);
    trips.add(trip);
}
insert trips;

System.debug('ONECOMMUTE DEMO SITE: ' + siteId);
System.debug('ONECOMMUTE DEMO EMPLOYERS: ' + employers.size());
System.debug('ONECOMMUTE DEMO SURVEY RESPONSES: ' + responses.size());
