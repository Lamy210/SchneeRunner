from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
RELEASE_NOTES = REPO_ROOT / "docs/releases/v0.1.2.md"
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"
WRITER = REPO_ROOT / "scripts/release/write-bootstrap-release-provenance.py"
VERIFIER = REPO_ROOT / "scripts/release/verify-bootstrap-release-provenance.py"
RESOURCE_VERIFIER = REPO_ROOT / "scripts/release/verify-app-resources.sh"
BUILD_ARTIFACT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
RELEASE_VERIFIER = REPO_ROOT / "scripts/release/verify-release.sh"


class V012HistoricalDistributionContractTests(unittest.TestCase):
    def test_v0_1_2_runtime_fix_contract_remains_in_build_and_verifier(self) -> None:
        self.assertIn(
            "SchneeRunnerSystemNotificationsEnabled",
            BUILD_ARTIFACT.read_text(encoding="utf-8"),
        )
        self.assertIn(
            'bash "${SCRIPT_DIR}/smoke-launch-app.sh"',
            RELEASE_VERIFIER.read_text(encoding="utf-8"),
        )

    def test_release_scripts_use_shared_packaged_resource_verifier(self) -> None:
        self.assertTrue(
            RESOURCE_VERIFIER.is_file(),
            f"missing packaged resource verifier: {RESOURCE_VERIFIER}",
        )
        self.assertIn(
            "verify-app-resources.sh",
            BUILD_ARTIFACT.read_text(encoding="utf-8"),
        )
        self.assertIn(
            "verify-app-resources.sh",
            RELEASE_VERIFIER.read_text(encoding="utf-8"),
        )

    def test_packaged_resource_verifier_requires_both_localizations(self) -> None:
        self.assertTrue(
            RESOURCE_VERIFIER.is_file(),
            f"missing packaged resource verifier: {RESOURCE_VERIFIER}",
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            app = self._make_resource_fixture(Path(temp_dir))

            complete = self._run_resource_verifier(app)
            self.assertEqual(complete.returncode, 0, complete.stderr)

            japanese = (
                app
                / "Contents/Resources/SchneeRunner_SchneeRunnerApp.bundle"
                / "ja.lproj/Localizable.strings"
            )
            japanese.unlink()
            missing_japanese = self._run_resource_verifier(app)
            self.assertNotEqual(missing_japanese.returncode, 0)

            japanese.parent.mkdir(parents=True, exist_ok=True)
            japanese.write_text('"probe" = "日本語";\n', encoding="utf-8")
            english = japanese.parent.parent / "en.lproj/Localizable.strings"
            english.unlink()
            missing_english = self._run_resource_verifier(app)
            self.assertNotEqual(missing_english.returncode, 0)

    def test_bootstrap_publisher_supports_exact_v0_1_2_historical_identity(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn('"v0.1.2|0.1.2|SchneeRunner-0.1.2.dmg"', text)

    def test_provenance_writer_and_verifier_support_exact_v0_1_2_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            dmg = root / "SchneeRunner-0.1.2.dmg"
            dmg.write_bytes(b"schneerunner-v0.1.2-provenance-contract\n")
            provenance = root / "release-provenance.json"
            source_sha = "3" * 40

            writer = subprocess.run(
                [
                    sys.executable,
                    str(WRITER),
                    "--repository",
                    "Lamy210/SchneeRunner",
                    "--source-sha",
                    source_sha,
                    "--tag",
                    "v0.1.2",
                    "--version",
                    "0.1.2",
                    "--workflow-run-id",
                    "125",
                    "--workflow-run-attempt",
                    "1",
                    "--dmg-path",
                    str(dmg),
                    "--output",
                    str(provenance),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(writer.returncode, 0, writer.stderr)

            document = json.loads(provenance.read_text(encoding="utf-8"))
            self.assertEqual(document["releaseMode"], "bootstrap-v0.1.2-unsigned-runtime-fix")
            self.assertEqual(document["tag"], "v0.1.2")
            self.assertEqual(document["version"], "0.1.2")
            self.assertEqual(document["dmgName"], "SchneeRunner-0.1.2.dmg")

            verifier = subprocess.run(
                [
                    sys.executable,
                    str(VERIFIER),
                    "--metadata",
                    str(provenance),
                    "--repository",
                    "Lamy210/SchneeRunner",
                    "--source-sha",
                    source_sha,
                    "--tag",
                    "v0.1.2",
                    "--version",
                    "0.1.2",
                    "--dmg-path",
                    str(dmg),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(verifier.returncode, 0, verifier.stderr)

    def test_release_notes_preserve_v0_1_2_historical_truth(self) -> None:
        self.assertTrue(RELEASE_NOTES.is_file(), f"missing release notes: {RELEASE_NOTES}")
        text = RELEASE_NOTES.read_text(encoding="utf-8").lower()
        self.assertIn("v0.1.1", text)
        self.assertIn("startup", text)
        self.assertIn("v0.1.2", text)
        self.assertIn("unsigned", text)
        self.assertIn("not notarized", text)
        self.assertIn("launch", text)

    def _make_resource_fixture(self, root: Path) -> Path:
        app = root / "SchneeRunner.app"
        bundle = app / "Contents/Resources/SchneeRunner_SchneeRunnerApp.bundle"
        character = bundle / "BuiltInCharacters/YukihanaLamy"
        character.mkdir(parents=True)
        for frame in range(1, 5):
            (character / f"walk_{frame}.png").write_bytes(b"png-fixture\n")
        for locale, value in (("en", "English"), ("ja", "日本語")):
            localization = bundle / f"{locale}.lproj/Localizable.strings"
            localization.parent.mkdir(parents=True)
            localization.write_text(f'"probe" = "{value}";\n', encoding="utf-8")
        return app

    def _run_resource_verifier(self, app: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(RESOURCE_VERIFIER)],
            env={"APP_PATH": str(app)},
            text=True,
            capture_output=True,
            check=False,
        )


if __name__ == "__main__":
    unittest.main()
