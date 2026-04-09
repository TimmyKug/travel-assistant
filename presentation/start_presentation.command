#!/usr/bin/env bash
set -e

# Wechselt in das Verzeichnis dieses Skripts
cd "$(dirname "$0")"

echo "Suche Monitoring VM IP via gcloud..."

# Holt die öffentliche IP der Monitoring-VM
MONITORING_IP=$(gcloud compute instances list \
    --filter="name=travel-assistant-monitoring-vm" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

echo "Suche App Load Balancer IP via gcloud..."
APP_IP=$(gcloud compute addresses describe travel-assistant-app-ip \
    --global \
    --format="value(address)")

if [ -z "$MONITORING_IP" ] || [ -z "$APP_IP" ]; then
    echo "Fehler: Konnte IPs nicht finden. Stelle sicher, dass du im richtigen gcloud-Projekt bist."
    exit 1
fi

echo "Gefundene Monitoring IP: $MONITORING_IP"
echo "Gefundene App IP: $APP_IP"

# URLs zusammenbauen. Wichtig: & muss für sed in Bash doppelt maskiert werden (\\&)
NEW_GRAFANA_URL="http://$MONITORING_IP/grafana/d/travel-assistant/travel-assistant?orgId=1\\&refresh=5s\\&theme=dark"
NEW_APP_URL="http://$APP_IP/"

# Ersetzen
sed -i.bak -e 's|src="[^"]*grafana/d/[^"]*"|src="'"$NEW_GRAFANA_URL"'"|g' index.html
sed -i.bak -e 's|data-src="[^"]*grafana/d/[^"]*"|data-src="'"$NEW_GRAFANA_URL"'"|g' index.html
sed -i.bak -e 's|YOUR_GRAFANA_URL_HERE_WITH_HTTP|'"$NEW_GRAFANA_URL"'|g' index.html

# App-Iframe-URLs müssen ebenfalls aktualisiert werden, die haben aktuell entweder 136... oder 34.160...
# Wir targeten alles was nicht grafana enthält, aber das ist riskant.
# Besser: Wir ersetzen einfach alle IP-Muster im iFrame src/data-src, die NICHT grafana sind.
sed -i.bak -e 's|src="http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/"|src="'"$NEW_APP_URL"'"|g' index.html
sed -i.bak -e 's|data-src="http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/"|data-src="'"$NEW_APP_URL"'"|g' index.html

rm -f index.html.bak

echo "Erfolg! index.html wurde mit der IP $MONITORING_IP aktualisiert."

# Starte den lokalen Python-Server für den "VM Kill" Button
echo "Starte Präsentations-Server auf http://localhost:8080..."
sleep 1
open "http://localhost:8080"
python3 server.py
