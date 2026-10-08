from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github/workflows/bootstrap-v0.1.1-release.yml"
README = REPO_ROOT / "README.md"
PUBLISHER = REPO_ROOT / "scripts/release/publish-bootstrap-release.sh"


class BootstrapV011SignedReleaseContractTests(unittest.TestCase):
    def workflow_text(self) -> str:
        self.assertTrue(WORKFLOW.is_file(), f"missing signed bootstrap workflow: {WORKFLOW}")
        return WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_is_trusted_main_only_and_exactly_v0_1_1(self) -> None:
        text = self.workflow_text()
        self.assertIn("name: Bootstrap v0.1.1 Signed Release", text)
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

    def test_workflow_requires_signed_notarized_gatekeeper_verified_distribution(self) -> None:
        text = self.workflow_text()
        required = (
            "environment: release",
            "Require signing identity configuration",
            "MACOS_SIGNING_IDENTITY",
            "scripts/release/import-certificate.sh",
            "scripts/release/sign-app.sh",
            "scripts/release/create-dmg.sh",
            "codesign --force --timestamp",
            "scripts/release/notarize.sh",
            "scripts/release/verify-release.sh",
            "RELEASE_SIGNED: true",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, text)
        self.assertNotIn("RELEASE_SIGNED: false", text)

    def test_apple_credentials_are_isolated_from_repository_write_job(self) -> None:
        text = self.workflow_text()
        sign_start = text.find("  sign:\n")
        publish_start = text.find("  publish:\n")
        self.assertGreaterEqual(sign_start, 0)
        self.assertGreater(publish_start, sign_start)
        sign_block = text[sign_start:publish_start]
        publish_block = text[publish_start:]

        self.assertIn("environment: release", sign_block)
        self.assertIn("contents: read", sign_block)
        self.assertNotIn("contents: write", sign_block)
        self.assertIn("contents: write", publish_block)
        for credential in (
            "MACOS_CERTIFICATE_P12_BASE64",
            "MACOS_CERTIFICATE_PASSWORD",
            "APP_STORE_CONNECT_API_KEY_P8",
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
        ):
            with self.subTest(credential=credential):
                self.assertIn(credential, sign_block)
                self.assertNotIn(credential, publish_block)

    def test_publication_happens_only_after_notarization_and_signed_verification(self) -> None:
        text = self.workflow_text()
        sign = text.find("      - name: Sign application\n")
        notarize = text.find("      - name: Notarize and staple\n")
        verify = text.find("      - name: Verify signed distribution\n")
        rebind = text.find("      - name: Rebind main immediately before publication\n")
        publish = text.find("      - name: Create immutable v0.1.1 tag and GitHub Release\n")
        self.assertGreaterEqual(sign, 0)
        self.assertGreater(notarize, sign)
        self.assertGreater(verify, notarize)
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

    def test_readme_points_users_away_from_unsigned_v0_1_0(self) -> None:
        text = README.read_text(encoding="utf-8")
        self.assertIn("releases/latest", text)
        self.assertIn("v0.1.0", text)
        self.assertIn("do not use", text.lower())
        self.assertIn("signed", text.lower())
        self.assertIn("notarized", text.lower())
        self.assertIn("unofficial", text.lower())
        self.assertIn("COVER", text)


if __name__ == "__main__":
    unittest.main()
