#!/usr/bin/env bash
# startup.sh — bootstraps the app VM on first boot.
#
# Runs automatically when the MIG creates a new VM (initial deploy or
# autohealing recovery). Installs Docker, pulls configs and the pre-built
# .env from GCS, then starts docker-compose.
#
# CI/CD uploads docker-compose.yml, promtail config, and the rendered .env
# to the GCS config bucket on every deploy, so this script always gets the
# latest versions.
#
# Template variables substituted by Terraform at plan time:
#   project_id    — GCP project ID
#   region        — GCP region (for Artifact Registry auth)
#   config_bucket — GCS bucket name
#   image_tag     — release image tag pinned into .env for this VM template
set -euo pipefail

PROJECT_ID="${project_id}"
REGION="${region}"
CONFIG_BUCKET="${config_bucket}"
IMAGE_TAG="${image_tag}"
LOKI_URL="${loki_url}"

APP_DIR=/opt/travel-assistant
LOG=/var/log/startup.log

exec > >(tee -a "$LOG") 2>&1
echo "[startup] $(date -u +%FT%TZ) — beginning bootstrap"

log_json() {
  local level="$1"
  local event="$2"
  local reason="$3"
  local message="$4"
  printf '{"level":"%s","event":"%s","reason":"%s","message":"%s","project_id":"%s","image_tag":"%s","instance":"%s","time":"%s"}\n' \
    "$level" "$event" "$reason" "$message" "$PROJECT_ID" "$IMAGE_TAG" "$(hostname)" "$(date -u +%FT%TZ)"
}

log_json "INFO" "vm_recovery_event" "vm_boot" "App VM bootstrap started"

# ── 1. Install Docker ─────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y docker-ce docker-compose-plugin

# ── 2. Deploy user ────────────────────────────────────────────────────────────
useradd -m -s /bin/bash deploy 2>/dev/null || true
usermod -aG docker deploy

# ── 3. App directory ──────────────────────────────────────────────────────────
mkdir -p "$APP_DIR/monitoring/promtail"
chown -R deploy:deploy "$APP_DIR"

# ── 4. Pull all files from GCS ────────────────────────────────────────────────
# CI/CD uploads these on every deploy:
#   docker-compose.yml          — service definitions
#   monitoring/promtail/promtail.yml — log shipper config
#   .env                        — rendered by Ansible from GitHub secrets
echo "[startup] pulling configs from gs://$CONFIG_BUCKET/"
gsutil -m cp "gs://$CONFIG_BUCKET/docker-compose.yml"                      "$APP_DIR/docker-compose.yml"
gsutil -m cp "gs://$CONFIG_BUCKET/monitoring/promtail/promtail.yml"        "$APP_DIR/monitoring/promtail/promtail.yml"
gsutil -m cp "gs://$CONFIG_BUCKET/.env"                                    "$APP_DIR/.env"

# The MIG rollout is keyed off the instance template's image tag. Pin that tag
# locally even if the bucket contents lag briefly during the deploy pipeline.
if grep -q '^IMAGE_TAG=' "$APP_DIR/.env"; then
  sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$IMAGE_TAG/" "$APP_DIR/.env"
else
  printf '\nIMAGE_TAG=%s\n' "$IMAGE_TAG" >> "$APP_DIR/.env"
fi

# Ensure promtail can reach Loki on the monitoring VM.
if grep -q '^LOKI_URL=' "$APP_DIR/.env"; then
  sed -i "s|^LOKI_URL=.*|LOKI_URL=$LOKI_URL|" "$APP_DIR/.env"
else
  printf 'LOKI_URL=%s\n' "$LOKI_URL" >> "$APP_DIR/.env"
fi

chmod 600 "$APP_DIR/.env"
chown -R deploy:deploy "$APP_DIR"

# ── 5. Authenticate Docker with Artifact Registry ────────────────────────────
echo "[startup] authenticating Docker with Artifact Registry"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

# ── 6. Start the app ──────────────────────────────────────────────────────────
echo "[startup] pulling images and starting services"
cd "$APP_DIR"
docker compose pull --quiet
docker compose up -d

echo "[startup] $(date -u +%FT%TZ) — bootstrap complete"
log_json "INFO" "app_instance_started" "vm_boot" "App services started after VM bootstrap"
