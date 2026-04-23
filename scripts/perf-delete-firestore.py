#!/usr/bin/env python3
"""Deletes all documents in a given top-level Firestore collection."""
from __future__ import annotations

import argparse
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from google.cloud import firestore

BATCH_SIZE = 500
PARALLEL_BATCHES = 20


def delete_batch(db: firestore.Client, refs: list) -> int:
    batch = db.batch()
    for ref in refs:
        batch.delete(ref)
    batch.commit()
    return len(refs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--collection", required=True)
    args = parser.parse_args()

    db = firestore.Client(project=args.project)
    started = time.monotonic()
    deleted = 0

    with ThreadPoolExecutor(max_workers=PARALLEL_BATCHES) as pool:
        pending = []
        buf: list = []
        for doc in db.collection(args.collection).stream():
            buf.append(doc.reference)
            if len(buf) >= BATCH_SIZE:
                pending.append(pool.submit(delete_batch, db, buf))
                buf = []
        if buf:
            pending.append(pool.submit(delete_batch, db, buf))

        for fut in as_completed(pending):
            deleted += fut.result()

    elapsed = time.monotonic() - started
    print(f"Deleted {deleted} docs from '{args.collection}' in {elapsed:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
