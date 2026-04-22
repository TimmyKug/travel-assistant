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

  #text(size: 10pt)[Modul: Cloud Computing II]

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
    [*Repository:*], [github.com/timothykugler/travel-assistant],
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
Vor diesem Hintergrund entstand die Projektidee eines dialogorientierten Reiseassistenten, der Nutzerinnen und Nutzern bei der Planung ganzer Reisen hilft, Gespräche speichert und personalisierte Vorschläge liefert.

Die Anwendung selbst bleibt dabei funktional bewusst schlicht und unterscheidet sich inhaltlich kaum von einem _leicht unterdurchschnittlichen_ #acr("KI")-Chatbot.
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

Aus technischer Sicht stellten sich im Projekt vier Kernfragen, die die Architektur wesentlich prägten:

+ *Wie wird ein stabiler öffentlicher Endpunkt erreicht, obwohl einzelne #acrpl("VM") selbstheilend ausgetauscht werden dürfen?*
+ *Wie wird erreicht, dass ein Fehlerzustand angezeigt wird, wenn die Applikation ausfällt oder die Daten korrupt sind?*
+ *Wie wird eine (automatische) Wiederherstellung der exakt gleichen Applikation erreicht?*
+ *Wie wird erreicht, dass Zwischenstände von Daten gesichert und wiederhergestellt werden können?*

Die Beantwortung dieser Fragen leitete sowohl die Infrastrukturgestaltung als auch die Gliederung dieser Ausarbeitung.
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
    [Google Firestore (#acr("NoSQL")), Google Artifact Registry für Docker-Images, Google Cloud Scheduler für geplante Backups, Google Cloud Storage für Terraform-State, App-Konfigurationen und Firestore-Backups.],

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
- *KI-Modell:* Google Gemini #acr("API") mit _Gemini 3.1 Flash-Lite_ für die Reiseassistenz.
- *Container und Orchestrierung:* Docker + Docker Compose, ein eigener Nginx als Reverse Proxy pro App-#acr("VM").
- *Infrastructure as Code:* Terraform (Provider `hashicorp/google ~> 5.0`) für Netzwerk, #acrpl("VM"), Load Balancer, Firestore, #acr("IAM") und Cloud Scheduler.
- *Konfigurationsmanagement:* Ansible (Playbook + Rolle) ausschließlich für die persistente Monitoring-#acr("VM").
- *CI/CD:* GitHub Actions (Build, Push, `terraform apply`, Ansible).
- *Monitoring:* Prometheus mit #acr("GCE")-Service-Discovery, Grafana mit provisionierten Dashboards, Loki mit Promtail als Log-Shipper, Alertmanager für Benachrichtigungen, Blackbox Exporter für den #acr("DB")-Integritätscheck und Node Exporter für Host-Metriken.

== Begründung der Technologieauswahl

Die Google Cloud Platform war durch die Projektvorgabe gesetzt.
Die Auswahl der konkreten #acr("GCP")-Dienste folgt jedoch der Architektur: Compute Engine bildet die #acr("IaaS")-Schicht für App- und Monitoring-#acrpl("VM"), Firestore übernimmt als verwalteter #acr("PaaS")-Dienst die persistente Datenhaltung, Artifact Registry speichert die Container-Images, Cloud Storage hält Terraform-State, App-Konfigurationen und Backup-Artefakte, und Cloud Scheduler stößt die geplanten Firestore-Exporte an.
GitHub Actions übernimmt als #acr("SaaS")-Dienst die #acr("CI/CD")-Ausführung.
Dadurch werden alle drei Cloud-Service-Modelle sichtbar genutzt, ohne zusätzliche Eigenbetriebs-Komplexität einzuführen.

=== Backend: FastAPI vs. Flask und Django

FastAPI wurde gegenüber Flask und Django bevorzugt, weil es typsichere JSON-#acrpl("API") direkt unterstützt: Pydantic-Modelle dienen zugleich als Validierungsschicht und als Quelle der automatisch generierten OpenAPI-Spezifikation, und der #acr("ASGI")-Unterbau liefert asynchrone #acr("I/O"), die bei Gemini-Aufrufen mit mehreren Sekunden Antwortzeit relevant ist @fastapi-features.
Flask müsste Validierung und OpenAPI über Zusatzbibliotheken nachrüsten, Django bringt mit #acr("ORM"), Admin und Templating Funktionen mit, die im Projekt nicht gebraucht werden.

=== Frontend: React + Vite vs. Create-React-App und Next.js

React als #acr("UI")-Bibliothek wurde aufgrund der persönlichen Vertrautheit gewählt, um den Fokus auf die Cloud-Architektur statt auf die Einarbeitung in neue Frontend-Technologien zu legen.
Als Build-Werkzeug kam Vite zum Einsatz, weil #acr("CRA") 2023 abgekündigt wurde und Vite als De-facto-Nachfolger für #acr("SPA")-Builds gilt @vite-why.
Gegen Next.js als Fullstack-Alternative sprachen zwei Gründe: Zum einen existiert das Backend bereits als eigenständiger FastAPI-Dienst, womit #acr("SSR") und #acr("API")-Routen überdimensioniert wären; zum anderen würde ein Next.js-Monolith die im Projekt bewusst gezogene Trennung zwischen statisch ausgeliefertem Frontend und containerisiertem Backend verwischen, die sowohl das Deployment-Modell als auch die Zuordnung zu den Cloud-Service-Ebenen trägt.

=== Datenhaltung: Firestore vs. Cloud SQL und selbstbetriebene #acr("DB")

Firestore wurde gegenüber Cloud SQL und einer selbstbetriebenen Datenbank bevorzugt.
Nutzerprofile, Konversationen und Reisepläne sind dokumentenförmig; die Subcollection-Struktur `users/{uid}/conversations/{id}` entspricht direkt dem #acr("UI")-Zugriffspfad.
Das tägliche Rate-Limit erfordert einen atomaren Read-Modify-Write, den Firestore über #acr("ACID")-Transaktionen auf Dokumentebene abdeckt @firestore-transactions.
Cloud SQL verursacht unabhängig von der Nutzung laufende Kosten @gcp-sql-pricing, während Firestore mit seinem Free-Tier-Sockel den Projektbetrieb abdeckt @firestore-pricing.

=== KI-Modell: Gemini 3.1 Flash-Lite vs. 2.5 Flash

Innerhalb des kostenlosen Kontingents der Gemini #acr("API") @gemini-rate-limits kamen Gemini 2.5 Flash und das zur Projektzeit als Preview verfügbare Gemini 3.1 Flash-Lite in Frage.
Letzteres wurde gewählt, da Google für das Modell bessere Geschwindigkeits- und Intelligenzwerte ausweist @gemini.

=== Container-Orchestrierung: Docker Compose vs. Kubernetes (#acr("GKE"))

Docker Compose wurde gegenüber Kubernetes gewählt, weil #acr("GKE") eine Cluster-Management-Gebühr von rund \$73 pro Monat erhebt @gke-pricing und damit bereits das Budget der \$50 Education Credits überschreiten würde.
Die im Projekt benötigten Kubernetes-Funktionen --- horizontales Replizieren und Selbstheilung --- übernimmt die Managed Instance Group mit #acr("HTTP")-Health-Check und Rolling-Replace @gcp-mig.

=== #acr("IaC") und Konfigurationsmanagement: Terraform und Ansible

Terraform und Ansible waren durch die Modulvorgabe gesetzt; die Entscheidung betraf ihre Aufteilung.
Terraform beschreibt deklarativ den Zielzustand der Infrastruktur und verwaltet Abhängigkeiten zwischen Ressourcen @terraform-google-provider.
Ansible arbeitet agentenlos über #acr("SSH") @ansible-agentless und wird ausschließlich für die persistente Monitoring-#acr("VM") eingesetzt.
App-#acrpl("VM") werden bewusst über Instance Template und Startup-Script bootstrapped, damit neu erzeugte #acr("MIG")-Instanzen ohne nachträglichen #acr("SSH")-Eingriff einsatzfähig sind.

=== Monitoring, Logging und Alerting

Prometheus und Grafana waren vorgegeben; Loki wurde ergänzt, weil es sich nahtlos als Datenquelle in Grafana einbinden lässt.
In der #acr("MIG")-Topologie ist Prometheus besonders passend, weil die `gce_sd_config`-Service-Discovery neu erzeugte Instanzen automatisch als Scrape-Targets erkennt @prom-gce-sd.
Node Exporter und Blackbox Exporter ergänzen Host-Metriken und aktive End-to-End-Prüfungen @blackbox-exporter.
Eine OpenTelemetry-basierte Pipeline wird als Ausblick behandelt.

// ========= 3. Architektur und Umsetzung =========
= Architektur und Umsetzung

== Gesamtarchitektur

@fig-architecture zeigt die finale Architektur nach der Migration auf einen Load-Balancer-basierten Betrieb mit $N > 1$ App-Instanzen.
Der öffentliche Einstiegspunkt ist eine reservierte globale IP-Adresse, die von einem externen HTTP(S)-Load-Balancer gehalten wird.
Dieser verteilt Traffic auf eine Managed Instance Group mit zwei App-VMs.
Der Monitoring-Stack läuft getrennt auf einer persistenten VM mit eigener Persistent-Disk.

Die Darstellung ist nach Cloud-Service-Modellen gegliedert: SaaS umfasst die extern konsumierten Dienste GitHub Actions und Gemini, PaaS die verwalteten GCP-Dienste Firestore, Artifact Registry, Cloud Storage und Cloud Scheduler, während IaaS die Compute- und Netzwerkkomponenten enthält.
Dadurch werden drei Flussarten sichtbar: Nutzertraffic, Deployment/Bootstrap und Observability/Disaster Recovery.
Gerade diese Trennung ist wichtig, weil ein Fehler im App-Pfad nicht gleichzeitig Monitoring, Backups oder die Wiederherstellung blockieren soll.

#figure(
  image("diagrams/System-Architecture.drawio.png", width: 100%),
  caption: [Gesamtarchitektur des Travel Assistant.
    Die Abbildung zeigt den produktiven Request-Pfad über Browser, Load Balancer und Managed Instance Group, den Deployment-Pfad über GitHub Actions, Artifact Registry und GCS-Konfiguration sowie die getrennten Monitoring- und Backup-Flüsse mit Prometheus, Loki, Grafana, Alertmanager, Cloud Scheduler und Firestore-Export.],
) <fig-architecture>

== Request-Pfad und Deployment-Flüsse

@fig-flows reduziert die Architektur auf drei operative Flüsse: Nutzertraffic, Rollout-Artefakte und Monitoring-Konfiguration.
Produktions-Traffic wird ausschließlich über den Load Balancer in die MIG geleitet; App-VMs werden daher nicht direkt als öffentliche Einstiegspunkte betrachtet.
Das CI/CD-System baut dagegen Container-Images, legt sie in der Artifact Registry ab, aktualisiert die GCP-Infrastruktur über Terraform und lädt die zur Laufzeit benötigten Konfigurationsdateien in einen GCS-App-Config-Bucket.

Die App-VMs ziehen beim Start genau diese Artefakte: Das Startup-Script liest die Compose-Dateien und Umgebungswerte aus GCS, authentifiziert Docker gegenüber Artifact Registry und startet Nginx, FastAPI, Promtail und Node Exporter lokal per Docker Compose.
So kann eine neue MIG-Instanz vollständig selbstständig starten, ohne dass GitHub Actions oder Ansible per SSH in die einzelne App-VM eingreifen müssen.
Ansible bleibt auf die langlebige Monitoring-VM beschränkt.

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

== Deployment-Modell

Das finale Deployment-Modell trennt App-Rollout und Monitoring-Konfiguration nach Verantwortlichkeit.
Terraform beschreibt die GCP-Infrastruktur einschließlich Load Balancer, Managed Instance Group, Instance Template, Firestore, IAM, Buckets und Cloud Scheduler.
Die App-VMs werden nicht nachträglich per SSH konfiguriert, sondern starten über das Instance Template und ein Startup-Script selbstständig.

Das Startup-Script holt Docker-Compose, `.env` und Promtail-Konfiguration aus einem GCS-Bucket, authentifiziert Docker gegenüber Artifact Registry und startet den Compose-Stack mit Nginx, FastAPI, Promtail und Node Exporter.
Dadurch kann jede neu erzeugte MIG-Instanz ohne manuellen Eingriff denselben Anwendungszustand herstellen.
Container-Images werden mit dem Git-SHA getaggt; pro Commit entsteht damit eine eindeutige Template-Version, die den MIG-Rollout nachvollziehbar auslöst.

Ansible bleibt auf die langlebige Monitoring-VM beschränkt.
Dort verwaltet es die Konfiguration von Prometheus, Grafana, Loki, Alertmanager und Nginx, also Komponenten, die nicht mit jedem App-Rollout neu erzeugt werden.

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
  Im Projekt wurde dieser Schutz aus Ersparnisgründen nicht dauerhaft aktiviert, damit die Disk nach Projektende ohne zusätzlichen Terraform-Eingriff gelöscht werden kann.

Auf den App-VMs laufen damit neben den fachlichen Containern auch unterstützende Betriebskomponenten.
Promtail folgt dem Sidecar-Prinzip: Der Container läuft auf jeder App-VM neben Nginx und FastAPI, nimmt selbst keinen Nutzertraffic entgegen und leitet Container- sowie Systemlogs an Loki weiter.
Der Node Exporter ist als begleitender Exporter ähnlich eingebunden, beobachtet aber die VM als Host und stellt CPU-, Speicher- und Dateisystemmetriken für Prometheus bereit.
Beide Komponenten erhöhen die Beobachtbarkeit, ohne die fachliche Anwendung direkt zu verändern.
Die Persistent Disk der Monitoring-VM ist dagegen kein Sidecar, sondern angebundener persistenter Speicher für Prometheus, Loki, Grafana und Alertmanager.

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
Fällt eine Instanz aus, ersetzt die MIG sie automatisch anhand des aktuellen Instance-Templates.
Das Startup-Script bootstrappt die Ersatz-Instanz ohne manuellen Eingriff.
Die globale Load-Balancer-IP bleibt dabei unverändert, weil sie nicht an eine konkrete VM gebunden ist.

== Datenrecovery

=== Deterministischer Integritätscheck

Ein bloßer Ping auf Firestore würde einen Datenverlust nicht erkennen, da die Datenbank technisch weiterhin antwortet.
Deshalb wurde ein dedizierter Endpoint `GET /api/health/db` entwickelt, der konkret die Existenz _und_ ein paar Pflichtfelder fester Referenzdokumente überprüft:

- `users/demo-user` (Felder: `display_name`, `email`)
- `users/demo-user/trips/demo-trip` (Felder: `destination`, `start_date`, `end_date`, `status`)
- `analytics/system` (Felder: `seed_version`, `last_seeded_at`)

Fehlt eines dieser Dokumente oder ein Pflichtfeld, liefert der Endpoint `HTTP 500` mit einer strukturierten Fehlerliste und loggt ein Ereignis `db_integrity_error`.
Ist Firestore selbst nicht erreichbar oder schlägt der Lesezugriff technisch fehl, wird derselbe HTTP-Status mit dem Grund `connectivity_error` zurückgegeben und als `db_connectivity_error` geloggt.
Der Endpoint unterscheidet damit bewusst zwischen _Daten sind erreichbar, aber inhaltlich beschädigt_ und _Datenbankzugriff ist technisch nicht möglich_.

Im Erfolgsfall antwortet der Endpoint mit `status: "healthy"` und `checked_documents: 3`.
Im Fehlerfall enthält die Antwort `status: "unhealthy"`, einen maschinenlesbaren `reason` sowie die konkrete Liste der fehlenden Dokumente oder Felder.
Dadurch kann der Recovery-Test nicht nur einen roten Zustand anzeigen, sondern auch begründen, welche Referenzdaten wiederhergestellt werden müssen.

Ein Blackbox Exporter fragt den Endpoint regelmäßig über den Prometheus-Job `db-health` ab und exportiert `probe_success` als Prometheus-Metrik.
Der Alert `FirestoreIntegrityCheckFailed` wird ausgelöst, wenn `probe_success` fehlschlägt und die betroffene App-Instanz gleichzeitig über den normalen API-Scrape erreichbar ist.
Dadurch wird ein echter Datenintegritätsfehler von einem allgemeinen App- oder VM-Ausfall getrennt.
Ein Grafana-Stat-Panel _Database Integrity_ zeigt den Zustand kontinuierlich, unabhängig von App-Traffic.

Für die Alarmierung lädt Prometheus die Regel aus `alerts.yml` und übergibt den kritischen Alert an Alertmanager.
Alertmanager gruppiert gleichartige Meldungen, sendet bei konfigurierten SMTP-Variablen eine E-Mail und markiert den Alarm nach erfolgreichem Restore automatisch als resolved, sobald der Blackbox-Probe wieder `probe_success = 1` liefert.
Damit entsteht eine geschlossene Kette aus _Erkennen_ (`/api/health/db`), _Messen_ (Blackbox Exporter), _Alarmieren_ (Prometheus/Alertmanager) und _Nachweisen der Wiederherstellung_ (grünes Grafana-Panel und resolved Alert).

=== Backups und Restore

Die aktuelle Backup-Strecke ist bewusst als täglicher Export umgesetzt: Der automatisierte Schutzpunkt entsteht einmal pro Tag, ergänzt durch manuelle Vorab-Backups für geplante Recovery-Tests.
Diese Lösung ist einfach, prüfbar und passt zum Projektumfang, hat aber einen groben RPO: Änderungen zwischen zwei Scheduler-Läufen sind nicht durch den letzten geplanten Export abgedeckt.
Firestore-Exporte eignen sich laut Google für das Wiederherstellen nach versehentlicher Löschung und werden über Cloud Storage abgelegt. Ein Export ist jedoch kein exakt zum Startzeitpunkt eingefrorener Snapshot @gcp-firestore-export.

Die Terraform-Konfiguration legt drei zusammenhängende Ressourcen an:

+ Ein GCS-Bucket `${project-id}-firestore-backups` mit einer 30-Tage-Lifecycle-Regel.
+ Ein dedizierter Service Account mit `datastore.importExportAdmin` auf Projektebene und `storage.admin` auf dem Backup-Bucket.
+ Ein Cloud-Scheduler-Job, der täglich um 03:00 Uhr Europe/Berlin die Firestore-Export-API mit OAuth-Token dieses Service Accounts aufruft und nach `gs://.../scheduled/` schreibt.

Zusätzlich existiert ein manuelles Backup-Script `presentation/demo-scripts/firestore-backup.sh` für Vorab-Backups vor gezielten Recovery-Tests.
Für den regulären manuellen Betrieb wurde derselbe Vorgang zusätzlich als GitHub-Actions-Workflow `Manual Firestore Backup` umgesetzt.
Er ist über `workflow_dispatch` startbar, authentifiziert sich mit demselben GCP-Service-Account wie die Deployment-Pipeline und exportiert Firestore nach `gs://${project-id}-firestore-backups/manual/<timestamp>-run-<nr>-<label>`.
Der erzeugte Backup-Pfad wird in der Job Summary ausgegeben, sodass der spätere Restore eindeutig auf einen konkreten Export zeigen kann.
Für den Restore existiert analog der Workflow `Manual Firestore Restore`, der nach manueller Bestätigung entweder das jüngste manuelle Backup oder einen explizit angegebenen `gs://`-Backup-Pfad importiert.
Das lokale Script `presentation/demo-scripts/firestore-restore.sh` bleibt als Demo- und Fallback-Werkzeug erhalten.

=== Recovery-Zeit und Kostenbewertung

Die im Projekt beobachteten Wiederherstellungszeiten unterscheiden sich deutlich zwischen Compute- und Datenpfad.
Die #acr("MIG")-basierte Compute-Recovery dauerte typischerweise etwa fünf bis zehn Minuten.
Diese Zeit setzt sich im Wesentlichen aus Health-Check-Erkennung, Autohealing-Entscheidung, Provisionierung einer Ersatz-#acr("VM"), Startup-Script, Docker-Image-Pull und erneutem Health-Check zusammen.
Für die Datenrecovery lagen Backup und Restore im Demo-Szenario jeweils nur bei wenigen Sekunden.
Diese Werte sind jedoch nicht auf größere Produktivdatenmengen übertragbar: Der Datenbestand war bewusst sehr klein, und der Integritätscheck bezieht sich auf wenige Referenzdokumente.
Außerdem laufen die geplanten Backups asynchron und beeinflussen daher nicht direkt die Nutzerverfügbarkeit; für die #acr("RTO")-Betrachtung ist vor allem der Restore-Pfad relevant.
Eine belastbare Messreihe mit größeren Datenmengen konnte nicht mehr durchgeführt werden, weil die verbleibenden Google-Cloud-Credits am Projektende bereits stark begrenzt waren.

Auch die Kosten lassen sich daher nur überschlägig anhand der veröffentlichten Google-Cloud-Preise berechnen.
Die produktive Redundanz besteht aus zwei App-#acrpl("VM") in der #acr("MIG") sowie einer Monitoring-#acr("VM"), jeweils als `e2-small` in `europe-west3`.
Bei einem On-Demand-Preis von 0,016752855 USD pro Stunde ergibt das für drei laufende #acrpl("VM") rund 36,69 USD pro Monat bei 730 Stunden; die zweite App-#acr("VM") als eigentlicher Compute-Redundanzanteil verursacht davon rund 12,23 USD pro Monat @gcp-compute-vm-pricing.
Hinzu kommen die Persistent Disks: Zwei App-Boot-Disks zu je 20 GiB, eine Monitoring-Boot-Disk mit 20 GiB und die persistente Monitoring-Disk mit 10 GiB ergeben 70 GiB `pd-standard`.
Da die Disk-Preise nach provisionierter Kapazität berechnet werden und in der Preistabelle für Standard Persistent Disk die ersten 30 GiB pro Monat kostenlos ausgewiesen sind, liegen die zusätzlichen Disk-Kosten überschlägig bei etwa 1,60 USD pro Monat; ohne freien Anteil wären es etwa 2,80 USD pro Monat @gcp-disk-pricing.

Für die Firestore-Seite bleibt der Projektbetrieb selbst wegen der kleinen Datenmengen innerhalb des kostenlosen Kontingents von 1 GiB Speicher, 50.000 Reads, 20.000 Writes und 20.000 Deletes pro Tag plausibel kostenlos @firestore-pricing.
Die Export-Strecke kann dennoch Kosten erzeugen, weil Firestore-Exporte laut Google einen Read pro exportiertem Dokument verursachen @gcp-firestore-export.
Die Backup-Artefakte liegen im #acr("GCS")-Bucket in `europe-west3`; Standard Storage kostet dort 0,0253 USD pro GiB und Monat @gcp-storage-pricing.
Bei täglichem Export und 30 Tagen Aufbewahrung entspricht das näherungsweise `30 * D * 0,0253 USD` pro Monat für eine Datenbankgröße von `D` GiB, also etwa 0,76 USD pro Monat je GiB produktiver Firestore-Daten.
Der Cloud-Scheduler-Job liegt mit einem Job unter dem freien Kontingent von drei Jobs pro Monat; außerhalb des freien Kontingents wären 0,10 USD pro Job und Monat anzusetzen @gcp-scheduler-pricing.
Tatsächliche Rechnungswerte können durch Rundung, Wechselkurse, bereits verbrauchte Free-Tier-Anteile, Netzwerkverkehr, Artifact-Registry-Speicher und konkrete Exportgröße abweichen; ein abschließender Abgleich gegen echte Billing-Daten war wegen der fast aufgebrauchten Credits nicht mehr sinnvoll möglich.

== Ausblick und Handlungsempfehlungen

=== Point-in-Time Recovery und robusterer Integritätscheck

Eine vollständig zeitgenaue Wiederherstellung (Point-in-Time Recovery, PITR) wird von Firestore nativ unterstützt.
Im Unterschied zum täglichen Export hält PITR ältere Dokumentversionen in einem Recovery-Fenster vor: ohne PITR ist nur ungefähr die letzte Stunde verfügbar, mit aktiviertem PITR bis zu sieben Tage; Lesezugriffe sind innerhalb der letzten Stunde auf beliebige unterstützte Zeitpunkte und darüber hinaus innerhalb des PITR-Fensters minutengenau möglich @gcp-firestore-pitr.
Damit ist PITR deutlich granularer als der hier umgesetzte tägliche Export.

Im Rahmen dieses Projekts wurde PITR nicht aktiviert, weil es zusätzliche Kosten verursacht und für die nachweisbare Backup-/Restore-Strecke nicht notwendig war.
Für einen produktionsnäheren Betrieb wäre ein hybrider Ansatz sinnvoll: Daily Exports bleiben als langlebige, bucketbasierte Sicherung und als Grundlage für projektübergreifende Restores erhalten, während PITR die Lücke zwischen zwei geplanten Exporten schließt und versehentliche Schreib- oder Löschfehler feingranularer rückgängig machen kann.
Architektonisch ließe sich PITR ohne Änderungen am App-Code nachziehen: Es müsste in der Firestore-Konfiguration aktiviert werden, anschließend könnten zeitpunktbezogene Reads, Exporte oder Datenbank-Klone für feinere Recovery-Szenarien genutzt werden.

Zusätzlich wäre ein gezielter Restore der tatsächlich betroffenen Dokumente oder Collection Groups schneller als ein vollständiger Firestore-Import.
Der aktuelle Integritätscheck benennt bereits konkret fehlende Referenzdokumente und Pflichtfelder; ein produktionsnäheres Repair-Script könnte genau diese Dokumente aus einem Export oder aus versionierten Seed-Daten wiederherstellen, statt die gesamte Datenbank neu zu importieren.
Das reduziert die Restore-Dauer besonders bei kleinen, klar lokalisierbaren Datenfehlern.
Bei großflächiger Korruption bleibt dagegen ein vollständiger Import, ein PITR-basierter Export oder ein Datenbank-Klon die robustere Strategie.

Zusätzlich sollte der Integritätscheck produktionsnäher gestaltet werden.
Der aktuelle Check ist für die Demo bewusst deterministisch, aber auch fehleranfällig: Er hängt an festen Referenzdokumenten wie `users/demo-user` und kann rot werden, wenn diese Demo-Daten aus anderen Gründen verändert werden.
Robuster wäre ein mehrstufiger Check, der zunächst Firestore-Konnektivität und Berechtigungen prüft, anschließend eine kleine, dedizierte Sentinel-Collection mit versionierten Prüfdokumenten validiert und fachliche Daten nur aggregiert oder stichprobenartig kontrolliert.
Damit bliebe der Check aussagekräftig für echte Datenverluste, wäre aber weniger abhängig von einzelnen Demo-Objekten.

=== Secret Manager für sensible Konfiguration

Aktuell liegen Laufzeit-Secrets wie der Gemini-API-Key und das JWT-Signing-Secret als Werte in einer `.env`-Datei im GCS-App-Config-Bucket, die das Startup-Script beim VM-Start lädt.
Für einen produktionsnäheren Betrieb wäre Google Secret Manager die passendere Ablage: Er bietet versionierte Secrets, feingranulare IAM-Bindings pro Secret sowie Audit-Logs über Zugriffe.
App-VMs könnten Secrets zur Laufzeit über den Service Account der Instanz abrufen, sodass sie nicht mehr im Klartext im Bucket liegen müssen.
Eine Rotation ließe sich dann durch das Anlegen einer neuen Secret-Version und eine anschließende MIG-Instance-Rotation umsetzen, ohne Terraform-State oder Bucket-Inhalte anzufassen.

// ========= 5. Ergebnisse und Diskussion =========
= Ergebnisse und Diskussion

== Umgesetzter Systemumfang

#figure(
  table(
    columns: (1fr, 1.8fr),
    stroke: 0.5pt + luma(180),
    align: (left, left),
    table.header([*Bereich*], [*Umsetzung*]),
    [Web-Anwendung],
    [E-Mail/Passwort-Login mit JWT, KI-Dialog mit persistenten Konversationen und speicherbaren Reiseplänen, Rate-Limit pro Nutzer.],

    [Cloud-Service-Modelle],
    [SaaS: Gemini API · PaaS: Firestore, Artifact Registry, Cloud Scheduler, Cloud Storage · IaaS: Compute Engine (MIG + Monitoring-VM), Load Balancer, Persistent Disks.],

    [Infrastruktur],
    [Komplette Infrastruktur inklusive MIG, LB, Firestore, IAM, Cloud-Storage-Buckets für Terraform-State, App-Konfiguration und Firestore-Backups sowie Cloud-Scheduler-Job.],

    [Konfiguration],
    [Auf die persistente Monitoring-VM fokussiert; App-VMs werden über Startup-Script bereitgestellt.],

    [Disaster Recovery],
    [Sichtbare Datenkorruption, MIG-Autohealing, Grafana-Alert und Restore-Script.],

    [Monitoring],
    [Prometheus (GCE-SD), Grafana, Loki, Alertmanager, Blackbox Exporter und Node Exporter auf separater VM mit persistenter Disk.],

    [Entwicklung und Betrieb],
    [Typed FastAPI-Endpunkte, pytest-Testsuite, CI über GitHub Actions.],

    [Rollout-Modell],
    [GitHub Actions: Build/Push → `terraform apply` → Ansible (Monitoring) → Instance-Template-Rotation; globale statische IP vor HTTP(S)-LB, $N > 1$ App-Instanzen mit Rolling-Replace.],
  ),
  caption: [Zusammenfassung der umgesetzten Systembereiche.],
) <tab-systemumfang>

== Testumfang und Methodik

Die automatisierte Testsuite konzentriert sich auf die FastAPI-Anwendung und wird in GitHub Actions vor Build und Deployment ausgeführt.
Die Tests nutzen `pytest` und den FastAPI-`TestClient`; externe Abhängigkeiten wie Firestore und Gemini werden über Mocks ersetzt, damit die Suite ohne echte Cloud-Zugriffe deterministisch und schnell läuft.
Damit prüft die CI vor allem fachliche API-Verträge, Fehlerbehandlung und die für das Disaster-Recovery-Feature relevanten Health-Endpunkte.

Abgedeckt sind Authentifizierung (Registrierung, Login, aktueller Nutzer), Chat- und Konversationsendpunkte, CRUD-Operationen für Reisepläne sowie `/api/health` und `/api/health/db`.
Für den DB-Integritätscheck existieren explizite Tests für den grünen Zustand, fehlende Referenzdaten und technische Firestore-Konnektivitätsfehler.
Gerade diese Negativtests sind wichtig, weil der Endpoint nicht nur Erreichbarkeit, sondern auch Datenintegrität signalisieren soll.

Nicht Teil der automatisierten Tests sind vollständige End-to-End-Tests gegen eine echte GCP-Umgebung, echte Gemini-Antworten, Load-Balancer-Verhalten, MIG-Autohealing oder ein realer Firestore-Import.
Diese Aspekte wurden im Projekt über die Demo-Skripte, die GitHub-Workflows für Backup/Restore und die Beobachtung in Grafana/Alertmanager validiert.
Der Testansatz ist damit bewusst risikobasiert: Wiederholbare Backend-Logik wird automatisiert geprüft, während kosten- und zeitintensive Cloud-Abläufe gezielt als Integrations- und Recovery-Tests nachgewiesen werden.
Ergänzend existiert ein Integrationsworkflow, der nach dem Deployment als Verification-Schritt und bei Bedarf manuell gegen die bereitgestellte öffentliche App-URL läuft.
Er prüft Health-Endpunkte, Authentifizierung, Trip-CRUD und die relevanten Storage-Buckets mit echten GCP-Diensten, verzichtet aber bewusst auf Gemini-Aufrufe.
Die dabei erzeugten Testdaten verwenden eine eindeutige E-Mail pro Workflow-Lauf und werden sowohl im Test selbst als auch in einem abschließenden Cleanup-Schritt (`if: always()`) aus Firestore entfernt.

== Grenzen der aktuellen Lösung

- Das Restore ist manuell angestoßen.
  In einem Produktionsbetrieb wäre ein definierter RTO/RPO-Zielwert mit automatisierter Restore-Entscheidung wünschenswert.
- Die geplanten Firestore-Backups laufen nur täglich; PITR ist konzeptionell vorgesehen, aber aus Kostengründen nicht aktiviert.
  Dadurch bleibt der Recovery-Punkt zwischen zwei täglichen Exporten gröber als in einem hybriden Export-plus-PITR-Setup.
- Das Logging ist aktuell klassisch über Promtail nach Loki umgesetzt, nicht über OpenTelemetry.
  Ein OTel-Collector mit OTLP-Empfang wäre eine sinnvolle Erweiterung, um Logs, Metriken und Traces stärker zu standardisieren und vendor-neutral weiterzugeben.

// ========= 6. Fazit =========
= Fazit

Das Projekt realisiert eine cloud-native Reiseplanungsanwendung mit klar getrennten Verantwortlichkeiten: Alle drei Cloud-Ebenen sind produktiv im Einsatz, die Infrastruktur wird vollständig über Terraform bereitgestellt, Ansible übernimmt die Konfiguration des persistenten Monitoring-Hosts, und das Monitoring-Konzept zeigt sowohl Infrastruktur- als auch Datengesundheit an.

Das Fokus-Feature _Disaster Recovery_ unterscheidet klar zwischen Compute-Recovery und Datenrecovery und macht diese Trennung im Recovery-Ablauf sichtbar.
Die eingeführte Unterscheidung zwischen Integritätscheck und reinem Connectivity-Ping sowie das zweistufige Backup-Konzept (geplant + manuell) machen den Recovery-Pfad nachvollziehbar.
Der Load Balancer und die CI/CD-Pipeline ergänzen diese Architektur um einen stabilen öffentlichen Einstiegspunkt und reproduzierbare Rollouts.

Für zukünftige Iterationen bieten sich vor allem vier Richtungen an:
_automatisiertes Restore_ (RTO/RPO-getrieben), ein hybrider _Daily-Export-plus-PITR_-Ansatz für Firestore, eine _OpenTelemetry_-basierte Observability-Pipeline und ein _Multi-Region-Failover_ für den Load Balancer.
Die aktuelle Trennung zwischen Terraform-gesteuertem App-Rollout und Ansible-gesteuertem Monitoring-Host bleibt dabei tragfähig und ermöglicht diese Erweiterungen, ohne die bestehende Deployment-Geschichte zu brechen.

// ========= Referenzen =========
#bibliography("references.bib", title: "Referenzen", style: "ieee", full: true)
