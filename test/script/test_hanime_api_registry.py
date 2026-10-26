"""Schema policy tests only; these fixtures are not site acceptance evidence."""

import copy
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "script/hanime/api_registry.py"
SPEC = importlib.util.spec_from_file_location("api_registry", SCRIPT)
registry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(registry)


def fixture():
    return {
        "schemaVersion": 1, "siteOrigin": "https://hanime1.me", "updatedOn": "2026-10-24",
        "evidence": [{
            "id": "code.like", "kind": "third_party_code", "observedOn": "2026-10-24",
            "source": {"path": "/research/client.dart"}, "context": {"auth": "unknown", "synthetic": False},
            "facts": ["Contains a candidate like request"], "limitations": ["Not first-party evidence"],
        }],
        "entities": [{"id": "video", "description": "Site video", "idPolicy": "Stable site id"}],
        "capabilities": [{
            "id": "video.like", "title": "Like", "area": "video", "entityTypes": ["video"],
            "evidenceRefs": ["code.like"], "implementationRefs": [{"file": "lib/site.dart", "line": 1}],
            "checkpoints": {name: {"status": "unknown", "evidenceRefs": [], "note": "Not accepted"} for name in registry.CHECKPOINTS},
            "missing": ["Real site observation"],
        }],
        "contracts": [{
            "id": "like.candidate", "capabilityId": "video.like", "claimLevel": "candidate",
            "sourceRefs": ["code.like"], "method": "POST", "route": "/like",
            "request": {"fields": ["video-id", {"name": "status", "required": True}]},
            "preconditions": [], "success": [], "failure": [], "readback": [], "notes": ["Candidate only"],
        }],
        "conflicts": [],
    }


def official_network(data):
    # Intentionally constructed policy fixture, never saved as real evidence.
    ev = data["evidence"][0]
    ev["kind"] = "official_network"
    ev["source"] = {"url": "https://hanime1.me/watch?v=1", "path": "/evidence/redacted.json"}
    ev["context"] = {"auth": "signed_in", "synthetic": False, "nativeAdapterExecuted": True}


class RegistryPolicyTest(unittest.TestCase):
    def test_candidate_is_valid_without_invented_observation(self):
        self.assertEqual(registry.validate_registry(fixture()), [])

    def test_third_party_cannot_be_promoted(self):
        for level in ("observed_static", "observed_runtime"):
            data = fixture()
            data["contracts"][0]["claimLevel"] = level
            self.assertTrue(any("first-party" in e for e in registry.validate_registry(data)))

    def test_mock_or_screenshot_does_not_accept_write_or_readback(self):
        for kind, synthetic in (("user_screenshot", False), ("official_network", True), ("local_implementation", False)):
            data = fixture()
            official_network(data)
            data["evidence"][0]["kind"] = kind
            data["evidence"][0]["context"]["synthetic"] = synthetic
            for name in ("write", "readback"):
                data["capabilities"][0]["checkpoints"][name] = {"status": "passed", "evidenceRefs": ["code.like"], "note": "Policy fixture"}
            errors = registry.validate_registry(data)
            self.assertTrue(any("checkpoints.write" in e and "requires" in e for e in errors))
            self.assertTrue(any("checkpoints.readback" in e and "requires" in e for e in errors))

    def test_network_must_have_explicit_non_synthetic_and_site_origin(self):
        for change in ("missing_flag", "mock", "foreign"):
            data = fixture()
            official_network(data)
            evidence = data["evidence"][0]
            if change == "missing_flag":
                del evidence["context"]["synthetic"]
            elif change == "mock":
                evidence["context"]["mock"] = True
            else:
                evidence["source"]["url"] = "https://unrelated.example/like"
            data["capabilities"][0]["checkpoints"]["write"] = {"status": "passed", "evidenceRefs": ["code.like"], "note": "Policy fixture"}
            self.assertTrue(any("checkpoints.write" in e for e in registry.validate_registry(data)))

    def test_valid_network_does_not_implicitly_accept_other_checkpoints(self):
        data = fixture()
        official_network(data)
        data["contracts"][0]["claimLevel"] = "observed_runtime"
        data["capabilities"][0]["checkpoints"]["write"] = {"status": "passed", "evidenceRefs": ["code.like"], "note": "Policy fixture only"}
        self.assertEqual(registry.validate_registry(data), [])
        self.assertEqual(data["capabilities"][0]["checkpoints"]["readback"]["status"], "unknown")

    def test_original_website_ui_cycle_is_protocol_evidence_not_native_acceptance(self):
        data = fixture()
        official_network(data)
        data["evidence"][0]["context"].update({"nativeAdapterExecuted": False, "scope": "original_site_ui_only"})
        data["contracts"][0]["claimLevel"] = "observed_runtime"
        point = data["capabilities"][0]["checkpoints"]["write"]
        point.update({"status": "observed", "evidenceRefs": ["code.like"], "note": "Original UI only"})
        self.assertEqual(registry.validate_registry(data), [])
        for checkpoint in ("write", "readback"):
            data["capabilities"][0]["checkpoints"][checkpoint] = {"status": "passed", "evidenceRefs": ["code.like"], "note": "Incorrect promotion"}
        self.assertTrue(any("nativeAdapterExecuted=true" in e for e in registry.validate_registry(data)))

    def test_actual_host_javascript_runtime_is_real_but_not_complete_native_acceptance(self):
        data = fixture()
        official_network(data)
        data["evidence"][0]["context"].update({
            "actualHostJavaScriptExecuted": True, "nativeAdapterExecuted": False,
            "scope": "actual_host_javascript_only", "dartControllerExecuted": False,
            "iosPlatformBridgeExecuted": False, "deviceUiExecuted": False,
        })
        data["contracts"][0]["claimLevel"] = "observed_runtime"
        data["contracts"][0]["scope"] = "actual_host_javascript_only"
        data["runtimeProtocolObservations"] = [{
            "evidenceRef": "code.like", "scope": "actual_host_javascript_only",
            "actualHostJavaScriptExecuted": True, "nativeAdapterExecuted": False,
        }]
        data["capabilities"][0]["checkpoints"]["readback"] = {"status": "observed", "evidenceRefs": ["code.like"], "note": "Actual JS GET"}
        self.assertEqual(registry.validate_registry(data), [])
        self.assertIn("actual_host_javascript_only", registry.render_markdown(data))
        bad = copy.deepcopy(data)
        bad["runtimeProtocolObservations"][0]["actualHostJavaScriptExecuted"] = False
        self.assertTrue(any("must be boolean and match" in e for e in registry.validate_registry(bad)))
        data["capabilities"][0]["checkpoints"]["readback"]["status"] = "passed"
        self.assertTrue(any("nativeAdapterExecuted=true" in e for e in registry.validate_registry(data)))

    def test_return_device_needs_device_evidence(self):
        data = fixture()
        official_network(data)
        data["capabilities"][0]["checkpoints"]["return_device"] = {"status": "passed", "evidenceRefs": ["code.like"], "note": "Policy fixture"}
        self.assertTrue(any("device screenshot" in e for e in registry.validate_registry(data)))
        data["evidence"][0]["kind"] = "user_diagnostic"
        self.assertEqual(registry.validate_registry(data), [])

    def test_bad_references_duplicates_and_missing_fields_are_reported(self):
        data = fixture()
        data["evidence"].append(copy.deepcopy(data["evidence"][0]))
        data["capabilities"][0]["entityTypes"] = ["missing"]
        data["contracts"][0]["sourceRefs"] = ["missing"]
        del data["capabilities"][0]["checkpoints"]["write"]
        data["runtimeProtocolObservations"] = [{"evidenceRef": "missing", "scope": "unverified"}]
        data["implementationCorrectionChecklist"] = [{"evidenceRefs": ["missing"]}]
        data["implementationSourceArchives"] = [{
            "evidenceRef": "missing", "sourceSha256": "0" * 64,
            "sourceArchive": "/archive/source.dart", "bodySha256": "1" * 64,
            "bodyArchive": "/archive/body.js",
        }]
        errors = registry.validate_registry(data)
        for expected in ("duplicate id", "unknown entities reference", "unknown evidence reference", "missing write"):
            self.assertTrue(any(expected in e for e in errors), errors)
        self.assertTrue(any("runtimeProtocolObservations[0].evidenceRef" in e for e in errors))
        self.assertTrue(any("implementationCorrectionChecklist[0].evidenceRefs" in e for e in errors))
        self.assertTrue(any("implementationSourceArchives[0].evidenceRef" in e for e in errors))

    def test_wrong_nested_types_return_errors_without_crashing(self):
        data = fixture()
        data["evidence"][0]["kind"] = []
        data["evidence"][0]["context"] = None
        data["contracts"][0]["claimLevel"] = {}
        data["capabilities"][0]["checkpoints"]["write"]["status"] = []
        self.assertGreaterEqual(len(registry.validate_registry(data)), 4)

    def test_export_is_queryable_local_and_does_not_overwrite_by_default(self):
        data = fixture()
        data["capabilities"][0]["scope"] = {"requiredForGoal": False, "note": "Optional test branch"}
        data["implementationCorrectionChecklist"] = [{"id": "fix.test", "status": "source_only"}]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "registry.sqlite"
            registry.export_sqlite(data, output)
            with sqlite3.connect(output) as conn:
                self.assertEqual(conn.execute("SELECT id,write,readback FROM capability_status").fetchall(), [("video.like", "unknown", "unknown")])
                self.assertEqual(conn.execute("SELECT id FROM unverified_contracts").fetchall(), [("like.candidate",)])
                self.assertEqual(conn.execute("SELECT json_extract(request_json,'$.fields[1].name') FROM contracts").fetchone()[0], "status")
                self.assertEqual(conn.execute("SELECT required_for_goal FROM capability_status").fetchone()[0], 0)
                self.assertEqual(json.loads(conn.execute("SELECT record_json FROM capabilities").fetchone()[0]), data["capabilities"][0])
                self.assertEqual(json.loads(conn.execute("SELECT value_json FROM metadata WHERE key='implementationCorrectionChecklist'").fetchone()[0]), data["implementationCorrectionChecklist"])
            before = output.read_bytes()
            with self.assertRaises(FileExistsError):
                registry.export_sqlite(data, output)
            self.assertEqual(output.read_bytes(), before)
            bad = copy.deepcopy(data)
            bad["contracts"][0]["claimLevel"] = "observed_runtime"
            with self.assertRaises(ValueError):
                registry.export_sqlite(bad, output, force=True)
            self.assertEqual(output.read_bytes(), before)

    def test_cli_can_run_from_another_directory_and_both_registry_positions(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "registry.json"
            source.write_text(json.dumps(fixture()))
            for args in (("--registry", str(source), "validate"), ("list", "--area", "video", "--registry", str(source)), ("show", "video.like", "--registry", str(source))):
                result = subprocess.run([sys.executable, str(SCRIPT), *args], cwd=directory, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_render_keeps_all_capabilities_contracts_and_independent_unknowns(self):
        data = fixture()
        data["capabilities"][0]["implementationStatus"] = "source_phase_only_pending_native_acceptance"
        data["evidence"][0]["source"]["sha256"] = "0" * 64
        data["implementationSourceArchives"] = [{
            "evidenceRef": "code.like", "sourceSha256": "0" * 64,
            "sourceArchive": "/archive/source.dart", "bodySha256": "1" * 64,
            "bodyArchive": "/archive/body.js",
        }]
        markdown = registry.render_markdown(data)
        for capability in data["capabilities"]:
            self.assertIn("## " + capability["id"], markdown)
        for contract in data["contracts"]:
            self.assertIn(contract["id"], markdown)
        self.assertIn("unknown", markdown)
        self.assertIn("source_phase_only_pending_native_acceptance", markdown)
        self.assertIn("lib/site.dart:1", markdown)
        self.assertIn("/archive/source.dart", markdown)
        bad_archive = copy.deepcopy(data)
        bad_archive["implementationSourceArchives"][0]["sourceSha256"] = "2" * 64
        self.assertTrue(any("historical evidence source hash" in e for e in registry.validate_registry(bad_archive)))
        bad = copy.deepcopy(data)
        bad["contracts"][0]["supersededBy"] = ["missing"]
        with self.assertRaises(ValueError):
            registry.render_markdown(bad)


if __name__ == "__main__":
    unittest.main()
