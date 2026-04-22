# Ausarbeitung

Schriftliche Ausarbeitung zu `Timmy's Travel Assistant` für Cloud Computing II.

## Struktur

- Einleitung
  - Kontext und Motivation
  - Zielsetzung
  - Problemstellung
- Technische Grundlagen
  - Cloud-Service-Modelle
  - Eingesetzte Technologien
  - Begründung der Technologieauswahl
- Architektur und Umsetzung
  - Gesamtarchitektur
  - Request-Pfad und Deployment-Flüsse
  - Entwicklung des Deployment-Modells
  - Monitoring-Stack
- Fokus-Feature: Disaster Recovery
  - Leitidee: zwei Recovery-Pfade
  - Compute-Recovery über die MIG
  - Datenrecovery
  - Begründung einzelner Designentscheidungen
  - Point-in-Time Recovery (Ausblick)
- Ergebnisse und Diskussion
  - Umgesetzter Systemumfang
  - Architektonische Iterationen
  - Beobachtete Probleme und Lessons Learned
  - Grenzen der aktuellen Lösung
- Fazit
- Referenzen

Die früheren TODOs sind abgedeckt: PITR steht im Ausblick, der
Firestore-Integritätscheck ist inklusive Alerting beschrieben, die
Monitoring-Persistenz wird über eigene VM und Persistent Disk behandelt, und die
pytest-Testsuite ist im Systemumfang eingeordnet.

## Build

```sh
typst compile ausarbeitung.typ ausarbeitung.pdf
```
