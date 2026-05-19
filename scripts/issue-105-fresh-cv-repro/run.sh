#!/usr/bin/env bash
# Repro orchestrator for TEST (3).docx — runs the full template-save + render
# flow with the production-style queueable boundary so the rendered PDF
# embeds the real logo instead of a 48×48 broken-image placeholder.
#
#   stage 1 (setup):  upload source DOCX → create template/version → enqueue
#                     pre-decomp queueable → exit (commits version row)
#   poll:             watch Pre_Decomposition_Status__c='Complete' on the version
#   sleep:            ~30s extra so shepherd publishes the extracted image CVs
#   stage 2 (render): generatePdfBlobFromData → save PDF + HTML
#   download:         fetch the LATEST output CVs (by ID, not by Title — avoids
#                     stale-file collisions when prior runs left CVs around)
#
# Usage:  scripts/issue-105-fresh-cv-repro/run.sh [target-org-alias] [path-to-docx]
# Default org: portwood-staging
# Default docx: Triage Docs/TEST (3).docx

set -euo pipefail

ORG="${1:-portwood-staging}"
SRC="${2:-Triage Docs/TEST (3).docx}"
OUT_DIR="/tmp/test3-repro"
TITLE="TEST3 Source DOCX"
POLL_TIMEOUT_S=180
SHEPHERD_SETTLE_S=30

mkdir -p "$OUT_DIR"

# ── helper: extract a "KEY=value" line from sf apex run output ────────────────
parse_kv() {
    local key="$1" file="$2"
    grep -oE "${key}=[a-zA-Z0-9]+" "$file" | tail -1 | cut -d'=' -f2
}

echo "── 1. Cleaning prior 'TEST3 Source DOCX' uploads in $ORG..."
sf data query --target-org "$ORG" \
    --query "SELECT ContentDocumentId FROM ContentVersion WHERE Title = '$TITLE' AND IsLatest = TRUE" \
    --json 2>/dev/null \
    | python3 -c "
import sys, json, subprocess
d = json.load(sys.stdin)
ids = [r['ContentDocumentId'] for r in d.get('result', {}).get('records', [])]
for cdId in ids:
    print(f'   deleting ContentDocument {cdId}')
    subprocess.run(['sf', 'data', 'delete', 'record', '--target-org', '$ORG', '--sobject', 'ContentDocument', '--record-id', cdId], check=False)
" || true

# Also wipe prior output artefacts on any old anchor (Title-collision protection)
sf data query --target-org "$ORG" \
    --query "SELECT ContentDocumentId FROM ContentVersion WHERE Title IN ('TEST3 Output PDF','TEST3 Rendered HTML') AND IsLatest = TRUE" \
    --json 2>/dev/null \
    | python3 -c "
import sys, json, subprocess
d = json.load(sys.stdin)
ids = [r['ContentDocumentId'] for r in d.get('result', {}).get('records', [])]
for cdId in ids:
    subprocess.run(['sf', 'data', 'delete', 'record', '--target-org', '$ORG', '--sobject', 'ContentDocument', '--record-id', cdId], check=False)
" || true

echo "── 2. Uploading $SRC → ContentVersion with Title='$TITLE'..."
sf data create file --target-org "$ORG" --file "$SRC" --title "$TITLE"

echo "── 3. Stage 1 — setup + enqueue pre-decomp queueable..."
sf apex run --target-org "$ORG" -f scripts/issue-105-fresh-cv-repro/stage1-setup.apex 2>&1 | tee "$OUT_DIR/apex-stage1.log"

VERSION_ID=$(parse_kv STAGE1_VERSION_ID "$OUT_DIR/apex-stage1.log")
TEMPLATE_ID=$(parse_kv STAGE1_TEMPLATE_ID "$OUT_DIR/apex-stage1.log")
ANCHOR_ID=$(parse_kv STAGE1_ANCHOR_ID "$OUT_DIR/apex-stage1.log")
if [ -z "$VERSION_ID" ] || [ -z "$TEMPLATE_ID" ]; then
    echo "ABORT: stage 1 did not emit STAGE1_VERSION_ID / STAGE1_TEMPLATE_ID" >&2
    exit 1
fi
echo "   template=$TEMPLATE_ID  version=$VERSION_ID  anchor=$ANCHOR_ID"

echo "── 4. Polling Pre_Decomposition_Status__c='Complete' (max ${POLL_TIMEOUT_S}s)..."
start_ts=$(date +%s)
status=""
while true; do
    status=$(sf data query --target-org "$ORG" \
        --query "SELECT Pre_Decomposition_Status__c FROM DocGen_Template_Version__c WHERE Id = '$VERSION_ID'" \
        --json 2>/dev/null \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
recs = d.get('result', {}).get('records', [])
print(recs[0].get('Pre_Decomposition_Status__c') or '' if recs else '')
")
    elapsed=$(( $(date +%s) - start_ts ))
    echo "   t+${elapsed}s — status: '${status:-<empty>}'"
    if [ "$status" = "Complete" ]; then
        break
    fi
    if [ "$status" = "Failed" ]; then
        echo "ABORT: pre-decomp queueable reported Failed" >&2
        exit 1
    fi
    if [ "$elapsed" -ge "$POLL_TIMEOUT_S" ]; then
        echo "ABORT: pre-decomp did not reach Complete within ${POLL_TIMEOUT_S}s (status=$status)" >&2
        exit 1
    fi
    sleep 5
done

echo "── 5. Sleeping ${SHEPHERD_SETTLE_S}s so shepherd publishes the extracted CVs..."
sleep "$SHEPHERD_SETTLE_S"

echo "── 6. Stage 2 — render..."
sf apex run --target-org "$ORG" -f scripts/issue-105-fresh-cv-repro/stage2-render.apex 2>&1 | tee "$OUT_DIR/apex-stage2.log"

echo
echo "── 7. Downloading output artefacts by CV ID (avoid Title-collision stale grabs)..."
# Get the freshest output CVs linked to this run's anchor, by ID
sf data query --target-org "$ORG" --json \
    --query "SELECT Id, Title FROM ContentVersion WHERE Title IN ('TEST3 Output PDF','TEST3 Rendered HTML') AND IsLatest = TRUE ORDER BY CreatedDate DESC LIMIT 2" \
    | python3 -c "
import sys, json, subprocess, os
d = json.load(sys.stdin)
out = '$OUT_DIR'
inst = json.loads(subprocess.check_output(['sf', 'org', 'display', '--target-org', '$ORG', '--json']).decode())['result']
for r in d.get('result', {}).get('records', []):
    cvId = r['Id']
    title = r['Title']
    safe = title.replace(' ', '_') + ('.pdf' if 'PDF' in title else '.html')
    target = os.path.join(out, safe)
    url = inst['instanceUrl'] + '/services/data/v60.0/sobjects/ContentVersion/' + cvId + '/VersionData'
    subprocess.run(['curl', '-s', '-H', 'Authorization: Bearer ' + inst['accessToken'], '-o', target, url], check=True)
    print(f'   {title} ({cvId}) -> {target} ({os.path.getsize(target)} bytes)')
"

echo
echo "── 8. Verifying the embedded image isn't the broken-image placeholder..."
if command -v pdfimages >/dev/null 2>&1; then
    rm -rf "$OUT_DIR/pdf_images"
    mkdir -p "$OUT_DIR/pdf_images"
    pdfimages -png "$OUT_DIR/TEST3_Output_PDF.pdf" "$OUT_DIR/pdf_images/img" 2>&1 || true
    first_img=$(ls "$OUT_DIR/pdf_images/"*.png 2>/dev/null | head -1)
    if [ -n "$first_img" ]; then
        dims=$(file "$first_img" | grep -oE '[0-9]+ x [0-9]+' | head -1)
        echo "   first embedded image: $dims"
        if [ "$dims" = "48 x 48" ]; then
            echo "   ✗ STILL BROKEN — Flying Saucer embedded its 48×48 placeholder. Try increasing SHEPHERD_SETTLE_S."
        else
            echo "   ✓ Real image rendered ($dims)."
        fi
    fi
else
    echo "   (skipped — pdfimages not installed)"
fi

echo
echo "── Artefacts saved to $OUT_DIR ──"
ls -la "$OUT_DIR"/*.pdf "$OUT_DIR"/*.html 2>/dev/null
