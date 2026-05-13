#!/bin/bash
# Build a 30,000-row commute survey end-to-end for DocGen runner testing.
#
# Usage:
#   bash scripts/build-30k-commute.sh                       # defaults to portwood-staging
#   bash scripts/build-30k-commute.sh <org-alias>           # override target org
#   bash scripts/build-30k-commute.sh <org-alias> <chunks>  # override chunk count (default 5)
#
# What it does (in order):
#   1. Deploys the demo-schema (Survey/Question/Response objects + Survey_Demo
#      permset) if not already present. Idempotent.
#   2. Assigns the Survey_Demo permset to the running user.
#   3. Creates or refreshes the "Commute Chart Example" DocGen_Template__c with
#      the latest docs/CommuteSurveyExample.html as its active version.
#   4. Runs scripts/demo-commute-chunk-seed.apex N times (default 5), inserting
#      6,000 rows per call to reach ~30,000 total Survey_Response__c records.
#   5. Prints Survey Id + Template Id + the org-relative path to the Survey
#      record so you can navigate straight to the DocGen runner UI.
#
# Re-running this script APPENDS another N×6K responses (no auto-wipe). To
# reset, delete the 'DocGen Chart Demo 30K Commute' Survey__c record (the
# Survey_Demo permset grants delete) then re-run.

set -euo pipefail

ORG="${1:-portwood-staging}"
RUNS="${2:-5}"

echo "================================================================"
echo "  DocGen v1.91 — 30K Commute Survey builder"
echo "  Target org : $ORG"
echo "  Chunks     : $RUNS  (×6,000 rows each = $((RUNS * 6000)) total)"
echo "================================================================"

# ----- Step 1: schema -----
echo ""
echo "[1/4] Deploying demo-schema (idempotent)..."
sf project deploy start \
  --source-dir demo-schema \
  --target-org "$ORG" \
  --ignore-conflicts \
  --wait 10 \
  > /tmp/build-30k-deploy.log 2>&1 || { echo "Schema deploy failed; see /tmp/build-30k-deploy.log"; exit 1; }
echo "      schema OK"

# ----- Step 2: permset -----
echo ""
echo "[2/4] Assigning Survey_Demo permset..."
sf org assign permset --name Survey_Demo --target-org "$ORG" > /dev/null 2>&1 || true
echo "      permset OK"

# ----- Step 3: template (base64 the HTML to dodge Apex string escaping) -----
echo ""
echo "[3/4] Setting up Commute Chart Example template..."
TEMPLATE_HTML="docs/CommuteSurveyExample.html"
if [ ! -f "$TEMPLATE_HTML" ]; then
  echo "ERROR: $TEMPLATE_HTML not found. Run from project root."
  exit 1
fi
HTML_B64=$(base64 < "$TEMPLATE_HTML" | tr -d '\n')

cat > /tmp/build-30k-template-setup.apex <<EOF
String htmlB64 = '$HTML_B64';
String htmlBody = EncodingUtil.base64Decode(htmlB64).toString();

// Delete existing template if present — clean slate for HTML refresh.
delete [SELECT Id FROM DocGen_Template__c WHERE Name = 'Commute Chart Example'];

// Query_Config omits Survey_Responses__r intentionally — the chart's SOQL
// fallback fires per-iteration and aggregates server-side, so the data
// retriever never has to load 30K rows into Apex heap.
String qc = 'Name';
DocGen_Template__c tpl = new DocGen_Template__c(
    Name = 'Commute Chart Example',
    Type__c = 'HTML',
    Output_Format__c = 'PDF',
    Base_Object_API__c = 'Survey__c',
    Query_Config__c = qc,
    Description__c = 'v1.91 commute chart demo — pivot + filter + multi-select + colSort'
);
insert tpl;

ContentVersion cv = new ContentVersion(
    Title = 'Commute Chart Example',
    PathOnClient = 'commute-chart-example.html',
    VersionData = Blob.valueOf(htmlBody),
    FirstPublishLocationId = tpl.Id
);
insert cv;
cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

insert new DocGen_Template_Version__c(
    Template__c = tpl.Id,
    Content_Version_Id__c = cv.Id,
    Is_Active__c = true,
    Type__c = 'HTML',
    Base_Object_API__c = 'Survey__c',
    Query_Config__c = qc
);
System.debug('TPL_ID:' + tpl.Id);
EOF

TPL_OUTPUT=$(sf apex run --target-org "$ORG" -f /tmp/build-30k-template-setup.apex 2>&1)
TPL_ID=$(echo "$TPL_OUTPUT" | grep -oE 'TPL_ID:[a-zA-Z0-9]+' | head -1 | cut -d: -f2)
if [ -z "$TPL_ID" ]; then
  echo "ERROR: Template setup failed."
  echo "$TPL_OUTPUT" | tail -20
  exit 1
fi
echo "      template OK — $TPL_ID"

# ----- Step 4: chunk seed loop -----
echo ""
echo "[4/4] Inserting $RUNS × 6,000 responses..."
for i in $(seq 1 "$RUNS"); do
  CHUNK_OUTPUT=$(sf apex run --target-org "$ORG" -f scripts/demo-commute-chunk-seed.apex 2>&1)
  TOTAL=$(echo "$CHUNK_OUTPUT" | grep -oE 'Total now: [0-9]+' | head -1 | cut -d' ' -f3)
  echo "      chunk $i/$RUNS done (running total: ${TOTAL:-?} responses)"
done

# ----- Final report -----
SURVEY_ID=$(sf data query --target-org "$ORG" \
  --query "SELECT Id FROM Survey__c WHERE Name = 'DocGen Chart Demo 30K Commute' LIMIT 1" \
  --result-format csv 2>/dev/null | tail -1)

echo ""
echo "================================================================"
echo "  Done."
echo ""
echo "  Survey Id  : $SURVEY_ID"
echo "  Template Id: $TPL_ID"
echo ""
echo "  Open the runner UI:"
echo "    sf org open --target-org $ORG --path /lightning/r/Survey__c/$SURVEY_ID/view"
echo ""
echo "  Then in DocGen, generate against 'Commute Chart Example' template."
echo "================================================================"
