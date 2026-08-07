#!/usr/bin/env bash
#
# SDocs-replacement demo — one command from nothing to a presentable org.
#
#   ./scripts/demo/sdocs/setup.sh                          # refresh an existing org
#   ./scripts/demo/sdocs/setup.sh portwood-sdocs --create  # create it first
#
# WHAT THIS BUILDS
# ----------------
# A project-delivery org for the customer scenario: "we generate project
# documents in SDocs and send them to clients for e-signature; some are simple
# approvals, some pull related lists off the project; users forget to attach the
# e-sig template so we built a Flow to auto-attach it."
#
#   - Portwood v3.54.0 installed as a REAL SUBSCRIBER INSTALL (not a source
#     deploy) — the customer sees what a customer gets, namespace and all.
#   - Demo_Project__c with three related lists (milestones, deliverables,
#     change orders) and ~35 seeded child records across three projects.
#   - Three templates: a simple one-signature approval letter, a three-related-
#     list acceptance certificate with totals and two signature roles, and a
#     two-page Project Invoice built entirely in the Canvas designer (pinned
#     letterhead, a milestone line-item table that paginates, an AMOUNT DUE
#     panel, and a change-order appendix with signature placements and a QR).
#   - A record-triggered Flow that fires the signature request on status change,
#     which is the answer to the "users forget to attach it" problem.
#
# WHY A REAL INSTALL AND NOT A SOURCE DEPLOY
# ------------------------------------------
# The whole demo is about what the customer would buy. A source deploy puts the
# classes in the default namespace, which hides every managed-package visibility
# behaviour and means the org is not the product. The cost is that the repo's
# scripts/e2e-*.apex suites cannot run here — they call `public` classes that a
# subscriber cannot see. Use scripts/demo/sdocs/verify-*.apex instead; those go
# through the `global` API, exactly like a customer's own Apex would.
set -euo pipefail

ORG="${1:-portwood-sdocs}"
[[ "$ORG" == --* ]] && ORG="portwood-sdocs"
CREATE=false
DAYS=30
HUB="${DOCGEN_DEVHUB:-Portwood Global - Production}"
# v3.54.0 — the current shipped version. Bump this when a newer one promotes.
PKG="${PORTWOOD_PACKAGE:-04tVx0000010Y4LIAU}"

for ((i = 1; i <= $#; i++)); do
    case "${!i}" in
        --create) CREATE=true ;;
        --days) DAYS="${@:i+1:1}" ;;
        --hub) HUB="${@:i+1:1}" ;;
        --package) PKG="${@:i+1:1}" ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT"

say() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# ── 1. the org ───────────────────────────────────────────────────────────────
if [[ "$CREATE" == true ]]; then
    say "Creating scratch org '$ORG' (${DAYS}d, hub: $HUB)"
    # --no-namespace: a subscriber does not OWN portwoodglobal, it receives the
    # namespace from the package. Creating this org namespaced would let
    # visibility bugs pass that a real customer would hit.
    sf org create scratch \
        --target-dev-hub "$HUB" \
        --definition-file config/project-scratch-def.json \
        --alias "$ORG" \
        --duration-days "$DAYS" \
        --no-namespace \
        --wait 30

    say "Installing Portwood $PKG (real subscriber install — takes ~5 min)"
    sf package install --target-org "$ORG" --package "$PKG" \
        --security-type AdminsOnly --no-prompt --publish-wait 20 --wait 60
fi

# ── 2. permissions ───────────────────────────────────────────────────────────
# AFTER the install, never before: assigning first (or forgetting) makes
# anonymous-Apex FLS report "No such column" on fields that plainly exist.
say "Assigning Portwood permission sets"
for ps in portwoodglobal__DocGen_Admin portwoodglobal__DocGen_User; do
    if out="$(sf org assign permset --target-org "$ORG" --name "$ps" 2>&1)"; then
        echo "   $ps assigned"
    elif printf '%s' "$out" | grep -qiE 'duplicate|already assigned'; then
        echo "   $ps already assigned"
    else
        echo "   !! $ps FAILED: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
        exit 1
    fi
done

# ── 3. demo schema ───────────────────────────────────────────────────────────
# Converted to metadata format in a THROWAWAY project first.
#
# `sf project deploy start --source-dir` only resolves source inside a registered
# packageDirectory, and this schema deliberately lives outside force-app so a
# package build can never pick it up. Deploying it directly fails with
# "NothingToDeploy: No local changes to deploy" — which reads like the schema is
# already there when in fact none of it landed.
say "Deploying demo schema, record page and Flow"
python3 "$HERE/gen_schema.py"
SCHEMA_TMP="$(mktemp -d)"
trap 'rm -rf "$SCHEMA_TMP"' EXIT
mkdir -p "$SCHEMA_TMP/proj"
cp -R "$HERE/schema/force-app" "$SCHEMA_TMP/proj/force-app"
cat >"$SCHEMA_TMP/proj/sfdx-project.json" <<'JSON'
{ "packageDirectories": [{ "path": "force-app", "default": true }], "namespace": "", "sourceApiVersion": "62.0" }
JSON
(cd "$SCHEMA_TMP/proj" && sf project convert source -r force-app -d "$SCHEMA_TMP/mdapi" >/dev/null)
sf project deploy start --target-org "$ORG" --metadata-dir "$SCHEMA_TMP/mdapi" --wait 25

say "Assigning the demo permission set"
sf org assign permset --target-org "$ORG" --name Demo_Projects 2>/dev/null ||
    echo "   (Demo_Projects already assigned)"

# ── 4. data ──────────────────────────────────────────────────────────────────
# Ordered: 01 creates the accounts/contacts/projects everything else hangs off.
# 03 derives Revised_Contract_Value__c from the change orders 02 inserted, so it
# must run after both.
say "Seeding demo data"
for s in seed-01-projects seed-02-related seed-03-rollup; do
    printf '   %s … ' "$s"
    if sf apex run --target-org "$ORG" -f "$HERE/seed/$s.apex" >/dev/null 2>&1; then
        echo "ok"
    else
        echo "FAILED (re-run: sf apex run --target-org $ORG -f \"$HERE/seed/$s.apex\")"
    fi
done

# ── 5. templates ─────────────────────────────────────────────────────────────
# No DOCGEN_DEMO_NS override any more. The installer used to need one here
# because it took the namespace from `sf org display`, which reports NOTHING for
# a subscriber org — the org does not own portwoodglobal, it received it — so the
# generated Apex referenced bare DocGen_Template__c and created zero templates.
# It now PROBES the org for whichever prefix the object really carries, which is
# the only thing that distinguishes a real install from a --no-namespace scratch
# org. Set DOCGEN_DEMO_NS only to force a prefix the probe would not pick.
say "Installing the templates"
node "$ROOT/scripts/demo/install/install.mjs" \
    "$ORG" --manifest=scripts/demo/sdocs/manifest.json

say "Stamping template API Names (the Flow references them by name, not Id)"
sf apex run --target-org "$ORG" -f "$HERE/seed/seed-04-template-api-names.apex" >/dev/null

# ── 6. prove it works ────────────────────────────────────────────────────────
say "Verifying all three templates render"
sf apex run --target-org "$ORG" -f "$HERE/verify-generate.apex" 2>&1 |
    grep -E 'USER_DEBUG.*VERIFY (OK|FAIL)' | sed 's/.*DEBUG|/   /'

say "Verifying the auto-send Flow fires"
sf apex run --target-org "$ORG" -f "$HERE/verify-flow.apex" 2>&1 |
    grep -E 'USER_DEBUG.*FLOW-TEST (REQUEST|SIGNER|FAIL)' | sed 's/.*DEBUG|/   /'

say "Resetting to a clean pre-demo state"
sf apex run --target-org "$ORG" -f "$HERE/reset.apex" >/dev/null

cat <<EOF

  sf org open --target-org $ORG

  Open the "Portwood Projects" app and pick P-2041 (Meridian Health Systems).
  Talk track: scripts/demo/sdocs/DEMO-SCRIPT.md

  Between rehearsals:
    sf apex run --target-org $ORG -f scripts/demo/sdocs/reset.apex

  Signing link for the newest pending signer:
    sf apex run --target-org $ORG -f scripts/demo/sdocs/print-signing-url.apex

EOF
