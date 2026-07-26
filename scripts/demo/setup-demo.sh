#!/usr/bin/env bash
#
# One command from nothing to a DEMO org you can show a customer.
#
#   ./scripts/demo/setup-demo.sh                     # refresh an existing org
#   ./scripts/demo/setup-demo.sh docgen-demo --create
#   ./scripts/demo/setup-demo.sh docgen-demo --create --days 30
#
# WHAT THIS IS
# -----------
# The same scratch-org bootstrap the QA harness uses (scripts/qa/setup-org.sh),
# plus the demo schema, ~2,400 seeded records and the 31-template example
# library. A demo org and a test org want almost exactly the same thing — the
# product deployed, permissions assigned, components placed on a record page and
# realistic data to point at — so this reuses that bootstrap rather than
# maintaining a second one that drifts.
#
# TWO ROOTS, ON PURPOSE
# ---------------------
# scripts/demo/   — this tooling: schema, seed, install, reset. INTERNAL. It was
#                   written for one specific sandbox and removed from the repo in
#                   #174; restored here, pointed at an arbitrary org alias.
# DEMO TEMPLATES/ — the example library: html/ bodies, the docx/pptx builders,
#                   and the two markdown files. PUBLISHED. Nothing in it is
#                   org-specific, and the #174 trim still holds for what ships.
#
# The installer's manifest names bodies relative to the library ("html/…",
# "docx/out/…"), so it resolves the two roots separately rather than assuming
# the tooling and the content sit together.
#
# ON CPQ
# ------
# Salesforce CPQ cannot be provisioned in a scratch org: it is a licensed managed
# package, not a scratch-org feature. What makes a CPQ document demanding is not
# CPQ itself but its SHAPE — hundreds of line items, grouping, pricing maths,
# long tables spanning many pages — and that is exactly what the seeded catalogs
# produce. The Giant Price List runs 2,200 rows through DocGen's giant-query
# path (the >2000-child-row branch with repeating headers), which is the heavy
# processing story worth showing. If CPQ itself is ever needed, it has to be a
# real licensed org, not a scratch org, and the templates would point at
# SBQQ__Quote__c instead of Opportunity.
set -euo pipefail

ORG="${1:-docgen-demo}"
[[ "$ORG" == --* ]] && ORG="docgen-demo"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DEMO="$ROOT/DEMO TEMPLATES"
cd "$ROOT"

T0=$(date +%s)
LAST=$T0
PHASES=()
say() {
    local now
    now=$(date +%s)
    [[ ${#PHASES[@]} -gt 0 ]] && PHASES[${#PHASES[@]} - 1]="${PHASES[${#PHASES[@]} - 1]}|$((now - LAST))"
    PHASES+=("$1")
    LAST=$now
    printf '\n\033[1m▸ %s\033[0m\n' "$1"
}
finish() {
    local now=$(date +%s)
    [[ ${#PHASES[@]} -gt 0 ]] && PHASES[${#PHASES[@]} - 1]="${PHASES[${#PHASES[@]} - 1]}|$((now - LAST))"
    printf '\n\033[1m── timing ──\033[0m\n'
    for p in "${PHASES[@]}"; do printf '  %5ss  %s\n' "${p#*|}" "${p%%|*}"; done
    printf '  %5ss  \033[1mTOTAL\033[0m\n' "$((now - T0))"
}
trap finish EXIT

# ── 1. the product, permissions and component placement ─────────────────────
# Everything the QA bootstrap already does, unchanged — including the record-page
# fixture, which a demo needs for exactly the same reason a test does: the
# package ships no FlexiPage, so without it there is no runner on any record.
say "Base org (product, permission sets, record page)"
"$ROOT/scripts/qa/setup-org.sh" "$@"

# ── 2. demo-only schema ─────────────────────────────────────────────────────
# Demo_*__c objects for the scenarios standard objects cannot model cleanly
# (events, education, certificates, statements). Deployed from outside force-app
# so a package build can never pick them up.
say "Deploying demo schema"
# Converted to metadata format in a THROWAWAY sfdx project first.
#
# `sf project deploy start --source-dir` only resolves source that lives inside a
# registered packageDirectory, and this schema deliberately does not — force-app
# is the sole package directory and adding this to it would put demo objects in
# the managed package. Deploying it directly fails with "NothingToDeploy: No
# local changes to deploy", which reads like the schema is already there. It is
# not: the org silently ends up with none of the Demo_*__c objects, seeds 02-04
# fail, and the events/education/certificate demos are simply absent from an org
# that otherwise looks fine.
SCHEMA_TMP="$(mktemp -d)"
mkdir -p "$SCHEMA_TMP/proj"
cp -R "$HERE/schema/force-app" "$SCHEMA_TMP/proj/force-app"
cat >"$SCHEMA_TMP/proj/sfdx-project.json" <<'JSON'
{
    "packageDirectories": [{ "path": "force-app", "default": true }],
    "namespace": "",
    "sourceApiVersion": "62.0"
}
JSON
(cd "$SCHEMA_TMP/proj" && sf project convert source -r force-app -d "$SCHEMA_TMP/mdapi" >/dev/null)
sf project deploy start --target-org "$ORG" --metadata-dir "$SCHEMA_TMP/mdapi" --wait 25
rm -rf "$SCHEMA_TMP"

say "Assigning the demo permission set"
sf org assign permset --target-org "$ORG" --name DocGen_Demo 2>/dev/null ||
    echo "   (DocGen_Demo already assigned)"

# ── 3. data ─────────────────────────────────────────────────────────────────
# Ordered: 01 creates the accounts/contacts/opportunities the rest hang off.
# 05 is the giant catalog and is by far the slowest — it is what makes the
# >2000-row path demonstrable at all.
say "Seeding demo data"
for s in seed-01-core seed-02-events seed-03-education seed-04-records seed-05-giant; do
    printf '   %s … ' "$s"
    if sf apex run --target-org "$ORG" -f "$HERE/seed/$s.apex" >/dev/null 2>&1; then
        echo "ok"
    else
        # Not fatal. A later scenario failing to seed should not cost you the
        # whole org — you find out which one, and every other demo still works.
        echo "FAILED (re-run: sf apex run --target-org $ORG -f \"$HERE/seed/$s.apex\")"
    fi
done

# ── 4. templates ────────────────────────────────────────────────────────────
say "Building Word + PowerPoint template binaries"
python3 "$DEMO/docx/build_docx.py" >/dev/null
python3 "$DEMO/pptx/build_pptx.py" >/dev/null

say "Installing the template library"
node "$HERE/install/install.mjs" "$ORG"

say "Done — $ORG is ready to demo"
cat <<EOF

  sf org open --target-org $ORG

  Open the "DocGen Demo" app, pick a record, press Generate.
  Catalog of what is installed: DEMO TEMPLATES/README.md

  Worth showing, in rough order of impact:
    - Giant Price List      2,200 rows, giant-query path, repeating headers
    - Sales Proposal        pipeline bar chart + SUM/COUNT aggregates
    - Statement of Work     line items and a real signature flow
    - Invoice with QR       per-row barcode / QR rendering
    - Purchase Agreement    two-party initials + signatures

EOF
