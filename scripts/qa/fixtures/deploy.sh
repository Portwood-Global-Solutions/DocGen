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
#
# NAMESPACE
# ---------
# A FlexiPage names its components exactly: `portwoodglobal:docGenRunner` in a
# namespaced org, `c:docGenRunner` in one created with --no-namespace. There is
# no wildcard. The checked-in fixture therefore only ever matched ONE org shape,
# and deploying it to the other fails with "We couldn't retrieve the design time
# component information" — which reads as a broken component and is really a
# broken prefix. So the prefix is rewritten here against whatever the target org
# actually is, and the fixture on disk is left alone.
set -euo pipefail
ORG="${1:-docgen-verify}"
HERE="$(cd "$(dirname "$0")" && pwd)"

NS="$(sf org display --target-org "$ORG" --json 2>/dev/null |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["result"].get("namespace") or "")' 2>/dev/null || echo '')"
PREFIX="${NS:-c}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$HERE/mdapi/." "$STAGE/"

for f in "$STAGE"/flexipages/*.flexipage; do
    [[ -e "$f" ]] || continue
    python3 - "$f" "$PREFIX" <<'PY'
import re, sys
path, prefix = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as fh:
    xml = fh.read()
# Only DocGen components move; force:* and flexipage:* are platform-owned and
# have no namespace of ours to rewrite.
xml = re.sub(r'<componentName>\w+:(docGen\w+)</componentName>',
             lambda m: f'<componentName>{prefix}:{m.group(1)}</componentName>', xml)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(xml)
PY
done

echo "Deploying QA UI fixtures to $ORG (component prefix: $PREFIX:) …"
sf project deploy start --target-org "$ORG" --metadata-dir "$STAGE" --wait 20
