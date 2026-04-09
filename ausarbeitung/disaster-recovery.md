# Disaster Recovery Concept And Demo Flow

## Goal

The disaster recovery concept of this project is meant to demonstrate two
different failure classes:

- infrastructure failure of application instances
- data loss or data corruption inside Firestore

The important design goal is that these two problems are treated separately.
The architecture should show that:

- a VM failure is handled automatically by Google Cloud
- a database corruption event is detected through monitoring
- deleted data can be restored from backups

This gives the project a stronger resilience story than a simple
"restart-the-server" demo.

## Core Idea

The final disaster recovery approach is intentionally split into two recovery
paths:

### 1. Compute recovery

Application VMs run inside a Managed Instance Group (MIG). If an app instance
fails its health checks, Google Cloud replaces it automatically using the
instance template and startup script.

This path solves:

- crashed app VM
- broken app process on one VM
- replacement of unhealthy instances

This path does **not** solve:

- deleted Firestore documents
- corrupted application data

### 2. Data recovery

Application state is stored in Firestore. If important data is deleted, the
application may still be reachable, but user-facing content becomes incomplete
or missing. This requires a separate recovery mechanism:

- detect corruption through a Firestore integrity check
- surface the failure in Grafana and Loki
- restore the missing data from a Firestore backup

This separation is important both technically and conceptually:

- MIG heals infrastructure
- backup and restore heal data

## Implemented Disaster Recovery Components

### Firestore integrity check

The backend exposes a dedicated endpoint at `/api/health/db`.

This endpoint does not only test connectivity. It verifies that defined
reference data exists in Firestore and that the expected structure is still
present. If required data is missing, it returns an unhealthy state and emits a
structured log event.

Benefits:

- simple health signal for monitoring
- easy to explain in the presentation
- detects missing application data even when the backend is still running

### Firestore backups

Firestore exports are stored in a dedicated GCS backup bucket. The design uses:

- one bucket for Firestore backup data
- a dedicated service account for export operations
- a scheduled export job via Cloud Scheduler
- a manual export script for ad hoc backups before the presentation

This creates two useful backup paths:

- scheduled backup for normal operation
- manual pre-demo backup for presentation safety

### Restore workflow

Restore is handled by a dedicated script that imports the latest or a specified
backup into Firestore.

Important operational point:

- the import is asynchronous and can take some time

That is why the presentation flow must include a short explanation phase while
the restore runs in the background.

### Monitoring

The database integrity signal is monitored separately from app instance health.

The monitoring path is:

- `/api/health/db` returns success or failure
- Prometheus checks the endpoint through a Blackbox Exporter
- Grafana visualizes the signal as `Database Integrity`
- an alert fires if the endpoint remains unhealthy
- Loki stores backend and startup-related log events

This allows the presentation to show:

- the app is still online, but the data is unhealthy
- later, the infrastructure is unhealthy as well after the VM kill

### Logging

Two kinds of structured log events are relevant:

- `db_integrity_error`
  emitted by the backend when the database health check detects missing data
- `vm_recovery_event` and `app_instance_started`
  emitted during VM bootstrap and recovery

This supports the narrative that the project distinguishes between:

- data failures
- infrastructure lifecycle events

## Presentation Demo Flow

The disaster recovery demo is strongest when it follows a staged escalation.

### Phase 1: Healthy baseline

Show:

- the live application
- existing user data / trips
- green monitoring state

This establishes the baseline.

### Phase 2: Simulated data corruption

Trigger the corruption step before killing the VMs.

For the presentation version, the corruption script deletes user-facing
Firestore data so the effect is clearly visible in the UI. This is more
aggressive than a small sentinel-only corruption, but it is easier to
demonstrate live.

Expected result:

- app still responds
- user data is missing
- `/api/health/db` becomes unhealthy
- Grafana shows a red database integrity signal
- Loki can show the related integrity event

### Phase 3: VM failure

After the data problem is visible, the demo escalates to infrastructure failure
by deleting the app VM instances.

Expected result:

- app becomes temporarily unreachable
- monitoring shows instance failure / reduced healthy instances
- the MIG starts replacing unhealthy instances

This demonstrates that infrastructure recovery is independent from data
recovery.

### Phase 4: Restore and recovery

Finally, restore the Firestore backup and allow the new instances to become
healthy again.

Expected result:

- app becomes reachable again
- user data reappears
- integrity monitoring returns to green
- the final state shows full recovery, not only process recovery

## Design Rationale

### Why not only demonstrate VM recovery?

Only killing VMs would show autohealing, but not real application resilience.
Because user data is stored outside the VM, a stronger cloud-computing story is
to show that:

- infrastructure can be replaced automatically
- persistent data still needs its own recovery strategy

### Why use a visible corruption step?

A hidden backend-only failure would be technically valid, but not ideal for a
live presentation. Making the data loss visible in the application improves:

- audience understanding
- demo clarity
- connection between monitoring and user-visible impact

### Why keep monitoring on a separate VM?

If monitoring lived on the same app VM, the observability stack could disappear
with the failure it is supposed to report. Keeping Prometheus, Grafana, and
Loki separate allows the monitoring view to remain available during app
replacement and recovery.

## Operational Lessons

During implementation, one important operational lesson appeared:

- infrastructure resources that depend on Google APIs may fail to deploy if the
  required API is not enabled or if the deploy service account cannot enable it

For example, the Cloud Scheduler-based backup job required:

- `cloudscheduler.googleapis.com`
- sufficient IAM permission for the CI/CD service account to enable project
  services

This is a useful report point because it shows that real disaster recovery is
not only an architectural topic, but also an operational one.

## Final Result

The final disaster recovery design demonstrates:

- self-healing app infrastructure via MIG
- separate monitoring visibility during outages
- Firestore integrity checks for data problems
- backup and restore for persistent-state recovery
- explicit distinction between compute recovery and data recovery

That makes the project stronger for both the written report and the live
presentation, because it shows that resilience is treated as a system property,
not only as a VM replacement trick.
