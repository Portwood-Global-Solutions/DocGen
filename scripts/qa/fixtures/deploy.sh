#!/usr/bin/env bash
# Deploy the QA-only UI host fixtures to a verify org.
#
# These live OUTSIDE force-app (the only packageDirectory in sfdx-project.json),
# so they cannot reach a customer. They exist because the package ships no
# FlexiPage or QuickAction, which left docGenRunner, docGenSignatureSender and
# docGenButton — the components customers actually touch — unreachable by any
# browser test.
#
#   ./scripts/qa/fixtures/deploy.sh docgen-verify
set -euo pipefail
ORG="${1:-docgen-verify}"
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "Deploying QA UI fixtures to $ORG …"
sf project deploy start --target-org "$ORG" --metadata-dir "$HERE/mdapi" --wait 20
