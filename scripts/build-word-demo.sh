#!/bin/bash
# Upload the docs/SurveyChartExample.docx Word template to DocGen, render
# to PDF against the existing Employee Engagement seed, and emit a public link.
#
# Usage: bash scripts/build-word-demo.sh [org-alias]

set -euo pipefail
ORG="${1:-portwood-staging}"
DOCX_PATH="docs/SurveyChartExample.docx"

if [ ! -f "$DOCX_PATH" ]; then
    echo "ERROR: $DOCX_PATH not found. Run scripts/build-word-chart-template.py first."
    exit 1
fi

echo "================================================================"
echo "  DocGen v1.91 — Word .docx chart template demo"
echo "  Target org : $ORG"
echo "================================================================"

# Find the most recent Employee Engagement survey for rendering
echo ""
echo "[1/5] Locating existing Employee Engagement survey..."
SURVEY_ID=$(sf data query --target-org "$ORG" \
    --query "SELECT Id FROM Survey__c WHERE Name = 'Employee Engagement 2026' ORDER BY CreatedDate DESC LIMIT 1" \
    --result-format csv 2>/dev/null | tail -1)
if [ -z "$SURVEY_ID" ]; then
    echo "ERROR: No 'Employee Engagement 2026' survey found. Run build-25-question-demo.sh first."
    exit 1
fi
echo "      survey OK — $SURVEY_ID"

# Set up template record
echo ""
echo "[2/5] Setting up Word template record..."
cat > /tmp/word-template-setup.apex <<'EOF'
String qc = 'Name, (SELECT Id, Question_Text__c, Display_Order__c FROM Survey_Questions__r ORDER BY Display_Order__c ASC)';

List<DocGen_Template__c> existing = [SELECT Id FROM DocGen_Template__c WHERE Name = 'Survey Chart Example (Word)' LIMIT 1];
DocGen_Template__c tpl;
if (existing.isEmpty()) {
    tpl = new DocGen_Template__c(
        Name = 'Survey Chart Example (Word)',
        Type__c = 'Word',
        Output_Format__c = 'PDF',
        Base_Object_API__c = 'Survey__c',
        Query_Config__c = qc,
        Description__c = 'v1.91 chart template authored in Microsoft Word'
    );
    insert tpl;
} else {
    tpl = existing[0];
}
tpl.Type__c = 'Word';
tpl.Output_Format__c = 'PDF';
tpl.Base_Object_API__c = 'Survey__c';
tpl.Query_Config__c = qc;
update tpl;

// Deactivate old versions
List<DocGen_Template_Version__c> oldVersions = [SELECT Id, Is_Active__c FROM DocGen_Template_Version__c WHERE Template__c = :tpl.Id];
for (DocGen_Template_Version__c v : oldVersions) { v.Is_Active__c = false; }
if (!oldVersions.isEmpty()) update oldVersions;

System.debug('TPL_ID:' + tpl.Id);
EOF
TPL_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/word-template-setup.apex 2>&1)
TPL_ID=$(echo "$TPL_OUTPUT" | grep -oE 'TPL_ID:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
if [ -z "$TPL_ID" ]; then
    echo "ERROR: template setup failed"; echo "$TPL_OUTPUT" | tail -20; exit 1
fi
echo "      template OK — $TPL_ID"

# Upload .docx via REST (bypass Apex 20KB limit)
echo ""
echo "[3/5] Uploading Word .docx via REST..."
INSTANCE_URL=$(sf org display --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['instanceUrl'])")
ACCESS_TOKEN=$(sf org display --target-org "$ORG" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['accessToken'])")

BOUNDARY="docgen$(date +%s)"
ENTITY_JSON='{"Title":"Survey Chart Example (Word) v1.91","PathOnClient":"survey-chart-example.docx","FirstPublishLocationId":"'"$TPL_ID"'"}'

MULTIPART_FILE=$(mktemp /tmp/word-upload.XXXXXX)
{
    printf -- "--%s\r\n" "$BOUNDARY"
    printf -- "Content-Disposition: form-data; name=\"entity_document\";\r\n"
    printf -- "Content-Type: application/json\r\n"
    printf -- "\r\n"
    printf -- "%s\r\n" "$ENTITY_JSON"
    printf -- "--%s\r\n" "$BOUNDARY"
    printf -- "Content-Disposition: form-data; name=\"VersionData\"; filename=\"survey-chart-example.docx\"\r\n"
    printf -- "Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document\r\n"
    printf -- "\r\n"
    cat "$DOCX_PATH"
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
    echo "ERROR: docx upload failed."; echo "$CV_CREATE_RESP" | head -10; exit 1
fi
echo "      uploaded — CV $CV_ID_NEW"

# Link as active template version
cat > /tmp/word-link-version.apex <<EOF
Id tplId = '$TPL_ID'; Id cvId = '$CV_ID_NEW';
String qc = 'Name, (SELECT Id, Question_Text__c, Display_Order__c FROM Survey_Questions__r ORDER BY Display_Order__c ASC)';
insert new DocGen_Template_Version__c(
    Template__c = tplId, Content_Version_Id__c = cvId, Is_Active__c = true,
    Type__c = 'Word', Base_Object_API__c = 'Survey__c', Query_Config__c = qc
);
System.debug('Linked');
EOF
sf apex run --target-org "$ORG" -f /tmp/word-link-version.apex > /dev/null 2>&1

# Render to PDF
echo ""
echo "[4/5] Rendering Word template to PDF..."
cat > /tmp/word-generate.apex <<EOF
Id contentDocId = DocGenService.generateDocument('$TPL_ID', '$SURVEY_ID', 'PDF');
if (contentDocId == null) { System.debug('NULL'); return; }
ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :contentDocId AND IsLatest = true LIMIT 1];
System.debug('GENERATED_CV:' + cv.Id);
EOF
GEN_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/word-generate.apex 2>&1)
GEN_CV_ID=$(echo "$GEN_OUTPUT" | grep -oE 'GENERATED_CV:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
if [ -z "$GEN_CV_ID" ]; then
    echo "ERROR: PDF generation failed."; echo "$GEN_OUTPUT" | tail -30; exit 1
fi
echo "      PDF generated — $GEN_CV_ID"

# Create public link
echo ""
echo "[5/5] Creating public ContentDistribution link..."
cat > /tmp/word-public-link.apex <<EOF
Id cvId = '$GEN_CV_ID';
delete [SELECT Id FROM ContentDistribution WHERE ContentVersionId = :cvId];
ContentDistribution cd = new ContentDistribution(
    ContentVersionId = cvId, Name = 'Survey Chart Example (Word) PDF',
    PreferencesAllowViewInBrowser = true, PreferencesAllowOriginalDownload = true,
    PreferencesPasswordRequired = false
);
insert cd;
cd = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
System.debug('PUBLIC_URL:' + cd.ContentDownloadUrl);
EOF
URL=$(sf apex run --target-org "$ORG" -f /tmp/word-public-link.apex 2>&1 | grep "USER_DEBUG.*PUBLIC_URL:" | sed 's/.*PUBLIC_URL://')

echo ""
echo "================================================================"
echo "  Word .docx demo: done."
echo ""
echo "  Survey         : $SURVEY_ID"
echo "  Word Template  : $TPL_ID"
echo "  Source .docx CV: $CV_ID_NEW"
echo "  Rendered PDF CV: $GEN_CV_ID"
echo ""
echo "  Public PDF link:"
echo "  $URL"
echo "================================================================"
