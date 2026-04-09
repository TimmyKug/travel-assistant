#!/usr/bin/env bash
# Deletes Firestore user data to simulate visible data corruption during the demo.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: PROJECT_ID argument missing and no gcloud default project set."
  exit 1
fi

if ! python3 - <<'PY' >/dev/null 2>&1
from google.cloud import firestore
PY
then
  echo "ERROR: python3 cannot import google.cloud.firestore."
  echo "Run this script from an environment where google-cloud-firestore is installed."
  echo "Do not install dependencies inside the Obsidian/iCloud workspace."
  exit 1
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "ERROR: No Application Default Credentials available for Firestore access."
  echo "Run: gcloud auth application-default login"
  exit 1
fi

echo "=== DEMO: Simulating Firestore data corruption ==="
echo "This deletes all user data plus the analytics/system document."
echo ""

python3 -c "
from google.cloud import firestore

db = firestore.Client(project='${PROJECT_ID}')

print('Deleting all users including trips and conversations...')
users = list(db.collection('users').stream())
for user in users:
    user_ref = db.collection('users').document(user.id)

    for subcollection_name in ('trips', 'conversations'):
        docs = list(user_ref.collection(subcollection_name).stream())
        for doc in docs:
            doc.reference.delete()
            print(f'  Deleted {subcollection_name}/{doc.id} for user {user.id}')

    user_ref.delete()
    print(f'  Deleted user {user.id}')

print('Deleting analytics/system...')
db.collection('analytics').document('system').delete()

print()
print('Database corruption simulated.')
print('The app should still load, but user data should be gone.')
print('Check /api/health/db. It should now report unhealthy.')
"
