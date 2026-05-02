#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?PROJECT_ID is required}"
REGION="${REGION:?REGION is required}"
ZONE="${ZONE:?ZONE is required}"
FIRESTORE_LOCATION="${FIRESTORE_LOCATION:-eur3}"

in_state() {
  terraform state list "$1" >/dev/null 2>&1
}

import_if_missing() {
  local address="$1"
  local import_id="$2"
  local describe_command="$3"

  if in_state "$address"; then
    echo "State already contains ${address}; skipping import."
    return
  fi

  if bash -c "$describe_command" >/dev/null 2>&1; then
    echo "Importing existing ${address}..."
    terraform import "$address" "$import_id"
  else
    echo "Remote resource for ${address} does not exist; Terraform will create it."
  fi
}

import_firestore_database() {
  local address="google_firestore_database.travel_db"
  local import_id="projects/${PROJECT_ID}/databases/(default)"

  if in_state "$address"; then
    local location
    location="$(terraform state show "$address" 2>/dev/null | awk '/location_id/ { gsub(/"/, "", $3); print $3; exit }')"
    if [[ -n "$location" && "$location" != "$FIRESTORE_LOCATION" ]]; then
      echo "Firestore in state has wrong location (${location}); removing for re-import."
      terraform state rm "$address"
    else
      echo "State already contains ${address}; skipping import."
      return
    fi
  fi

  if gcloud firestore databases list --project="${PROJECT_ID}" --format="value(name)" | grep -q "(default)"; then
    echo "Importing existing ${address}..."
    terraform import "$address" "$import_id"
  else
    echo "No existing Firestore default DB found; Terraform will create it."
  fi
}

import_firestore_database

import_if_missing \
  "google_storage_bucket.firestore_backups" \
  "${PROJECT_ID}-firestore-backups" \
  "gcloud storage buckets describe gs://${PROJECT_ID}-firestore-backups --project=${PROJECT_ID}"

import_if_missing \
  "google_service_account.firestore_backup_sa" \
  "projects/${PROJECT_ID}/serviceAccounts/firestore-backup-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  "gcloud iam service-accounts describe firestore-backup-sa@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID}"

import_if_missing \
  "google_service_account.travel_vm_sa" \
  "projects/${PROJECT_ID}/serviceAccounts/travel-assistant-vm@${PROJECT_ID}.iam.gserviceaccount.com" \
  "gcloud iam service-accounts describe travel-assistant-vm@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID}"

import_if_missing \
  "google_project_service.secret_manager_api" \
  "${PROJECT_ID}/secretmanager.googleapis.com" \
  "gcloud services list --enabled --project=${PROJECT_ID} --filter='config.name:secretmanager.googleapis.com' --format='value(config.name)' | grep -q '^secretmanager.googleapis.com$'"

import_if_missing \
  "google_project_service.cloud_scheduler_api" \
  "${PROJECT_ID}/cloudscheduler.googleapis.com" \
  "gcloud services list --enabled --project=${PROJECT_ID} --filter='config.name:cloudscheduler.googleapis.com' --format='value(config.name)' | grep -q '^cloudscheduler.googleapis.com$'"

import_if_missing \
  "google_secret_manager_secret.gemini_api_key" \
  "projects/${PROJECT_ID}/secrets/gemini-api-key" \
  "gcloud secrets describe gemini-api-key --project=${PROJECT_ID}"

import_if_missing \
  "google_secret_manager_secret.jwt_secret_key" \
  "projects/${PROJECT_ID}/secrets/jwt-secret-key" \
  "gcloud secrets describe jwt-secret-key --project=${PROJECT_ID}"

import_if_missing \
  "google_service_account.monitoring_vm_sa" \
  "projects/${PROJECT_ID}/serviceAccounts/travel-assistant-monitoring@${PROJECT_ID}.iam.gserviceaccount.com" \
  "gcloud iam service-accounts describe travel-assistant-monitoring@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID}"

import_if_missing \
  "google_artifact_registry_repository.travel_assistant" \
  "projects/${PROJECT_ID}/locations/${REGION}/repositories/travel-assistant" \
  "gcloud artifacts repositories describe travel-assistant --location=${REGION} --project=${PROJECT_ID}"

import_if_missing \
  "google_storage_bucket.app_configs" \
  "${PROJECT_ID}-travel-assistant-configs" \
  "gcloud storage buckets describe gs://${PROJECT_ID}-travel-assistant-configs --project=${PROJECT_ID}"

import_if_missing \
  "google_compute_global_address.app_static_ip" \
  "projects/${PROJECT_ID}/global/addresses/travel-assistant-app-ip" \
  "gcloud compute addresses describe travel-assistant-app-ip --global --project=${PROJECT_ID}"

import_if_missing \
  "google_compute_health_check.app_health" \
  "projects/${PROJECT_ID}/global/healthChecks/travel-assistant-app-health" \
  "gcloud compute health-checks describe travel-assistant-app-health --global --project=${PROJECT_ID}"

import_if_missing \
  "google_compute_disk.monitoring_data" \
  "projects/${PROJECT_ID}/zones/${ZONE}/disks/travel-assistant-monitoring" \
  "gcloud compute disks describe travel-assistant-monitoring --zone=${ZONE} --project=${PROJECT_ID}"

for firewall in \
  "allow_lb_http:travel-assistant-allow-lb-http" \
  "allow_metrics_from_monitoring:travel-assistant-allow-monitoring-http" \
  "monitoring_allow_http:travel-monitoring-allow-http" \
  "monitoring_allow_ssh:travel-monitoring-allow-ssh" \
  "allow_node_exporter_from_monitoring:travel-allow-node-exporter-from-monitoring" \
  "allow_loki_from_app:travel-allow-loki-from-app"; do
  tf_name="${firewall%%:*}"
  gcp_name="${firewall##*:}"
  import_if_missing \
    "google_compute_firewall.${tf_name}" \
    "projects/${PROJECT_ID}/global/firewalls/${gcp_name}" \
    "gcloud compute firewall-rules describe ${gcp_name} --project=${PROJECT_ID}"
done
