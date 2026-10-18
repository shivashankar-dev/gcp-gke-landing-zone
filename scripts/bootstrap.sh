#!/usr/bin/env bash
# One-time setup: Terraform state bucket, deployer service account, and
# Workload Identity Federation so GitHub Actions can deploy without any key files.
#
# Usage: ./scripts/bootstrap.sh <project-id> <github-owner/repo> [region]
set -euo pipefail

PROJECT_ID="${1:?project id required}"
REPO="${2:?github owner/repo required, e.g. alice/gcp-gke-landing-zone}"
REGION="${3:-asia-south1}"

POOL="github-pool"
PROVIDER="github-provider"
SA_NAME="terraform-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
BUCKET="${PROJECT_ID}-tfstate"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

echo ">> Enabling APIs"
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  cloudresourcemanager.googleapis.com storage.googleapis.com --project "$PROJECT_ID"

echo ">> State bucket gs://${BUCKET} (versioned, uniform access)"
if ! gcloud storage buckets describe "gs://${BUCKET}" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET}" --project "$PROJECT_ID" \
    --location "$REGION" --uniform-bucket-level-access
fi
gcloud storage buckets update "gs://${BUCKET}" --versioning

echo ">> Deployer service account"
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --project "$PROJECT_ID" \
    --display-name "Terraform deployer (GitHub Actions)"
fi

# Sandbox convenience. In a real organisation, grant narrower roles
# (container.admin, compute.networkAdmin, iam.serviceAccountAdmin, ...).
for role in roles/editor roles/resourcemanager.projectIamAdmin roles/iam.serviceAccountAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${SA_EMAIL}" --role "$role" --condition=None >/dev/null
done
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" \
  --member "serviceAccount:${SA_EMAIL}" --role roles/storage.objectAdmin >/dev/null

echo ">> Workload Identity pool and GitHub OIDC provider"
if ! gcloud iam workload-identity-pools describe "$POOL" --location global --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL" --location global --project "$PROJECT_ID" \
    --display-name "GitHub Actions"
fi
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER" --workload-identity-pool "$POOL" \
  --location global --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
    --workload-identity-pool "$POOL" --location global --project "$PROJECT_ID" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition "assertion.repository == '${REPO}'"
fi

# Only workflows from this exact repository can impersonate the deployer.
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" --project "$PROJECT_ID" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}" >/dev/null

cat <<EOF

Done. Add these as GitHub environment variables (Settings > Environments > dev > Variables):

  GCP_PROJECT_ID   = ${PROJECT_ID}
  GCP_WIF_PROVIDER = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}
  GCP_TERRAFORM_SA = ${SA_EMAIL}
  TF_STATE_BUCKET  = ${BUCKET}
EOF
