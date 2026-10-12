from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts/ci/audit-live-repository-settings.sh"
REPOSITORY = "Lamy210/SchneeRunner"


def canonical_document() -> dict[str, object]:
    return {
        "full_name": REPOSITORY,
        "allow_squash_merge": True,
        "allow_merge_commit": False,
        "allow_rebase_merge": False,
        "delete_branch_on_merge": True,
    }


class LiveRepositorySettingsAuditTests(unittest.TestCase):
    def run_wrapper(
        self,
        *args: str,
        document: dict[str, object] | None = None,
        github_repository: str | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            record = root / "gh-argv.jsonl"
            fixture = root / "repository.json"
            fixture.write_text(
                json.dumps(canonical_document() if document is None else document),
                encoding="utf-8",
            )
            gh = bin_dir / "gh"
            gh.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, pathlib, sys\n"
                "with pathlib.Path(os.environ['GH_STUB_RECORD']).open('a', encoding='utf-8') as handle:\n"
                "    handle.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "sys.stdout.write(pathlib.Path(os.environ['GH_STUB_FIXTURE']).read_text(encoding='utf-8'))\n",
                encoding="utf-8",
            )
            gh.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
            env["GH_STUB_RECORD"] = str(record)
            env["GH_STUB_FIXTURE"] = str(fixture)
            if github_repository is None:
                env.pop("GITHUB_REPOSITORY", None)
            else:
                env["GITHUB_REPOSITORY"] = github_repository

            result = subprocess.run(
                ["bash", str(SCRIPT), *args],
                cwd=REPO_ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )
            recorded = (
                [json.loads(line) for line in record.read_text(encoding="utf-8").splitlines()]
                if record.exists()
                else []
            )
            return result, recorded

    def test_valid_repository_uses_fixed_read_only_endpoint(self) -> None:
        result, recorded = self.run_wrapper(REPOSITORY)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(recorded), 1)
        argv = recorded[0]
        self.assertEqual(argv.count(f"repos/{REPOSITORY}"), 1)
        self.assertFalse(any(arg == "-X" or arg.startswith("-X") for arg in argv))
        self.assertFalse(any(arg == "--method" or arg.startswith("--method=") for arg in argv))
        for method in ("PATCH", "PUT", "POST", "DELETE"):
            self.assertNotIn(method, argv)

    def test_github_repository_environment_is_used_when_argument_is_absent(self) -> None:
        result, recorded = self.run_wrapper(github_repository=REPOSITORY)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(recorded), 1)
        self.assertIn(f"repos/{REPOSITORY}", recorded[0])

    def test_validator_failure_is_propagated(self) -> None:
        document = canonical_document()
        document["allow_merge_commit"] = True

        result, recorded = self.run_wrapper(REPOSITORY, document=document)

        self.assertEqual(result.returncode, 1)
        self.assertIn("allow_merge_commit", result.stderr)
        self.assertEqual(len(recorded), 1)
        self.assertIn(f"repos/{REPOSITORY}", recorded[0])

    def test_invalid_repository_inputs_are_rejected_before_gh(self) -> None:
        for repository in (
            "owner/repo/extra",
            "https://github.com/owner/repo",
            "owner%2Frepo",
        ):
            with self.subTest(repository=repository):
                result, recorded = self.run_wrapper(repository)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(recorded, [])

    def test_extra_positional_argument_is_rejected_before_gh(self) -> None:
        result, recorded = self.run_wrapper(REPOSITORY, "extra")

        self.assertEqual(result.returncode, 2)
        self.assertEqual(recorded, [])


if __name__ == "__main__":
    unittest.main()
