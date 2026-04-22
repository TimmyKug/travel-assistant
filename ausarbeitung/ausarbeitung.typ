#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/cetz:0.3.4"
#import fletcher.shapes: rect, hexagon, circle, pill, diamond

// ========= Document setup =========
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
  #text(size: 14pt)[Eine cloud-native KI-Reiseplanungsanwendung mit\
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

Die Planung einer Reise ist auch im Jahr 2026 trotz einer Vielzahl spezialisierter Online-Dienste
aufwändig. Informationen über Ziele, Aktivitäten und Zeitpläne liegen verteilt vor und müssen von
Reisenden manuell zusammengeführt werden. Gleichzeitig haben sich generative KI-Modelle
zu einer tragfähigen Basis für konversationelle Assistenzsysteme entwickelt. Vor diesem Hintergrund
entstand die Projektidee eines dialogorientierten Reiseassistenten, der Nutzerinnen und Nutzern bei
der Planung ganzer Reisen hilft, Gespräche speichert und personalisierte Vorschläge liefert.

Das Modul Cloud Computing II fokussiert nicht nur die Funktionalität einer Anwendung, sondern vor
allem ihre _Cloud-native_ Umsetzung. Der Projektkontext umfasst die Nutzung aller drei
Cloud-Ebenen (IaaS, PaaS, SaaS), eine automatisierte Infrastrukturbereitstellung
mit Terraform, eine Konfigurationsautomatisierung mit Ansible sowie ein erkennbares
Monitoring-Konzept.
Der vorliegende Projektbericht beschreibt die Umsetzung eines entsprechenden
Systems unter dem Namen _Timmy's Travel Assistant_ auf der Google Cloud Platform (GCP).

== Zielsetzung

Ziel des Projekts war die Entwicklung einer containerbasierten Web-Anwendung, die folgende
Eigenschaften erfüllt:

- *Funktional:* ein KI-basierter Reiseassistent mit Nutzerkonten, persistenten
  Konversationen und speicherbaren Reiseplänen.
- *Architektonisch:* Einsatz aller drei Cloud-Ebenen (SaaS, PaaS, IaaS) mit klarer Verantwortungstrennung.
- *Betrieblich:* vollständig automatisierte Bereitstellung über Terraform, Ansible und GitHub Actions mit reproduzierbaren Konfigurationen.
- *Resilient:* ein Fokus-Feature _Disaster Recovery_, das sowohl Compute-Ausfälle über eine Managed Instance Group als auch Datenverluste in Firestore über ein Backup/Restore-Konzept behandelt.
- *Beobachtbar:* Monitoring mit Prometheus, Grafana und Loki, einschließlich eines dedizierten Integritätschecks für die Datenbank.

== Problemstellung

Aus technischer Sicht stellten sich im Projekt vier Kernfragen, die die Architektur wesentlich prägten:

+ *Wie wird ein stabiler öffentlicher Endpunkt erreicht, obwohl einzelne VMs selbstheilend ausgetauscht werden dürfen?*
+ *Wie wird erreicht, dass selbst bei Absturz der Applikation die Überwachung weiterläuft und den Fehlerzustand anzeigt*
+ *Wie wird eine automatische Wiederherstellung der exakt gleichen Applikation erreicht?*
+ *Wie wird erreicht, dass Zwischenstände von Daten gesichert und wiederhergestellt werden können?*

Die Beantwortung dieser Fragen leitete sowohl die Infrastrukturgestaltung als auch die Gliederung dieser Ausarbeitung. Die folgenden Kapitel entwickeln die Lösung von den technologischen Grundlagen (Kapitel 2) über die Architektur und Umsetzung (Kapitel 3)
bis hin zum Fokus-Feature _Disaster Recovery_ (Kapitel 4), einer Diskussion der Ergebnisse (Kapitel 5) und einem Fazit (Kapitel 6).

// ========= 2. Technische Grundlagen =========
= Technische Grundlagen

== Cloud-Service-Modelle

Die folgende Tabelle fasst die wesentlichen Eigenschaften der drei Cloud-Service-Modelle und das im Projekt gewählte Mapping zusammen.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt + luma(180),
    table.header(
      [*Ebene*], [*Definition*], [*Im Projekt verwendet*],
    ),
    [SaaS], [Fertige Software als Dienst, meist über APIs konsumiert.],
      [Google Gemini API (Gemini 3.1 Flash-Lite) für die KI-Antworten.],
    [PaaS], [Verwaltete Plattformdienste ohne eigene Infrastrukturverantwortung.],
      [Google Firestore (NoSQL), Google Artifact Registry für Docker-Images,
       Google Cloud Scheduler für geplante Backups, Google Cloud Storage für
       Backup- und Konfigurationsartefakte.],
    [IaaS], [Bereitstellung virtueller Maschinen, Netzwerk- und Speicherressourcen.],
      [Google Compute Engine (App-MIG + Monitoring-VM), Load Balancer,
       Persistent Disks.],
  ),
  caption: [Zuordnung der Projekt-Komponenten zu den Cloud-Service-Modellen.],
) <tab-xaas>

== Eingesetzte Technologien

- *Backend:* Python 3.13 mit FastAPI (`0.115`), Pydantic v2 und Uvicorn als ASGI-Server.
  E-Mail/Passwort-Authentifizierung mit serverseitig ausgestellten JWTs über
  `python-jose`, Prometheus-Metriken über den `prometheus-fastapi-instrumentator`.
- *Frontend:* React + Vite, ausgeliefert als statische Dateien über Nginx.
  Das Frontend hält das JWT im Browser und sendet es als Bearer-Token an die API.
- *Datenhaltung:* Google Firestore (Native Mode) im Multi-Dokumenten-Modell
  (siehe @tab-firestore).
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
    [`analytics/daily_usage`, `analytics/system`], [Aggregierte Metriken und Seed-Markierung],
  ),
  caption: [Firestore-Datenmodell.]
) <tab-firestore>
- *KI-Modell:* Google Gemini API mit _Gemini 3.1 Flash-Lite_ für die
  Reiseassistenz.
- *Container und Orchestrierung:* Docker + Docker Compose, ein eigener Nginx
  als Reverse Proxy pro App-VM.
- *Infrastructure as Code:* Terraform (Provider `hashicorp/google ~> 5.0`) für
  Netzwerk, VMs, Load Balancer, Firestore, IAM und Cloud Scheduler.
- *Konfigurationsmanagement:* Ansible (Playbook + Rolle) ausschließlich für die
  persistente Monitoring-VM.
- *CI/CD:* GitHub Actions (Build, Push, `terraform apply`, Ansible).
- *Monitoring:* Prometheus mit GCE-Service-Discovery, Grafana mit provisionierten
  Dashboards, Loki mit Promtail als Log-Shipper, Blackbox Exporter für den
  DB-Integritätscheck.

== Begründung der Technologieauswahl

Die Google Cloud Platform war durch die Projektvorgabe gesetzt. Die Auswahl der
konkreten GCP-Dienste folgt jedoch der Architektur: Compute Engine bildet die
IaaS-Schicht für App- und Monitoring-VMs, Firestore übernimmt als verwalteter
PaaS-Dienst die persistente Datenhaltung, Artifact Registry speichert die
Container-Images, Cloud Storage hält Konfigurations- und Backup-Artefakte, und
Cloud Scheduler stößt die geplanten Firestore-Exporte an. Dadurch werden alle
drei Cloud-Service-Modelle sichtbar genutzt, ohne zusätzliche Eigenbetriebs-
Komplexität einzuführen.

=== Backend: FastAPI vs. Flask und Django

FastAPI wurde gegenüber den naheliegenden Python-Alternativen Flask und Django
bevorzugt. Flask ist zwar ähnlich leichtgewichtig, liefert aber weder
Request-Validierung noch OpenAPI-Generierung out-of-the-box; beides müsste über
Zusatzbibliotheken (z.B. `flask-pydantic`, `flasgger`) nachgerüstet werden.
Django bringt ORM, Admin und Templating mit, die im Projekt nicht gebraucht
werden, da Firestore als Datenhaltung fungiert und das Frontend als
SPA getrennt läuft. FastAPI ist dagegen explizit auf typsichere JSON-APIs
ausgelegt: Pydantic-Modelle dienen zugleich als Validierungsschicht und als
Quelle der automatisch generierten OpenAPI-Spezifikation, und der
ASGI-Unterbau (Starlette + Uvicorn) liefert asynchrone I/O, die bei
Gemini-Aufrufen mit typisch mehreren Sekunden Antwortzeit relevant ist
@fastapi-features. Unabhängige Benchmarks (TechEmpower Round~22) zeigen
FastAPI/Uvicorn im JSON-Durchsatz mehrfach vor Flask @techempower. Für ein
Projekt mit Chat-, Auth-, Health- und Metrik-Endpunkten ergibt das bei
gleicher Codemenge ein strengeres Vertragsmodell zwischen Frontend und Backend.

=== Frontend: React + Vite vs. Create-React-App und Next.js

Für das Frontend wurde React mit Vite statt des historisch üblichen
Create-React-App (CRA) oder eines Full-Stack-Frameworks wie Next.js gewählt.
CRA wurde von seinen Maintainern 2023 abgekündigt und erhält keine aktiven
Updates mehr; Vite gilt seitdem als de-facto Nachfolger für SPA-Builds und
bietet dank ESM-basiertem Dev-Server Start- und HMR-Zeiten im
Millisekundenbereich @vite-why. Next.js wäre mit SSR und API-Routen
überdimensioniert: Das Backend existiert bereits als FastAPI-Dienst, und eine
server-gerenderte Seite bringt für den eingeloggten Chat-Flow keinen Vorteil.
Die statische Auslieferung des Vite-Builds über Nginx passt hingegen direkt
in das bestehende Container-Modell.

=== Datenhaltung: Firestore vs. Cloud SQL und selbstbetriebene DB

Firestore wurde gegenüber den Alternativen Cloud SQL (PostgreSQL) und einer
selbst auf einer VM betriebenen Datenbank bevorzugt. Die drei Hauptargumente
sind Datenmodell, Betriebsaufwand und Kosten:

- *Datenmodell.* Nutzerprofile, verschachtelte Konversationen mit
  Nachrichten-Arrays und Reisepläne sind dokumentenförmig; sie in ein
  relationales Schema zu zwingen, würde Joins erzeugen, die im Zugriffsmuster
  gar nicht gebraucht werden. Die Subcollection-Struktur
  `users/{uid}/conversations/{id}` entspricht direkt dem UI-Zugriffspfad.
- *Transaktionen.* Das tägliche Gemini-Rate-Limit erfordert einen atomaren
  Read-Modify-Write auf `rate_limits/{uid}`. Firestore liefert dafür
  ACID-Transaktionen auf Dokumentebene @firestore-transactions; ein häufiges
  Gegenargument gegen NoSQL-Datenbanken greift an dieser Stelle also nicht.
- *Betrieb und Kosten.* Eine selbstbetriebene PostgreSQL-Instanz auf einer VM
  würde Backup, Patching und Monitoring zusätzlich zur eigentlichen Anwendung
  erfordern. Cloud SQL nimmt diese Aufgaben ab, verursacht aber bereits in der
  kleinsten Zone unabhängig von der tatsächlichen Nutzung laufende Kosten
  @gcp-sql-pricing, während Firestore einen Free-Tier-Sockel (1~GiB Speicher,
  50k Reads, 20k Writes pro Tag) bietet, der den Projektbetrieb abdeckt
  @firestore-pricing.

=== KI-Modell: Gemini 3.1 Flash-Lite vs. 2.5 Flash

Aufgrund der Nutzungslimits des Gratis Tiers der Gemini API @gemini-rate-limits kamen nur zwei Modelle in Frage:
Gemini 2.5 Flash und Gemini 3.1 Flash-Lite (zur Zeit dieses Projekts noch Preview). 
Gemini 3.1 Flash-Lite (momentan noch Preview) ist laut Google auf niedrige Latenz und hohen Durchsatz bei gleichzeitig günstigerem Preismodell ausgelegt und übertrifft in internen Benchmarks den Vorgänger Gemini 2.5 Flash bei Geschwindigkeit und
Antwortqualität @gemini.

=== Container-Orchestrierung: Docker Compose vs. Kubernetes (GKE)

Docker Compose wurde gegenüber Kubernetes bewusst gewählt. GKE (Autopilot wie
Standard) erhebt eine Cluster-Management-Gebühr von derzeit \$0,10 pro
Stunde und Cluster @gke-pricing, was rund \$73 pro Monat _vor_ den
eigentlichen Worker-Kosten bedeutet. Das Projekt wird über die monatlichen
\$50 Education Credits finanziert, womit die reine GKE-Grundgebühr das
Budget bereits überschreiten würde, bevor überhaupt eine Worker-VM läuft.
Zusätzlich wäre die operative Komplexität (Manifeste, Ingress-Controller,
RBAC, Cluster-Upgrades) für drei Container pro VM und zwei Instanzen
insgesamt deutlich überdimensioniert. Die eigentlichen Kubernetes-Funktionen,
die im Projekt gebraucht werden --- horizontales Replizieren und
Selbstheilung --- übernimmt die Managed Instance Group mit
HTTP-Health-Check und Rolling-Replace @gcp-mig. Compose bleibt damit auf
die VM-lokale Orchestrierung von Frontend-, Backend- und
Promtail-Containern beschränkt, wo es eindeutig das einfachste Werkzeug
ist.

=== IaC und Konfigurationsmanagement: Terraform und Ansible

Terraform und Ansible waren durch die Modulvorgabe gesetzt; die inhaltliche
Entscheidung betraf daher weniger _ob_, sondern _wo_ jedes der beiden
Werkzeuge eingesetzt wird. Die Trennung folgt den jeweiligen Stärken:
Terraform beschreibt mit dem `hashicorp/google`-Provider deklarativ den
Zielzustand der Infrastruktur (Netzwerk, Load Balancer, Managed Instance
Group, Firestore, IAM, Buckets, Scheduler) und verwaltet über seinen State
Abhängigkeiten zwischen diesen Ressourcen @terraform-google-provider.
Ansible ist dagegen prozedural-imperativ, arbeitet agentenlos über SSH
@ansible-agentless und eignet sich damit gut für die Konfiguration einer
bestehenden, lange laufenden VM, ohne dort dauerhafte Agenten-Software zu
installieren.

Im Projekt wird Ansible deshalb ausschließlich für die persistente
Monitoring-VM eingesetzt, auf der Prometheus-, Grafana- und Loki-Konfiguration
über eine Rolle verwaltet werden. Die App-VMs werden bewusst _nicht_ mit
Ansible provisioniert, sondern über Instance Template und Startup-Script
bootstrapped, damit neu erzeugte MIG-Instanzen ohne nachträglichen
SSH-Eingriff einsatzfähig werden. GitHub Actions verbindet diese Schritte zu
einer Pipeline aus Build, Image-Push, `terraform apply` und
Ansible-Lauf für die Monitoring-VM.

=== Monitoring: Prometheus, Grafana und ergänzend Loki

Prometheus und Grafana waren als Werkzeuge vorgegeben. Loki wurde ergänzend
aufgenommen, weil es aus demselben Grafana-Labs-Ökosystem stammt und sich
nahtlos als Datenquelle in Grafana einbinden lässt --- dadurch liegen
Metriken und Logs in derselben Oberfläche, ohne zusätzlichen Tool-Wechsel.

In der MIG-Topologie ist Prometheus besonders passend, weil die offizielle
`gce_sd_config`-Service-Discovery neu erzeugte Instanzen automatisch als
Scrape-Targets erkennt und bei Replacement-Ereignissen entfernt
@prom-gce-sd; statische Target-Listen wären bei Rolling-Replace fragil.
Der Blackbox Exporter ergänzt das Setup um _aktive_ Prüfungen des
`GET /api/health/db`-Endpunkts, die unabhängig vom Nutzertraffic laufen und
so auch bei geringer Last Fehlzustände sichtbar machen @blackbox-exporter.
Promtail reicht als Log-Shipper, weil auf den App-VMs lediglich Container-
und System-Logs abgeholt werden; eine OpenTelemetry-basierte Pipeline wird
deshalb nicht als aktueller Stand, sondern als Ausblick behandelt.

// ========= 3. Architektur und Umsetzung =========
= Architektur und Umsetzung

== Gesamtarchitektur

@fig-architecture zeigt die finale Architektur nach der Migration auf
einen Load-Balancer-basierten Betrieb mit $N > 1$ App-Instanzen. Der öffentliche
Einstiegspunkt ist eine reservierte globale IP-Adresse, die von einem externen
HTTP(S)-Load-Balancer gehalten wird. Dieser verteilt Traffic auf eine Managed
Instance Group mit zwei App-VMs. Der Monitoring-Stack läuft getrennt auf einer
persistenten VM mit eigener Persistent-Disk.

#figure(
  block(width: 100%)[#set text(size: 8pt)
  #let col-client  = luma(246)
  #let col-edge    = rgb("#dceaff")
  #let col-iaas    = rgb("#e2f4df")
  #let col-ops     = rgb("#fff1d8")
  #let col-paas    = rgb("#f0e8ff")
  #let col-saas    = rgb("#ffe0ea")
  #let mig-green   = rgb("#21843a")
  #let google-blue = rgb("#4285f4")
  #let google-red  = rgb("#ea4335")
  #let google-yel  = rgb("#fbbc05")
  #let google-grn  = rgb("#34a853")
  #let col-head    = luma(85)
  #let col-label(txt) = text(weight: "bold", size: 0.9em, fill: col-head, txt)
  #let mark(txt, fill, fg: white) = box(
    width: 17pt,
    height: 17pt,
    fill: fill,
    stroke: 0.35pt + luma(150),
    radius: 3pt,
    inset: 0pt,
  )[#align(center + horizon)[#text(size: 6.5pt, weight: "bold", fill: fg, txt)]]
  #let svc(m, color, body) = grid(
    columns: (auto, auto),
    column-gutter: 4pt,
    align: (horizon, left),
    mark(m, color),
    body,
  )
  #diagram(
    node-stroke: 0.6pt,
    node-inset: 5pt,
    spacing: (15mm, 8.5mm),
    node-corner-radius: 3pt,
    edge-stroke: 0.6pt,

    // ---- Column headers ----
    node((0, -2.7), col-label[Client], stroke: none),
    node((1, -2.7), col-label[Edge], stroke: none),
    node((2, -2.7), col-label[Compute (IaaS)], stroke: none),
    node((3, -2.7), col-label[Managed Services], stroke: none),

    // ==== Client column ====
    node((0, 0), svc("WWW", google-blue, [*Nutzer*\ Browser]), fill: col-client),

    // ==== Edge column ====
    node((1, 0), svc("LB", google-blue, [*Global IP*\ HTTP(S) LB]),
         shape: pill, fill: col-edge),

    // ==== Compute column ====
    node((2, -0.45), svc("VM", google-grn, [*App-VM 1*\ nginx · React/FastAPI]),
         fill: col-iaas),
    node((2, 0.65), svc("VM", google-grn, [*App-VM 2*\ nginx · React/FastAPI]),
         fill: col-iaas),
    node(enclose: ((2, -0.45), (2, 0.65)),
         inset: 8pt,
         stroke: (dash: "dashed", paint: mig-green, thickness: 0.8pt),
         corner-radius: 6pt),
    node((2, 1.25),
         text(fill: mig-green, weight: "bold", size: 0.8em)[MIG · auto-healing],
         stroke: none),

    // ==== Managed services ====
    node((3, -1.25), svc("AI", google-red, [*Gemini API*\ Reiseantworten]),
         fill: col-saas),
    node((3, -0.1), svc("FS", google-yel, [*Firestore*\ Profile · Chats · Trips]),
         fill: col-paas),
    node((3, 1.55), svc("CS", google-blue, [*Cloud Scheduler*\ täglicher Export]),
         fill: col-paas),
    node((3, 3.35), svc("GCS", google-grn, [*Cloud Storage*\ Firestore-Backups]),
         fill: col-paas),

    // ==== Observability ====
    node((2, 3.35), svc("OBS", google-blue, [*Monitoring-VM*\ Prometheus · Grafana\ Loki · Blackbox]),
         fill: col-ops),

    // ---- Request path ----
    edge((0, 0), (1, 0), "->", [HTTPS]),
    edge((1, 0), (2, -0.45), "->"),
    edge((1, 0), (2, 0.65), "->"),

    // ---- Application dependencies ----
    edge((2, -0.45), (3, -1.25), "->", [AI]),
    edge((2, 0.65), (3, -0.1), "->", [R/W]),

    // ---- Monitoring and backups ----
    edge((2, 3.35), (2, 0.65), "->", [scrape/logs]),
    edge((2, 3.35), (3, -0.1), "->", bend: -24deg, [DB probe]),
    edge((3, 1.55), (3, -0.1), "->", [trigger]),
    edge((3, -0.1), (3, 3.35), "->", bend: 45deg, [export]),
    edge((3, 3.35), (3, -0.1), "->", bend: 45deg, [restore]),

    // ---- Legend row ----
    node((0, 4.35), col-label[Legende:], stroke: none),
    node((0.75, 4.35), box(fill: col-iaas, inset: 3pt, radius: 2pt, stroke: 0.4pt)[IaaS], stroke: none),
    node((1.35, 4.35), box(fill: col-paas, inset: 3pt, radius: 2pt, stroke: 0.4pt)[PaaS], stroke: none),
    node((1.95, 4.35), box(fill: col-saas, inset: 3pt, radius: 2pt, stroke: 0.4pt)[SaaS], stroke: none),
    node((2.6, 4.35), box(fill: col-ops, inset: 3pt, radius: 2pt, stroke: 0.4pt)[Betrieb], stroke: none),
    node((3, 4.35), box(fill: col-edge, inset: 3pt, radius: 2pt, stroke: 0.4pt)[Edge/LB], stroke: none),
  )],
  caption: [Gesamtarchitektur mit getrennten Pfaden: Der Nutzerverkehr läuft
            horizontal über Browser, globale IP und Load Balancer in die
            Managed Instance Group. Firestore und Gemini sind als direkte
            Laufzeitabhängigkeiten sichtbar, während Monitoring und
            Backup/Restore als eigene Betriebsflüsse räumlich getrennt sind.],
) <fig-architecture>

== Request-Pfad und Deployment-Flüsse

Die Architektur trennt bewusst den _Request-Pfad_ vom _Deployment-Pfad_.
@fig-flows macht diese Trennung explizit. Produktions-Traffic wird ausschließlich
über den Load Balancer in die MIG geleitet, während das CI/CD-System über
Terraform und die Instance-Template-Rotation neue Versionen ausrollt.

#figure(
  block(width: 100%)[#set text(size: 8.5pt)
  #diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    spacing: (7mm, 7mm),
    node-corner-radius: 3pt,

    // Request path (top row)
    node((0, 0), [Nutzer], fill: luma(245)),
    node((1.4, 0), [LB], shape: pill, fill: rgb("#e8f1ff")),
    node((2.8, 0), [App-VM\ (MIG)], fill: rgb("#eafbe8")),
    node((4.4, 0), [Firestore /\ Gemini]),

    edge((0, 0), (1.4, 0), "->", [HTTPS]),
    edge((1.4, 0), (2.8, 0), "->", [healthy]),
    edge((2.8, 0), (4.4, 0), "->"),

    // Deployment path (bottom row)
    node((0, 2), [git push], fill: luma(245)),
    node((1.4, 2), [GitHub\ Actions], fill: rgb("#fff9cc")),
    node((2.8, 2), [Terraform\ apply], fill: rgb("#fff9cc")),
    node((4.2, 2), [Instance-\ Template], fill: rgb("#fff9cc")),
    node((5.6, 2), [MIG Rolling\ Replace], fill: rgb("#eafbe8")),

    edge((0, 2), (1.4, 2), "->"),
    edge((1.4, 2), (2.8, 2), "->"),
    edge((2.8, 2), (4.2, 2), "->"),
    edge((4.2, 2), (5.6, 2), "->"),
    edge((5.6, 2), (2.8, 0), "->", bend: -25deg,
         label-pos: 0.3, [new tag]),

    // Monitoring VM via Ansible (separate lane)
    node((1.4, 3.3), [Ansible\ (Monitoring)], fill: rgb("#ffe7cc")),
    node((2.8, 3.3), [Monitoring-VM], fill: rgb("#fff3e6")),
    edge((1.4, 2), (1.4, 3.3), "->"),
    edge((1.4, 3.3), (2.8, 3.3), "->"),
  )],
  caption: [Getrennte Pfade für Laufzeit-Requests (oben) und Deployment
            (unten). Ansible wird nur für die persistente Monitoring-VM
            verwendet.],
) <fig-flows>

== Entwicklung des Deployment-Modells

Die heutige Trennung _Terraform + Startup-Script für App, Ansible für Monitoring_
ist das Ergebnis einer iterativen Designentwicklung. Zunächst war sowohl App-
als auch Monitoring-Deployment über Ansible organisiert. Dieses Modell wurde
aus drei Gründen abgelöst:

+ Mit $N > 1$ App-Instanzen würde ein SSH-basiertes Deployment in eine konkrete
  VM zwangsläufig Konfigurationsdrift erzeugen.
+ Eine im MIG neu gestartete Ersatz-VM muss ohne externes Eingreifen einsatzbereit
  werden – ein Nachzug über Ansible wäre ein Single Point of Operator Intervention.
+ Das Image-Tagging auf `latest` triggerte kein zuverlässiges Instance-Template-Update.
  Durch die Umstellung auf den Git-SHA als Image-Tag entsteht pro Commit eine
  eindeutige Template-Version, die den MIG-Rollout sicher auslöst.

Konkret wurden folgende Änderungen umgesetzt:

- Öffentlicher Einstieg auf reservierte globale Load-Balancer-IP umgestellt.
- App-MIG auf zwei Instanzen mit proaktivem Rolling-Replace erweitert.
- Startup-Script als autoritativer App-Bootstrap: holt Docker-Compose, `.env`
  und Promtail-Konfiguration aus einem GCS-Bucket, authentifiziert sich gegen
  Artifact Registry und startet den Compose-Stack.
- Legacy-Ansible-Rollen für die App entfernt, um nur noch _eine_
  Deployment-Geschichte im Repository zu halten.

== Monitoring-Stack

Der Monitoring-Stack läuft auf einer eigenen VM. Das ist bewusst gewählt, damit
die Observability nicht mit der überwachten Infrastruktur verschwindet:

- *Prometheus* entdeckt Scrape-Targets über GCE-Service-Discovery. Ein statischer
  Target-Eintrag wäre bei einer rollierenden MIG fragil.
- *Blackbox Exporter* prüft `GET /api/health/db` regelmäßig und exportiert
  `probe_success`. Der Endpoint wird also _aktiv_ und _unabhängig_ von App-Traffic
  beobachtet.
- *Grafana* lädt Dashboards automatisch aus einer provisionierten
  Verzeichnisstruktur. Ein initialer Fehler bei der Volume-Mount-Konfiguration
  (siehe Kapitel @sec-lessons) wurde behoben, indem das Dashboard-Verzeichnis
  explizit in den Container gemountet wurde.
- *Loki* nimmt Logs von Promtail entgegen, welches auf jeder App-VM Container-
  und System-Logs einsammelt.
- *Persistente Metriken und Logs* liegen auf einer separaten Persistent Disk mit
  `prevent_destroy = true`, damit sie VM-Neustarts und Redeploys überleben.

// ========= 4. Fokus-Feature: Disaster Recovery =========
= Fokus-Feature: Disaster Recovery

== Leitidee: zwei Recovery-Pfade

Das gewählte Fokus-Feature ist ein klar strukturiertes Disaster-Recovery-Konzept.
Die zentrale Entscheidung: _Compute-Recovery_ und _Datenrecovery_ werden als zwei
getrennte Recovery-Pfade behandelt, weil sie unterschiedliche Fehlerklassen
adressieren (@fig-dr-paths).

#figure(
  block(width: 100%)[#set text(size: 8.5pt)
  #diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    spacing: (8mm, 7mm),
    node-corner-radius: 3pt,

    node((0, 0), [Fehler-\ klassen], shape: hexagon, fill: rgb("#fff6d5")),
    node((1.6, -1), [Compute-\ Ausfall], fill: rgb("#ffe2e2")),
    node((1.6, 1), [Datenverlust\ (Firestore)], fill: rgb("#ffe2e2")),
    edge((0, 0), (1.6, -1), "->"),
    edge((0, 0), (1.6, 1), "->"),

    node((3.4, -1), [MIG Health\ + Auto-Replace], fill: rgb("#eafbe8")),
    node((3.4, 1), [Integrity Check\ + Backup/Restore], fill: rgb("#eafbe8")),
    edge((1.6, -1), (3.4, -1), "->"),
    edge((1.6, 1), (3.4, 1), "->"),

    node((5.2, -1), [App wieder\ erreichbar], fill: rgb("#e0f0ff")),
    node((5.2, 1), [Daten wieder\ vollständig], fill: rgb("#e0f0ff")),
    edge((3.4, -1), (5.2, -1), "->"),
    edge((3.4, 1), (5.2, 1), "->"),
  )],
  caption: [Zwei-Pfad-Recovery: Compute-Fehler werden durch die MIG behandelt,
            Datenfehler durch Integritätscheck, Backup und Restore.],
) <fig-dr-paths>

Diese Trennung ergibt sich aus einer einfachen Beobachtung: Eine MIG heilt nur
_Infrastruktur_, nicht _Daten_. Würde man ausschließlich auf MIG-Autohealing setzen,
bliebe ein Szenario wie ein versehentlich gelöschtes Firestore-Dokument unbehandelt,
obwohl die App-Instanzen technisch gesund sind.

== Compute-Recovery über die MIG

Jede App-Instanz wird über einen HTTP-Health-Check gegen `/api/health` überwacht.
Fällt eine Instanz aus, ersetzt die MIG sie automatisch anhand des aktuellen
Instance-Templates. Das Startup-Script bootstrappt die Ersatz-Instanz ohne
manuellen Eingriff. Die globale Load-Balancer-IP bleibt dabei unverändert,
weil sie nicht an eine konkrete VM gebunden ist.

== Datenrecovery

=== Deterministischer Integritätscheck

Ein bloßer Ping auf Firestore würde einen Datenverlust nicht erkennen, da die
Datenbank technisch weiterhin antwortet. Deshalb wurde ein dedizierter Endpoint
`GET /api/health/db` entwickelt, der konkret die Existenz _und_ ein paar
Pflichtfelder fester Referenzdokumente überprüft:

- `users/demo-user` (Felder: `display_name`, `email`)
- `users/demo-user/trips/demo-trip` (Felder: `destination`, `start_date`, `end_date`, `status`)
- `analytics/system` (Felder: `seed_version`, `last_seeded_at`)

Fehlt eines dieser Dokumente oder ein Pflichtfeld, liefert der Endpoint
`HTTP 500` mit einer strukturierten Fehlerliste und loggt ein Ereignis
`db_integrity_error`. Ein Blackbox Exporter fragt den Endpoint regelmäßig ab
und exportiert `probe_success` als Prometheus-Metrik. Ein Grafana-Stat-Panel
_Database Integrity_ zeigt den Zustand kontinuierlich, unabhängig von App-Traffic.

=== Backups und Restore

Die aktuelle Backup-Strecke ist bewusst als _Daily Export_ umgesetzt: Der
automatisierte Schutzpunkt entsteht einmal pro Tag, ergänzt durch manuelle
Vorab-Backups für geplante Recovery-Tests. Diese Lösung ist einfach,
prüfbar und passt zum Projektumfang, hat aber einen groben RPO: Änderungen
zwischen zwei Scheduler-Läufen sind nicht durch den letzten geplanten Export
abgedeckt. Firestore-Exporte eignen sich laut Google für das Wiederherstellen
nach versehentlicher Löschung und werden über Cloud Storage abgelegt; ein
Export ist jedoch kein exakt zum Startzeitpunkt eingefrorener Snapshot @gcp-firestore-export.

Die Terraform-Konfiguration legt drei zusammenhängende Ressourcen an:

+ Ein GCS-Bucket `${project-id}-firestore-backups` mit einer 30-Tage-
  Lifecycle-Regel.
+ Ein dedizierter Service Account mit den Rollen
  `datastore.importExportAdmin` und `storage.admin` für genau diesen Bucket.
+ Ein Cloud-Scheduler-Job, der täglich um 03:00 Uhr Europe/Berlin die
  Firestore-Export-API mit OAuth-Token dieses Service Accounts aufruft und
  nach `gs://.../scheduled/` schreibt.

Zusätzlich existiert ein manuelles Backup-Script
`presentation/demo-scripts/firestore-backup.sh`
für Vorab-Backups vor gezielten Recovery-Tests. Der Restore erfolgt über
`presentation/demo-scripts/firestore-restore.sh`, das entweder das jüngste manuelle Backup oder
einen explizit angegebenen Backup-Pfad importiert. Der Import ist asynchron
und kann mehrere Minuten dauern.

=== Recovery-Ablauf

Der Recovery-Ablauf eskaliert bewusst schrittweise, um die Zwei-Pfad-Logik
sichtbar zu machen:

#figure(
  block(width: 100%)[#set text(size: 8pt)
  #diagram(
    node-stroke: 0.5pt,
    node-inset: 5pt,
    spacing: (4mm, 5mm),
    node-corner-radius: 3pt,

    node((0, 0), [1. Baseline\ grün], fill: rgb("#eafbe8")),
    node((1, 0), [2. Daten\ löschen], fill: rgb("#ffe2e2")),
    node((2, 0), [3. Monitoring\ rot], fill: rgb("#ffe2e2")),
    node((3, 0), [4. VMs killen\ (optional)], fill: rgb("#ffe2e2")),
    node((4, 0), [5. Restore +\ MIG heilt], fill: rgb("#fff9cc")),
    node((5, 0), [6. Baseline\ wieder OK], fill: rgb("#eafbe8")),

    edge((0, 0), (1, 0), "->"),
    edge((1, 0), (2, 0), "->"),
    edge((2, 0), (3, 0), "->"),
    edge((3, 0), (4, 0), "->"),
    edge((4, 0), (5, 0), "->"),
  )],
  caption: [Staged Escalation des Recovery-Ablaufs: Daten werden vor Compute gekippt,
            damit der Unterschied zwischen App-Recovery und Daten-Recovery
            erkennbar wird.],
) <fig-dr-flow>

== Begründung einzelner Designentscheidungen

- *Warum sichtbare Datenlöschung statt eines versteckten Sentinel-Fehlers?*
  Eine Korruption, die nur im Backend sichtbar ist, ist schwer nachzuvollziehen.
  Durch gezieltes Löschen von Referenzdaten entsteht ein
  unmittelbarer UI-Effekt, der die Alarmierung nachvollziehbar macht.
- *Warum Cloud Scheduler statt VM-Cronjob?*
  Ein VM-lokaler Cronjob hätte dasselbe Ergebnis, ist aber architektonisch
  weniger passend: Cloud Scheduler + Managed-Export-API zeigt einen
  echten PaaS-Backup-Pfad, der VMs überlebt.
- *Warum ein eigener `demo-user`?*
  Der Integrity-Check darf sich nicht auf „irgendeinen Nutzer" verlassen.
  Mit einem festen Referenzdatensatz wird der Recovery-Test reproduzierbar und die
  Alarmierung deterministisch.

== Point-in-Time Recovery (Ausblick)

Eine vollständig zeitgenaue Wiederherstellung (Point-in-Time Recovery, PITR)
wird von Firestore nativ unterstützt. Im Unterschied zum täglichen Export hält
PITR ältere Dokumentversionen in einem Recovery-Fenster vor: ohne PITR ist nur
ungefähr die letzte Stunde verfügbar, mit aktiviertem PITR bis zu sieben Tage;
Lesezugriffe sind innerhalb der letzten Stunde mit Mikrosekundenpräzision und
darüber hinaus innerhalb des PITR-Fensters minutengenau möglich @gcp-firestore-pitr.
Damit ist PITR deutlich granularer als der hier umgesetzte Daily Export.

Im Rahmen dieses Projekts wurde PITR nicht aktiviert, weil es zusätzliche Kosten
verursacht und für die nachweisbare Backup-/Restore-Strecke nicht notwendig war.
Für einen produktionsnäheren Betrieb wäre ein hybrider Ansatz sinnvoll: Daily
Exports bleiben als langlebige, bucketbasierte Sicherung und als Grundlage für
projektübergreifende Restores erhalten, während PITR die Lücke zwischen zwei
geplanten Exporten schließt und versehentliche Schreib- oder Löschfehler
feingranularer rückgängig machen kann. Architektonisch ließe sich PITR ohne
Änderungen am App-Code nachziehen: Es müsste in der Firestore-Konfiguration
aktiviert werden, anschließend könnten zeitpunktbezogene Reads, Exporte oder
Datenbank-Klone für feinere Recovery-Szenarien genutzt werden.

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
      [E-Mail/Passwort-Login mit JWT, KI-Dialog mit persistenten Konversationen und
       speicherbaren Reiseplänen, Rate-Limit pro Nutzer.],
    [Cloud-Service-Modelle],
      [SaaS: Gemini API · PaaS: Firestore, Artifact Registry,
       Cloud Scheduler, Cloud Storage · IaaS: Compute Engine (MIG + Monitoring-VM),
       Load Balancer, Persistent Disks.],
    [Infrastruktur],
      [Komplette Infrastruktur inklusive MIG, LB, Firestore, IAM, Cloud-Storage-Buckets
       und Cloud-Scheduler-Job.],
    [Konfiguration],
      [Auf die persistente Monitoring-VM fokussiert; App-VMs werden über
       Startup-Script bereitgestellt.],
    [Disaster Recovery],
      [Sichtbare Datenkorruption, MIG-Autohealing,
       Grafana-Alert und Restore-Script.],
    [Monitoring],
      [Prometheus (GCE-SD), Grafana, Loki, Blackbox Exporter auf separater VM
       mit persistenter Disk.],
    [Entwicklung und Betrieb],
      [Typed FastAPI-Endpunkte, pytest-Testsuite, CI über GitHub Actions.],
    [Rollout-Modell],
      [GitHub Actions: Build/Push → `terraform apply` → Ansible
       (Monitoring) → Instance-Template-Rotation; globale statische IP vor HTTP(S)-LB,
       $N > 1$ App-Instanzen mit Rolling-Replace.],
  ),
  caption: [Zusammenfassung der umgesetzten Systembereiche.],
) <tab-systemumfang>

== Architektonische Iterationen

Die Commit-Historie des Repositories dokumentiert eine gradlinige
Architekturentwicklung:

+ _Single-VM + lokales Monitoring._
+ _Monitoring auf eigene VM ausgelagert._ Begründung: bessere Fehlertoleranz,
  klarere Verantwortlichkeiten.
+ _Self-healing MIG mit statischer VM-IP._ Begründung: Resilienz ohne
  zusätzliche Load-Balancer-Komplexität.
+ _Statische IP an Load Balancer verschoben, MIG auf $N = 2$._ Begründung:
  konsistentes $N > 1$-Modell und stabile öffentliche Adresse.
+ _App-Deployment aus Ansible gelöst, in Instance-Template + Startup-Script
  überführt._ Begründung: reproduzierbares, drift-freies Multi-Instance-Rollout.

Der Wechsel von einer direkt an die VM gebundenen statischen IP auf eine
Load-Balancer-IP ist dabei bewusst als _Supersede_-Entscheidung markiert: das
ältere Design war für einen einzelnen VM-Autoheal-Zyklus tragfähig, wurde aber
mit dem Übergang zu $N > 1$ architektonisch zur falschen Abstraktion.

== Beobachtete Probleme und Lessons Learned <sec-lessons>

- *Startup-Script zu früh gestartet.* Beim ersten LB-Rollout lief die
  Startup-Sequenz einer Ersatz-VM an, bevor die aktualisierten Deployment-Dateien
  im GCS-Bucket lagen. Der Rollout erholte sich bei der nächsten Runde,
  dokumentiert aber einen Bedarf für Retry-Logik bei GCS-Downloads.
- *Backend-Healthcheck ohne `curl`.* Der Docker-Compose-Healthcheck nutzte
  `curl`, das im Backend-Image nicht enthalten war. Fix: `curl` im Dockerfile
  ergänzen. Lesson: Healthchecks verlangen dieselbe Toolkette wie die
  Anwendung.
- *Grafana-Dashboards nicht provisioniert.* Die Provisioning-Konfiguration
  zeigte auf `/etc/grafana/dashboards`, aber der Volume-Mount legte nur
  Teilpfade ab. Fix: das Dashboard-Verzeichnis explizit mounten.
- *`cloudscheduler.googleapis.com` nicht aktiviert.* Ein neu eingeführter
  Scheduler-Job schlug fehl, bis die API projektweit aktiviert und dem
  CI/CD-Service-Account die Rolle `serviceusage.serviceUsageAdmin`
  zugewiesen wurde. Lesson: Disaster Recovery ist nicht nur Architektur,
  sondern auch _Service-Account-Hygiene_.

== Grenzen der aktuellen Lösung

- Das Restore ist manuell angestoßen. In einem Produktionsbetrieb wäre ein
  definierter RTO/RPO-Zielwert mit automatisierter Restore-Entscheidung wünschenswert.
- Die geplanten Firestore-Backups laufen nur täglich; PITR ist konzeptionell
  vorgesehen, aber aus Kostengründen nicht aktiviert. Dadurch bleibt der
  Recovery-Punkt zwischen zwei Daily Exports gröber als in einem hybriden
  Export-plus-PITR-Setup.
- Das Logging ist aktuell klassisch über Promtail nach Loki umgesetzt, nicht
  über OpenTelemetry. Ein OTel-Collector mit OTLP-Empfang wäre eine sinnvolle
  Erweiterung, um Logs, Metriken und Traces stärker zu standardisieren und
  vendor-neutral weiterzugeben.
- Die MIG betreibt zwei Instanzen in _einer_ Region. Ein echtes
  Multi-Region-Setup würde einen deutlich größeren Aufwand bedeuten,
  wurde im Projektumfang aber nicht umgesetzt.

// ========= 6. Fazit =========
= Fazit

Das Projekt realisiert eine cloud-native Reiseplanungsanwendung mit klar
getrennten Verantwortlichkeiten: Alle drei Cloud-Ebenen sind produktiv im
Einsatz, die Infrastruktur wird vollständig über Terraform bereitgestellt,
Ansible übernimmt die Konfiguration des persistenten Monitoring-Hosts, und das
Monitoring-Konzept zeigt sowohl Infrastruktur- als auch Datengesundheit an.

Das Fokus-Feature _Disaster Recovery_ unterscheidet klar zwischen
Compute-Recovery und Datenrecovery und macht diese Trennung im Recovery-Ablauf
sichtbar. Die eingeführte Unterscheidung zwischen Integritätscheck und
reinem Connectivity-Ping sowie das zweistufige Backup-Konzept (geplant +
manuell) machen den Recovery-Pfad nachvollziehbar. Der Load Balancer und die
CI/CD-Pipeline ergänzen diese Architektur um einen stabilen öffentlichen
Einstiegspunkt und reproduzierbare Rollouts.

Für zukünftige Iterationen bieten sich vor allem drei Richtungen an:
_automatisiertes Restore_ (RTO/RPO-getrieben), ein hybrider
_Daily-Export-plus-PITR_-Ansatz für Firestore, eine _OpenTelemetry_-basierte
Observability-Pipeline und ein _Multi-Region-Failover_ für den Load Balancer. Die aktuelle
Trennung zwischen Terraform-gesteuertem App-Rollout und Ansible-gesteuertem
Monitoring-Host bleibt dabei tragfähig und ermöglicht diese Erweiterungen,
ohne die bestehende Deployment-Geschichte zu brechen.

// ========= Referenzen =========
#bibliography("references.bib", title: "Referenzen", style: "ieee", full: true)
