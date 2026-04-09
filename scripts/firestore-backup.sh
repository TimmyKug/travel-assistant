#!/usr/bin/env bash
# Triggers a manual Firestore export to GCS.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: PROJECT_ID argument missing and no gcloud default project set."
  exit 1
fi

BUCKET="gs://${PROJECT_ID}-firestore-backups"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_URI="${BUCKET}/manual/${TIMESTAMP}"

echo "Starting Firestore export to ${OUTPUT_URI}..."
gcloud firestore export "${OUTPUT_URI}" \
  --project="${PROJECT_ID}" \
  --async

echo "Export initiated. Check status with:"
echo "  gcloud firestore operations list --project=${PROJECT_ID}"
