#!/usr/bin/env bash
#
# DocGen — spin up an Einstein-enabled DEMO org in one command.
#
#   ./scripts/setup-einstein-demo-org.sh
#   ./scripts/setup-einstein-demo-org.sh --recreate
#   ./scripts/setup-einstein-demo-org.sh --base 04t... --ext 04t... --alias demo2
#
# Installs DocGen + the Agentforce Extension into a fresh no-namespace org with
# Prompt Builder switched on, so the Designer's "Generate with AI" button is live and
# a prospect can describe a document and watch DocGen write the template.
#
# WHY INSTALL, NOT SOURCE DEPLOY: DocGenEinsteinProvider references
# ConnectApi.EinsteinLLM, which is fenced out of force-app by .forceignore — a package
# containing it is refused at install in a non-Einstein org, and leaving it in
# force-app breaks the next DocGen release build. The provider and the
# DocGen_HTML_Body prompt template ship in the separate Agentforce Extension package.
# Installing both is the only path that produces a working AI demo AND matches what a
# customer actually gets.
#
# SCRATCH ORGS EXPIRE (30 days max). This is for your own demos, prospect calls, and
# testing the extension. It is NOT a vehicle for an AppExchange listing — that needs a
# Trialforce / Test Drive org, which is a different setup path entirely.

set -euo pipefail

ALIAS="docgen-einstein-demo"
DURATION="30"
DEVHUB="Portwood Global - Production"
DEF_FILE="config/einstein-demo-scratch-def.json"
RECREATE="false"
# Defaults track the current release; override per run when testing a new build.
BASE_VERSION="04tVx000000zgS9IAI"     # DocGen 3.48.0
EXT_VERSION="04tVx000000s82DIAQ"      # Agentforce Extension 1.0.0-2
EXT_KEY="${DOCGEN_EXT_INSTALL_KEY:-}" # extension may be install-key gated
TEST_PASSWORD="${DOCGEN_TEST_PASSWORD:-DocGenTest2026!}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --alias)    ALIAS="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --devhub)   DEVHUB="$2"; shift 2 ;;
        --base)     BASE_VERSION="$2"; shift 2 ;;
        --ext)      EXT_VERSION="$2"; shift 2 ;;
        --recreate) RECREATE="true"; shift ;;
        -h|--help)  sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> Einstein demo org: $ALIAS (${DURATION}d)"

if [[ "$RECREATE" == "true" ]]; then
    sf org delete scratch --target-org "$ALIAS" --no-prompt >/dev/null 2>&1 || true
fi

if sf org display --target-org "$ALIAS" >/dev/null 2>&1; then
    echo "==> Reusing existing org (pass --recreate to rebuild)"
else
    echo "==> Creating scratch org (Einstein1AIPlatform + Prompt Builder)"
    # --no-namespace: a subscriber does not own portwoodglobal, it receives it.
    sf org create scratch \
        --definition-file "$DEF_FILE" \
        --alias "$ALIAS" \
        --duration-days "$DURATION" \
        --target-dev-hub "$DEVHUB" \
        --no-namespace \
        --wait 30
fi

echo "==> Installing DocGen base $BASE_VERSION"
sf package install --target-org "$ALIAS" --package "$BASE_VERSION" \
    --security-type AdminsOnly --no-prompt --publish-wait 20 --wait 30

echo "==> Installing Agentforce Extension $EXT_VERSION"
ext_args=(--target-org "$ALIAS" --package "$EXT_VERSION"
          --security-type AdminsOnly --no-prompt --publish-wait 20 --wait 30)
if [[ -n "$EXT_KEY" ]]; then
    ext_args+=(--installation-key "$EXT_KEY")
fi
if ! sf package install "${ext_args[@]}"; then
    echo "ERROR: extension install failed." >&2
    echo "  If it reports an installation key, set DOCGEN_EXT_INSTALL_KEY and re-run." >&2
    exit 1
fi

echo "==> Assigning permission sets to the org admin"
for ps in DocGen_Admin EinsteinGPTPromptTemplateManager; do
    sf org assign permset --target-org "$ALIAS" --name "$ps" >/dev/null 2>&1 \
        && echo "    $ps" \
        || echo "    $ps (not assigned — may not exist in this org)"
done

tmp_dir="$(mktemp -d -t docgen-demo-XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
tmp_apex="$tmp_dir/setup.apex"
sed "s|__DOCGEN_TEST_PASSWORD__|${TEST_PASSWORD}|g" \
    scripts/setup-permission-test-org.apex > "$tmp_apex"

# Two runs: User/PermissionSetAssignment are setup objects and cannot share a
# transaction with Account/Contact DML (MIXED_DML_OPERATION).
echo "==> Creating demo users"
setup_out="$(sf apex run --target-org "$ALIAS" -f "$tmp_apex" 2>&1 || true)"
echo "$setup_out" | grep '|DEBUG|' | grep -oE 'SETUP USER >> .*|SETUP RESULT >> .*' | sed 's/^/    /' || true
if ! echo "$setup_out" | grep '|DEBUG|' | grep -q 'SETUP RESULT.*ALL GOOD'; then
    echo "ERROR: user setup failed" >&2; echo "$setup_out" >&2; exit 1
fi

echo "==> Seeding sample data"
seed_out="$(sf apex run --target-org "$ALIAS" -f scripts/seed-permission-test-data.apex 2>&1 || true)"
echo "$seed_out" | grep '|DEBUG|' | grep -oE 'SEED RESULT >> .*' | sed 's/^/    /' || true

instance_url="$(sf org display --target-org "$ALIAS" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["instanceUrl"])')"
email_domain="$(sf org display --target-org "$ALIAS" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["username"].split("@")[1])')"

cat <<EOF

============================================================
  DocGen Einstein demo org ready
============================================================
  Login URL : ${instance_url}
  Admin     : sf org open --target-org ${ALIAS}
  Password  : ${TEST_PASSWORD}   (demo users below)

  dgadmin.docgenperm@${email_domain}   Standard User + DocGen_Admin
  dguser.docgenperm@${email_domain}    Platform User + DocGen_User

  Installed : DocGen ${BASE_VERSION}
              Agentforce Extension ${EXT_VERSION}

  DEMO PATH: DocGen Template Manager -> Create New ->
             "Generate with AI" -> describe the document -> it writes the
             template, validates it against the PDF engine, and reports what
             it changed and why.

  Expires in ${DURATION} days. Scratch orgs are NOT a listing vehicle —
  an AppExchange Test Drive needs Trialforce.
============================================================
EOF
