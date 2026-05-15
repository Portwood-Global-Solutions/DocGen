#!/usr/bin/env bash
# DocGen Repro #87 — Diagnostic 4 upload helper
# Generates 3 pandoc-built DOCX templates with embedded distinct images and
# uploads each as a ContentVersion via the Salesforce REST API. Writes the
# resulting CV Ids to /tmp/repro87-cv-ids.json for the Apex diagnostic to read.
#
# Why pandoc + images: Diagnostics 1 and 2 (synthetic minimal templates, no
# images, no rels beyond document.xml) passed all assertions. The remaining
# top hypothesis for issue #87 is rId/image-asset collision across
# concatenated multi-template signature packets. Pandoc produces realistic
# DOCX with sequential rIds (rId1-rId9), embedded images at word/media/, and
# full styles.xml — matching real-world templates Dustin uses.
#
# Pre-reqs: pandoc, jq, sf CLI auth'd to ${TARGET_ORG:-portwood-staging}.
#
# Usage: scripts/repro-87-upload-pandoc.sh [target-org-alias]

set -euo pipefail

TARGET_ORG="${1:-portwood-staging}"
FIXTURES_DIR="$(cd "$(dirname "$0")/repro87-fixtures" && pwd)"
WORK_DIR="$(mktemp -d /tmp/repro87.XXXXXX)"
RESULT_JSON=/tmp/repro87-cv-ids.json

echo "Target org:   $TARGET_ORG"
echo "Fixtures dir: $FIXTURES_DIR"
echo "Work dir:     $WORK_DIR"
echo

if ! command -v pandoc >/dev/null 2>&1; then
    echo "ERROR: pandoc not found on PATH." >&2; exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not found on PATH." >&2; exit 1
fi

upload_one() {
    local letter="$1"
    local NAME="REPRO87_DOC_${letter}"
    local SRC_HTML="${FIXTURES_DIR}/${NAME}.html"
    local OUT_DOCX="${WORK_DIR}/${NAME}.docx"
    local BODY_JSON="${WORK_DIR}/${NAME}.body.json"

    if [[ ! -f "$SRC_HTML" ]]; then
        echo "ERROR: missing fixture $SRC_HTML" >&2; return 1
    fi

    echo "Converting $SRC_HTML → $OUT_DOCX" >&2
    ( cd "$FIXTURES_DIR" && pandoc "${NAME}.html" -o "$OUT_DOCX" )

    local SIZE
    SIZE=$(wc -c <"$OUT_DOCX" | tr -d ' ')
    local BASE64_DATA
    BASE64_DATA=$(base64 -i "$OUT_DOCX" | tr -d '\n')

    # Title is uniquified per run so reruns don't collide with previously
    # uploaded CVs that may still be linked elsewhere.
    local TITLE="${NAME}_$(date +%s)"

    jq -n \
        --arg title "$TITLE" \
        --arg path  "${NAME}.docx" \
        --arg data  "$BASE64_DATA" \
        '{Title: $title, PathOnClient: $path, VersionData: $data}' \
        > "$BODY_JSON"

    echo "Uploading $TITLE ($SIZE bytes)…" >&2
    local RESPONSE
    RESPONSE=$(sf api request rest \
        --target-org "$TARGET_ORG" \
        --method POST \
        --header 'Content-Type:application/json' \
        --body "@${BODY_JSON}" \
        '/services/data/v61.0/sobjects/ContentVersion/' 2>&1 || true)

    # sf api request rest leaks CLI Warning lines onto stdout before the JSON
    # body. Extract just the JSON object — first '{' through matching '}'.
    local JSON_BODY
    JSON_BODY=$(echo "$RESPONSE" | sed -n '/^{/,/^}/p')
    local CV_ID
    CV_ID=$(echo "$JSON_BODY" | jq -r '.id // empty')
    if [[ -z "$CV_ID" ]]; then
        echo "ERROR uploading $TITLE:" >&2
        echo "$RESPONSE" >&2
        return 1
    fi
    echo "  → ContentVersion Id: $CV_ID" >&2
    echo "$CV_ID"  # stdout — caller captures
}

CV_A=$(upload_one A)
CV_B=$(upload_one B)
CV_C=$(upload_one C)

jq -n \
    --arg a "$CV_A" \
    --arg b "$CV_B" \
    --arg c "$CV_C" \
    --arg ts "$(date +%s)" \
    '{cvA: $a, cvB: $b, cvC: $c, uploadedAt: $ts}' \
    > "$RESULT_JSON"

echo
echo "Wrote CV Ids to $RESULT_JSON"
cat "$RESULT_JSON"
echo
echo "Next: sf apex run --target-org $TARGET_ORG -f scripts/repro-87-diag4-images.apex"
