#!/bin/bash
# Build and render the 25-question Employee Engagement demo end-to-end.
#
# Usage:
#   bash scripts/build-25-question-demo.sh                          # portwood-staging, no email
#   bash scripts/build-25-question-demo.sh <org-alias>              # custom org
#   bash scripts/build-25-question-demo.sh <org-alias> <email>      # also email PDF to recipient
#
# Steps:
#   1. Deploy code changes (chart resolver + service)
#   2. Refresh "Survey Chart Example" template HTML from docs/SurveyChartExample.html
#   3. Ensure proper Query_Config__c + Header/Footer fields are set
#   4. Seed 25-question Employee Engagement survey (~4,200 responses)
#   5. Render PDF via DocGenService.generateDocument
#   6. (Optional) email PDF as an attachment to the provided address

set -euo pipefail

ORG="${1:-portwood-staging}"
EMAIL="${2:-}"

echo "================================================================"
echo "  DocGen v1.91 — 25-question Employee Engagement demo"
echo "  Target org : $ORG"
if [ -n "$EMAIL" ]; then
    echo "  Email to   : $EMAIL"
fi
echo "================================================================"

# ----- 1. Deploy code + demo-schema -----
echo ""
echo "[1/6] Deploying chart resolver + service updates + demo schema..."
sf project deploy start \
    --source-dir force-app/main/default/classes/DocGenChartBucketResolver.cls \
    --source-dir force-app/main/default/classes/DocGenService.cls \
    --source-dir demo-schema \
    --target-org "$ORG" \
    --ignore-conflicts \
    --wait 10 \
    > /tmp/build-25q-deploy.log 2>&1 || {
    echo "Deploy failed; see /tmp/build-25q-deploy.log"
    tail -20 /tmp/build-25q-deploy.log
    exit 1
}
# Re-assign permset in case new field perms were added
sf org assign permset --name Survey_Demo --target-org "$ORG" > /dev/null 2>&1 || true
echo "      code + schema OK"

# ----- 2. Refresh template HTML -----
echo ""
echo "[2/6] Refreshing template HTML + Query_Config + Header/Footer..."
TEMPLATE_HTML="docs/SurveyChartExample.html"
if [ ! -f "$TEMPLATE_HTML" ]; then
    echo "ERROR: $TEMPLATE_HTML not found. Run from project root."
    exit 1
fi

# Set up the template record first via apex (small, well under 20KB limit),
# THEN upload the HTML body via REST API (no Apex size cap).
cat > /tmp/build-25q-template-refresh.apex <<EOF
String qc = 'Name, (SELECT Id, Question_Text__c, Display_Order__c FROM Survey_Questions__r ORDER BY Display_Order__c ASC)';

String headerHtml =
    '<table style="width:100%;border-collapse:collapse;font-family:Helvetica,Arial,sans-serif;border-bottom:2px solid #1e3a8a;padding-bottom:4px;">' +
        '<tr>' +
            '<td style="text-align:left;font-size:9pt;color:#1e3a8a;font-weight:bold;">{Name}</td>' +
            '<td style="text-align:right;font-size:9pt;color:#6b7280;">Survey Response Report</td>' +
        '</tr>' +
    '</table>';

String footerHtml =
    '<table style="width:100%;border-collapse:collapse;font-family:Helvetica,Arial,sans-serif;border-top:1px solid #d1d5db;padding-top:4px;">' +
        '<tr>' +
            '<td style="text-align:left;font-size:8pt;color:#9ca3af;">Generated {today:date}</td>' +
            '<td style="text-align:right;font-size:8pt;color:#9ca3af;">Page {PageNumber} of {TotalPages}</td>' +
        '</tr>' +
    '</table>';

// Find or recreate the template
List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = 'Survey Chart Example' LIMIT 1];
DocGen_Template__c tpl;
if (existing.isEmpty()) {
    tpl = new DocGen_Template__c(
        Name = 'Survey Chart Example',
        Type__c = 'HTML',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Survey__c',
        Query_Config__c = qc,
        Description__c = 'v1.91 25-question survey chart demo'
    );
    insert tpl;
} else {
    tpl = existing[0];
}
tpl.Type__c = 'HTML';
tpl.Output_Format__c = 'PDF';
tpl.Base_Object_API__c = 'Survey__c';
tpl.Query_Config__c = qc;
tpl.Header_Html__c = headerHtml;
tpl.Footer_Html__c = footerHtml;
update tpl;

// Deactivate old versions
List<DocGen_Template_Version__c> oldVersions = [SELECT Id, Is_Active__c FROM DocGen_Template_Version__c WHERE Template__c = :tpl.Id];
for (DocGen_Template_Version__c v : oldVersions) { v.Is_Active__c = false; }
if (!oldVersions.isEmpty()) update oldVersions;

System.debug('TPL_ID:' + tpl.Id);
EOF

TPL_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/build-25q-template-refresh.apex 2>&1)
TPL_ID=$(echo "$TPL_OUTPUT" | grep -oE 'TPL_ID:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
if [ -z "$TPL_ID" ]; then
    echo "ERROR: Template setup failed."
    echo "$TPL_OUTPUT" | tail -20
    exit 1
fi

# Upload ContentVersion VersionData via REST API (bypasses Apex 20KB limit)
# Build multipart/form-data body and POST to /services/data/v66.0/sobjects/ContentVersion
INSTANCE_URL=$(sf org display --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['instanceUrl'])")
ACCESS_TOKEN=$(sf org display --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['accessToken'])")

# Build the multipart body
BOUNDARY="docgen$(date +%s)"
ENTITY_JSON='{"Title":"Survey Chart Example v1.91","PathOnClient":"survey-chart-example.html","FirstPublishLocationId":"'"$TPL_ID"'"}'

MULTIPART_FILE=$(mktemp /tmp/build-25q-multipart.XXXXXX)
{
    printf -- "--%s\r\n" "$BOUNDARY"
    printf -- "Content-Disposition: form-data; name=\"entity_document\";\r\n"
    printf -- "Content-Type: application/json\r\n"
    printf -- "\r\n"
    printf -- "%s\r\n" "$ENTITY_JSON"
    printf -- "--%s\r\n" "$BOUNDARY"
    printf -- "Content-Disposition: form-data; name=\"VersionData\"; filename=\"survey-chart-example.html\"\r\n"
    printf -- "Content-Type: text/html\r\n"
    printf -- "\r\n"
    cat "$TEMPLATE_HTML"
    printf -- "\r\n--%s--\r\n" "$BOUNDARY"
} > "$MULTIPART_FILE"

CV_CREATE_RESP=$(curl -s -X POST \
    "$INSTANCE_URL/services/data/v66.0/sobjects/ContentVersion" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: multipart/form-data; boundary=$BOUNDARY" \
    --data-binary "@$MULTIPART_FILE")
rm -f "$MULTIPART_FILE"

CV_ID_NEW=$(echo "$CV_CREATE_RESP" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('id',''))" 2>/dev/null)
if [ -z "$CV_ID_NEW" ]; then
    echo "ERROR: ContentVersion upload failed."
    echo "$CV_CREATE_RESP" | head -10
    exit 1
fi

# Now create the DocGen_Template_Version__c pointing at this CV
cat > /tmp/build-25q-link-version.apex <<EOF
Id tplId = '$TPL_ID';
Id cvId = '$CV_ID_NEW';
String qc = 'Name, (SELECT Id, Question_Text__c, Display_Order__c FROM Survey_Questions__r ORDER BY Display_Order__c ASC)';

insert new DocGen_Template_Version__c(
    Template__c = tplId,
    Content_Version_Id__c = cvId,
    Is_Active__c = true,
    Type__c = 'HTML',
    Base_Object_API__c = 'Survey__c',
    Query_Config__c = qc
);
System.debug('Linked CV $CV_ID_NEW to template $TPL_ID');
EOF
sf apex run --target-org "$ORG" -f /tmp/build-25q-link-version.apex > /dev/null 2>&1 || {
    echo "ERROR: failed to create DocGen_Template_Version__c"
    exit 1
}

echo "      template OK — $TPL_ID  (CV: $CV_ID_NEW)"

# ----- 3. Seed survey -----
echo ""
echo "[3/6] Seeding 25-question survey..."
SEED_OUTPUT=$(sf apex run --target-org "$ORG" -f scripts/demo-25-question-seed.apex 2>&1)
SURVEY_ID=$(echo "$SEED_OUTPUT" | grep -oE 'SURVEY_ID:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
TOTAL_RESP=$(echo "$SEED_OUTPUT" | grep -oE 'Total Responses: [0-9]+' | head -1 | cut -d' ' -f3)
if [ -z "$SURVEY_ID" ]; then
    echo "ERROR: Seed failed."
    echo "$SEED_OUTPUT" | tail -30
    exit 1
fi
echo "      seed OK — Survey $SURVEY_ID, $TOTAL_RESP responses"

# ----- 4. Generate PDF -----
echo ""
echo "[4/6] Generating PDF via DocGen runner..."
cat > /tmp/build-25q-generate.apex <<EOF
Id tplId = '$TPL_ID';
Id surveyId = '$SURVEY_ID';

Id contentDocId = DocGenService.generateDocument(tplId, surveyId, 'PDF');
if (contentDocId == null) {
    System.debug('ERROR: generateDocument returned null');
    return;
}
ContentVersion cv = [
    SELECT Id FROM ContentVersion
    WHERE ContentDocumentId = :contentDocId AND IsLatest = true
    LIMIT 1
];
System.debug('CV_ID:' + cv.Id);
System.debug('PDF generated for Survey ' + surveyId);
EOF

GEN_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/build-25q-generate.apex 2>&1)
CV_ID=$(echo "$GEN_OUTPUT" | grep -oE 'CV_ID:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
if [ -z "$CV_ID" ]; then
    echo "ERROR: PDF generation failed."
    echo "$GEN_OUTPUT" | tail -30
    exit 1
fi
echo "      PDF generated — ContentVersion $CV_ID"

# ----- 5. (Optional) email -----
if [ -n "$EMAIL" ]; then
    echo ""
    echo "[5/6] Emailing PDF to $EMAIL..."
    cat > /tmp/build-25q-email.apex <<EOF
Id cvId = '$CV_ID';
String toAddr = '$EMAIL';

ContentVersion cv = [SELECT Id, Title, FileExtension, VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];

Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
att.setFileName(cv.Title + '.' + cv.FileExtension);
att.setBody(cv.VersionData);
att.setContentType('application/pdf');

Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
msg.setToAddresses(new List<String>{ toAddr });
msg.setSubject('DocGen v1.91 demo — 25-question Employee Engagement Survey');
msg.setPlainTextBody(
    'Attached is the DocGen v1.91 demo PDF.\n\n' +
    'It renders a 25-question Employee Engagement survey using the new {#ChartBucket} aggregation tag.\n\n' +
    '— Cover page + table of contents\n' +
    '— One page per question with auto page-break\n' +
    '— Running header/footer (Page X of Y) on every page\n' +
    '— Per-question chart aggregates ~4,200 responses via server-side SOQL GROUP BY\n' +
    '— Executive summary at the end\n\n' +
    'Generated automatically by scripts/build-25-question-demo.sh.'
);
msg.setSaveAsActivity(false);
msg.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });

Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
for (Messaging.SendEmailResult r : results) {
    if (r.isSuccess()) {
        System.debug('Email sent successfully to ' + toAddr);
    } else {
        for (Messaging.SendEmailError e : r.getErrors()) {
            System.debug('Email send FAILED: ' + e.getStatusCode() + ' — ' + e.getMessage());
        }
    }
}
EOF

    EMAIL_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/build-25q-email.apex 2>&1)
    if echo "$EMAIL_OUTPUT" | grep -q "Email sent successfully"; then
        echo "      email OK"
    else
        echo "      email may have failed — output below:"
        echo "$EMAIL_OUTPUT" | grep -E 'USER_DEBUG|FAILED|Error|ERROR' | tail -10
    fi
fi

# ----- 6. Report -----
echo ""
echo "================================================================"
echo "  Done."
echo ""
echo "  Survey Id       : $SURVEY_ID"
echo "  Template Id     : $TPL_ID"
echo "  ContentVersion  : $CV_ID  (the generated PDF)"
echo ""
echo "  Open runner UI:"
echo "    sf org open --target-org $ORG --path /lightning/r/Survey__c/$SURVEY_ID/view"
echo ""
echo "  Open generated PDF:"
echo "    sf org open --target-org $ORG --path /sfc/servlet.shepherd/version/download/$CV_ID"
echo "================================================================"
