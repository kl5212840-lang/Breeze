#!/usr/bin/env python3
"""Regression checks for acceptance status and evidence requirements."""

import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_task_acceptance import validate_record


class TaskAcceptanceTests(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "acceptance.json"
        self.check = {
            "entry": "Saved accounts > Add account > Cancel",
            "scope": "Shared host, browser fixture",
            "expected": "The original account and add action are available",
            "method": "test",
            "status": "pending",
        }

    def write_record(self, *checks):
        self.path.write_text(
            json.dumps({"task": "Account cancellation", "checks": checks}),
            encoding="utf-8",
        )

    def test_pending_checks_can_be_recorded_before_acceptance(self):
        self.write_record(self.check)
        self.assertEqual(validate_record(self.path)["pending"], 1)
        with self.assertRaisesRegex(ValueError, "1 pending, 0 failed"):
            validate_record(self.path, require_complete=True)

    def test_complete_checks_resolve_evidence_next_to_the_record(self):
        self.path.with_name("result.log").write_text("All tests passed\n")
        self.write_record({**self.check, "status": "passed", "evidence": "result.log"})
        self.assertEqual(validate_record(self.path, require_complete=True)["passed"], 1)

    def test_failed_checks_keep_evidence_and_prevent_completion(self):
        self.path.with_name("result.log").write_text("The list remained loading\n")
        self.write_record({**self.check, "status": "failed", "evidence": "result.log"})
        self.assertEqual(validate_record(self.path)["failed"], 1)
        with self.assertRaisesRegex(ValueError, "0 pending, 1 failed"):
            validate_record(self.path, require_complete=True)

    def test_a_pass_cannot_reference_missing_or_empty_evidence(self):
        self.write_record({**self.check, "status": "passed", "evidence": "empty.log"})
        with self.assertRaisesRegex(ValueError, "evidence is missing or empty"):
            validate_record(self.path)
        self.path.with_name("empty.log").touch()
        with self.assertRaisesRegex(ValueError, "evidence is missing or empty"):
            validate_record(self.path)

    def test_invalid_method_or_status_and_empty_scope_are_rejected(self):
        for field, value in [("method", "guess"), ("status", "done"), ("scope", " ")]:
            with self.subTest(field=field):
                self.write_record({**self.check, field: value})
                with self.assertRaisesRegex(ValueError, rf"checks\[0\]\.{field}"):
                    validate_record(self.path)


if __name__ == "__main__":
    unittest.main()
