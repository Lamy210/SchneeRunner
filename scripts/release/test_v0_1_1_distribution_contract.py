from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
APP_DELEGATE = REPO_ROOT / "Sources/SchneeRunnerApp/AppDelegate.swift"
STARTUP_LOADER = REPO_ROOT / "Sources/SchneeRunnerApp/StartupCharacterLoader.swift"
PUBLISHER = REPO_ROOT / ".github/workflows/release-publisher.yml"
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
ASSET_ROOT = REPO_ROOT / "Resources/BuiltInCharacters/YukihanaLamy"
RESOURCE_PATH = "Contents/Resources/BuiltInCharacters/YukihanaLamy"


class V011DistributionContractTests(unittest.TestCase):
    def test_bundled_walk_cycle_contains_four_real_ordered_png_frames(self) -> None:
        expected = [ASSET_ROOT / f"walk_{index}.png" for index in range(1, 5)]
        for path in expected:
            with self.subTest(path=path.name):
                self.assertTrue(path.is_file(), f"missing bundled walk-cycle frame: {path}")
                self.assertGreater(
                    path.stat().st_size,
                    100_000,
                    f"bundled walk-cycle frame is unexpectedly small: {path}",
                )

    def test_release_build_copies_bundled_character_into_app_resources(self) -> None:
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("Resources/BuiltInCharacters/YukihanaLamy", text)
        self.assertIn(RESOURCE_PATH, text)

    def test_release_verifier_checks_bundled_character_inside_mounted_dmg(self) -> None:
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn(RESOURCE_PATH, text)
        self.assertIn("for frame in 1 2 3 4", text)
        self.assertIn('"walk_${frame}.png"', text)

    def test_launch_selection_isolated_from_app_delegate(self) -> None:
        self.assertTrue(STARTUP_LOADER.is_file(), "missing startup character loader")
        app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
        self.assertIn("restoreInitialCharacter()", app_delegate)
        self.assertLessEqual(len(app_delegate.splitlines()), 500)

    def test_normal_release_publisher_requires_signing_and_notarization(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn("Require signing identity configuration", text)
        self.assertIn("sign_release: true", text)
        self.assertIn("signing_identity: ${{ vars.MACOS_SIGNING_IDENTITY }}", text)
        self.assertNotIn("sign_release: false", text)


if __name__ == "__main__":
    unittest.main()
