#!/usr/bin/env bash
#
# One command from nothing to a fully testable DocGen org.
#
#   ./scripts/qa/setup-org.sh                    # reuse/refresh docgen-verify
#   ./scripts/qa/setup-org.sh my-org --create    # create it first
#   ./scripts/qa/setup-org.sh my-org --create --days 30
#
# WHY THIS EXISTS
# ---------------
# Standing an org up by hand meant: create it, push source, remember the permset
# (and remember it goes AFTER the deploy, or anonymous-Apex FLS makes a missing
# permset look like corrupted metadata), place the components on a record page,
# find the setting that stops signature emails needing a verified sender, then
# seed a template before any browser test has something to open. Every one of
# those steps has been forgotten at least once, and each failure looks like a
# different bug.
#
# Idempotent: safe to re-run against an existing org. Everything is upserted.

set -euo pipefail

ORG="${1:-docgen-verify}"
[[ "$ORG" == --* ]] && ORG="docgen-verify"
CREATE=false
DAYS=30
for a in "$@"; do
    case "$a" in
        --create) CREATE=true ;;
        --days) shift ;;
    esac
done
for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "--days" ]]; then
        j=$((i + 1))
        DAYS="${!j}"
    fi
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

say() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# ── 1. the org ───────────────────────────────────────────────────────────────
if [[ "$CREATE" == true ]]; then
    say "Creating scratch org '$ORG' ($DAYS days)"
    # --no-namespace so the e2e scripts' bare class/field references compile.
    # A namespaced org is the RIGHT place to catch managed-package visibility
    # traps, but it is the WRONG place to run these scripts.
    sf org create scratch \
        --definition-file config/project-scratch-def.json \
        --alias "$ORG" \
        --duration-days "$DAYS" \
        --no-namespace \
        --set-default \
        --wait 20
fi

say "Target org: $ORG"
sf org display --target-org "$ORG" --json >/dev/null

# ── 2. source ────────────────────────────────────────────────────────────────
say "Deploying force-app"
sf project deploy start --target-org "$ORG" --source-dir force-app --ignore-conflicts --wait 30

# ── 3. permission sets — AFTER the deploy, never before ──────────────────────
# Assigning first, or forgetting entirely, produces "No such column" on fields
# that plainly exist. It reads as broken metadata and is not.
say "Assigning permission sets"
for ps in DocGen_Admin DocGen_User; do
    sf org assign permset --target-org "$ORG" --name "$ps" 2>/dev/null ||
        echo "   ($ps already assigned)"
done

# ── 4. component placement ───────────────────────────────────────────────────
# docGenRunner and docGenSignatureSender are lightning__RecordPage components and
# the package ships no FlexiPage on purpose — customers place them themselves.
# Without this there is nowhere for a browser test to reach them at all.
say "Placing components on the Account record page (QA-only fixture)"
sf project deploy start --target-org "$ORG" --metadata-dir "$HERE/fixtures/mdapi" --wait 20

# ── 5. org settings + seed data ──────────────────────────────────────────────
say "Configuring DocGen settings and seeding test data"
sf apex run --target-org "$ORG" -f "$HERE/setup-org.apex"

say "Done — $ORG is ready"
cat <<EOF

  npm run qa -- --org $ORG              every suite
  npm run qa -- --org $ORG --fast       skip the slow ones
  npm run smoke -- --org $ORG           designer only

EOF
