#!/usr/bin/env bash
# ============================================================================
# Portwood DocGen DEMO — reset wrapper.
#
#   refresh : QUICK REFRESH — delete generated documents + signature artifacts
#             to free storage. KEEPS all templates and seeded data. Run this
#             often to keep storage under control between demos.
#
#   full    : FULL RESET — remove ALL demo data, templates, generated docs, and
#             template bodies. Returns the org to clone-clean data state.
#             (The custom Demo_*__c schema + DocGen_Demo permset are KEPT so you
#              can re-seed quickly with setup.sh. To remove the schema too, see
#              README "Removing the schema".)
#
# Usage: bash "DEMO TEMPLATES/reset/reset.sh" <orgAlias> refresh|full
# ============================================================================
set -euo pipefail
ORG="${1:?usage: reset.sh <org> refresh|full}"
MODE="${2:?usage: reset.sh <org> refresh|full}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$MODE" in
  refresh)
    echo "==> QUICK REFRESH on $ORG (templates + data preserved)"
    sf apex run --target-org "$ORG" -f "$ROOT/reset/quick-refresh.apex"
    ;;
  full)
    echo "==> FULL RESET on $ORG — this deletes ALL demo data + templates."
    if [ "${3:-}" != "--yes" ]; then
      read -r -p "    Type 'yes' to continue: " confirm
      [ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }
    fi
    sf apex run --target-org "$ORG" -f "$ROOT/reset/full-reset.apex"
    echo "    Removing the 2,200-line giant catalog in chunks..."
    for i in $(seq 1 12); do
      out="$(sf apex run --target-org "$ORG" -f "$ROOT/reset/full-reset-giant.apex" 2>&1 || true)"
      rem="$(printf '%s' "$out" | grep -oE 'GIANT-REMAINING [0-9]+' | grep -oE '[0-9]+' | tail -1)"
      echo "    giant remaining: ${rem:-?}"
      [ "${rem:-1}" = "0" ] && break
    done
    echo "    Re-seed anytime with: bash \"$ROOT/install/setup.sh\" $ORG"
    ;;
  *)
    echo "Unknown mode '$MODE'. Use 'refresh' or 'full'."; exit 1;;
esac
