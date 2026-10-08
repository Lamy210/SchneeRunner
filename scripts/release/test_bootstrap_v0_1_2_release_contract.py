from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github/workflows/bootstrap-v0.1.2-release.yml"
RELEASE_NOTES = REPO_ROOT / "docs/releases/v0.1.2.md"
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"


class BootstrapV012UnsignedReleaseContractTests(unittest.TestCase):
    def workflow_text(self) -> str:
        self.assertTrue(WORKFLOW.is_file(), f"missing unsigned bootstrap workflow: {WORKFLOW}")
        return WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_is_trusted_main_only_and_exactly_v0_1_2(self) -> None:
        text = self.workflow_text()
        self.assertIn("name: Bootstrap v0.1.2 Unsigned Release", text)
        self.assertIn("branches:", text)
        self.assertIn("- main", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("RELEASE_TAG: v0.1.2", text)
        self.assertIn("RELEASE_VERSION: 0.1.2", text)
        self.assertIn("DMG_NAME: SchneeRunner-0.1.2.dmg", text)
        self.assertIn("BOOTSTRAP_EXPECTED_TAG: v0.1.2", text)
        self.assertIn("BOOTSTRAP_EXPECTED_VERSION: 0.1.2", text)
        self.assertIn("BOOTSTRAP_EXPECTED_DMG: SchneeRunner-0.1.2.dmg", text)
        self.assertIn("refs/heads/main", text)
        self.assertIn("bootstrap-v0.1.2-release", text)

    def test_workflow_requires_unsigned_distribution_and_packaged_launch_verification(self) -> None:
        text = self.workflow_text()
        self.assertIn("scripts/ci/build-release-artifact.sh", text)
        self.assertIn("scripts/release/create-dmg.sh", text)
        self.assertIn("scripts/release/verify-release.sh", text)
        self.assertIn("RELEASE_SIGNED: false", text)
        self.assertIn(
            "SchneeRunnerSystemNotificationsEnabled",
            (REPO_ROOT / "scripts/ci/build-release-artifact.sh").read_text(encoding="utf-8"),
        )
        self.assertIn(
            'bash "${SCRIPT_DIR}/smoke-launch-app.sh"',
            (REPO_ROOT / "scripts/release/verify-release.sh").read_text(encoding="utf-8"),
        )

    def test_workflow_does_not_require_apple_credentials(self) -> None:
        text = self.workflow_text()
        for forbidden in (
            "environment: release",
            "MACOS_CERTIFICATE_P12_BASE64",
            "MACOS_CERTIFICATE_PASSWORD",
            "APP_STORE_CONNECT_API_KEY_P8",
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
            "RELEASE_SIGNED: true",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, text)

    def test_publication_is_after_verification_and_main_rebind(self) -> None:
        text = self.workflow_text()
        verify = text.find("      - name: Verify unsigned distribution\n")
        rebind = text.find("      - name: Rebind main immediately before publication\n")
        publish = text.find("      - name: Create immutable v0.1.2 tag and GitHub Release\n")
        self.assertGreaterEqual(verify, 0)
        self.assertGreater(rebind, verify)
        self.assertGreater(publish, rebind)

    def test_bootstrap_publisher_supports_exact_v0_1_2_identity(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn('"v0.1.2|0.1.2|SchneeRunner-0.1.2.dmg"', text)

    def test_release_notes_mark_v0_1_1_runtime_failure_and_v0_1_2_fix(self) -> None:
        self.assertTrue(RELEASE_NOTES.is_file(), f"missing release notes: {RELEASE_NOTES}")
        text = RELEASE_NOTES.read_text(encoding="utf-8").lower()
        self.assertIn("v0.1.1", text)
        self.assertIn("startup", text)
        self.assertIn("v0.1.2", text)
        self.assertIn("unsigned", text)
        self.assertIn("not notarized", text)
        self.assertIn("launch", text)


if __name__ == "__main__":
    unittest.main()
