#!/bin/bash
# Run this ONCE before the first push to create the GCS Terraform state bucket.
# After that, GitHub Actions handles everything automatically.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${2:-europe-west1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: ./scripts/bootstrap.sh YOUR_PROJECT_ID [REGION]"
  exit 1
fi

BUCKET="${PROJECT_ID}-terraform-state"
echo "Creating GCS state bucket: gs://$BUCKET"
gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET" || echo "Bucket may already exist, continuing..."
gsutil versioning set on "gs://$BUCKET"

echo ""
echo "✅ Done! Set these GitHub Secrets, then push to main:"
echo ""
echo "   Secret name              Value"
echo "   ─────────────────────────────────────────────────────"
echo "   GCP_SA_KEY               JSON service account key (roles: Compute Admin, Datastore Owner, Storage Admin, IAM User)"
echo "   GCP_PROJECT_ID           $PROJECT_ID"
echo "   GCP_REGION               $REGION"
echo "   GCP_ZONE                 ${REGION}-b"
echo "   SSH_PUBLIC_KEY           your public key (ssh-rsa AAAA...)"
echo "   SSH_PRIVATE_KEY          your private key"
echo "   GEMINI_API_KEY           from Google AI Studio (aistudio.google.com)"
echo "   JWT_SECRET               \$(openssl rand -hex 32)"
echo "   GRAFANA_ADMIN_PASSWORD   choose a strong password"
echo "   GITHUB_REPO_URL          https://github.com/YOU/YOUR_REPO"
