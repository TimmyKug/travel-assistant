#!/usr/bin/env python3
"""Seeds a dedicated top-level Firestore collection with N dummy trip documents.

Used by the DR scale-test workflow. Each run gets its own collection name so
the seeded data is isolated from real users and can be exported, deleted and
re-imported without touching production paths.
"""
from __future__ import annotations

import argparse
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

from google.cloud import firestore

BATCH_SIZE = 500
PARALLEL_BATCHES = 20


def build_doc(index: int, now_iso: str) -> dict:
    return {
        "destination": f"Perf City {index}",
        "start_date": "2026-06-01",
        "end_date": "2026-06-07",
        "status": "planned",
        "notes": f"perf-test doc #{index}",
        "updated_at": now_iso,
    }


def write_batch(db: firestore.Client, collection: str, start: int, count: int, now_iso: str) -> int:
    batch = db.batch()
    for i in range(start, start + count):
        ref = db.collection(collection).document(f"trip-{i:08d}")
        batch.set(ref, build_doc(i, now_iso))
    batch.commit()
    return count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--collection", required=True)
    parser.add_argument("--count", type=int, required=True)
    args = parser.parse_args()

    db = firestore.Client(project=args.project)
    now_iso = datetime.now(timezone.utc).isoformat()

    total = args.count
    remaining = total
    next_start = 0
    written = 0
    started = time.monotonic()

    print(f"Seeding {total} docs into '{args.collection}' ({PARALLEL_BATCHES} parallel batches of {BATCH_SIZE})")

    with ThreadPoolExecutor(max_workers=PARALLEL_BATCHES) as pool:
        futures = []
        while remaining > 0:
            size = min(BATCH_SIZE, remaining)
            futures.append(pool.submit(write_batch, db, args.collection, next_start, size, now_iso))
            next_start += size
            remaining -= size

        last_report = started
        for fut in as_completed(futures):
            written += fut.result()
            now = time.monotonic()
            if now - last_report > 5 or written == total:
                rate = written / max(now - started, 1e-6)
                print(f"  {written}/{total} ({rate:,.0f} writes/s)")
                last_report = now

    elapsed = time.monotonic() - started
    print(f"Seed complete: {written} docs in {elapsed:.1f}s ({written/elapsed:,.0f} writes/s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
