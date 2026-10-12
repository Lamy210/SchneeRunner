from __future__ import annotations

from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBLISHER = REPO_ROOT / ".github/workflows/release-publisher.yml"
REUSABLE_RELEASE = REPO_ROOT / ".github/workflows/reusable-macos-release.yml"
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
RELEASE_DOC = REPO_ROOT / "docs/RELEASE.md"
BOOTSTRAP_WORKFLOWS = (
    REPO_ROOT / ".github/workflows/bootstrap-v0.1.0-release.yml",
    REPO_ROOT / ".github/workflows/bootstrap-v0.1.1-release.yml",
    REPO_ROOT / ".github/workflows/bootstrap-v0.1.2-release.yml",
)


def job_block(text: str, job_id: str) -> str:
    marker = f"  {job_id}:\n"
    start = text.find(marker)
    if start < 0:
        return ""
    match = re.search(r"(?m)^  [A-Za-z0-9_-]+:\n", text[start + len(marker) :])
    if match is None:
        return text[start:]
    end = start + len(marker) + match.start()
    return text[start:end]


def step_block(text: str, step_name: str) -> str:
    marker = f"      - name: {step_name}\n"
    start = text.find(marker)
    if start < 0:
        return ""
    match = re.search(r"(?m)^      - name: ", text[start + len(marker) :])
    if match is None:
        return text[start:]
    end = start + len(marker) + match.start()
    return text[start:end]


class SignedStableReleaseContractTests(unittest.TestCase):
    def test_schneerunner_publisher_requires_signed_stable_release(self) -> None:
        publisher = PUBLISHER.read_text(encoding="utf-8")

        self.assertIn("Require signing identity configuration", publisher)
        self.assertIn("sign_release: true", publisher)
        self.assertIn(
            "signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}",
            publisher,
        )
        self.assertIn("publish_github_release: true", publisher)
        self.assertNotIn("sign_release: false", publisher)

    def test_publisher_rejects_blank_signing_identity(self) -> None:
        publisher = PUBLISHER.read_text(encoding="utf-8")
        block = step_block(publisher, "Require signing identity configuration")

        self.assertTrue(block, "missing signing identity configuration gate")
        self.assertIn(
            "MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}",
            block,
        )
        self.assertIn("set -euo pipefail", block)
        self.assertIn("MACOS_SIGNING_IDENTITY//[[:space:]]/", block)
        self.assertRegex(block, r"(?m)^\s+exit 1$")

    def test_reusable_release_has_secret_free_policy_job(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        policy = job_block(text, "policy")
        release = job_block(text, "release")

        self.assertTrue(policy, "missing reusable release policy job")
        self.assertNotIn("environment: release", policy)
        for token in (
            "MACOS_CERTIFICATE_P12_BASE64",
            "MACOS_CERTIFICATE_PASSWORD",
            "APP_STORE_CONNECT_API_KEY_P8",
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
        ):
            with self.subTest(token=token):
                self.assertNotIn(token, policy)
        self.assertIn("inputs.publish_github_release", policy)
        self.assertIn("inputs.sign_release", policy)
        self.assertIn(
            "Stable GitHub Release publication requires Developer ID signing and notarization.",
            policy,
        )
        self.assertIn("needs: policy", release)
        self.assertEqual(1, text.count("environment: release"))

    def test_reusable_policy_rejects_only_unsigned_publication(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        policy = job_block(text, "policy")

        self.assertIn("SIGN_RELEASE: ${{ inputs.sign_release }}", policy)
        self.assertIn(
            "PUBLISH_GITHUB_RELEASE: ${{ inputs.publish_github_release }}",
            policy,
        )
        self.assertIn(
            '[[ "${PUBLISH_GITHUB_RELEASE}" == "true" && "${SIGN_RELEASE}" != "true" ]]',
            policy,
        )
        self.assertNotIn('if [[ "${SIGN_RELEASE}" != "true" ]]; then', policy)

    def test_reusable_release_keeps_unsigned_artifact_verification_available(self) -> None:
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('RELEASE_SIGNED="${RELEASE_SIGNED:-true}"', text)
        self.assertIn('if [[ "${RELEASE_SIGNED}" == "true" ]]; then', text)
        self.assertIn('hdiutil verify "${DMG_PATH}"', text)

    def test_release_documentation_states_signed_stable_promotion_contract(self) -> None:
        text = RELEASE_DOC.read_text(encoding="utf-8")

        self.assertIn("## Signed stable publication contract", text)
        self.assertIn("unsigned intermediate artifact", text)
        self.assertIn("must not be promoted to a stable GitHub Release", text)
        self.assertIn("Developer ID signed", text)
        self.assertIn("notarized and stapled", text)
        self.assertIn("signed verification", text)
        self.assertIn("secret-free policy job", text)

    def test_historical_bootstrap_publishers_are_retired(self) -> None:
        for workflow in BOOTSTRAP_WORKFLOWS:
            with self.subTest(workflow=workflow.name):
                self.assertFalse(workflow.exists(), f"retired workflow still exists: {workflow}")

        workflows_dir = REPO_ROOT / ".github/workflows"
        for workflow in workflows_dir.glob("*.yml"):
            text = workflow.read_text(encoding="utf-8")
            with self.subTest(workflow=workflow.name):
                self.assertFalse(
                    "sign_release: false" in text
                    and "publish_github_release: true" in text,
                    f"unsigned public release path found in {workflow}",
                )
                self.assertNotIn("publish-bootstrap-release.sh publish", text)


if __name__ == "__main__":
    unittest.main()
