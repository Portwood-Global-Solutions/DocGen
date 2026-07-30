#!/usr/bin/env bash
#
# DocGen — spin up a permission-test scratch org, end to end, in one command.
#
#   ./scripts/setup-permission-test-org.sh
#   ./scripts/setup-permission-test-org.sh --alias my-org --duration 7
#   ./scripts/setup-permission-test-org.sh --recreate        # delete + rebuild
#   ./scripts/setup-permission-test-org.sh --recreate --install 04t...   # real install
#
# Creates the org, puts DocGen in it, then creates two NON-ADMIN users, assigns their
# permission sets, sets passwords, and seeds Accounts + Contacts.
#
# TWO MODES:
#   default    source-deploy force-app into a NAMESPACED org. Fast iteration; the
#              scripts/e2e-*.apex suites can run against it.
#   --install  create a NO-NAMESPACE org and install a built package version, exactly
#              as a customer would. This is the only mode that catches packaging traps
#              — missing permission-set entries, `public` where `global` was needed,
#              post-install script failures. The e2e suites CANNOT run here: they call
#              public (subscriber-invisible) classes unprefixed. Use the default mode
#              for those, and drive the UI for install verification.
#
# WHY THIS EXISTS: a System Administrator has implicit access to every Apex class,
# so a permission-set gap (an LWC importing a class the permset never granted)
# renders blank for real users and works fine for you. Reproducing that needs users
# whose access comes only from the DocGen permission sets.
#
# NOTE ON NAMESPACE: default mode creates the org WITH the portwoodglobal namespace so
# namespace-sensitive behaviour (LWS sandbox, prefixed SObject keys) is representative.
# --install mode does the opposite on purpose — a subscriber does not own the namespace,
# it receives it from the package.

set -euo pipefail

ALIAS="docgen-permtest"
DURATION="30"
DEVHUB="Portwood Global - Production"
DEF_FILE="config/permission-test-scratch-def.json"
RECREATE="false"
INSTALL_VERSION=""
TEST_PASSWORD="${DOCGEN_TEST_PASSWORD:-DocGenTest2026!}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --alias)     ALIAS="$2"; shift 2 ;;
        --duration)  DURATION="$2"; shift 2 ;;
        --devhub)    DEVHUB="$2"; shift 2 ;;
        --recreate)  RECREATE="true"; shift ;;
        --install)   INSTALL_VERSION="$2"; shift 2 ;;
        -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -f "$DEF_FILE" ]]; then
    echo "ERROR: scratch org definition not found: $DEF_FILE" >&2
    exit 1
fi

echo "==> Scratch org: $ALIAS (${DURATION}d, Dev Hub: $DEVHUB)"

if [[ "$RECREATE" == "true" ]]; then
    echo "==> Deleting any existing org aliased $ALIAS"
    sf org delete scratch --target-org "$ALIAS" --no-prompt >/dev/null 2>&1 || true
fi

if sf org display --target-org "$ALIAS" >/dev/null 2>&1; then
    echo "==> Reusing existing org (pass --recreate to rebuild)"
else
    echo "==> Creating scratch org"
    # Install mode creates the org WITHOUT the namespace: a subscriber org does not
    # own portwoodglobal, it receives it from the package. Creating it namespaced
    # would let namespace-visibility bugs pass that a real customer would hit.
    ns_flag=()
    if [[ -n "$INSTALL_VERSION" ]]; then
        ns_flag=(--no-namespace)
    fi
    sf org create scratch \
        --definition-file "$DEF_FILE" \
        --alias "$ALIAS" \
        --duration-days "$DURATION" \
        --target-dev-hub "$DEVHUB" \
        "${ns_flag[@]}" \
        --wait 30
fi

if [[ -n "$INSTALL_VERSION" ]]; then
    # REAL INSTALL PATH — exercises what a customer actually gets.
    #
    # Note what this can and cannot cover. The scripts/e2e-*.apex suites call
    # DocGenController, DocGenBulkController, DocGenDataRetriever, DocGenHtmlRenderer
    # and DocGenService.processXmlForTest — all `public`, so INVISIBLE to a subscriber,
    # and all referenced unprefixed. They cannot run here by construction; they are a
    # source-deploy suite. Run them against a --no-namespace org instead.
    #
    # What an install test DOES catch, and nothing else does: packaging traps. Missing
    # permission-set entries, public-where-global-was-needed, post-install script
    # failures, and anything that only misbehaves under the namespace.
    echo "==> Installing package version $INSTALL_VERSION (real subscriber install)"
    sf package install \
        --target-org "$ALIAS" \
        --package "$INSTALL_VERSION" \
        --security-type AdminsOnly \
        --no-prompt \
        --publish-wait 20 \
        --wait 30
else
    echo "==> Deploying force-app (source deploy)"
    sf project deploy start --target-org "$ALIAS" --source-dir force-app --wait 45
fi

# The scratch org's own admin needs DocGen_Admin too. Without it, anonymous Apex
# hits field-level security and reports a deployed field as "Field does not exist:
# Query_Config__c" — which reads like corrupted metadata rather than a missing
# permission set. Every later step here runs as this user.
echo "==> Assigning DocGen_Admin to the org admin"
sf org assign permset --target-org "$ALIAS" --name DocGen_Admin >/dev/null 2>&1 \
    || echo "    (already assigned)"

# The password is injected here rather than committed. Anonymous Apex takes no
# parameters, so the placeholder in the .apex file is substituted into a temp copy.
tmp_dir="$(mktemp -d -t docgen-setup-XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
tmp_apex="$tmp_dir/setup.apex"
sed "s|__DOCGEN_TEST_PASSWORD__|${TEST_PASSWORD}|g" \
    scripts/setup-permission-test-org.apex > "$tmp_apex"

# Two separate runs, not one: User and PermissionSetAssignment are setup objects and
# cannot share a transaction with Account/Contact DML (MIXED_DML_OPERATION).
echo "==> Creating users and assigning permission sets"
setup_out="$(sf apex run --target-org "$ALIAS" -f "$tmp_apex" 2>&1 || true)"
# Filter to real log output first: `sf apex run` echoes the script source, so an
# unfiltered grep also matches the string literals and prints them as if they fired.
echo "$setup_out" | grep '|DEBUG|' | grep -oE 'SETUP USER >> .*|SETUP RESULT >> .*|SETUP: FAIL .*' | sed 's/^/    /' || true
if ! echo "$setup_out" | grep '|DEBUG|' | grep -q 'SETUP RESULT.*ALL GOOD'; then
    echo "ERROR: user setup failed — full output below" >&2
    echo "$setup_out" >&2
    exit 1
fi

echo "==> Seeding sample data"
seed_out="$(sf apex run --target-org "$ALIAS" -f scripts/seed-permission-test-data.apex 2>&1 || true)"
echo "$seed_out" | grep '|DEBUG|' | grep -oE 'SEED RESULT >> .*' | sed 's/^/    /' || true
if ! echo "$seed_out" | grep '|DEBUG|' | grep -q 'SEED RESULT.*ALL GOOD'; then
    echo "ERROR: data seeding failed — full output below" >&2
    echo "$seed_out" >&2
    exit 1
fi

MODE_LABEL="source deploy (namespaced) — e2e suites can run here"
if [[ -n "$INSTALL_VERSION" ]]; then
    MODE_LABEL="REAL INSTALL of ${INSTALL_VERSION} (no-namespace subscriber org)"
fi

instance_url="$(sf org display --target-org "$ALIAS" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["instanceUrl"])')"
email_domain="$(sf org display --target-org "$ALIAS" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["username"].split("@")[1])')"

cat <<EOF

============================================================
  DocGen permission-test org is ready
============================================================
  Login URL : ${instance_url}
  Password  : ${TEST_PASSWORD}   (both users)

  dgadmin.docgenperm@${email_domain}
      Standard User profile / Salesforce license + DocGen_Admin
      -> Designer, clone, bulk screen, query builder sort

  dguser.docgenperm@${email_domain}
      Standard Platform User profile / Platform license + DocGen_User
      -> runner as a restricted user

  Admin shell:  sf org open --target-org ${ALIAS}
  Seeded:       3 Accounts x 4 Contacts
  Mode:         ${MODE_LABEL}

  Log in as the two users above in a private window — as a System
  Administrator you will not reproduce permission-set gaps.
============================================================
EOF
