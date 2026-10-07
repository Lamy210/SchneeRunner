from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_SCRIPT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
APP_DELEGATE = REPO_ROOT / "Sources/SchneeRunnerApp/AppDelegate.swift"
PUBLISHER = REPO_ROOT / ".github/workflows/release-publisher.yml"
ASSET_ROOT = REPO_ROOT / "Resources/BuiltInCharacters/YukihanaLamy"


class V011DistributionContractTests(unittest.TestCase):
    def test_bundled_walk_cycle_contains_four_ordered_png_frames(self) -> None:
        expected = [ASSET_ROOT / f"walk_{index}.png" for index in range(1, 5)]
        for path in expected:
            with self.subTest(path=path.name):
                self.assertTrue(path.is_file(), f"missing bundled walk-cycle frame: {path}")

    def test_release_build_copies_bundled_character_into_app_resources(self) -> None:
        text = BUILD_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('Resources/BuiltInCharacters/YukihanaLamy', text)
        self.assertIn('Contents/Resources/BuiltInCharacters/YukihanaLamy', text)

    def test_launch_path_falls_back_to_bundled_character(self) -> None:
        text = APP_DELEGATE.read_text(encoding="utf-8")
        self.assertIn("loadBundledDefaultCharacterIfNeeded()", text)
        self.assertIn("restoreLastCharacter()", text)

    def test_normal_release_publisher_requires_signing_and_notarization(self) -> None:
        text = PUBLISHER.read_text(encoding="utf-8")
        self.assertIn("sign_release: true", text)
        self.assertNotIn("sign_release: false", text)


if __name__ == "__main__":
    unittest.main()
