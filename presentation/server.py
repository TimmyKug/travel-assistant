import http.server
import socketserver
import subprocess
import json
import os
import re
from pathlib import Path

PORT = 8080
REPO_ROOT = Path(__file__).resolve().parent.parent
DEMO_SCRIPTS_DIR = Path(__file__).resolve().parent / "demo-scripts"
CORRUPT_SCRIPT = DEMO_SCRIPTS_DIR / "demo-corrupt-db.sh"
RESTORE_SCRIPT = DEMO_SCRIPTS_DIR / "firestore-restore.sh"
PROJECT_ID = "timmys-travel-assistant"
LAST_RESTORE_OPERATION = None


class PresentationHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self.path == "/restore-status":
            global LAST_RESTORE_OPERATION
            if not LAST_RESTORE_OPERATION:
                self.send_response(404)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "idle",
                            "message": "No restore operation has been started yet.",
                        }
                    ).encode()
                )
                return

            try:
                output = subprocess.check_output(
                    [
                        "gcloud",
                        "firestore",
                        "operations",
                        "list",
                        f"--project={PROJECT_ID}",
                        "--format=json",
                    ],
                    cwd=REPO_ROOT,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                operations = json.loads(output)
                operation = next(
                    (
                        item
                        for item in operations
                        if item.get("name") == LAST_RESTORE_OPERATION
                    ),
                    None,
                )
                if operation is None:
                    import_operations = [
                        item
                        for item in operations
                        if item.get("metadata", {})
                        .get("@type", "")
                        .endswith("ImportDocumentsMetadata")
                    ]
                    import_operations.sort(
                        key=lambda item: item.get("metadata", {}).get("startTime", ""),
                        reverse=True,
                    )
                    operation = import_operations[0] if import_operations else None

                if operation is None:
                    self.send_response(404)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(
                        json.dumps(
                            {
                                "status": "error",
                                "message": "Restore operation could not be found in Firestore operations.",
                            }
                        ).encode()
                    )
                    return

                done = operation.get("done", False)
                metadata = operation.get("metadata", {})
                response = {
                    "status": "completed" if done else "restoring",
                    "done": done,
                    "operation": LAST_RESTORE_OPERATION,
                    "operation_state": metadata.get("operationState"),
                }
                if done:
                    response["message"] = "Firestore restore is complete."
                else:
                    response["message"] = "Firestore restore is still running."

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                return
            except subprocess.CalledProcessError as e:
                self.send_response(500)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "error",
                            "message": "Failed to query restore status.",
                            "output": e.output,
                        }
                    ).encode()
                )
                return

        return super().do_GET()

    def do_POST(self):
        if self.path == "/kill-vm":
            try:
                # Hole ALLE App VMs aus der MIG
                cmd_list = 'gcloud compute instances list --filter="name~^travel-assistant-vm-" --format="value(name,zone)"'
                output = subprocess.check_output(cmd_list, shell=True).decode().strip()

                if not output:
                    self.send_response(404)
                    self.end_headers()
                    self.wfile.write(b"Keine laufende App VM gefunden.")
                    return

                killed = []
                for line in output.splitlines():
                    parts = line.split()
                    if len(parts) < 2:
                        continue
                    instance_name, zone = parts[0], parts[1]

                    print(
                        f"🔥 ZERSTÖRUNG EINGELEITET: Lösche Instanz {instance_name} in Zone {zone} 🔥"
                    )

                    # Delete VM — MIG will automatically create a new one
                    cmd_kill = f"gcloud compute instances delete {instance_name} --zone={zone} --quiet"
                    subprocess.Popen(cmd_kill, shell=True)
                    killed.append(instance_name)

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                response = json.dumps(
                    {
                        "status": "destroyed",
                        "instances": killed,
                        "instance": ", ".join(killed),
                    }
                )
                self.wfile.write(response.encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        elif self.path == "/corrupt-db":
            try:
                print("☠️ DATENKORRUPTION EINGELEITET: Starte demo-corrupt-db.sh ☠️")
                output = subprocess.check_output(
                    [str(CORRUPT_SCRIPT)],
                    cwd=REPO_ROOT,
                    stderr=subprocess.STDOUT,
                    text=True,
                )

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                response = json.dumps(
                    {
                        "status": "corrupted",
                        "message": "Firestore-Demodaten wurden erfolgreich korrumpiert.",
                        "output": output,
                    }
                )
                self.wfile.write(response.encode())
            except subprocess.CalledProcessError as e:
                print("❌ DATENKORRUPTION FEHLGESCHLAGEN")
                print(e.output)
                self.send_response(500)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                response = json.dumps(
                    {
                        "status": "error",
                        "message": "Firestore-Datenkorruption fehlgeschlagen.",
                        "output": e.output,
                    }
                )
                self.wfile.write(response.encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        elif self.path == "/restore-db":
            try:
                global LAST_RESTORE_OPERATION
                print("🛠️ RESTORE EINGELEITET: Starte firestore-restore.sh 🛠️")
                output = subprocess.check_output(
                    [str(RESTORE_SCRIPT), PROJECT_ID],
                    cwd=REPO_ROOT,
                    stderr=subprocess.STDOUT,
                    text=True,
                    env={**os.environ, "AUTO_CONFIRM": "1"},
                )
                match = re.search(r"^name:\s*(.+)$", output, re.MULTILINE)
                LAST_RESTORE_OPERATION = match.group(1).strip() if match else None

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                response = json.dumps(
                    {
                        "status": "restoring",
                        "message": "Firestore restore was started successfully.",
                        "operation": LAST_RESTORE_OPERATION,
                        "output": output,
                    }
                )
                self.wfile.write(response.encode())
            except subprocess.CalledProcessError as e:
                print("❌ RESTORE FEHLGESCHLAGEN")
                print(e.output)
                self.send_response(500)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                response = json.dumps(
                    {
                        "status": "error",
                        "message": "Failed to start Firestore restore.",
                        "output": e.output,
                    }
                )
                self.wfile.write(response.encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        else:
            self.send_response(404)
            self.end_headers()


# Verhindert Address Already in Use Errors
socketserver.TCPServer.allow_reuse_address = True

print(f"🚀 Präsentations-Server läuft auf http://localhost:{PORT}")
print(
    "   Die Demo-Buttons werden lokale Skripte und gcloud-Befehle von diesem Terminal aus starten."
)
with socketserver.TCPServer(("", PORT), PresentationHandler) as httpd:
    httpd.serve_forever()
