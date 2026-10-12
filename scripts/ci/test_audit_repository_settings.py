from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts/ci/audit_repository_settings.py"
REPOSITORY = "Lamy210/SchneeRunner"


def canonical_document() -> dict[str, object]:
    return {
        "full_name": REPOSITORY,
        "allow_squash_merge": True,
        "allow_merge_commit": False,
        "allow_rebase_merge": False,
        "delete_branch_on_merge": True,
    }


class RepositorySettingsAuditTests(unittest.TestCase):
    def run_document(self, document: object) -> subprocess.CompletedProcess[str]:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
            json.dump(document, handle)
            path = Path(handle.name)
        try:
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(path), REPOSITORY],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
        finally:
            path.unlink(missing_ok=True)

    def test_canonical_repository_settings_pass(self) -> None:
        result = self.run_document(canonical_document())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("matches the Solo governance contract", result.stdout)

    def test_each_policy_drift_fails_with_field_name(self) -> None:
        cases = {
            "allow_squash_merge": False,
            "allow_merge_commit": True,
            "allow_rebase_merge": True,
            "delete_branch_on_merge": False,
        }
        for field, live_value in cases.items():
            with self.subTest(field=field):
                document = canonical_document()
                document[field] = live_value
                result = self.run_document(document)
                self.assertEqual(result.returncode, 1)
                self.assertIn(field, result.stderr)

    def test_multiple_policy_drift_values_are_all_reported(self) -> None:
        document = canonical_document()
        document["allow_merge_commit"] = True
        document["allow_rebase_merge"] = True
        document["delete_branch_on_merge"] = False

        result = self.run_document(document)

        self.assertEqual(result.returncode, 1)
        for field in (
            "allow_merge_commit",
            "allow_rebase_merge",
            "delete_branch_on_merge",
        ):
            self.assertIn(field, result.stderr)

    def test_missing_required_setting_fails(self) -> None:
        document = canonical_document()
        del document["allow_squash_merge"]

        result = self.run_document(document)

        self.assertEqual(result.returncode, 1)
        self.assertIn("allow_squash_merge", result.stderr)
        self.assertIn("missing", result.stderr.lower())

    def test_non_boolean_policy_values_fail_without_coercion(self) -> None:
        for live_value in ("false", 0, 1, None):
            with self.subTest(live_value=live_value):
                document = canonical_document()
                document["allow_merge_commit"] = live_value
                result = self.run_document(document)
                self.assertEqual(result.returncode, 1)
                self.assertIn("allow_merge_commit", result.stderr)
                self.assertIn("boolean", result.stderr.lower())

    def test_mismatched_repository_identity_fails(self) -> None:
        document = canonical_document()
        document["full_name"] = "owner/other"

        result = self.run_document(document)

        self.assertEqual(result.returncode, 1)
        self.assertIn(REPOSITORY, result.stderr)
        self.assertIn("owner/other", result.stderr)

    def test_invalid_json_fails_with_parse_diagnostic(self) -> None:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
            handle.write("{")
            path = Path(handle.name)
        try:
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(path), REPOSITORY],
                cwd=REPO_ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
        finally:
            path.unlink(missing_ok=True)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid JSON", result.stderr)

    def test_non_object_json_fails(self) -> None:
        for document in ([], "text", None):
            with self.subTest(document=document):
                result = self.run_document(document)
                self.assertEqual(result.returncode, 1)
                self.assertIn("JSON object", result.stderr)


if __name__ == "__main__":
    unittest.main()
