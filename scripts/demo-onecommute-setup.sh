#!/usr/bin/env bash
set -euo pipefail

ORG_ALIAS="${1:-portwood-staging}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_SOURCE="$ROOT_DIR/demos/onecommute/force-app"
PPTX_PATH="$ROOT_DIR/docs/OneCommuteChartDemoTemplate.pptx"
TEMPLATE_NAME="OneCommute Demo PowerPoint Chart Report"
SITE_NAME="OneCommute Demo - 925 NorthPoint Parkway"

echo "Building the OneCommute PowerPoint template..."
node "$ROOT_DIR/scripts/build-onecommute-chart-demo.mjs"

echo "Deploying OneCommute demo objects to $ORG_ALIAS..."
sf project deploy start --target-org "$ORG_ALIAS" --source-dir "$DEMO_SOURCE" --wait 10

echo "Assigning OneCommute demo permissions..."
ORG_USERNAME="$(sf org display --target-org "$ORG_ALIAS" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>console.log(JSON.parse(s).result.username));')"
PERMSET_ASSIGNED="$(sf data query --target-org "$ORG_ALIAS" --query "SELECT Id FROM PermissionSetAssignment WHERE PermissionSet.Name = 'OneCommute_Demo' AND Assignee.Username = '$ORG_USERNAME'" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>console.log(JSON.parse(s).result.totalSize));')"
if [ "$PERMSET_ASSIGNED" = "0" ]; then
    sf org assign permset --target-org "$ORG_ALIAS" --name OneCommute_Demo
else
    echo "OneCommute_Demo is already assigned to $ORG_USERNAME."
fi

echo "Seeding OneCommute custom-object data..."
sf apex run --target-org "$ORG_ALIAS" -f "$ROOT_DIR/scripts/demo-onecommute-seed.apex"

echo "Uploading PowerPoint template..."
ORG_DISPLAY_JSON="$(sf org display --target-org "$ORG_ALIAS" --json)"
ACCESS_TOKEN="$(printf '%s' "$ORG_DISPLAY_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>console.log(JSON.parse(s).result.accessToken));')"
INSTANCE_URL="$(printf '%s' "$ORG_DISPLAY_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>console.log(JSON.parse(s).result.instanceUrl));')"
CV_JSON="$(
    curl -sS --fail-with-body "$INSTANCE_URL/services/data/v66.0/sobjects/ContentVersion" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -F 'entity_content={"Title":"OneCommuteChartDemoTemplate","PathOnClient":"OneCommuteChartDemoTemplate.pptx"};type=application/json' \
        -F "VersionData=@$PPTX_PATH;type=application/vnd.openxmlformats-officedocument.presentationml.presentation"
)"
CV_ID="$(printf '%s' "$CV_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>console.log(JSON.parse(s).id));')"

TMP_APEX="$(mktemp "${TMPDIR:-/tmp}/onecommute-template.XXXXXX.apex")"
cat > "$TMP_APEX" <<APEX
String templateName = '$TEMPLATE_NAME';
String siteName = '$SITE_NAME';
Id cvId = '$CV_ID';

SObject site = Database.query('SELECT Id FROM OneCommute_Site__c WHERE Name = :siteName LIMIT 1');
String queryConfig =
    '{"v":3,"root":"OneCommute_Site__c","nodes":[' +
    '{"id":"n0","object":"OneCommute_Site__c","fields":["Name","Client_Name__c","Address__c","City__c","State__c","Postal_Code__c","Report_Month__c","Reporting_Year__c","Total_Employees__c","Alt_Mode_Target__c","Alt_Mode_Rate__c","Summary__c"],"parentNode":null,"lookupField":null,"relationshipName":null},' +
    '{"id":"n1","object":"OneCommute_Employer__c","fields":["Name","Employee_Count__c","Response_Count__c","Response_Rate__c"],"parentNode":"n0","lookupField":"Site__c","relationshipName":"Employers__r"},' +
    '{"id":"n2","object":"OneCommute_Trip_Count__c","fields":["Name","Location__c","Direction__c","Daily_Average__c","Midweek_Average__c","AM_Peak__c","PM_Peak__c"],"parentNode":"n0","lookupField":"Site__c","relationshipName":"Trip_Counts__r"},' +
    '{"id":"n3","object":"OneCommute_Survey_Response__c","fields":["Name","Employer__c","Commute_Mode__c","Alternative_Mode__c","Shuttle_Interest__c","Resource_Interests__c","Survey_Year__c"],"parentNode":"n0","lookupField":"Site__c","relationshipName":"Survey_Responses__r"}' +
    ']}';

DocGen_Template__c template = new DocGen_Template__c(
    Name = templateName,
    Type__c = 'PowerPoint',
    Output_Format__c = 'Native',
    Base_Object_API__c = 'OneCommute_Site__c',
    Query_Config__c = queryConfig,
    Document_Title_Format__c = 'OneCommute Commuter Report - {Name}',
    Description__c = 'OneCommute-specific PowerPoint report generated from live custom-object survey data.',
    Category__c = 'OneCommute Demo',
    Is_Active__c = true,
    Test_Record_Id__c = String.valueOf(site.Id)
);
insert template;

DocGen_Template_Version__c version = new DocGen_Template_Version__c(
    Template__c = template.Id,
    Is_Active__c = true,
    Content_Version_Id__c = cvId,
    Query_Config__c = queryConfig,
    Type__c = 'PowerPoint',
    Output_Format__c = 'Native',
    Base_Object_API__c = 'OneCommute_Site__c',
    Description__c = template.Description__c,
    Category__c = template.Category__c
);
insert version;

DocGenService.extractAndSaveTemplateImages(template.Id, version.Id);
version.Pre_Decomposition_Status__c = 'Complete';
update version;
System.debug('ONECOMMUTE DEMO TEMPLATE: ' + template.Id);
System.debug('ONECOMMUTE DEMO VERSION: ' + version.Id);
System.debug('ONECOMMUTE DEMO SOURCE CV: ' + cvId);
APEX

echo "Creating DocGen template and pre-decomposing PPTX..."
sf apex run --target-org "$ORG_ALIAS" -f "$TMP_APEX"
rm -f "$TMP_APEX"

echo "Done. Run the demo through DocGen Runner on the OneCommute Site record:"
echo "  Template: $TEMPLATE_NAME"
echo "  Base record: $SITE_NAME"
