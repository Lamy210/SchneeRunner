from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WRITER = REPO_ROOT / "scripts/release/write-bootstrap-release-provenance.py"
VERIFIER = REPO_ROOT / "scripts/release/verify-bootstrap-release-provenance.py"


class BootstrapReleaseProvenanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.dmg = self.root / "SchneeRunner-0.1.0.dmg"
        self.dmg.write_bytes(b"schneerunner-bootstrap-dmg\n")
        self.provenance = self.root / "release-provenance.json"
        self.source_sha = "1" * 40

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def writer_command(self) -> list[str]:
        return [
            sys.executable,
            str(WRITER),
            "--repository",
            "Lamy210/SchneeRunner",
            "--source-sha",
            self.source_sha,
            "--tag",
            "v0.1.0",
            "--version",
            "0.1.0",
            "--workflow-run-id",
            "123",
            "--workflow-run-attempt",
            "2",
            "--dmg-path",
            str(self.dmg),
            "--output",
            str(self.provenance),
        ]

    def verifier_command(self) -> list[str]:
        return [
            sys.executable,
            str(VERIFIER),
            "--metadata",
            str(self.provenance),
            "--repository",
            "Lamy210/SchneeRunner",
            "--source-sha",
            self.source_sha,
            "--tag",
            "v0.1.0",
            "--version",
            "0.1.0",
            "--dmg-path",
            str(self.dmg),
        ]

    def run_command(self, command: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(command, text=True, capture_output=True, check=False)

    def write_valid_document(self) -> dict[str, object]:
        result = self.run_command(self.writer_command())
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.provenance.read_text(encoding="utf-8"))

    def test_writer_emits_exact_closed_bootstrap_schema_and_verifier_accepts_it(self) -> None:
        document = self.write_valid_document()
        self.assertEqual(
            set(document),
            {
                "schemaVersion",
                "releaseMode",
                "repository",
                "sourceSHA",
                "tag",
                "version",
                "workflowRunId",
                "workflowRunAttempt",
                "dmgName",
                "dmgSHA256",
            },
        )
        self.assertEqual(document["schemaVersion"], 1)
        self.assertEqual(document["releaseMode"], "bootstrap-v0.1.0")
        self.assertEqual(document["repository"], "Lamy210/SchneeRunner")
        self.assertEqual(document["sourceSHA"], self.source_sha)
        self.assertEqual(document["tag"], "v0.1.0")
        self.assertEqual(document["version"], "0.1.0")
        self.assertEqual(document["workflowRunId"], 123)
        self.assertEqual(document["workflowRunAttempt"], 2)
        self.assertEqual(document["dmgName"], "SchneeRunner-0.1.0.dmg")
        self.assertRegex(str(document["dmgSHA256"]), r"^sha256:[0-9a-f]{64}$")
        verify = self.run_command(self.verifier_command())
        self.assertEqual(verify.returncode, 0, verify.stderr)

    def test_writer_and_verifier_accept_exact_signed_v0_1_1_identity(self) -> None:
        dmg = self.root / "SchneeRunner-0.1.1.dmg"
        dmg.write_bytes(b"schneerunner-signed-bootstrap-dmg\n")
        provenance = self.root / "signed-release-provenance.json"
        writer = [
            sys.executable,
            str(WRITER),
            "--repository",
            "Lamy210/SchneeRunner",
            "--source-sha",
            self.source_sha,
            "--tag",
            "v0.1.1",
            "--version",
            "0.1.1",
            "--workflow-run-id",
            "124",
            "--workflow-run-attempt",
            "1",
            "--dmg-path",
            str(dmg),
            "--output",
            str(provenance),
        ]
        result = self.run_command(writer)
        self.assertEqual(result.returncode, 0, result.stderr)
        document = json.loads(provenance.read_text(encoding="utf-8"))
        self.assertEqual(document["releaseMode"], "bootstrap-v0.1.1-signed")
        self.assertEqual(document["tag"], "v0.1.1")
        self.assertEqual(document["version"], "0.1.1")
        self.assertEqual(document["dmgName"], "SchneeRunner-0.1.1.dmg")

        verifier = [
            sys.executable,
            str(VERIFIER),
            "--metadata",
            str(provenance),
            "--repository",
            "Lamy210/SchneeRunner",
            "--source-sha",
            self.source_sha,
            "--tag",
            "v0.1.1",
            "--version",
            "0.1.1",
            "--dmg-path",
            str(dmg),
        ]
        verify = self.run_command(verifier)
        self.assertEqual(verify.returncode, 0, verify.stderr)

    def test_writer_rejects_malformed_identity_and_run_values(self) -> None:
        cases = (
            ("--source-sha", "A" * 40),
            ("--source-sha", "1" * 39),
            ("--tag", "v0.1.2"),
            ("--version", "0.1.2"),
            ("--workflow-run-id", "0"),
            ("--workflow-run-attempt", "0"),
        )
        for flag, value in cases:
            with self.subTest(flag=flag, value=value):
                command = self.writer_command()
                index = command.index(flag)
                command[index + 1] = value
                result = self.run_command(command)
                self.assertNotEqual(result.returncode, 0)

    def test_writer_rejects_wrong_dmg_basename(self) -> None:
        wrong = self.root / "Other.dmg"
        wrong.write_bytes(b"wrong\n")
        command = self.writer_command()
        index = command.index("--dmg-path")
        command[index + 1] = str(wrong)
        result = self.run_command(command)
        self.assertNotEqual(result.returncode, 0)

    def test_verifier_rejects_unknown_missing_and_malformed_fields(self) -> None:
        document = self.write_valid_document()
        mutations = []
        unknown = dict(document)
        unknown["extra"] = "nope"
        mutations.append(unknown)
        missing = dict(document)
        del missing["tag"]
        mutations.append(missing)
        malformed_digest = dict(document)
        malformed_digest["dmgSHA256"] = "sha256:ABC"
        mutations.append(malformed_digest)
        boolean_run = dict(document)
        boolean_run["workflowRunId"] = True
        mutations.append(boolean_run)

        for mutated in mutations:
            with self.subTest(mutated=mutated):
                self.provenance.write_text(json.dumps(mutated), encoding="utf-8")
                result = self.run_command(self.verifier_command())
                self.assertNotEqual(result.returncode, 0)

    def test_verifier_rejects_expected_identity_drift(self) -> None:
        self.write_valid_document()
        cases = (
            ("--repository", "example/Other"),
            ("--source-sha", "2" * 40),
            ("--tag", "v0.1.1"),
            ("--version", "0.1.1"),
        )
        for flag, value in cases:
            with self.subTest(flag=flag, value=value):
                command = self.verifier_command()
                index = command.index(flag)
                command[index + 1] = value
                result = self.run_command(command)
                self.assertNotEqual(result.returncode, 0)

    def test_verifier_rejects_dmg_bytes_changed_after_attestation(self) -> None:
        self.write_valid_document()
        self.dmg.write_bytes(b"tampered\n")
        result = self.run_command(self.verifier_command())
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
