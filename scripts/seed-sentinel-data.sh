#!/usr/bin/env bash
# Seeds deterministic Firestore sentinel data for integrity checks.
set -euo pipefail

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"

if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: PROJECT_ID argument missing and no gcloud default project set."
  exit 1
fi

python3 -c "
from datetime import datetime, timezone
from google.cloud import firestore

db = firestore.Client(project='${PROJECT_ID}')
now = datetime.now(timezone.utc).isoformat()

db.collection('users').document('sentinel-user').set({
    'display_name': 'Sentinel User',
    'email': 'sentinel@example.com',
    'created_at': now,
}, merge=True)

db.collection('users').document('sentinel-user').collection('trips').document('sentinel-trip').set({
    'title': 'Recovery Sentinel Trip',
    'destination': 'Rome',
    'start_date': '2026-06-01',
    'end_date': '2026-06-07',
    'status': 'planned',
    'notes': 'Reference trip for Firestore integrity checks',
    'updated_at': now,
}, merge=True)

db.collection('users').document('sentinel-user').collection('conversations').document('sentinel-conversation').set({
    'title': 'Recovery Sentinel Conversation',
    'messages': [
        {'role': 'user', 'parts': ['Plan my Rome trip']},
        {'role': 'model', 'parts': ['Sure, here is a simple itinerary.']},
    ],
    'updated_at': now,
}, merge=True)

db.collection('analytics').document('system').set({
    'seed_version': 1,
    'last_seeded_at': now,
}, merge=True)

print('Seeded Firestore sentinel reference data.')
print('User: users/sentinel-user')
print('Trip: users/sentinel-user/trips/sentinel-trip')
print('Conversation: users/sentinel-user/conversations/sentinel-conversation')
print('Analytics: analytics/system')
"
