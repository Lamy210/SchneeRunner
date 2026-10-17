from __future__ import annotations

from pathlib import Path
import plistlib
import re
from tempfile import TemporaryDirectory
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBLISHER = REPO_ROOT / ".github/workflows/release-publisher.yml"
PUBLISHER_EXAMPLE = REPO_ROOT / "examples/app-release-publisher.yml"
REUSABLE_RELEASE = REPO_ROOT / ".github/workflows/reusable-macos-release.yml"
SCHNEERUNNER_CI = REPO_ROOT / ".github/workflows/schnee-runner-ci.yml"
ENTITLEMENTS = REPO_ROOT / "SchneeRunner.entitlements"
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
RELEASE_DOC = REPO_ROOT / "docs/RELEASE.md"
SETUP_DOC = REPO_ROOT / "docs/SETUP.md"
SECRETS_DOC = REPO_ROOT / "docs/SECRETS.md"
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


def release_workflow_files(workflows_dir: Path) -> tuple[Path, ...]:
    return tuple(
        sorted(
            path
            for path in workflows_dir.iterdir()
            if path.is_file() and path.suffix in {".yml", ".yaml"}
        )
    )


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

    def test_schneerunner_signed_release_uses_minimal_app_sandbox_entitlements(self) -> None:
        publisher = PUBLISHER.read_text(encoding="utf-8")

        self.assertIn("entitlements_path: SchneeRunner.entitlements", publisher)
        self.assertTrue(ENTITLEMENTS.is_file(), "missing SchneeRunner.entitlements")
        entitlements = plistlib.loads(ENTITLEMENTS.read_bytes())
        self.assertEqual(
            {
                "com.apple.security.app-sandbox": True,
                "com.apple.security.files.user-selected.read-write": True,
            },
            entitlements,
        )

    def test_ci_launch_smoke_exercises_ad_hoc_signed_sandbox_bundle(self) -> None:
        workflow = SCHNEERUNNER_CI.read_text(encoding="utf-8")
        ordered_steps = (
            "Build release bundle smoke artifact",
            "Ad-hoc sign sandboxed release bundle",
            "Verify sandboxed release signature",
            "Extract sandboxed release entitlements",
            "Verify sandboxed release entitlements",
            "Launch release bundle smoke artifact",
        )
        markers = [f"      - name: {name}\n" for name in ordered_steps]

        for marker in markers:
            self.assertIn(marker, workflow)
        for previous, following in zip(markers, markers[1:]):
            self.assertLess(workflow.index(previous), workflow.index(following))

        sign = step_block(workflow, "Ad-hoc sign sandboxed release bundle")
        verify_signature = step_block(workflow, "Verify sandboxed release signature")
        extract = step_block(workflow, "Extract sandboxed release entitlements")
        verify_entitlements = step_block(workflow, "Verify sandboxed release entitlements")
        self.assertIn(
            "codesign --force --sign - --entitlements SchneeRunner.entitlements build/SchneeRunner.app",
            sign,
        )
        self.assertIn(
            "codesign --verify --deep --strict build/SchneeRunner.app",
            verify_signature,
        )
        self.assertIn("codesign --display --entitlements", extract)
        self.assertIn("build/actual-entitlements.plist", extract)
        self.assertIn("/usr/bin/python3 - <<'PY'", verify_entitlements)
        self.assertIn("import plistlib", verify_entitlements)
        self.assertIn('"com.apple.security.app-sandbox": True', verify_entitlements)
        self.assertIn(
            '"com.apple.security.files.user-selected.read-write": True',
            verify_entitlements,
        )
        self.assertIn("entitlements.get(key)", verify_entitlements)
        self.assertNotIn("plutil -extract", verify_entitlements)

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

    def test_copyable_publisher_example_uses_same_signed_stable_configuration(self) -> None:
        example = PUBLISHER_EXAMPLE.read_text(encoding="utf-8")
        validate = job_block(example, "validate")
        publish = job_block(example, "sign-and-publish")

        self.assertIn("Require signing identity configuration", validate)
        self.assertIn(
            "MACOS_SIGNING_IDENTITY: ${{ vars.MACOS_SIGNING_IDENTITY }}",
            validate,
        )
        self.assertIn("MACOS_SIGNING_IDENTITY//[[:space:]]/", validate)
        self.assertIn("sign_release: true", publish)
        self.assertIn(
            "signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}",
            publish,
        )
        self.assertNotIn(
            'signing_identity: "Developer ID Application: Example Developer (TEAMID)"',
            publish,
        )

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

    def test_reusable_policy_rejects_signed_mode_without_signing_identity(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        policy = job_block(text, "policy")

        self.assertIn("SIGNING_IDENTITY: ${{ inputs.signing_identity }}", policy)
        self.assertIn(
            '[[ "${SIGN_RELEASE}" == "true" && -z "${SIGNING_IDENTITY//[[:space:]]/}" ]]',
            policy,
        )
        self.assertIn(
            "Signed release execution requires a non-blank signing identity.",
            policy,
        )

    def test_imported_certificate_identity_must_match_configured_identity_before_signing(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        binding = step_block(text, "Verify imported signing identity")
        app_signing = step_block(text, "Sign application")
        dmg_signing = step_block(text, "Sign DMG")

        self.assertTrue(binding, "missing imported signing identity binding step")
        self.assertIn(
            "EXPECTED_SIGNING_IDENTITY: ${{ inputs.signing_identity }}",
            binding,
        )
        self.assertIn(
            "IMPORTED_SIGNING_IDENTITY: ${{ steps.certificate.outputs.signing-identity }}",
            binding,
        )
        self.assertIn(
            '[[ "${IMPORTED_SIGNING_IDENTITY}" != "${EXPECTED_SIGNING_IDENTITY}" ]]',
            binding,
        )
        self.assertIn("Configured signing identity does not match imported certificate identity.", binding)
        self.assertLess(text.index("- name: Import Developer ID certificate"), text.index("- name: Verify imported signing identity"))
        self.assertLess(text.index("- name: Verify imported signing identity"), text.index("- name: Sign application"))
        for signing in (app_signing, dmg_signing):
            self.assertIn(
                "SIGNING_IDENTITY: ${{ steps.certificate.outputs.signing-identity }}",
                signing,
            )
            self.assertNotIn("SIGNING_IDENTITY: ${{ inputs.signing_identity }}", signing)

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

    def test_signing_identity_is_documented_as_repository_level_variable(self) -> None:
        setup = SETUP_DOC.read_text(encoding="utf-8")
        secrets = SECRETS_DOC.read_text(encoding="utf-8")

        self.assertIn("repository-level GitHub Actions variable", setup)
        self.assertNotIn("trusted repository/environment configuration", setup)
        self.assertIn("repository-level Actions variable", secrets)
        self.assertIn("publisher validation job does not enter the `release` Environment", secrets)
        self.assertIn("must exactly match the Developer ID Application identity in the imported certificate", setup)
        self.assertIn("must exactly match the Developer ID Application identity imported from the certificate", secrets)

    def test_release_workflow_scan_covers_all_supported_extensions(self) -> None:
        with TemporaryDirectory() as temp_dir:
            workflows_dir = Path(temp_dir)
            (workflows_dir / "release-a.yml").write_text("name: a\n", encoding="utf-8")
            (workflows_dir / "release-b.yaml").write_text("name: b\n", encoding="utf-8")
            (workflows_dir / "README.md").write_text("ignore\n", encoding="utf-8")

            self.assertEqual(
                {"release-a.yml", "release-b.yaml"},
                {path.name for path in release_workflow_files(workflows_dir)},
            )

    def test_historical_bootstrap_publishers_are_retired(self) -> None:
        for workflow in BOOTSTRAP_WORKFLOWS:
            with self.subTest(workflow=workflow.name):
                self.assertFalse(workflow.exists(), f"retired workflow still exists: {workflow}")

        workflows_dir = REPO_ROOT / ".github/workflows"
        for workflow in release_workflow_files(workflows_dir):
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
