#!/usr/bin/env bash
# Grant the demo permission sets to teammates.
#   Usage: bash "DEMO TEMPLATES/install/assign-team.sh" <orgAlias> user1@example.com user2@example.com ...
#   Each user gets DocGen_Admin (template builder + generate) and DocGen_Demo
#   (the demo objects/fields/tabs). Use DocGen_User instead of DocGen_Admin for
#   generate-only access (edit the PSETS line below).
set -euo pipefail
ORG="${1:?usage: assign-team.sh <org> <username> [username...]}"
shift
PSETS=(DocGen_Admin DocGen_Demo)
for user in "$@"; do
  for ps in "${PSETS[@]}"; do
    echo "Assigning $ps to $user"
    sf org assign permset --target-org "$ORG" --name "$ps" --on-behalf-of "$user" 2>/dev/null \
      || echo "  ($ps already assigned to $user, or user not found)"
  done
done
echo "Done."
