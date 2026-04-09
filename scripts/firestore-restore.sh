#!/usr/bin/env bash
# Restores Firestore from the latest or a specified backup.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: PROJECT_ID argument missing and no gcloud default project set."
  exit 1
fi

BUCKET="gs://${PROJECT_ID}-firestore-backups"

if [ -n "${2:-}" ]; then
  BACKUP_URI="$2"
else
  echo "Finding latest manual backup in ${BUCKET}/manual/..."
  BACKUP_URI="$(gsutil ls "${BUCKET}/manual/" | sort | tail -1)"
  if [ -z "${BACKUP_URI}" ]; then
    echo "ERROR: No backups found in ${BUCKET}/manual/"
    exit 1
  fi
fi

echo "Restoring Firestore from: ${BACKUP_URI}"
echo "WARNING: Firestore import is asynchronous and may take some time."
read -r -p "Continue? [y/N] " confirm
if [[ "${confirm}" != [yY] ]]; then
  echo "Aborted."
  exit 0
fi

gcloud firestore import "${BACKUP_URI}" \
  --project="${PROJECT_ID}" \
  --async

echo "Import initiated. Check status with:"
echo "  gcloud firestore operations list --project=${PROJECT_ID}"
