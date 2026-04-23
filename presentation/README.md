# Presentation

Reveal.js slide deck for the AI Travel Assistant project presentation.

## Files

- `index.html` - the slide deck
- `server.py` - local helper server for live demo actions
- `demo-scripts/` - Firestore backup, restore, and corruption demo scripts
- `backup-status.json` - sample backup status response used by the demo
- `start_presentation.command` - macOS launcher for the local presentation server

## Run

For the full demo controls, start the local server:

```bash
cd presentation
python3 server.py
```

Then open:

```text
http://localhost:8080
```

On macOS, you can also run `start_presentation.command`.

## Notes

Some demo actions call local scripts and `gcloud`, so they require an authenticated Google Cloud CLI session with access to the project.

As an alternative to running the scripts with the buttons, the github actions workflows can be used.

For Firestore scripts (especially `demo-scripts/demo-corrupt-db.sh`), Application Default Credentials (ADC) are required because the script uses Python `google-cloud-firestore` (not only `gcloud` CLI auth):

```bash
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

The ADC identity must have Firestore data access in the target project (for example `roles/datastore.user` or higher), otherwise calls fail with `403 Missing or insufficient permissions`.

Grant command (run with an admin identity):

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="user:YOUR_EMAIL@example.com" \
  --role="roles/datastore.user"
```

For restore scripts that resolve the latest manual backup from
`gs://<project>-firestore-backups/manual/...`, the identity also needs GCS object listing/reading:

```bash
gcloud storage buckets add-iam-policy-binding gs://YOUR_PROJECT_ID-firestore-backups \
  --member="user:YOUR_EMAIL@example.com" \
  --role="roles/storage.objectViewer"
```

If the same user should trigger Firestore import/export operations directly, grant:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="user:YOUR_EMAIL@example.com" \
  --role="roles/datastore.importExportAdmin"
```

Sentinel seeding is part of infrastructure provisioning and is intentionally not triggered by the presentation launcher.
