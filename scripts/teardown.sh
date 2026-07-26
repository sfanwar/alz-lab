#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Teardown, in the only order that works.
#
# Management groups will not delete while they still contain child groups,
# subscriptions, policy assignments or role assignments. Run this with a week
# of credit left, not on the last day - if the subscription gets disabled
# while still parented under a management group, cleanup gets awkward.
#
# Usage:
#   ./scripts/teardown.sh alzlab
# ---------------------------------------------------------------------------
set -euo pipefail

PREFIX="${1:?Usage: ./scripts/teardown.sh <prefix>}"
ROOT_MG=$(az account management-group list --query "[?properties.displayName=='Tenant Root Group'].name | [0]" -o tsv)

# Leaves first, root last.
GROUPS=(
  "${PREFIX}-corp"
  "${PREFIX}-online"
  "${PREFIX}-identity"
  "${PREFIX}-management"
  "${PREFIX}-connectivity"
  "${PREFIX}-platform"
  "${PREFIX}-landingzones"
  "${PREFIX}-sandbox"
  "${PREFIX}-decommissioned"
  "${PREFIX}"
)

# --- 1. move any subscriptions back to the tenant root ----------------------
echo "==> Relocating subscriptions to the tenant root group"
for mg in "${GROUPS[@]}"; do
  subs=$(az account management-group show --name "$mg" --expand \
         --query "children[?type=='/subscriptions'].name" -o tsv 2>/dev/null || true)
  for sub in $subs; do
    echo "    moving $sub out of $mg"
    az account management-group subscription add --name "$ROOT_MG" --subscription "$sub" >/dev/null
  done
done

# --- 2. remove policy assignments -------------------------------------------
# These block management group deletion and are easy to forget.
echo "==> Removing policy assignments"
for mg in "${GROUPS[@]}"; do
  scope="/providers/Microsoft.Management/managementGroups/${mg}"
  ids=$(az policy assignment list --scope "$scope" --query "[?scope=='$scope'].id" -o tsv 2>/dev/null || true)
  for id in $ids; do
    echo "    deleting assignment $(basename "$id")"
    az policy assignment delete --ids "$id" 2>/dev/null || true
  done
done

# --- 3. remove definitions and initiatives ----------------------------------
echo "==> Removing initiatives and policy definitions"
az policy set-definition delete --name 'ALZLab-Baseline' --management-group "$PREFIX" 2>/dev/null || true
az policy definition delete --name 'Deny-Storage-PublicBlobAccess' --management-group "$PREFIX" 2>/dev/null || true
az policy definition delete --name 'Deny-PublicIP' --management-group "$PREFIX" 2>/dev/null || true

# --- 4. delete management groups, leaves first ------------------------------
echo "==> Deleting management groups"
for mg in "${GROUPS[@]}"; do
  echo "    deleting $mg"
  az account management-group delete --name "$mg" 2>/dev/null || echo "      (skipped - not found or not empty)"
done

echo
echo "Done. Verify in the portal that no management groups remain under the"
echo "Tenant Root Group. Anything left over is usually a policy assignment"
echo "created outside this repo, or a subscription that did not move."
