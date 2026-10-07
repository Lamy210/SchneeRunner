from __future__ import annotations

from pathlib import Path
import re
import unittest

from scripts.release.test_bootstrap_v0_1_0_release_contract import (
    BootstrapV010ReleaseContractTests,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBLISHER = REPO_ROOT / ".github/workflows/release-publisher.yml"
REUSABLE_RELEASE = REPO_ROOT / ".github/workflows/reusable-macos-release.yml"
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"


def step_block(text: str, step_name: str) -> str:
    marker = f"      - name: {step_name}\n"
    start = text.find(marker)
    if start < 0:
        return ""
    match = re.search(r"(?m)^      - name: ", text[start + len(marker) :])
    if match is None:
        return text[start:]
    return text[start : start + len(marker) + match.start()]


class UnsignedReleaseWorkflowContractTests(unittest.TestCase):
    def test_schneerunner_publisher_requires_signed_release(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn("sign_release: true", text)
        self.assertIn("signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}", text)
        self.assertNotIn("sign_release: false", text)
        self.assertIn("publish_github_release: true", text)

    def test_reusable_release_keeps_signed_mode_as_default(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        self.assertRegex(
            text,
            r"(?ms)^      sign_release:\n"
            r"        description: .*\n"
            r"        required: false\n"
            r"        default: true\n"
            r"        type: boolean$",
        )
        self.assertRegex(
            text,
            r"(?ms)^      signing_identity:\n"
            r"        description: .*\n"
            r"        required: false\n"
            r"        default: \"\"\n"
            r"        type: string$",
        )

    def test_signing_and_notarization_steps_are_guarded_by_release_mode(self) -> None:
        text = REUSABLE_RELEASE.read_text(encoding="utf-8")
        for step_name in (
            "Import Developer ID certificate",
            "Sign application",
            "Sign DMG",
            "Notarize and staple",
        ):
            with self.subTest(step=step_name):
                block = step_block(text, step_name)
                self.assertTrue(block, f"missing release step: {step_name}")
                self.assertIn("if: ${{ inputs.sign_release }}", block)

        create_dmg = step_block(text, "Create DMG")
        self.assertTrue(create_dmg)
        self.assertNotIn("if: ${{ inputs.sign_release }}", create_dmg)

        verify = step_block(text, "Verify release")
        self.assertIn("RELEASE_SIGNED: ${{ inputs.sign_release }}", verify)

    def test_release_verifier_supports_unsigned_distribution_checks(self) -> None:
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('RELEASE_SIGNED="${RELEASE_SIGNED:-true}"', text)
        self.assertIn('if [[ "${RELEASE_SIGNED}" == "true" ]]; then', text)
        self.assertIn('hdiutil verify "${DMG_PATH}"', text)
        self.assertIn('bash "${SCRIPT_DIR}/verify-app-executable.sh"', text)
        self.assertIn('shasum -a 256 "$(basename "${DMG_PATH}")"', text)


if __name__ == "__main__":
    unittest.main()
