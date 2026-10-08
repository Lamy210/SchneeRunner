from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github/workflows/bootstrap-v0.1.1-release.yml"
README = REPO_ROOT / "README.md"
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"


class BootstrapV011UnsignedReleaseContractTests(unittest.TestCase):
    def workflow_text(self) -> str:
        self.assertTrue(WORKFLOW.is_file(), f"missing unsigned bootstrap workflow: {WORKFLOW}")
        return WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_is_trusted_main_only_and_exactly_v0_1_1(self) -> None:
        text = self.workflow_text()
        self.assertIn("name: Bootstrap v0.1.1 Unsigned Release", text)
        self.assertIn("branches:", text)
        self.assertIn("- main", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("RELEASE_TAG: v0.1.1", text)
        self.assertIn("RELEASE_VERSION: 0.1.1", text)
        self.assertIn("DMG_NAME: SchneeRunner-0.1.1.dmg", text)
        self.assertIn("Lamy210/SchneeRunner", text)
        self.assertIn("refs/heads/main", text)
        self.assertIn("bootstrap-v0.1.1-release", text)
        self.assertIn("cancel-in-progress: false", text)

    def test_workflow_builds_unsigned_distribution_without_apple_credentials(self) -> None:
        text = self.workflow_text()
        for required in (
            "scripts/release/create-dmg.sh",
            "scripts/release/verify-release.sh",
            "RELEASE_SIGNED: false",
        ):
            with self.subTest(required=required):
                self.assertIn(required, text)

        for forbidden in (
            "environment: release",
            "scripts/release/import-certificate.sh",
            "scripts/release/sign-app.sh",
            "codesign --force --timestamp",
            "scripts/release/notarize.sh",
            "RELEASE_SIGNED: true",
            "MACOS_CERTIFICATE_P12_BASE64",
            "MACOS_CERTIFICATE_PASSWORD",
            "APP_STORE_CONNECT_API_KEY_P8",
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, text)

    def test_publication_happens_only_after_unsigned_verification(self) -> None:
        text = self.workflow_text()
        create_dmg = text.find("      - name: Create DMG\n")
        verify = text.find("      - name: Verify unsigned distribution\n")
        rebind = text.find("      - name: Rebind main immediately before publication\n")
        publish = text.find("      - name: Create immutable v0.1.1 tag and GitHub Release\n")
        self.assertGreaterEqual(create_dmg, 0)
        self.assertGreater(verify, create_dmg)
        self.assertGreater(rebind, verify)
        self.assertGreater(publish, rebind)

    def test_workflow_uses_generalized_bootstrap_provenance_and_publisher(self) -> None:
        text = self.workflow_text()
        for required in (
            "scripts/release/write-bootstrap-release-provenance.py",
            "scripts/release/verify-bootstrap-release-provenance.py",
            "scripts/release/publish-bootstrap-release.sh preflight",
            "scripts/release/publish-bootstrap-release.sh publish",
            "BOOTSTRAP_EXPECTED_TAG: v0.1.1",
            "BOOTSTRAP_EXPECTED_VERSION: 0.1.1",
            "BOOTSTRAP_EXPECTED_DMG: SchneeRunner-0.1.1.dmg",
        ):
            self.assertIn(required, text)
        self.assertIn(
            "DMG_PATH: ${{ github.workspace }}/release-output/${{ env.DMG_NAME }}",
            text,
        )

    def test_bootstrap_publisher_has_explicit_supported_identity_inputs(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn("BOOTSTRAP_EXPECTED_TAG", text)
        self.assertIn("BOOTSTRAP_EXPECTED_VERSION", text)
        self.assertIn("BOOTSTRAP_EXPECTED_DMG", text)
        self.assertIn("v0.1.1", text)
        self.assertIn("SchneeRunner-0.1.1.dmg", text)

    def test_readme_marks_v0_1_0_unusable_and_describes_unsigned_v0_1_1(self) -> None:
        text = README.read_text(encoding="utf-8")
        lower = text.lower()
        self.assertIn("releases/latest", text)
        self.assertIn("v0.1.0", text)
        self.assertIn("do not use", lower)
        self.assertIn("v0.1.1 is intentionally published unsigned and not notarized", lower)
        self.assertIn("damaged", lower)
        self.assertNotIn("there is no unsigned fallback for v0.1.1", lower)
        self.assertNotIn("v0.1.1 release is published only after developer id signing", lower)
        self.assertIn("COVER", text)


# Compatibility alias retained while historical imports still use the old class name.
BootstrapV011SignedReleaseContractTests = BootstrapV011UnsignedReleaseContractTests


if __name__ == "__main__":
    unittest.main()
