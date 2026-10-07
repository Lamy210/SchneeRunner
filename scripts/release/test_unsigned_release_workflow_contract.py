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
BUILD_SCRIPT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
DEFAULT_CHARACTER = REPO_ROOT / "Resources/DefaultCharacter"
FRAME_NAMES = (
    "lamy-walk-01.png",
    "lamy-walk-02.png",
    "lamy-walk-03.png",
    "lamy-walk-04.png",
)


def step_block(text: str, step_name: str) -> str:
    marker = f"      - name: {step_name}\n"
    start = text.find(marker)
    if start < 0:
        return ""
    match = re.search(r"(?m)^      - name: ", text[start + len(marker) :])
    if match is None:
        return text[start:]
    return text[start : start + len(marker) + match.start()]


class SignedReleaseWorkflowContractTests(unittest.TestCase):
    def test_schneerunner_publisher_requires_signed_notarized_release(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn("Require signing identity configuration", text)
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

    def test_signing_and_notarization_steps_are_enabled_by_signed_mode(self) -> None:
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

        verify = step_block(text, "Verify release")
        self.assertIn("RELEASE_SIGNED: ${{ inputs.sign_release }}", verify)

    def test_signed_release_verifier_enforces_gatekeeper_and_stapling(self) -> None:
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('codesign --verify --deep --strict --verbose=2 "${APP_PATH}"', text)
        self.assertIn('spctl --assess --type execute --verbose=4 "${APP_PATH}"', text)
        self.assertIn('xcrun stapler validate "${DMG_PATH}"', text)
        self.assertIn('hdiutil verify "${DMG_PATH}"', text)

    def test_release_build_bundles_all_default_character_frames(self) -> None:
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('Contents/Resources/DefaultCharacter', text)
        for name in FRAME_NAMES:
            with self.subTest(frame=name):
                self.assertTrue(
                    (DEFAULT_CHARACTER / name).is_file(),
                    f"missing bundled default character frame: {name}",
                )
                self.assertIn(name, text)


if __name__ == "__main__":
    unittest.main()
