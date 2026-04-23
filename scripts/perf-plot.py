#!/usr/bin/env python3
"""Plots performance-test JSON results produced by the perf-* workflows.

Usage:
  python scripts/perf-plot.py --input scale.json --output scale.png
  python scripts/perf-plot.py --input mig.json   --output mig.png

The script detects the test type from the JSON payload:
  - "dr_scale"      → seed/export/import duration vs. document count (log-x, points + median line per stage)
  - "mig_recovery"  → stacked timeline of the recovery phases per iteration plus median markers

Dependencies: matplotlib, numpy (install via `pip install matplotlib numpy`).
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def plot_scale(rows: list[dict], output: Path) -> None:
    buckets: dict[int, list[dict]] = defaultdict(list)
    for r in rows:
        buckets[r["doc_count"]].append(r)

    doc_counts = sorted(buckets)
    stages = [
        ("seed_seconds",   "Seed",   "#6baed6"),
        ("export_seconds", "Export", "#fd8d3c"),
        ("import_seconds", "Import", "#74c476"),
    ]

    fig, ax = plt.subplots(figsize=(9, 5.5))

    for field, label, color in stages:
        medians = [statistics.median(r[field] for r in buckets[dc]) for dc in doc_counts]
        ax.plot(doc_counts, medians, marker="o", color=color, label=f"{label} (median)", linewidth=2)
        # Individual samples as faint dots
        for dc in doc_counts:
            for r in buckets[dc]:
                ax.scatter([dc], [r[field]], color=color, alpha=0.25, s=18)

    ax.set_xscale("log")
    ax.set_xlabel("Dokumente pro Iteration")
    ax.set_ylabel("Dauer (Sekunden)")
    ax.set_title("Firestore DR-Phasen — Dauer pro Datenmenge")
    ax.grid(True, which="both", alpha=0.3)
    ax.legend(loc="upper left")

    # Nicely formatted x ticks
    ax.set_xticks(doc_counts)
    ax.set_xticklabels([f"{dc:,}" for dc in doc_counts])

    fig.tight_layout()
    fig.savefig(output, dpi=150)
    print(f"Wrote {output}")


def plot_mig(rows: list[dict], output: Path) -> None:
    events = [
        ("seconds_to_unhealthy", "LB UNHEALTHY", "#c6dbef"),
        ("seconds_to_replacing", "MIG replace",  "#6baed6"),
        ("seconds_to_running",   "Neue VM RUNNING", "#2171b5"),
        ("seconds_to_healthy",   "Recovery komplett", "#08306b"),
    ]

    iterations = [r["iteration"] for r in rows]
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5), gridspec_kw={"width_ratios": [3, 2]})

    # Left: per-iteration timeline
    width = 0.18
    x = np.arange(len(iterations))
    for i, (field, label, color) in enumerate(events):
        vals = [r.get(field) or 0 for r in rows]
        ax1.bar(x + i * width, vals, width=width, color=color, label=label)

    ax1.set_xticks(x + width * (len(events) - 1) / 2)
    ax1.set_xticklabels([f"#{it}" for it in iterations])
    ax1.set_xlabel("Iteration")
    ax1.set_ylabel("Sekunden seit Kill-Event (T0)")
    ax1.set_title("MIG-Recovery — Ereigniszeiten pro Iteration")
    ax1.grid(True, axis="y", alpha=0.3)
    ax1.legend(loc="upper right", fontsize=9)

    # Right: median summary
    labels = [lbl for _, lbl, _ in events]
    medians: list[float] = []
    mins: list[float] = []
    maxs: list[float] = []
    colors = [c for _, _, c in events]
    for field, _, _ in events:
        vals = [r[field] for r in rows if r.get(field) is not None]
        if vals:
            medians.append(statistics.median(vals))
            mins.append(min(vals))
            maxs.append(max(vals))
        else:
            medians.append(0); mins.append(0); maxs.append(0)

    y = np.arange(len(labels))
    ax2.barh(y, medians, color=colors)
    ax2.errorbar(
        medians, y,
        xerr=[np.subtract(medians, mins), np.subtract(maxs, medians)],
        fmt="none", ecolor="black", capsize=4, linewidth=1,
    )
    for yi, m in zip(y, medians):
        ax2.text(m, yi, f"  {m:.0f}s", va="center", fontsize=9)
    ax2.set_yticks(y)
    ax2.set_yticklabels(labels)
    ax2.invert_yaxis()
    ax2.set_xlabel("Sekunden (Median, Whiskers = Min/Max)")
    ax2.set_title(f"Median über {len(rows)} Iterationen")
    ax2.grid(True, axis="x", alpha=0.3)

    fig.tight_layout()
    fig.savefig(output, dpi=150)
    print(f"Wrote {output}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    with args.input.open() as f:
        rows = json.load(f)
    if not rows:
        print("Input file contains no rows", file=sys.stderr)
        return 1

    test = rows[0].get("test")
    if test == "dr_scale":
        plot_scale(rows, args.output)
    elif test == "mig_recovery":
        plot_mig(rows, args.output)
    else:
        print(f"Unknown test type: {test!r}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
