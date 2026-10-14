from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest

from scripts.release.fetch_actions_artifact import fetch_with_retry


class FetchActionsArtifactTests(unittest.TestCase):
    def test_transient_api_failure_is_retried_without_publishing_partial_output(self) -> None:
        calls: list[list[str]] = []
        sleeps: list[float] = []
        results = iter(
            [
                subprocess.CompletedProcess(
                    args=[],
                    returncode=1,
                    stdout=b"partial-response",
                    stderr=b"gh: Not Found (HTTP 404)\n",
                ),
                subprocess.CompletedProcess(
                    args=[],
                    returncode=0,
                    stdout=b'{"digest":"sha256:abc"}\n',
                    stderr=b"",
                ),
            ]
        )

        def runner(command: list[str]) -> subprocess.CompletedProcess[bytes]:
            calls.append(command)
            return next(results)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.json"
            fetch_with_retry(
                "/repos/example/project/actions/artifacts/123",
                output,
                attempts=3,
                delay_seconds=0.25,
                runner=runner,
                sleeper=sleeps.append,
            )

            self.assertEqual(output.read_bytes(), b'{"digest":"sha256:abc"}\n')

        self.assertEqual(
            calls,
            [
                ["gh", "api", "/repos/example/project/actions/artifacts/123"],
                ["gh", "api", "/repos/example/project/actions/artifacts/123"],
            ],
        )
        self.assertEqual(sleeps, [0.25])

    def test_retry_exhaustion_fails_closed_and_removes_stale_output(self) -> None:
        sleeps: list[float] = []

        def runner(command: list[str]) -> subprocess.CompletedProcess[bytes]:
            return subprocess.CompletedProcess(
                args=command,
                returncode=1,
                stdout=b"partial-response",
                stderr=b"gh: Not Found (HTTP 404)\n",
            )

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.zip"
            output.write_bytes(b"stale")

            with self.assertRaisesRegex(RuntimeError, "after 3 attempts"):
                fetch_with_retry(
                    "/repos/example/project/actions/artifacts/123/zip",
                    output,
                    attempts=3,
                    delay_seconds=0.5,
                    runner=runner,
                    sleeper=sleeps.append,
                )

            self.assertFalse(output.exists())

        self.assertEqual(sleeps, [0.5, 1.0])

    def test_attempt_count_must_be_positive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact.json"
            with self.assertRaisesRegex(ValueError, "attempts must be positive"):
                fetch_with_retry(
                    "/repos/example/project/actions/artifacts/123",
                    output,
                    attempts=0,
                )


if __name__ == "__main__":
    unittest.main()
