#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node
#import "@preview/cetz:0.3.4"
#import "@preview/acrostiche:0.7.0": *
#import fletcher.shapes: circle, diamond, hexagon, pill, rect

// ========= Document setup =========
#init-acronyms((
  "ACID": "Atomicity, Consistency, Isolation, Durability",
  "API": "Application Programming Interface",
  "ASGI": "Asynchronous Server Gateway Interface",
  "CI/CD": "Continuous Integration/Continuous Deployment",
  "CPU": "Central Processing Unit",
  "CRA": "Create React App",
  "CRUD": "Create, Read, Update, Delete",
  "DB": "Datenbank",
  "GCE": "Google Compute Engine",
  "GCP": "Google Cloud Platform",
  "GCS": "Google Cloud Storage",
  "GKE": "Google Kubernetes Engine",
  "HTTP": "Hypertext Transfer Protocol",
  "HTTP(S)": (
    short: "HTTP(S)",
    long: "Hypertext Transfer Protocol Secure",
  ),
  "HTTPS": "Hypertext Transfer Protocol Secure",
  "I/O": "Input/Output",
  "IaaS": "Infrastructure as a Service",
  "IAM": "Identity and Access Management",
  "IP": "Internet Protocol",
  "IaC": "Infrastructure as Code",
  "JWT": ("JSON Web Token", "JSON Web Tokens"),
  "KI": "Künstliche Intelligenz",
  "LB": "Load Balancer",
  "MIG": "Managed Instance Group",
  "NoSQL": "Not only SQL",
  "ORM": "Object-Relational Mapping",
  "OTel": "OpenTelemetry",
  "OTLP": "OpenTelemetry Protocol",
  "OAuth": "Open Authorization",
  "PITR": "Point-in-Time Recovery",
  "PaaS": "Platform as a Service",
  "RPO": "Recovery Point Objective",
  "RTO": "Recovery Time Objective",
  "SaaS": "Software as a Service",
  "SMTP": "Simple Mail Transfer Protocol",
  "SPA": "Single Page Application",
  "SSH": "Secure Shell",
  "SSR": "Server-Side Rendering",
  "UI": "User Interface",
  "URL": "Uniform Resource Locator",
  "VM": (
    short: "VM",
    short-pl: "VMs",
    long: "Virtual Machine",
    long-pl: "Virtual Machines",
  ),
))

#set document(
  title: "Timmy's Travel Assistant — Projektarbeit Cloud Computing II",
  author: "Timothy Kugler",
)

#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
  numbering: "1",
  number-align: center,
)

#set text(
  font: "New Computer Modern",
  size: 11pt,
  lang: "de",
  region: "DE",
)

#set par(justify: true, leading: 0.7em, first-line-indent: 0pt)
#show heading: set block(above: 1.4em, below: 0.8em)
#set heading(numbering: "1.1")

#show heading.where(level: 1): it => {
  set text(size: 18pt, weight: "bold")
  block(it)
}
#show heading.where(level: 2): set text(size: 13pt, weight: "bold")
#show heading.where(level: 3): set text(size: 11.5pt, weight: "bold")

#show link: it => text(fill: rgb("#1a4b8c"), it)
#show raw.where(block: false): it => box(
  fill: luma(240),
  inset: (x: 3pt, y: 1pt),
  outset: (y: 2pt),
  radius: 2pt,
  text(font: "DejaVu Sans Mono", size: 0.92em, it),
)
#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
  text(font: "DejaVu Sans Mono", size: 0.9em, it),
)

// ========= Title page =========
#align(center)[
  #v(3cm)
  #text(size: 10pt)[Duale Hochschule Baden-Württemberg Stuttgart]

  #v(3cm)
  #text(size: 22pt, weight: "bold")[Travel Assistant]

  #v(0.3cm)
  #text(size: 14pt)[Eine cloud-native #acs("KI")-Reiseplanungsanwendung mit\
    automatisiertem Deployment, Monitoring und Disaster Recovery]

  #v(2cm)
  #text(size: 12pt)[Schriftliche Ausarbeitung zur Projektarbeit]

  #v(3cm)
  #grid(
    columns: (auto, auto),
    column-gutter: 1cm,
    row-gutter: 0.4cm,
    align: (right, left),
    [*Verfasser:*], [Timothy Kugler, 2348056],
    [*Modul:*], [Cloud Computing II],
    [*Abgabedatum:*], [3. Mai 2026],
    [*Repository:*], [github.com/timmykug/travel-assistant],
  )
]

#pagebreak()

// ========= Table of contents =========
#outline(title: "Inhaltsverzeichnis", indent: auto, depth: 2)
#pagebreak()

// ========= 1. Einleitung =========
= Einleitung

== Kontext und Motivation

Die Planung einer Reise ist auch im Jahr 2026 trotz einer Vielzahl spezialisierter Online-Dienste aufwändig.
Informationen über Ziele, Aktivitäten und Zeitpläne liegen verteilt vor und müssen von Reisenden manuell zusammengeführt werden.
Gleichzeitig haben sich generative #acr("KI")-Modelle zu einer tragfähigen Basis für konversationelle Assistenzsysteme entwickelt.
Vor diesem Hintergrund steht die Projektidee eines dialogorientierten Reiseassistenten, der Nutzerinnen und Nutzern bei der Planung ganzer Reisen hilft, Gespräche speichert und personalisierte Vorschläge liefert.

Die Anwendung ist bewusst eher als Demonstrator für Cloud-Architektur und -Betrieb konzipiert denn als Feature-vollständige Produktivlösung.
Der Fokus dieser Arbeit liegt stattdessen auf der _Cloud-nativen_ Umsetzung: dem Entwurf einer robusten, skalierbaren und wartbaren Architektur, die im Rahmen des Fokus-Features _Disaster Recovery_ sowohl Ausfälle als auch Datenverluste adressiert.
Der Projektkontext umfasst die Nutzung aller drei Cloud-Ebenen (#acr("IaaS"), #acr("PaaS"), #acr("SaaS")), eine automatisierte Infrastrukturbereitstellung mit Terraform, eine Konfigurationsautomatisierung mit Ansible sowie ein erkennbares Monitoring-Konzept.
Der vorliegende Projektbericht beschreibt die Umsetzung des entsprechenden Systems eines _Travel Assistant_ auf der #acr("GCP").

== Zielsetzung

Ziel des Projekts war die Entwicklung einer containerbasierten Web-Anwendung, die folgende Eigenschaften erfüllt:

- *Funktional:* ein #acr("KI")-basierter Reiseassistent mit Nutzerkonten, persistenten Konversationen und speicherbaren Reiseplänen.
- *Architektonisch:* Einsatz aller drei Cloud-Ebenen (#acr("SaaS"), #acr("PaaS"), #acr("IaaS")) mit klarer Verantwortungstrennung.
- *Betrieblich:* vollständig automatisierte Bereitstellung über Terraform, Ansible und GitHub Actions mit reproduzierbaren Konfigurationen.
- *Resilient:* ein Fokus-Feature _Disaster Recovery_, das sowohl Compute-Ausfälle über eine Managed Instance Group als auch Datenverluste in Firestore über ein Backup/Restore-Konzept behandelt.
- *Beobachtbar:* Monitoring mit Prometheus, Grafana und Loki, einschließlich eines dedizierten Integritätschecks für die Datenbank.

== Problemstellung

Architekturprägend waren vier Kernfragen: wie ein stabiler öffentlicher Endpunkt trotz selbstheilender #acrpl("VM") entsteht, wie App- und Datenfehler sichtbar gemacht werden, wie eine identische Wiederherstellung der Anwendung automatisiert abläuft und wie Datenstände gesichert und zurückgespielt werden.
Die folgenden Kapitel entwickeln die Lösung von den technologischen Grundlagen (Kapitel 2) über die Architektur und Umsetzung (Kapitel 3) bis hin zum Fokus-Feature _Disaster Recovery_ (Kapitel 4), einer Diskussion der Ergebnisse (Kapitel 5) und einem Fazit (Kapitel 6).

// ========= 2. Technische Grundlagen =========
= Technische Grundlagen

== Cloud-Service-Modelle

Die folgende Tabelle fasst das im Projekt gewählte Mapping auf die drei Cloud-Service-Modelle zusammen.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt + luma(180),
    table.header([*Ebene*], [*Im Projekt verwendet*]),
    [#acr("SaaS")],
    [Google Gemini #acr("API") (Gemini 3.1 Flash-Lite) für die #acr("KI")-Antworten,
      GitHub Actions für die #acr("CI/CD")-Automatisierung.],

    [#acr("PaaS")],
    [Google Firestore (#acr("NoSQL")), Google Artifact Registry für Docker-Images, Google Cloud Scheduler für geplante Backups, Google Cloud Storage für Terraform-State, App-Konfigurationen und Firestore-Backups, Google Secret Manager für Laufzeit-Secrets.],

    [#acr("IaaS")],
    [Google Compute Engine (App-#acr("MIG") + Monitoring-#acr("VM")), Load Balancer, Persistent Disks.],
  ),
  caption: [Zuordnung der Projekt-Komponenten zu den Cloud-Service-Modellen.],
) <tab-xaas>

== Eingesetzte Technologien

- *Backend:* Python 3.13 mit FastAPI (`0.115`), Pydantic v2 und Uvicorn als ASGI-Server.
  E-Mail/Passwort-Authentifizierung mit serverseitig ausgestellten JWTs über `python-jose`, Prometheus-Metriken über den `prometheus-fastapi-instrumentator`.
- *Frontend:* React + Vite, ausgeliefert als statische Dateien über Nginx.
  Das Frontend hält das #acr("JWT") im Browser und sendet es als Bearer-Token an die #acr("API").
- *Datenhaltung:* Google Firestore (Native Mode) im Multi-Dokumenten-Modell (siehe @tab-firestore).
#figure(
  table(
    columns: (auto, 1fr),
    stroke: 0.5pt + luma(180),
    align: (left, left),
    table.header([*Collection*], [*Inhalt*]),
    [`users/{uid}`], [Nutzerprofil (`display_name`, `email`)],
    [`users/{uid}/conversations/{id}`], [Chatverläufe mit dem Assistenten],
    [`users/{uid}/trips/{id}`], [Gespeicherte Reisepläne],
    [`rate_limits/{uid}`], [Tägliches Gemini-Request-Kontingent je Nutzer],
    [`analytics/daily_usage`, `analytics/system`],
    [Aggregierte Metriken und Seed-Markierung],
  ),
  caption: [Firestore-Datenmodell.],
) <tab-firestore>
- *KI-Modell:* Google Gemini #acr("API") mit _Gemini 3.1 Flash-Lite_ für die Reiseassistenz; gewählt gegenüber 2.5 Flash wegen besserer Geschwindigkeits- und Intelligenzwerte @gemini bei gleichem Free-Tier-Kontingent @gemini-rate-limits.
- *Container und Orchestrierung:* Docker + Docker Compose, ein eigener Nginx als Reverse Proxy pro App-#acr("VM").
- *Infrastructure as Code:* Terraform (Provider `hashicorp/google ~> 5.0`) für Netzwerk, #acrpl("VM"), Load Balancer, Firestore, #acr("IAM") und Cloud Scheduler.
- *Konfigurationsmanagement:* Ansible (Playbook + Rolle) ausschließlich für die persistente Monitoring-#acr("VM").
- *CI/CD:* GitHub Actions (Build, Push, `terraform apply`, Ansible).
- *Monitoring:* Prometheus mit #acr("GCE")-Service-Discovery, Grafana mit provisionierten Dashboards, Loki mit Promtail als Log-Shipper, Alertmanager für Benachrichtigungen, Blackbox Exporter für den #acr("DB")-Integritätscheck und Node Exporter für Host-Metriken.

== Begründung der Technologieauswahl

Die Google Cloud Platform war durch die Projektvorgabe gesetzt.
Die Auswahl der konkreten #acr("GCP")-Dienste folgt jedoch der Architektur: Compute Engine bildet die #acr("IaaS")-Schicht für App- und Monitoring-#acrpl("VM"), Firestore übernimmt als verwalteter #acr("PaaS")-Dienst die persistente Datenhaltung, Artifact Registry speichert die Container-Images, Cloud Storage hält Terraform-State, App-Konfigurationen und Backup-Artefakte, Cloud Scheduler stößt die geplanten Firestore-Exporte an, und Secret Manager hält die Laufzeit-Secrets getrennt von der übrigen Konfiguration.
GitHub Actions übernimmt als #acr("SaaS")-Dienst die #acr("CI/CD")-Ausführung.
Dadurch werden alle drei Cloud-Service-Modelle sichtbar genutzt, ohne zusätzliche Eigenbetriebs-Komplexität einzuführen.

=== Backend und Frontend

FastAPI wurde gegenüber Flask und Django gewählt, weil Pydantic-Modelle gleichzeitig Validierung und automatisch generierte OpenAPI-Spezifikation liefern und der #acr("ASGI")-Unterbau asynchrone #acr("I/O") für die mehrsekündigen Gemini-Aufrufe bereitstellt @fastapi-features.
Im Frontend kommt React mit Vite zum Einsatz, weil #acr("CRA") 2023 abgekündigt wurde und Vite als Nachfolger für #acr("SPA")-Builds gilt @vite-why; Next.js hätte die bewusste Trennung zwischen statischem Frontend und containerisiertem Backend aufgeweicht.

=== Datenhaltung: Firestore vs. Cloud SQL und selbstbetriebene #acr("DB")

Firestore wurde gegenüber Cloud SQL und einer selbstbetriebenen Datenbank bevorzugt.
Nutzerprofile, Konversationen und Reisepläne sind dokumentenförmig; die Subcollection-Struktur `users/{uid}/conversations/{id}` entspricht direkt dem #acr("UI")-Zugriffspfad.
Das tägliche Rate-Limit erfordert einen atomaren Read-Modify-Write, den Firestore über #acr("ACID")-Transaktionen auf Dokumentebene abdeckt @firestore-transactions.
Cloud SQL verursacht unabhängig von der Nutzung laufende Kosten @gcp-sql-pricing, während Firestore mit seinem Free-Tier-Sockel den Projektbetrieb abdeckt @firestore-pricing.

=== Container-Orchestrierung: Docker Compose vs. Kubernetes (#acr("GKE"))

Docker Compose wurde gegenüber Kubernetes gewählt, weil #acr("GKE") eine Cluster-Management-Gebühr von rund \$73 pro Monat erhebt @gke-pricing und damit bereits das Budget der \$50 Education Credits überschreiten würde.
Die im Projekt benötigten Kubernetes-Funktionen --- horizontales Replizieren und Selbstheilung --- übernimmt die Managed Instance Group mit #acr("HTTP")-Health-Check und Rolling-Replace @gcp-mig.

=== #acr("IaC") und Konfigurationsmanagement: Terraform und Ansible

Terraform und Ansible waren durch die Modulvorgabe gesetzt; die Entscheidung betraf ihre Aufteilung.
Terraform beschreibt deklarativ die Infrastruktur @terraform-google-provider, Ansible arbeitet agentenlos über #acr("SSH") @ansible-agentless und bleibt auf die persistente Monitoring-#acr("VM") beschränkt; App-#acrpl("VM") werden stattdessen über Instance Template und Startup-Script bootstrapped.

=== Monitoring, Logging und Alerting

Prometheus und Grafana sind vorgegeben; Loki ergänzt den Stack, weil es sich nahtlos als Datenquelle in Grafana einbinden lässt.
In der #acr("MIG")-Topologie ist Prometheus besonders passend, weil die `gce_sd_config`-Service-Discovery neu erzeugte Instanzen automatisch als Scrape-Targets erkennt @prom-gce-sd.
Node Exporter und Blackbox Exporter ergänzen Host-Metriken und aktive End-to-End-Prüfungen @blackbox-exporter.
Eine OpenTelemetry-basierte Pipeline wird als Ausblick behandelt.

// ========= 3. Architektur und Umsetzung =========
= Architektur und Umsetzung

== Gesamtarchitektur

@fig-architecture zeigt die Architektur des Systems im Load-Balancer-basierten Betrieb mit $N > 1$ App-Instanzen.
Der öffentliche Einstiegspunkt ist eine reservierte globale IP-Adresse, die von einem externen HTTP(S)-Load-Balancer gehalten wird.
Dieser verteilt Traffic auf eine Managed Instance Group mit zwei App-VMs.
Der Monitoring-Stack läuft getrennt auf einer persistenten VM mit eigener Persistent-Disk.

Die Darstellung ist nach Cloud-Service-Modellen gegliedert: SaaS umfasst die extern konsumierten Dienste GitHub Actions und Gemini, PaaS die verwalteten GCP-Dienste Firestore, Artifact Registry, Cloud Storage, Cloud Scheduler und Secret Manager, während IaaS die Compute- und Netzwerkkomponenten enthält.
Dadurch werden drei Flussarten sichtbar: Nutzertraffic, Deployment/Bootstrap und Observability/Disaster Recovery.
Gerade diese Trennung ist wichtig, weil ein Fehler im App-Pfad nicht gleichzeitig Monitoring, Backups oder die Wiederherstellung blockieren soll.

#figure(
  image("diagrams/system-architecture.drawio.png", width: 100%),
  caption: [Gesamtarchitektur des Travel Assistant.
    Die Abbildung zeigt den produktiven Request-Pfad über Browser, Load Balancer und Managed Instance Group, den Deployment-Pfad über GitHub Actions, Artifact Registry und GCS-Konfiguration sowie die getrennten Monitoring- und Backup-Flüsse mit Prometheus, Loki, Grafana, Alertmanager, Cloud Scheduler und Firestore-Export.],
) <fig-architecture>

== Request-Pfad und Deployment-Flüsse

@fig-flows reduziert die Architektur auf drei operative Flüsse: Nutzertraffic, Rollout-Artefakte und Monitoring-Konfiguration.
Produktions-Traffic läuft ausschließlich über den Load Balancer in die MIG; App-VMs sind keine öffentlichen Einstiegspunkte.
Die Details des Rollout-Flusses --- Artefakt-Bereitstellung, Bootstrap und Secret-Handhabung --- behandelt @sec-deployment.

#figure(
  block(width: 100%)[#set text(size: 8.5pt)
    #let ink = rgb("#5f7286")
    #let muted = rgb("#6d7f92")
    #let fill-default = rgb("#f8fbff")
    #let fill-soft = rgb("#eef6ff")
    #let fill-emphasis = rgb("#dcecff")
    #let fill-service = rgb("#f2f7fc")

    #diagram(
      node-stroke: 0.55pt + ink,
      edge-stroke: 0.55pt + ink,
      node-inset: 6pt,
      spacing: (8mm, 8mm),
      node-corner-radius: 4pt,

      // Lane labels
      node(
        (0, 0),
        text(size: 7.5pt, weight: "bold", fill: muted)[Request],
        stroke: none,
      ),
      node(
        (0, 2.25),
        text(size: 7.5pt, weight: "bold", fill: muted)[Deployment],
        stroke: none,
      ),
      node(
        (0, 3.55),
        text(size: 7.5pt, weight: "bold", fill: muted)[Monitoring],
        stroke: none,
      ),

      // Request path (top row)
      node((1.0, 0), [Nutzer], fill: fill-default),
      node((2.25, 0), [Load\ Balancer], shape: pill, fill: fill-soft),
      node((3.65, 0), [App-VM\ (MIG)], fill: fill-emphasis),
      node((5.25, 0), [Firestore\ + Gemini], fill: fill-service),

      edge((1.0, 0), (2.25, 0), "->", [HTTPS]),
      edge((2.25, 0), (3.65, 0), "->", [healthy]),
      edge((3.65, 0), (5.25, 0), "->", [API]),

      // MIG rollout bridge
      node((3.65, 1.18), [MIG Rolling\ Replace], fill: fill-emphasis),
      edge((3.65, 1.18), (3.65, 0), "->", [bootstrap]),

      // Deployment path (bottom row)
      node((1.0, 2.25), [git push], fill: fill-default),
      node((2.25, 2.25), [GitHub\ Actions], fill: fill-soft),
      node((3.65, 2.25), [Terraform\ apply], fill: fill-soft),
      node((5.25, 2.25), [Artifact Registry\ + GCS], fill: fill-soft),

      edge((1.0, 2.25), (2.25, 2.25), "->"),
      edge((2.25, 2.25), (3.65, 2.25), "->"),
      edge((3.65, 2.25), (5.25, 2.25), "->", [publish]),
      edge((3.65, 2.25), (3.65, 1.18), "->", [template]),

      // Monitoring VM via Ansible (separate lane)
      node((2.25, 3.55), [Ansible\ role], fill: fill-soft),
      node((3.65, 3.55), [Monitoring-VM], fill: fill-emphasis),
      node((5.25, 3.55), [Prometheus\ Grafana\ Loki], fill: fill-service),

      edge((2.25, 2.25), (2.25, 3.55), "->"),
      edge((2.25, 3.55), (3.65, 3.55), "->"),
      edge((3.65, 3.55), (5.25, 3.55), "->"),
    )],
  caption: [Getrennte Pfade für Laufzeit-Requests (oben) und Deployment (unten).
    Images und App-Konfiguration werden als Artefakte bereitgestellt; Ansible wird nur für die persistente Monitoring-VM verwendet.],
) <fig-flows>

== Deployment-Modell <sec-deployment>

Terraform beschreibt die GCP-Infrastruktur (Load Balancer, MIG, Instance Template, Firestore, IAM, Buckets, Cloud Scheduler); App-VMs werden nicht per SSH konfiguriert, sondern starten über Instance Template und Startup-Script selbstständig.
Das Startup-Script holt Docker-Compose, `.env` und Promtail-Konfiguration aus einem GCS-Bucket, zieht sensible Laufzeitwerte (Gemini-API-Key, #acr("JWT")-Signing-Key) aus Google Secret Manager, authentifiziert Docker gegenüber Artifact Registry und startet den Compose-Stack mit Nginx, FastAPI, Promtail und Node Exporter.
Container-Images werden mit dem Git-SHA getaggt, sodass pro Commit eine eindeutige Template-Version den MIG-Rollout auslöst.

Secrets und nicht-sensible Konfiguration sind bewusst getrennt: Der GCS-Bucket hält unkritische Werte (Projekt-ID, Loki-Endpoint, Image-Tag), Gemini-API-Key und #acr("JWT")-Signing-Key liegen als benannte Secrets in Secret Manager.
Der App-#acr("VM")-Service-Account besitzt `roles/secretmanager.secretAccessor` pro Secret; Rotationen erfolgen per neuer Secret-Version plus MIG-Instance-Rotation, ohne Terraform-State oder Bucket-Inhalte zu berühren.

Ansible bleibt auf die langlebige Monitoring-VM beschränkt und verwaltet dort Prometheus, Grafana, Loki, Alertmanager und Nginx --- Komponenten, die nicht mit jedem App-Rollout neu erzeugt werden.

== Anwendungsumfang (Frontend und Backend)

Die Anwendung bildet einen durchgängigen Reiseplanungs-Workflow von der Konversation bis zur Trip-Verwaltung ab.
Backend-seitig erzwingt `POST /api/ai/chat` ein striktes JSON-Enveloping (`triptitle`, `response`, `recommendations`); bei Vertragsverletzungen folgt ein Reparatur-Retry, danach `HTTP 502` mit gekürztem Raw-Snippet zur Diagnose.
`services/gemini.py` implementiert einen zweiphasigen Dialogfluss (Präferenzklärung, dann Itinerary-Generierung nach `GO`-Signal); Konversationen und Trips werden über dedizierte CRUD-Endpunkte persistiert.

Frontend-seitig rendert die Chat-Oberfläche Konversationsverwaltung (Suche, Pinning, Umbenennen, Löschen), Empfehlungschips und einen Retry-Flow; strukturierte Antworten werden als Timeline-Karten mit Tagespunkten, Hotelvorschlägen und Budgetblock visualisiert.
Reisepläne lassen sich direkt aus dem Chat speichern, später in denselben Trip zurückschreiben und als Markdown exportieren.

== Monitoring-Stack

Der Monitoring-Stack läuft auf einer eigenen VM.
Das ist bewusst gewählt, damit die Observability nicht mit der überwachten Infrastruktur verschwindet:

- *Prometheus* entdeckt Scrape-Targets über GCE-Service-Discovery.
  Ein statischer Target-Eintrag wäre bei einer rollierenden MIG fragil.
  Neben den FastAPI-Metriken werden auch Host-Metriken der App- und Monitoring-VMs über Node Exporter erfasst.
- *Blackbox Exporter* prüft den öffentlichen Load-Balancer-Pfad und darüber `GET /api/health/db` regelmäßig und exportiert `probe_success`.
  Der Endpoint wird also _aktiv_ und _unabhängig_ von App-Traffic beobachtet.
- *Grafana* lädt Dashboards automatisch aus einer provisionierten Verzeichnisstruktur.
- *Alertmanager* verarbeitet Prometheus-Alerts und kann bei gesetzten SMTP-Variablen E-Mail-Benachrichtigungen versenden.
- *Loki* nimmt Logs von Promtail entgegen, welches auf jeder App-VM Container- und System-Logs einsammelt.
- *Persistente Metriken und Logs* liegen auf einer separaten Persistent Disk, damit sie VM-Neustarts und Redeploys überleben.
  Für einen dauerhaften Betrieb wäre ein Terraform-`prevent_destroy` auf dieser Disk sinnvoll, weil es versehentliche Löschung von Monitoring-Historie bei `terraform destroy` verhindert.
  Dieser Schutz ist im gezeigten Setup nicht dauerhaft aktiviert, damit die Disk ohne zusätzlichen Terraform-Eingriff gelöscht werden kann (aus Ersparnisgründen).

Auf jeder App-VM laufen Promtail und Node Exporter als Sidecars neben Nginx und FastAPI: Promtail leitet Container- und Systemlogs an Loki weiter, Node Exporter stellt Host-Metriken für Prometheus bereit.

=== Alertierung und Betriebszugriff

Die Monitoring-VM stellt die Bedienoberflächen über einen lokalen Nginx bereit.
Grafana ist unter `/grafana/` erreichbar; Prometheus und Alertmanager liegen unter `/prometheus/` beziehungsweise `/alertmanager/` und werden per Basic Auth geschützt, da beide Dienste selbst keine vollständige Zugriffsschicht für diesen Einsatzfall mitbringen.
Dadurch bleibt Grafana als Dashboard leicht erreichbar, während die administrativeren Werkzeuge zusätzlich abgesichert sind.

Prometheus lädt seine Alert-Regeln aus einer provisionierten Datei und leitet ausgelöste Alarme an Alertmanager weiter.
Die Regeln decken fünf Gruppen ab:

- *App-Verfügbarkeit:* `AppVMDown`, `NoHealthyAppVMs` und `AppPublicHealthCheckFailed` unterscheiden zwischen einzelner VM, fehlenden Scrape-Targets und einem tatsächlich fehlerhaften öffentlichen Load-Balancer-Pfad.
- *App-Performance:* Fehlerquote über 5\% und p95-Latenz über zwei Sekunden werden als Warnungen erfasst.
- *Firestore-Integrität:* `FirestoreIntegrityCheckFailed` feuert nur, wenn der DB-Healthcheck fehlschlägt _und_ die App-Instanz selbst erreichbar ist.
  Damit wird ein Datenproblem nicht mit einem reinen App-Ausfall verwechselt.
- *App-Ressourcen:* CPU-Auslastung und Root-Disk-Füllstand der App-VMs werden über Node Exporter überwacht.
- *Monitoring-Ressourcen:* Der Füllstand der persistenten Monitoring-Disk wird separat geprüft, weil ein voller Metrics-/Log-Speicher die Beobachtbarkeit selbst gefährden würde.

Alertmanager gruppiert Benachrichtigungen nach `alertname` und `severity`, wiederholt kritische Alarme häufiger und kann bei gesetzten SMTP-Variablen E-Mails versenden.
Zusätzlich unterdrückt eine Inhibition den weniger aussagekräftigen `AppVMNodeExporterDown`, wenn gleichzeitig `AppVMDown` aktiv ist; bei einem kompletten VM-Ausfall reicht also der primäre App-Alarm.

// ========= 4. Fokus-Feature: Disaster Recovery =========
= Fokus-Feature: Disaster Recovery

== Leitidee: zwei Recovery-Pfade

Das gewählte Fokus-Feature ist ein klar strukturiertes Disaster-Recovery-Konzept.
Die zentrale Entscheidung: _Compute-Recovery_ und _Datenrecovery_ werden als zwei getrennte Recovery-Pfade behandelt, weil sie unterschiedliche Fehlerklassen adressieren (@fig-dr-paths).

#figure(
  block(width: 100%)[#set text(size: 7.8pt)
    #let ink = rgb("#5f7286")
    #let muted = rgb("#6d7f92")
    #let fill-header = rgb("#f5f8fb")
    #let fill-problem = rgb("#fff4f2")
    #let fill-detect = rgb("#f8fbff")
    #let fill-action = rgb("#eef6ff")
    #let fill-result = rgb("#e4f3ff")

    #diagram(
      node-stroke: 0.55pt + ink,
      edge-stroke: 0.55pt + ink,
      node-inset: 5pt,
      spacing: (6mm, 6mm),
      node-corner-radius: 4pt,

      node(
        (0.75, -1.1),
        text(weight: "bold", fill: muted)[Fehlerbild],
        fill: fill-header,
      ),
      node(
        (2.25, -1.1),
        text(weight: "bold", fill: muted)[Erkennung],
        fill: fill-header,
      ),
      node(
        (3.75, -1.1),
        text(weight: "bold", fill: muted)[Recovery],
        fill: fill-header,
      ),
      node(
        (5.25, -1.1),
        text(weight: "bold", fill: muted)[Nachweis],
        fill: fill-header,
      ),

      node(
        (-0.55, -0.25),
        text(weight: "bold", fill: muted)[Compute],
        stroke: none,
      ),
      node((0.75, -0.25), [VM/App\ fällt aus], fill: fill-problem),
      node((2.25, -0.25), [`/api/health`\ + Alert], fill: fill-detect),
      node((3.75, -0.25), [MIG ersetzt\ Instanz], fill: fill-action),
      node((5.25, -0.25), [App über LB\ erreichbar], fill: fill-result),

      edge((0.75, -0.25), (2.25, -0.25), "->"),
      edge((2.25, -0.25), (3.75, -0.25), "->"),
      edge((3.75, -0.25), (5.25, -0.25), "->"),

      node(
        (-0.55, 0.85),
        text(weight: "bold", fill: muted)[Daten],
        stroke: none,
      ),
      node((0.75, 0.85), [Firestore-\ Daten fehlen], fill: fill-problem),
      node((2.25, 0.85), [`/api/health/db`\ + Alert], fill: fill-detect),
      node((3.75, 0.85), [Firestore\ Import], fill: fill-action),
      node((5.25, 0.85), [DB-Check\ grün], fill: fill-result),

      edge((0.75, 0.85), (2.25, 0.85), "->"),
      edge((2.25, 0.85), (3.75, 0.85), "->"),
      edge((3.75, 0.85), (5.25, 0.85), "->"),
    )],
  caption: [Zwei getrennte Recovery-Pfade mit jeweils eigener Erkennung, Wiederherstellung und Erfolgskontrolle.],
) <fig-dr-paths>

Diese Trennung ergibt sich aus einer einfachen Beobachtung: Eine MIG heilt nur _Infrastruktur_, nicht _Daten_.
Würde man ausschließlich auf MIG-Autohealing setzen, bliebe ein Szenario wie ein versehentlich gelöschtes Firestore-Dokument unbehandelt, obwohl die App-Instanzen technisch gesund sind.

== Compute-Recovery über die MIG

Jede App-Instanz wird über einen HTTP-Health-Check gegen `/api/health` überwacht.
Fällt eine Instanz aus, ersetzt die MIG sie automatisch anhand des hinterlegten Instance-Templates.
Das Startup-Script bootstrappt die Ersatz-Instanz ohne manuellen Eingriff.
Die globale Load-Balancer-IP bleibt dabei unverändert, weil sie nicht an eine konkrete VM gebunden ist.

== Datenrecovery

=== Deterministischer Integritätscheck

Ein bloßer Ping auf Firestore würde einen Datenverlust nicht erkennen, da die Datenbank technisch weiterhin antwortet.
Deshalb prüft ein dedizierter Endpoint `GET /api/health/db` konkret die Existenz _und_ Pflichtfelder fester Sentinel-Dokumente:

- `users/sentinel-user` (Felder: `display_name`, `email`)
- `users/sentinel-user/trips/sentinel-trip` (Felder: `destination`, `start_date`, `end_date`, `status`)
- `analytics/system` (Felder: `seed_version`, `last_seeded_at`)

Fehlt eines dieser Dokumente oder ein Pflichtfeld, liefert der Endpoint `HTTP 500` mit einer strukturierten Fehlerliste und loggt ein Ereignis `db_integrity_error`.
Ist Firestore selbst nicht erreichbar oder schlägt der Lesezugriff technisch fehl, wird derselbe HTTP-Status mit dem Grund `connectivity_error` zurückgegeben und als `db_connectivity_error` geloggt.
Der Endpoint unterscheidet damit bewusst zwischen _Daten sind erreichbar, aber inhaltlich beschädigt_ und _Datenbankzugriff ist technisch nicht möglich_.

Im Erfolgsfall antwortet der Endpoint mit `status: "healthy"` und `checked_documents: 3`.
Im Fehlerfall enthält die Antwort `status: "unhealthy"`, einen maschinenlesbaren `reason` sowie die konkrete Liste der fehlenden Dokumente oder Felder.
Dadurch kann der Recovery-Test nicht nur einen roten Zustand anzeigen, sondern auch begründen, welche Sentinel-Dokumente wiederhergestellt werden müssen.

Ein Blackbox Exporter fragt den Endpoint über den Prometheus-Job `db-health` ab und exportiert `probe_success`.
Der Alert `FirestoreIntegrityCheckFailed` feuert nur, wenn `probe_success` fehlschlägt _und_ die App-Instanz über den API-Scrape erreichbar bleibt --- so wird ein Datenintegritätsfehler von einem App- oder VM-Ausfall getrennt.
Alertmanager versendet bei konfigurierten SMTP-Variablen eine E-Mail und markiert den Alarm automatisch als resolved, sobald der Probe wieder `probe_success = 1` liefert; ein Grafana-Stat-Panel _Database Integrity_ zeigt den Zustand zusätzlich kontinuierlich.

=== Backups und Restore

Die Backup-Strecke ist bewusst als täglicher Export umgesetzt: Der automatisierte Schutzpunkt entsteht einmal pro Tag, ergänzt durch manuelle Vorab-Backups für geplante Recovery-Tests.
Diese Lösung ist einfach, prüfbar und passt zum Projektumfang, hat aber einen groben #acr("RPO"): Änderungen zwischen zwei Scheduler-Läufen sind nicht durch den letzten geplanten Export abgedeckt.
Firestore-Exporte eignen sich laut Google für das Wiederherstellen nach versehentlicher Löschung und werden über Cloud Storage abgelegt. Ein Export ist jedoch kein exakt zum Startzeitpunkt eingefrorener Snapshot @gcp-firestore-export.

Die Terraform-Konfiguration legt drei zusammenhängende Ressourcen an:

+ Ein GCS-Bucket `${project-id}-firestore-backups` mit einer 30-Tage-Lifecycle-Regel.
+ Ein dedizierter Service Account mit `datastore.importExportAdmin` auf Projektebene und `storage.objectCreator` auf dem Backup-Bucket (least privilege: nur Schreiben der Export-Artefakte, kein Löschen oder Lesen).
+ Ein Cloud-Scheduler-Job, der täglich um 03:00 Uhr Europe/Berlin die Firestore-Export-API mit OAuth-Token dieses Service Accounts aufruft und nach `gs://.../scheduled/` schreibt.

Zusätzlich existiert ein manuelles Backup-Script `presentation/demo-scripts/firestore-backup.sh` für Vorab-Backups vor gezielten Recovery-Tests.
Für den regulären manuellen Betrieb steht derselbe Vorgang zusätzlich als GitHub-Actions-Workflow `Manual Firestore Backup` bereit.
Er ist über `workflow_dispatch` startbar, authentifiziert sich mit demselben GCP-Service-Account wie die Deployment-Pipeline und exportiert Firestore nach `gs://${project-id}-firestore-backups/manual/<timestamp>-run-<nr>-<label>`.
Der erzeugte Backup-Pfad wird in der Job Summary ausgegeben, sodass der spätere Restore eindeutig auf einen konkreten Export zeigen kann.
Für den Restore existiert analog der Workflow `Manual Firestore Restore`, der nach manueller Bestätigung entweder das jüngste manuelle Backup oder einen explizit angegebenen `gs://`-Backup-Pfad importiert.
Das lokale Script `presentation/demo-scripts/firestore-restore.sh` dient als Demo- und Fallback-Werkzeug.

=== Recovery-Zeit

Compute- und Datenpfad wurden jeweils über eine eigene Messreihe quantifiziert.
Beide Messreihen sind als GitHub-Actions-Workflows (`perf-mig-recovery.yml`, `perf-dr-scale-test.yml`) automatisiert und reproduzierbar; sie schreiben die gemessenen Zeiten als JSON-Artefakte, die anschließend über `scripts/perf-plot.py` in die hier eingebundenen Diagramme überführt werden.

==== Compute-Recovery

Die Compute-Messreihe umfasst fünf aufeinanderfolgende Kill-and-Restore-Zyklen, in denen jeweils eine App-#acr("VM") der #acr("MIG") gestoppt und die Zeit bis zur vollständig wiederhergestellten Fleet gemessen wird.
Die verbleibende zweite Instanz bedient währenddessen weiter Traffic, sodass die Messung gezielt das Autohealing-Verhalten abbildet und nicht einen Gesamtausfall.

#figure(
  image("diagrams/perf-mig.png", width: 100%),
  caption: [MIG-Recovery-Ereigniszeiten je Iteration über fünf Durchläufe.],
) <fig-mig-recovery>

Die Ergebnisse sind über alle Iterationen bemerkenswert stabil: der Median bis zur vollständigen Wiederherstellung liegt bei 498 s (≈ 8 min 18 s) bei einer Spannweite von nur 33 s (491--524 s).
Der Ablauf gliedert sich in drei klar trennbare Phasen.
Die #acr("MIG") stößt die Ersatz-Provisionierung bereits nach median 21 s an, weil sie gestoppte Instanzen direkt über ihren #acr("VM")-Status erkennt und nicht auf Health-Check-Failures wartet.
Die neue #acr("VM") erreicht nach median 391 s den Status RUNNING; dieser Schritt dominiert das Gesamtbudget und wird im Wesentlichen durch die Paketinstallation von Docker, die Artifact-Registry-Authentifizierung und den `docker compose pull` aus dem Startup-Script bestimmt.
Nach weiteren rund 107 s ist die App antwortbereit und passt den Health-Check, sodass der Load Balancer Traffic auf die neue Instanz routet.

Die eingangs im Projekt angenommene rein Health-Check-basierte Erkennungszeit (3 × 30 s = 90 s) beschreibt also nur den Sonderfall eines laufenden, aber abstürzenden Anwendungsprozesses.
Im hier gemessenen Szenario eines kompletten #acr("VM")-Ausfalls liegt die effektive Erkennung mehr als eine Größenordnung darunter und ist für die #acr("RTO")-Betrachtung vernachlässigbar; der dominierende Term ist der #acr("VM")-Bootstrap.
Ein vorgepacktes Image mit vorinstalliertem Docker und vorgepullten Container-Images würde diesen Term deutlich reduzieren und die Recovery überschlägig in den Bereich von fünf Minuten bringen.

==== Daten-Recovery

Für die Datenseite wurde eine zweite Messreihe mit drei Wiederholungen pro Größenklasse über 1 000, 10 000 und 100 000 synthetische Dokumente gefahren.
Jede Iteration legt eine isolierte Collection an, exportiert sie nach #acr("GCS"), löscht sie aus Firestore und importiert sie anschließend wieder, jeweils mit Zeitmessung pro Phase.

#figure(
  image("diagrams/perf-scale.png", width: 100%),
  caption: [Firestore-Seed-, Export- und Import-Dauer in Abhängigkeit von der Datenmenge (x-Achse log, y-Achse linear in Sekunden). Transparente Punkte zeigen die einzelnen Iterationen, Linien die Mediane.],
) <fig-dr-scale>

Die Messung zeigt ein klar asymmetrisches Bild.
Der _Export_ skaliert nur schwach und bleibt auch bei 100 000 Dokumenten unter 15 s, weil er serverseitig als Snapshot implementiert ist und im Wesentlichen Fixkosten aufweist.
Der _Import_ skaliert dagegen streng linear mit rund 5,6 ms pro Dokument: median 10 s bei 1 000, 107 s bei 10 000 und 563 s (≈ 9 min 23 s) bei 100 000 Dokumenten.
Linear extrapoliert entspricht das bei einer Million Dokumenten einer Restore-Dauer von rund 94 Minuten.

Der Restore ist damit der dominierende Term im #acr("RTO")-Budget der Datenrecovery, während der Export für die #acr("RTO")-Planung praktisch irrelevant bleibt und nur die Backup-Häufigkeit (und damit den #acr("RPO")) begrenzt.
Solange der Datenbestand in der Größenordnung einiger zehntausend Dokumente bleibt, deckt der vollständige Import das Ziel einer Recovery innerhalb weniger Minuten ab.
Bei stark wachsendem Datenvolumen würden die in @fig-dr-paths skizzierten Teilstrategien --- gezielter Restore betroffener Collection Groups oder ein #acr("PITR")-basiertes Zeitpunkt-Recovery --- zum dominanten Hebel, weil ein vollständiger Import dann aus dem zulässigen #acr("RTO")-Fenster fällt.

=== Kostenbewertung

Die Kosten lassen sich anhand der veröffentlichten Google-Cloud-Preise überschlägig berechnen.
In Summe liegt der Grundbetrieb bei rund 38 bis 40 USD pro Monat, zuzüglich etwa 0,76 USD pro Monat je GiB produktiver Firestore-Daten für 30 tägliche Backup-Artefakte.
Die genaue Herleitung ist im Anhang in @tab-cost-estimate dokumentiert.
Tatsächliche Rechnungswerte können durch Rundung, Wechselkurse, Netzwerkverkehr, Artifact-Registry-Speicher und konkrete Exportgröße abweichen.

// ========= 5. Ergebnisse und Diskussion =========
= Ergebnisse und Diskussion

== Rückblick auf den umgesetzten Systemumfang

Das umgesetzte System umfasst eine durchgängige, cloud-native End-to-End-Lösung aus React-Frontend, FastAPI-Backend, Firestore-Datenhaltung und Gemini-gestützter Assistenzlogik.
Auf Infrastrukturebene wurden die zentralen Betriebsbausteine --- #acr("MIG"), Load Balancer, Artifact Registry, Secret Manager, Cloud Scheduler sowie ein separater Monitoring-Host mit Prometheus/Grafana/Loki --- reproduzierbar über Terraform und Ansible bereitgestellt.
Mit der #acr("CI/CD")-Pipeline, automatisierten Tests und den nachgewiesenen Recovery-Pfaden (Compute-Autohealing, Firestore-Export/Import) ist damit nicht nur ein funktionaler Prototyp, sondern ein belastbarer Betriebs- und Wiederanlaufrahmen umgesetzt.

== Testumfang und Methodik

Die automatisierten Tests laufen in GitHub Actions vor Build und Deployment und decken sowohl Backend- als auch Frontend-Verhalten ab.
Im Backend prüfen `pytest` und der FastAPI-`TestClient` Authentifizierung, Chat- und Konversationsendpunkte, Trip-CRUD sowie `/api/health` und `/api/health/db`.
Firestore und Gemini werden dabei gemockt, sodass die Suite deterministisch und ohne echte Cloud-Zugriffe läuft; für den DB-Integritätscheck existieren zusätzlich Negativtests für fehlende Referenzdaten und Firestore-Konnektivitätsfehler.
Zusätzlich existieren *Gemini*-Integrationstests mit `pytest -m integration`, die reale Gemini-Aufrufe abdecken und als Teil der Backend-Testsuite laufen.
Davon getrennt läuft nach dem Deployment ein eigener Public-App-Integrationsworkflow gegen die bereitgestellte Umgebung.

Im Frontend prüfen Vitest und React Testing Library komponentennahe Nutzerflüsse wie Login/Register-Formulare, Auth-Routing, Session-Management via AuthContext, Navigation, Chat-Fehlerfälle, das Speichern einer Antwort als Reiseplan sowie das Erstellen und Löschen von Trips.
Die API-Schicht wird mit axios-mock-adapter gemockt; getestet werden damit UI-Verhalten, Zustandsübergänge und HTTP-Interceptor-Logik (Token-Injektion, 401-Handling), nicht visuelle Pixel-Regressionen.
Ergänzend gatekeepen `ruff`, `mypy`, `pip-audit`, `tsc --noEmit`, ESLint, `vitest run --coverage` und `npm audit` formale Korrektheit, funktionale Korrektheit und Lieferkettensicherheit.

Die gemessene Zeilenabdeckung liegt bei rund 96 % im Backend und rund 77 % im Frontend; die detaillierten Coverage-Tabellen sind im Anhang in @tab-coverage-frontend und @tab-coverage-backend dokumentiert.
Zusätzlich läuft ein Integrationsworkflow gegen die öffentliche App-URL, der Health-Endpunkte, Authentifizierung, Trip-CRUD und relevante Storage-Buckets mit echten GCP-Diensten prüft, aber bewusst auf Gemini-Aufrufe verzichtet.
Vollständige End-to-End-Prüfungen von Load-Balancer-Verhalten, MIG-Autohealing oder realen Firestore-Imports bleiben aus Kosten- und Laufzeitgründen getrennten Demo- und Recovery-Nachweisen vorbehalten.

== Grenzen der Lösung

- Das Restore ist manuell angestoßen; es gibt keine automatisierte #acr("RTO")/#acr("RPO")-getriebene Recovery-Entscheidung.
- Der belastbar nachgewiesene Daten-Recovery-Pfad basiert auf täglichen Firestore-Exporten; #acr("PITR") ist zwar aktiviert, wurde im Projekt jedoch nicht als eigener, automatisierter Restore-Pfad getestet.
- Der Monitoring-Zugriff ist bewusst niedrigschwellig (öffentlich erreichbare Monitoring-VM, anonymer Grafana-Viewer), damit in der Präsentation ohne Zugangshürden zwischen App, Dashboard und Recovery-Nachweis gewechselt werden kann --- für den Produktionsbetrieb wären IP-Restriktionen, Authentifizierungspflicht und HTTPS nötig.
- Logging läuft pragmatisch über Promtail nach Loki; verteilte Traces und eine vendor-neutrale Telemetrie-Pipeline fehlen.

== Ausblick und Handlungsempfehlungen

=== Point-in-Time Recovery und partieller Restore

Firestore unterstützt nativ Point-in-Time Recovery (PITR) mit einem Recovery-Fenster von bis zu sieben Tagen und minutengenauen Lesezugriffen @gcp-firestore-pitr, und ist damit deutlich granularer als der hier umgesetzte tägliche Export.
PITR ist in der Terraform-Konfiguration über `point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"` aktiviert; bei der hier produzierten Datenmenge liegen die Zusatzkosten im Cent-Bereich pro Monat.
Ein konkreter zeitpunktbezogener Restore (Export mit `--snapshot-time` oder DB-Klon zu einem Zeitpunkt) ist aus Scope-Gründen im Rahmen dieser Arbeit nicht getestet oder als Workflow nachgewiesen worden --- PITR steht damit als zusätzliche Recovery-Option zur Verfügung, der belastbare Nachweis beschränkt sich weiterhin auf die beiden gemessenen Pfade (MIG-Autohealing und vollständiger Firestore-Export/Import).
Ein gezielter Restore einzelner Collection Groups wäre zusätzlich schneller als ein vollständiger Import und deckt den Fall kleiner, lokalisierter Datenfehler besser ab.

=== Robusterer Integritätscheck

Der Check ist bewusst deterministisch und erkennt vor allem das Fehlen fester Sentinel-Dokumente.
Kleinere Datenverluste --- gelöschte Trips, fehlende Pflichtfelder, Mengenabweichungen --- würde er übersehen.
Ein produktionsnäherer Check wäre mehrstufig: Konnektivität, versionierte Sentinel-Collection und fachliche Invarianten über Aggregationsabfragen (`count()`, `sum()`) @gcp-firestore-aggregation sowie Parity-Dokumente, die pro Collection Group erwartete Zähler oder Hashes in derselben Firestore-Transaktion mitpflegen @firestore-transactions.
Konzeptionell entspricht das etablierten Data-Quality-Dimensionen wie _Completeness_, _Consistency_ und _Uniqueness_, wie sie etwa Dataplex Auto Data Quality formalisiert @gcp-dataplex-data-quality.

=== Parameter Manager für nicht-sensible Laufzeitkonfiguration

Die im GCS-Bucket verbliebene `.env` enthält nur deployment-spezifische Werte, die beim `terraform apply` ohnehin gerendert werden.
Parameter, die sich ohne Rollout ändern sollen --- Feature-Flags, Gemini-Modell, Alert-Thresholds --- ließen sich aus Google Parameter Manager beziehen, der Werte analog zu Secret Manager versioniert, aber ohne Secret-Garantien auskommt @gcp-parameter-manager.
Im aktuellen Projektumfang existieren solche Werte nicht, weshalb diese Schicht überdimensioniert wäre.

// ========= 6. Fazit =========
= Fazit

Das Projekt realisiert eine cloud-native Reiseplanungsanwendung mit klar getrennten Verantwortlichkeiten: Alle drei Cloud-Ebenen sind produktiv im Einsatz, die Infrastruktur wird vollständig über Terraform bereitgestellt, Ansible übernimmt die Konfiguration des persistenten Monitoring-Hosts, und das Monitoring-Konzept zeigt sowohl Infrastruktur- als auch Datengesundheit an.

Das Fokus-Feature _Disaster Recovery_ unterscheidet klar zwischen Compute-Recovery und Datenrecovery und macht diese Trennung im Recovery-Ablauf sichtbar.
Die eingeführte Unterscheidung zwischen Integritätscheck und reinem Connectivity-Ping sowie das zweistufige Backup-Konzept (geplant + manuell) machen den Recovery-Pfad nachvollziehbar.
Der Load Balancer und die CI/CD-Pipeline ergänzen diese Architektur um einen stabilen öffentlichen Einstiegspunkt und reproduzierbare Rollouts.

Für zukünftige Iterationen bieten sich vor allem vier Richtungen an:
_automatisiertes Restore_ (#acr("RTO")/#acr("RPO")-getrieben), ein hybrider _Daily-Export-plus-PITR_-Ansatz für Firestore, eine _OpenTelemetry_-basierte Observability-Pipeline und ein _Multi-Region-Failover_ für den Load Balancer.
Die Trennung zwischen Terraform-gesteuertem App-Rollout und Ansible-gesteuertem Monitoring-Host bleibt dabei tragfähig und ermöglicht diese Erweiterungen, ohne die bestehende Deployment-Struktur zu brechen.

// ========= Anhang =========
= Anhang

== Kostenrechnung

Die folgende Tabelle zeigt die überschlägige Kostenrechnung für den Grundbetrieb.
Sie basiert auf den veröffentlichten On-Demand-Preisen und vereinfacht auf 730 Stunden pro Monat.

#figure(
  table(
    columns: (1.25fr, 1.7fr, 1.05fr),
    stroke: 0.45pt + luma(180),
    inset: (x: 5pt, y: 4pt),
    align: (left, left, right),
    table.header([*Posten*], [*Annahme / Rechnung*], [*Monatlich*]),
    [Compute],
    [3 × `e2-small` × 730 h × 0,016752855 USD/h @gcp-compute-vm-pricing],
    [36,69 USD],

    [Persistent Disks],
    [70 GiB `pd-standard`; in `europe-west3` ohne anrechenbaren Compute-Free-Tier vollständig kostenpflichtig @gcp-disk-pricing],
    [ca. 2,80 USD],

    [Firestore],
    [Kleine Projekt-Datenmenge innerhalb des Free Tier; Exporte verursachen dennoch Reads @firestore-pricing @gcp-firestore-export],
    [ca. 0 USD],

    [Backup Storage],
    [`30 * D * 0,0253 USD` bei 30 täglichen Backups und Datenbankgröße `D` GiB @gcp-storage-pricing],
    [ca. 0,76 USD/GiB],

    [Cloud Scheduler],
    [1 Job; innerhalb des Free Tier von drei Jobs, sonst 0,10 USD/Job @gcp-scheduler-pricing],
    [ca. 0 USD],

    [*Summe*],
    [Grundbetrieb ohne variable Zusatzkosten],
    [*ca. 40--42 USD + 0,76 USD/GiB*],
  ),
  caption: [Überschlägige monatliche Kostenrechnung.],
) <tab-cost-estimate>

== Testabdeckung

Die folgenden Tabellen dokumentieren die gemessene Testabdeckung für Frontend und Backend.
Die Frontend-Abdeckung stammt aus `npm run test:coverage` mit Vitest und V8-Coverage-Provider.

#figure(
  block(width: 100%)[
    #set text(size: 7.5pt)
    #table(
      columns: (1.45fr, auto, auto, auto, auto, 1.55fr),
      stroke: 0.45pt + luma(180),
      inset: (x: 4pt, y: 3pt),
      align: (left, right, right, right, right, left),
      table.header(
        [*Datei*],
        [*Statements*],
        [*Branches*],
        [*Functions*],
        [*Lines*],
        [*Nicht abgedeckte Zeilen*],
      ),
      [`All files`], [74,83 %], [59,66 %], [66,8 %], [76,98 %], [],
      [`src`], [100 %], [100 %], [100 %], [100 %], [],
      [`App.tsx`], [100 %], [100 %], [100 %], [100 %], [],
      [`AuthContext.tsx`], [100 %], [100 %], [100 %], [100 %], [],
      [`src/components`], [69,96 %], [59,92 %], [61,19 %], [72,26 %], [],
      [`Chat.tsx`],
      [67,16 %],
      [61,3 %],
      [62,06 %],
      [68,68 %],
      [`...-1078,1092-1093`],

      [`Login.tsx`], [100 %], [100 %], [100 %], [100 %], [],
      [`Nav.tsx`], [100 %], [100 %], [100 %], [100 %], [],
      [`Register.tsx`], [100 %], [100 %], [100 %], [100 %], [],
      [`TripDetail.tsx`],
      [64,7 %],
      [52,63 %],
      [52,3 %],
      [70,27 %],
      [`...397-413,427-496`],

      [`TripPlanner.tsx`],
      [72,09 %],
      [61,22 %],
      [61,11 %],
      [72,36 %],
      [`...246,267,296-299`],

      [`src/services`], [100 %], [88,88 %], [100 %], [100 %], [],
      [`api.ts`], [100 %], [88,88 %], [100 %], [100 %], [`15`],
      [`src/utils`], [92,1 %], [50 %], [100 %], [94,36 %], [],
      [`tripMarkdown.ts`], [92,1 %], [50 %], [100 %], [94,36 %], [`13-21,41`],
    )
  ],
  caption: [Frontend-Testabdeckung mit Vitest und V8-Coverage.],
) <tab-coverage-frontend>

Die Backend-Abdeckung stammt aus der `pytest`-Testsuite mit `pytest-cov`.

#figure(
  block(width: 100%)[
    #set text(size: 8pt)
    #table(
      columns: (1.9fr, auto, auto, auto, 1.3fr),
      stroke: 0.45pt + luma(180),
      inset: (x: 4pt, y: 3pt),
      align: (left, right, right, right, left),
      table.header(
        [*Datei*], [*Statements*], [*Miss*], [*Coverage*], [*Fehlend*]
      ),
      [`main.py`], [34], [0], [100 %], [],
      [`metrics.py`], [8], [0], [100 %], [],
      [`routers/__init__.py`], [0], [0], [100 %], [],
      [`routers/ai.py`], [178], [21], [88 %], [`48-49, 52, 63, 65, 67, 69, 71, 85, 92, 102-103, 122, 147-153, 203`],
      [`routers/auth.py`], [62], [0], [100 %], [],
      [`routers/health.py`], [37], [3], [92 %], [`21, 62, 84`],
      [`routers/trips.py`], [66], [0], [100 %], [],
      [`services/__init__.py`], [0], [0], [100 %], [],
      [`services/firestore_client.py`], [7], [0], [100 %], [],
      [`services/gemini.py`], [69], [5], [93 %], [`180-191`],
      [`services/jwt_auth.py`], [24], [0], [100 %], [],
      [`tests/__init__.py`], [0], [0], [100 %], [],
      [`tests/conftest.py`], [22], [0], [100 %], [],
      [`tests/test_ai.py`], [154], [0], [100 %], [],
      [`tests/test_auth.py`], [55], [0], [100 %], [],
      [`tests/integration/test_gemini.py`], [77], [5], [94 %], [`96-98, 155, 181`],
      [`tests/test_health.py`], [62], [3], [95 %], [`86, 93, 98`],
      [`tests/test_services.py`], [111], [0], [100 %], [],
      [`tests/test_trips.py`], [86], [0], [100 %], [],
      [*TOTAL*], [*1052*], [*37*], [*96 %*], [],
    )
  ],
  caption: [Backend-Testabdeckung mit pytest-cov.],
) <tab-coverage-backend>

// ========= Referenzen =========
#bibliography("references.bib", title: "Referenzen", style: "ieee", full: true)
