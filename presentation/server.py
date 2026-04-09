import http.server
import socketserver
import subprocess
import json

PORT = 8080

class PresentationHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/kill-vm':
            try:
                # Hole die erste gefundene App VM aus der MIG
                cmd_list = 'gcloud compute instances list --filter="name~^travel-assistant-app-" --format="value(name)" --limit=1'
                instance_name = subprocess.check_output(cmd_list, shell=True).decode().strip()
                
                if not instance_name:
                    self.send_response(404)
                    self.end_headers()
                    self.wfile.write(b'Keine laufende App VM gefunden.')
                    return

                cmd_zone = f'gcloud compute instances list --filter="name={instance_name}" --format="value(zone)"'
                zone = subprocess.check_output(cmd_zone, shell=True).decode().strip()
                
                print(f"🔥 ZERSTÖRUNG EINGELEITET: Lösche Instanz {instance_name} in Zone {zone} 🔥")
                
                # Delete instance (asynchronously so UI updates instantly)
                cmd_delete = f'gcloud compute instances delete {instance_name} --zone={zone} --quiet'
                subprocess.Popen(cmd_delete, shell=True)

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = json.dumps({"status": "destroyed", "instance": instance_name})
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
print("   Der KILL-VM Button wird gcloud-Befehle von diesem Terminal aus starten.")
with socketserver.TCPServer(("", PORT), PresentationHandler) as httpd:
    httpd.serve_forever()
