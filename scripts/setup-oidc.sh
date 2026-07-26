#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time setup: creates an Entra ID app registration with federated
# credentials so GitHub Actions can authenticate to Azure with no secrets.
#
# Run this locally, signed in as yourself, AFTER you have elevated access at
# tenant root (see README step 1).
#
# Usage:
#   ./scripts/setup-oidc.sh <github-org>/<repo-name>
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="${1:?Usage: ./scripts/setup-oidc.sh <owner>/<repo>}"
APP_NAME="gh-alz-lab"
ENVIRONMENT_NAME="alz-lab"

TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "Tenant:       $TENANT_ID"
echo "Subscription: $SUBSCRIPTION_ID"
echo "Repository:   $REPO"
echo

# --- app registration + service principal ----------------------------------
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID" >/dev/null
echo "App registration created: $APP_ID"

# --- federated credentials --------------------------------------------------
# One per trigger context. The 'subject' must match exactly what GitHub sends,
# and a mismatch here is the single most common cause of AADSTS700213 errors.

# Pull requests - used by the what-if job.
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"gh-pull-request\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${REPO}:pull_request\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" >/dev/null
echo "Federated credential created: pull_request"

# Protected environment - used by the deploy job. Because the deploy job
# declares 'environment: alz-lab', GitHub sends an environment subject,
# NOT a branch subject. Getting this wrong is the classic first-run failure.
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"gh-environment\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${REPO}:environment:${ENVIRONMENT_NAME}\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" >/dev/null
echo "Federated credential created: environment:${ENVIRONMENT_NAME}"

# --- permissions ------------------------------------------------------------
# Owner at tenant root. Broad, but tenant-scope deployments and management
# group creation genuinely need it. Acceptable in a throwaway lab tenant;
# in production you would scope to the intermediate root and use a custom role.
az role assignment create \
  --assignee "$APP_ID" \
  --role "Owner" \
  --scope "/" >/dev/null
echo "Role assigned: Owner at tenant root"

cat <<EOF

---------------------------------------------------------------------------
Done. Now add these as GitHub repository VARIABLES (not secrets - none of
these are sensitive, and variables render readably in logs):

  Settings > Secrets and variables > Actions > Variables tab

  AZURE_CLIENT_ID        $APP_ID
  AZURE_TENANT_ID        $TENANT_ID
  AZURE_SUBSCRIPTION_ID  $SUBSCRIPTION_ID

Then create the protected environment:

  Settings > Environments > New environment > "alz-lab"
    -> tick "Required reviewers", add yourself, save

Note: required reviewers on a PRIVATE repo needs a paid plan. Make the repo
public, or drop the reviewer requirement and rely on branch protection.
---------------------------------------------------------------------------
EOF
