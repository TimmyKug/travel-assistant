# Presentation

Reveal.js slide deck for the AI Travel Assistant project presentation.

## Files

- `index.html` - the slide deck
- `server.py` - local helper server for live demo actions
- `demo-scripts/` - Firestore backup, restore, seed, and corruption demo scripts
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

Some demo actions call local scripts and `gcloud`, so they require an authenticated Google Cloud CLI session with access to the project. The static slides can still be viewed by opening `index.html`, but live demo actions need the local server.
