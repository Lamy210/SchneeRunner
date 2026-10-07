from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github/workflows/bootstrap-v0.1.0-release.yml"
README = REPO_ROOT / "README.md"
PROVENANCE_WRITER = REPO_ROOT / "scripts/release/write-bootstrap-release-provenance.py"
PROVENANCE_VERIFIER = REPO_ROOT / "scripts/release/verify-bootstrap-release-provenance.py"
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"


class BootstrapV010ReleaseContractTests(unittest.TestCase):
    def workflow_text(self) -> str:
        self.assertTrue(WORKFLOW.is_file(), f"missing bootstrap workflow: {WORKFLOW}")
        return WORKFLOW.read_text(encoding="utf-8")

    def test_bootstrap_workflow_is_trusted_main_only_and_version_pinned(self) -> None:
        text = self.workflow_text()
        self.assertIn("name: Bootstrap v0.1.0 Release", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("branches:", text)
        self.assertIn("- main", text)
        self.assertIn("RELEASE_TAG: v0.1.0", text)
        self.assertIn("RELEASE_VERSION: 0.1.0", text)
        self.assertIn("DMG_NAME: SchneeRunner-0.1.0.dmg", text)
        self.assertIn("Lamy210/SchneeRunner", text)
        self.assertIn("refs/heads/main", text)
        self.assertIn("bootstrap-v0.1.0-release", text)
        self.assertIn("cancel-in-progress: false", text)

    def test_bootstrap_reuses_release_build_and_unsigned_verification_helpers(self) -> None:
        text = self.workflow_text()
        for required in (
            "scripts/ci/build-release-artifact.sh",
            "scripts/release/package-app-artifact.sh",
            "scripts/release/extract-app-artifact.sh",
            "scripts/release/create-dmg.sh",
            "scripts/release/verify-release.sh",
            "scripts/release/write-bootstrap-release-provenance.py",
            "scripts/release/verify-bootstrap-release-provenance.py",
            "scripts/release/publish-bootstrap-release.sh",
        ):
            self.assertIn(required, text)
        self.assertIn("RELEASE_SIGNED: false", text)

    def test_bootstrap_does_not_use_apple_signing_or_notarization(self) -> None:
        text = self.workflow_text()
        for forbidden in (
            "MACOS_CERTIFICATE_P12_BASE64",
            "MACOS_CERTIFICATE_PASSWORD",
            "MACOS_SIGNING_IDENTITY",
            "APP_STORE_CONNECT_API_KEY_P8",
            "notarize.sh",
            "sign-app.sh",
            "Import Developer ID certificate",
            "Notarize and staple",
        ):
            self.assertNotIn(forbidden, text)

    def test_bootstrap_has_read_only_preflight_and_write_scoped_publisher(self) -> None:
        text = self.workflow_text()
        self.assertIn("preflight:", text)
        self.assertIn("release_required:", text)
        self.assertIn("contents: read", text)
        self.assertIn("contents: write", text)
        self.assertIn("needs.preflight.outputs.release_required == 'true'", text)

    def test_bootstrap_passes_canonical_absolute_asset_paths_to_publisher(self) -> None:
        text = self.workflow_text()
        self.assertIn(
            "DMG_PATH: ${{ github.workspace }}/release-output/${{ env.DMG_NAME }}",
            text,
        )
        self.assertIn(
            "RELEASE_PROVENANCE_PATH: ${{ github.workspace }}/release-output/release-provenance.json",
            text,
        )

    def test_bootstrap_support_files_exist(self) -> None:
        self.assertTrue(PROVENANCE_WRITER.is_file(), f"missing provenance writer: {PROVENANCE_WRITER}")
        self.assertTrue(PROVENANCE_VERIFIER.is_file(), f"missing provenance verifier: {PROVENANCE_VERIFIER}")
        self.assertTrue(PUBLISHER.is_file(), f"missing bootstrap publisher: {PUBLISHER}")

    def test_readme_exposes_stable_latest_release_download_and_unsigned_warning(self) -> None:
        text = README.read_text(encoding="utf-8")
        self.assertIn("## Download", text)
        self.assertIn("https://github.com/Lamy210/SchneeRunner/releases/latest", text)
        self.assertIn("macOS 14 or later", text)
        self.assertIn("Download the DMG", text)
        self.assertIn("Applications", text)
        self.assertIn("unsigned", text.lower())
        self.assertIn("not notarized", text.lower())


if __name__ == "__main__":
    unittest.main()
