#!/usr/bin/env bash
# Seeds deterministic Firestore demo data for the disaster-recovery demo.
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

db.collection('users').document('demo-user').set({
    'display_name': 'Demo User',
    'email': 'demo@example.com',
    'created_at': now,
}, merge=True)

db.collection('users').document('demo-user').collection('trips').document('demo-trip').set({
    'title': 'Recovery Demo Trip',
    'destination': 'Rome',
    'start_date': '2026-06-01',
    'end_date': '2026-06-07',
    'status': 'planned',
    'notes': 'Reference trip for Firestore integrity demo',
    'updated_at': now,
}, merge=True)

db.collection('users').document('demo-user').collection('conversations').document('demo-conversation').set({
    'title': 'Recovery Demo Conversation',
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

print('Seeded Firestore demo reference data.')
print('User: users/demo-user')
print('Trip: users/demo-user/trips/demo-trip')
print('Conversation: users/demo-user/conversations/demo-conversation')
print('Analytics: analytics/system')
"
