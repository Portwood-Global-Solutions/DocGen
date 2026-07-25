#!/usr/bin/env bash
# ============================================================================
# Portwood DocGen DEMO — one-command environment setup.
#   1. Deploys the custom demo schema (objects, fields, permset, app)
#   2. Assigns DocGen_Admin + DocGen_Demo to the running user
#   3. Seeds all demo data (standard + custom + giant-scale)
#   4. Builds the Word/PowerPoint template binaries
#   5. Installs all templates (uploads bodies + creates template records)
#
# Usage:  bash "DEMO TEMPLATES/install/setup.sh" [orgAlias]
#   default org: dave@portwood.dev.demo
# ============================================================================
set -euo pipefail
ORG="${1:-dave@portwood.dev.demo}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEMO="$ROOT/DEMO TEMPLATES"

echo "==> [1/5] Deploying demo schema to $ORG"
sf project deploy start --target-org "$ORG" --source-dir "$DEMO/schema/force-app" --ignore-conflicts --wait 15

echo "==> [2/5] Assigning permission sets to running user"
for ps in DocGen_Admin DocGen_Demo; do
  sf org assign permset --target-org "$ORG" --name "$ps" 2>/dev/null || echo "    ($ps already assigned)"
done

echo "==> [3/5] Seeding demo data"
for s in seed-01-core seed-02-events seed-03-education seed-04-records seed-05-giant; do
  echo "    - $s"
  sf apex run --target-org "$ORG" -f "$DEMO/seed/$s.apex" >/dev/null
done

echo "==> [4/5] Building Word + PowerPoint template binaries"
python3 "$DEMO/docx/build_docx.py" >/dev/null
python3 "$DEMO/pptx/build_pptx.py" >/dev/null

echo "==> [5/5] Installing templates"
node "$DEMO/install/install.mjs" "$ORG"

echo ""
echo "==> Done. The DocGen Demo environment is ready in $ORG."
echo "    Open the 'DocGen Demo' app to browse sample records, then generate"
echo "    documents with the DocGen runner. Catalog: DEMO TEMPLATES/README.md"
