#!/usr/bin/env bash
set -e

# Wechselt in das Verzeichnis dieses Skripts
cd "$(dirname "$0")"

echo "Suche Monitoring VM IP via gcloud..."

# Holt die öffentliche IP der Monitoring-VM
MONITORING_IP=$(gcloud compute instances list \
    --filter="name=travel-assistant-monitoring-vm" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

if [ -z "$MONITORING_IP" ]; then
    echo "Fehler: Konnte keine IP für 'travel-assistant-monitoring-vm' finden."
    echo "Bist du im richtigen gcloud Projekt eingeloggt? (gcloud config set project <project-id>)"
    exit 1
fi

echo "Gefundene Monitoring IP: $MONITORING_IP"

# Die Basis-Grafana-URL mit der gefundenen IP
NEW_URL="http://$MONITORING_IP/grafana/d/travel-assistant/travel-assistant?orgId=1&refresh=5s&theme=dark"

# Ersetzt die Platzhalter-URL ODER eine bereits eingetragene alte IP in der index.html
# Wir matchen alles was nach 'src="http' oder 'data-src="http' kommt bis zum nächsten Anführungszeichen, 
# wenn es grafana enthält.
sed -i.bak -e 's|src="[^"]*grafana/d/[^"]*"|src="'"$NEW_URL"'"|g' index.html
sed -i.bak -e 's|data-src="[^"]*grafana/d/[^"]*"|data-src="'"$NEW_URL"'"|g' index.html
sed -i.bak -e 's|YOUR_GRAFANA_URL_HERE_WITH_HTTP|'"$NEW_URL"'|g' index.html

rm -f index.html.bak

echo "Erfolg! index.html wurde mit der IP $MONITORING_IP aktualisiert."

# Öffne die Präsentation im Standard-Browser
echo "Starte Präsentation im Browser..."
open index.html
