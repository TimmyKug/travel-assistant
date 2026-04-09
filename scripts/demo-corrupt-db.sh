#!/usr/bin/env bash
# Deletes fixed demo reference data to simulate Firestore corruption.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: PROJECT_ID argument missing and no gcloud default project set."
  exit 1
fi

echo "=== DEMO: Simulating Firestore data corruption ==="
echo "This deletes analytics/system and users/demo-user/trips/demo-trip."
echo ""

python3 -c "
from google.cloud import firestore

db = firestore.Client(project='${PROJECT_ID}')

print('Deleting analytics/system...')
db.collection('analytics').document('system').delete()

print('Deleting users/demo-user/trips/demo-trip...')
db.collection('users').document('demo-user').collection('trips').document('demo-trip').delete()

print()
print('Database corruption simulated.')
print('Check /api/health/db. It should now report unhealthy.')
"
