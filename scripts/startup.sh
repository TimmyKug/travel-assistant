#!/usr/bin/env bash
# startup.sh — bootstraps the app VM on first boot.
#
# This script runs automatically when the Managed Instance Group creates a new
# VM (both on first deploy and after autohealing replaces an unhealthy instance).
# It installs Docker, pulls config files from GCS, fetches secrets from Secret
# Manager, and starts the app stack — no manual Ansible run required.
#
# Template variables are substituted by Terraform at plan time:
#   project_id    — GCP project ID
#   region        — GCP region (for Artifact Registry)
#   config_bucket — GCS bucket containing docker-compose.yml and promtail config
#   loki_url      — Internal URL of the monitoring VM's Loki instance
set -euo pipefail

PROJECT_ID="${project_id}"
REGION="${region}"
CONFIG_BUCKET="${config_bucket}"
LOKI_URL="${loki_url}"

APP_DIR=/opt/travel-assistant
LOG=/var/log/startup.log

exec > >(tee -a "$LOG") 2>&1
echo "[startup] $(date -u +%FT%TZ) — beginning bootstrap"

# ── 1. System packages ────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg

# Docker (official apt repo)
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

# ── 4. Pull config files from GCS ─────────────────────────────────────────────
# CI/CD uploads docker-compose.yml and promtail config here on every deploy.
echo "[startup] pulling configs from gs://$CONFIG_BUCKET/"
gsutil -m cp "gs://$CONFIG_BUCKET/docker-compose.yml" "$APP_DIR/docker-compose.yml"
gsutil -m cp "gs://$CONFIG_BUCKET/monitoring/promtail/promtail.yml" \
  "$APP_DIR/monitoring/promtail/promtail.yml"
chown -R deploy:deploy "$APP_DIR"

# ── 5. Fetch secrets from Secret Manager ──────────────────────────────────────
echo "[startup] fetching secrets from Secret Manager"

# Access the instance's OAuth token via the metadata server
TOKEN=$(curl -sf \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  -H "Metadata-Flavor: Google" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

fetch_secret() {
  local secret_name="$1"
  curl -sf \
    "https://secretmanager.googleapis.com/v1/projects/$PROJECT_ID/secrets/$secret_name/versions/latest:access" \
    -H "Authorization: Bearer $TOKEN" \
    | python3 -c "import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)['payload']['data']).decode())"
}

JWT_SECRET_KEY=$(fetch_secret "travel-assistant-jwt-secret-key")
GEMINI_API_KEY=$(fetch_secret "travel-assistant-gemini-api-key")

# ── 6. Write .env ─────────────────────────────────────────────────────────────
cat > "$APP_DIR/.env" << ENV
GCP_PROJECT_ID=$PROJECT_ID
JWT_SECRET_KEY=$JWT_SECRET_KEY
GEMINI_API_KEY=$GEMINI_API_KEY
LOKI_URL=$LOKI_URL
IMAGE_TAG=latest
ENV
chmod 600 "$APP_DIR/.env"
chown deploy:deploy "$APP_DIR/.env"

# ── 7. Authenticate Docker with Artifact Registry ────────────────────────────
echo "[startup] authenticating Docker with Artifact Registry"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

# ── 8. Start the app ──────────────────────────────────────────────────────────
echo "[startup] pulling images and starting services"
cd "$APP_DIR"
docker compose pull --quiet
docker compose up -d

echo "[startup] $(date -u +%FT%TZ) — bootstrap complete"
