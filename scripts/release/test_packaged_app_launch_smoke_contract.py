from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
SMOKE_SCRIPT = REPO_ROOT / "scripts/release/smoke-launch-app.sh"


class PackagedAppLaunchSmokeContractTests(unittest.TestCase):
    def test_release_verifier_launch_smokes_source_and_mounted_apps(self) -> None:
        self.assertTrue(SMOKE_SCRIPT.is_file(), f"missing launch smoke script: {SMOKE_SCRIPT}")
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('bash "${SCRIPT_DIR}/smoke-launch-app.sh"', text)
        self.assertIn('APP_PATH="${APP_PATH}"', text)
        self.assertIn('APP_PATH="${mounted_app}"', text)

    def test_launch_smoke_requires_process_to_survive_startup_window(self) -> None:
        self.assertTrue(SMOKE_SCRIPT.is_file(), f"missing launch smoke script: {SMOKE_SCRIPT}")
        text = SMOKE_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("kill -0", text)
        self.assertIn("SchneeRunner exited during launch smoke", text)


if __name__ == "__main__":
    unittest.main()
