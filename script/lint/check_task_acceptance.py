#!/usr/bin/env python3
"""Validate a local Breeze task acceptance record and its evidence files."""

import argparse
from collections import Counter
import json
from pathlib import Path


METHODS = ("test", "simulator", "device", "review")
STATUSES = ("pending", "passed", "failed")


def required_text(value, label):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be non-empty text")
    return value.strip()


def validate_record(path, *, require_complete=False):
    record = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(record, dict):
        raise ValueError("The record must be a JSON object")
    required_text(record.get("task"), "task")
    checks = record.get("checks")
    if not isinstance(checks, list) or not checks:
        raise ValueError("checks must contain at least one acceptance check")

    counts = Counter()
    for index, check in enumerate(checks):
        label = f"checks[{index}]"
        if not isinstance(check, dict):
            raise ValueError(f"{label} must be a JSON object")
        for field in ("entry", "scope", "expected"):
            required_text(check.get(field), f"{label}.{field}")
        if check.get("method") not in METHODS:
            raise ValueError(f"{label}.method must be one of {', '.join(METHODS)}")
        status = check.get("status")
        if status not in STATUSES:
            raise ValueError(f"{label}.status must be one of {', '.join(STATUSES)}")
        counts[status] += 1

        evidence = check.get("evidence")
        if status == "pending" and evidence is None:
            continue
        evidence = path.parent / required_text(evidence, f"{label}.evidence")
        if not evidence.is_file() or evidence.stat().st_size == 0:
            raise ValueError(f"{label}.evidence is missing or empty: {evidence}")

    if require_complete and (counts["pending"] or counts["failed"]):
        raise ValueError(
            f"Acceptance is incomplete: {counts['pending']} pending, "
            f"{counts['failed']} failed"
        )
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path, help="Path to the JSON record")
    parser.add_argument(
        "--complete", action="store_true", help="Require all recorded checks to pass"
    )
    args = parser.parse_args()
    try:
        counts = validate_record(args.record, require_complete=args.complete)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{args.record}: {error}\n")
    print(
        f"{args.record}: {counts['passed']} passed, {counts['pending']} pending, "
        f"{counts['failed']} failed"
    )


if __name__ == "__main__":
    main()
