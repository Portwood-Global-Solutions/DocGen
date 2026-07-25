#!/usr/bin/env bash
#
# One command from nothing to a fully testable DocGen org.
#
#   ./scripts/qa/setup-org.sh                    # reuse/refresh docgen-verify
#   ./scripts/qa/setup-org.sh my-org --create    # create it first
#   ./scripts/qa/setup-org.sh my-org --create --days 30
#   ./scripts/qa/setup-org.sh my-org --create --hub portwood-prod
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
# The Dev Hub is NOT optional and there is no safe guess. This machine has four
# hubs authorised and no default set, so `sf org create scratch` fails on line
# one with NoDefaultDevHubError — which reads like a broken script and is really
# missing config. Default to the project's hub (CLAUDE.md § Package info),
# override with --hub or $DOCGEN_DEVHUB.
HUB="${DOCGEN_DEVHUB:-Portwood Global - Production}"
for ((i = 1; i <= $#; i++)); do
    case "${!i}" in
        --create) CREATE=true ;;
        --days) DAYS="${@:i+1:1}" ;;
        --hub) HUB="${@:i+1:1}" ;;
    esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

# Per-phase timing, printed as a table at the end. "How long does standing up a
# QA org take?" should be answerable from any run, not re-measured by hand.
T0=$(date +%s)
LAST=$T0
PHASES=()
say() {
    local now
    now=$(date +%s)
    [[ ${#PHASES[@]} -gt 0 || "$LAST" != "$T0" ]] && PHASES[${#PHASES[@]} - 1]="${PHASES[${#PHASES[@]} - 1]}|$((now - LAST))"
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

# ── 1. the org ───────────────────────────────────────────────────────────────
if [[ "$CREATE" == true ]]; then
    say "Creating scratch org '$ORG' ($DAYS days, hub: $HUB)"
    # --no-namespace so the e2e scripts' bare class/field references compile.
    # A namespaced org is the RIGHT place to catch managed-package visibility
    # traps, but it is the WRONG place to run these scripts.
    sf org create scratch \
        --target-dev-hub "$HUB" \
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
# Via deploy.sh, not a direct deploy: the FlexiPage's component names carry a
# namespace prefix that has to match the target org, and that logic lives there.
"$HERE/fixtures/deploy.sh" "$ORG"

# ── 4b. the quick action onto the layout ─────────────────────────────────────
# docGenButton is a lightning__RecordAction — it cannot live in a FlexiPage
# region, so the fixture above cannot reach it. The only way in is a quick action
# in the highlights panel, and the highlights panel takes its actions from the
# page LAYOUT, not the Lightning page.
#
# The layout cannot be shipped as a fixture: Account's layout differs per org and
# overwriting it wholesale would discard whatever else is on it. So retrieve the
# org's own layout, add one entry, put it back.
say "Adding the DocGen Button quick action to the Account layout"
LAYOUT_TMP="$(mktemp -d)"
if sf project retrieve start --target-org "$ORG" \
    --metadata "Layout:Account-Account Layout" \
    --target-metadata-dir "$LAYOUT_TMP" --unzip --wait 10 >/dev/null 2>&1; then
    LAYOUT_FILE="$(find "$LAYOUT_TMP" -name '*.layout' -o -name '*.layout-meta.xml' | head -1)"
    # Object-qualified — a bare name is rejected inside a layout.
    if [[ -n "$LAYOUT_FILE" ]] && python3 "$HERE/fixtures/add-quick-action.py" "$LAYOUT_FILE" Account.QA_DocGen_Button; then
        sf project deploy start --target-org "$ORG" \
            --metadata-dir "$(dirname "$(dirname "$LAYOUT_FILE")")" --wait 20 >/dev/null
        echo "   quick action on the layout"
    else
        echo "   SKIPPED — layout already has it, or could not be patched"
    fi
else
    # Not fatal. Every other suite still runs; only the docGenButton checks lose
    # their host, and they report as skipped rather than passing by omission.
    echo "   SKIPPED — could not retrieve 'Account-Account Layout'"
fi
rm -rf "$LAYOUT_TMP"

# ── 5. org settings + seed data ──────────────────────────────────────────────
say "Configuring DocGen settings and seeding test data"
sf apex run --target-org "$ORG" -f "$HERE/setup-org.apex"

say "Done — $ORG is ready"
cat <<EOF

  npm run qa -- --org $ORG              every suite
  npm run qa -- --org $ORG --fast       skip the slow ones
  npm run smoke -- --org $ORG           designer only

EOF
