from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
SMOKE_SCRIPT = REPO_ROOT / "scripts/release/smoke-launch-app.sh"
SMOKE_HELPER = REPO_ROOT / "scripts/release/smoke-launch-app.swift"
BUILD_SCRIPT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
LAUNCH_TRACE = REPO_ROOT / "Sources/SchneeRunnerApp/LaunchTrace.swift"


class PackagedAppLaunchSmokeContractTests(unittest.TestCase):
    def test_release_verifier_launch_smokes_source_and_mounted_apps(self) -> None:
        self.assertTrue(SMOKE_SCRIPT.is_file(), f"missing launch smoke script: {SMOKE_SCRIPT}")
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('bash "${SCRIPT_DIR}/smoke-launch-app.sh"', text)
        self.assertIn('APP_PATH="${APP_PATH}"', text)
        self.assertIn('APP_PATH="${mounted_app}"', text)

    def test_launch_smoke_delegates_to_nsworkspace_helper(self) -> None:
        self.assertTrue(SMOKE_SCRIPT.is_file(), f"missing launch smoke script: {SMOKE_SCRIPT}")
        self.assertTrue(SMOKE_HELPER.is_file(), f"missing launch smoke helper: {SMOKE_HELPER}")
        shell_text = SMOKE_SCRIPT.read_text(encoding="utf-8")
        helper_text = SMOKE_HELPER.read_text(encoding="utf-8")

        self.assertIn('xcrun swift "${SCRIPT_DIR}/smoke-launch-app.swift"', shell_text)
        self.assertIn("NSWorkspace.shared.openApplication", helper_text)
        self.assertIn("createsNewApplicationInstance = true", helper_text)
        self.assertIn("allowsRunningApplicationSubstitution = false", helper_text)
        self.assertIn("processIdentifier", helper_text)
        self.assertIn("isTerminated", helper_text)
        self.assertNotIn('/usr/bin/open -n -W "${APP_PATH}"', shell_text)
        self.assertNotIn(
            '"${executable_path}" >"${log_path}" 2>&1 &',
            shell_text,
        )

    def test_launch_smoke_captures_app_startup_trace_on_early_exit(self) -> None:
        helper_text = SMOKE_HELPER.read_text(encoding="utf-8")
        trace_text = LAUNCH_TRACE.read_text(encoding="utf-8")

        self.assertIn('configuration.environment["SCHNEERUNNER_LAUNCH_TRACE"] = "1"', helper_text)
        self.assertIn('configuration.environment["SCHNEERUNNER_LAUNCH_TRACE_FILE"]', helper_text)
        self.assertIn("Launch trace:", helper_text)
        self.assertIn('"SCHNEERUNNER_LAUNCH_TRACE_FILE"', trace_text)
        self.assertIn("FileHandle(forWritingTo:", trace_text)

    def test_unsigned_release_bundle_explicitly_disables_system_notifications(self) -> None:
        text = BUILD_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("<key>SchneeRunnerSystemNotificationsEnabled</key>", text)
        self.assertIn("<false/>", text)


if __name__ == "__main__":
    unittest.main()
