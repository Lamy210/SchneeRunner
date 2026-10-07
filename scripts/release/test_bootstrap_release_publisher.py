from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"
WRITER = REPO_ROOT / "scripts/release/write-bootstrap-release-provenance.py"
SOURCE_SHA = "1" * 40
NEXT_SHA = "2" * 40
REPOSITORY = "Lamy210/SchneeRunner"
REPOSITORY_ID = "1391190258"
TAG = "v0.1.0"
VERSION = "0.1.0"
DMG_NAME = "SchneeRunner-0.1.0.dmg"


FAKE_GH = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import sys

state_path = Path(os.environ["FAKE_GH_STATE"])
remote_dir = Path(os.environ["FAKE_GH_REMOTE"])
repository = os.environ["GITHUB_REPOSITORY"]
repository_id = int(os.environ["EXPECTED_REPOSITORY_ID"])
tag = os.environ["RELEASE_TAG"]
args = sys.argv[1:]
state = json.loads(state_path.read_text())


def save():
    state_path.write_text(json.dumps(state, sort_keys=True))


if not args:
    raise SystemExit(90)

if args[0] == "api":
    if args[1:2] == [f"repos/{repository}"]:
        print(json.dumps({"id": repository_id, "full_name": repository}))
        raise SystemExit(0)

    if f"repos/{repository}/git/matching-refs/tags/{tag}" in args:
        refs = []
        if state.get("tag_sha"):
            refs.append({"ref": f"refs/tags/{tag}", "object": {"type": "commit", "sha": state["tag_sha"]}})
        print(json.dumps(refs))
        raise SystemExit(0)

    if f"repos/{repository}/releases?per_page=100" in args:
        if state.get("release_exists"):
            print(tag)
        raise SystemExit(0)

    if "--method" in args and "POST" in args and f"repos/{repository}/git/refs" in args:
        sha_arg = next((value for value in args if value.startswith("sha=")), None)
        if sha_arg is None:
            raise SystemExit(91)
        requested_sha = sha_arg.split("=", 1)[1]
        if state.get("tag_sha") and state["tag_sha"] != requested_sha:
            raise SystemExit(1)
        state["tag_sha"] = requested_sha
        save()
        print(json.dumps({"ref": f"refs/tags/{tag}", "object": {"type": "commit", "sha": requested_sha}}))
        raise SystemExit(0)

    raise SystemExit(92)

if args[:2] == ["release", "create"]:
    remote_dir.mkdir(parents=True, exist_ok=True)
    for value in args[3:]:
        path = Path(value)
        if path.is_file():
            shutil.copy2(path, remote_dir / path.name)
    state["release_exists"] = True
    save()
    raise SystemExit(0)

if args[:2] == ["release", "view"]:
    if not state.get("release_exists"):
        raise SystemExit(1)
    assets = [{"name": path.name} for path in sorted(remote_dir.iterdir()) if path.is_file()]
    print(json.dumps({"assets": assets, "isDraft": False, "isPrerelease": False, "tagName": tag}))
    raise SystemExit(0)

if args[:2] == ["release", "download"]:
    if not state.get("release_exists"):
        raise SystemExit(1)
    pattern = args[args.index("--pattern") + 1]
    destination = Path(args[args.index("--dir") + 1])
    source = remote_dir / pattern
    if not source.is_file():
        raise SystemExit(1)
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination / pattern)
    raise SystemExit(0)

raise SystemExit(93)
'''


class BootstrapReleasePublisherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.remote = self.root / "remote"
        self.remote.mkdir()
        self.state = self.root / "state.json"
        self.state.write_text(json.dumps({"tag_sha": None, "release_exists": False}))
        self.output = self.root / "github-output.txt"
        gh = self.bin / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(0o755)
        self.local = self.root / "release-output"
        self.local.mkdir()
        self.dmg = self.local / DMG_NAME
        self.dmg.write_bytes(b"bootstrap-dmg\n")
        with (self.local / f"{DMG_NAME}.sha256").open("w", encoding="utf-8") as checksum_output:
            subprocess.run(
                ["shasum", "-a", "256", self.dmg.name],
                cwd=self.local,
                check=True,
                text=True,
                stdout=checksum_output,
            )
        result = subprocess.run(
            [
                sys.executable,
                str(WRITER),
                "--repository",
                REPOSITORY,
                "--source-sha",
                SOURCE_SHA,
                "--tag",
                TAG,
                "--version",
                VERSION,
                "--workflow-run-id",
                "123",
                "--workflow-run-attempt",
                "1",
                "--dmg-path",
                str(self.dmg),
                "--output",
                str(self.local / "release-provenance.json"),
            ],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def env(self, *, source_sha: str = SOURCE_SHA) -> dict[str, str]:
        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{self.bin}:{env['PATH']}",
                "GH_TOKEN": "fake-token",
                "GITHUB_REPOSITORY": REPOSITORY,
                "EXPECTED_REPOSITORY_ID": REPOSITORY_ID,
                "SOURCE_SHA": source_sha,
                "RELEASE_TAG": TAG,
                "RELEASE_VERSION": VERSION,
                "DMG_NAME": DMG_NAME,
                "FAKE_GH_STATE": str(self.state),
                "FAKE_GH_REMOTE": str(self.remote),
                "GITHUB_OUTPUT": str(self.output),
                "RUNNER_TEMP": str(self.root),
            }
        )
        return env

    def run_publisher(self, action: str, *, source_sha: str = SOURCE_SHA) -> subprocess.CompletedProcess[str]:
        env = self.env(source_sha=source_sha)
        if action == "publish":
            env["DMG_PATH"] = str(self.dmg)
            env["RELEASE_PROVENANCE_PATH"] = str(self.local / "release-provenance.json")
        return subprocess.run(
            ["bash", str(PUBLISHER), action],
            cwd=REPO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def read_state(self) -> dict[str, object]:
        return json.loads(self.state.read_text())

    def test_preflight_requires_release_when_tag_and_release_are_absent(self) -> None:
        result = self.run_publisher("preflight")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), "release_required=true\n")
        self.assertEqual(self.read_state(), {"tag_sha": None, "release_exists": False})

    def test_preflight_fails_closed_for_partial_remote_state(self) -> None:
        for state in (
            {"tag_sha": SOURCE_SHA, "release_exists": False},
            {"tag_sha": None, "release_exists": True},
        ):
            with self.subTest(state=state):
                self.state.write_text(json.dumps(state))
                self.output.write_text("")
                result = self.run_publisher("preflight")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.output.read_text(), "")

    def test_publish_creates_exact_tag_and_three_assets_then_future_preflight_is_noop(self) -> None:
        result = self.run_publisher("publish")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.read_state(), {"tag_sha": SOURCE_SHA, "release_exists": True})
        self.assertEqual(
            {path.name for path in self.remote.iterdir()},
            {DMG_NAME, f"{DMG_NAME}.sha256", "release-provenance.json"},
        )

        self.output.write_text("")
        preflight = self.run_publisher("preflight", source_sha=NEXT_SHA)
        self.assertEqual(preflight.returncode, 0, preflight.stderr)
        self.assertEqual(self.output.read_text(), "release_required=false\n")

    def test_preflight_rejects_tampered_published_dmg(self) -> None:
        publish = self.run_publisher("publish")
        self.assertEqual(publish.returncode, 0, publish.stderr)
        (self.remote / DMG_NAME).write_bytes(b"tampered\n")
        self.output.write_text("")
        result = self.run_publisher("preflight", source_sha=NEXT_SHA)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), "")


if __name__ == "__main__":
    unittest.main()
