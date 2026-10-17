from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFY_RELEASE = REPO_ROOT / "scripts/release/verify-release.sh"
SMOKE_SCRIPT = REPO_ROOT / "scripts/release/smoke-launch-app.sh"
SMOKE_HELPER = REPO_ROOT / "scripts/release/smoke-launch-app.swift"
BUILD_SCRIPT = REPO_ROOT / "scripts/ci/build-release-artifact.sh"
CI_WORKFLOW = REPO_ROOT / ".github/workflows/schnee-runner-ci.yml"
LAUNCH_TRACE = REPO_ROOT / "Sources/SchneeRunnerApp/LaunchTrace.swift"


class PackagedAppLaunchSmokeContractTests(unittest.TestCase):
    def test_release_verifier_launch_smokes_source_and_mounted_apps(self) -> None:
        self.assertTrue(SMOKE_SCRIPT.is_file(), f"missing launch smoke script: {SMOKE_SCRIPT}")
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        self.assertIn('bash "${SCRIPT_DIR}/smoke-launch-app.sh"', text)
        self.assertIn('APP_PATH="${APP_PATH}"', text)
        self.assertIn('APP_PATH="${mounted_app}"', text)

    def test_signed_mounted_app_passes_gatekeeper_before_launch_smoke(self) -> None:
        text = VERIFY_RELEASE.read_text(encoding="utf-8")
        mounted_start = text.index('mounted_app="${MOUNT_POINT}/${APP_BASENAME}"')
        mounted_section = text[mounted_start:]

        codesign = 'codesign --verify --deep --strict --verbose=2 "${mounted_app}"'
        gatekeeper = 'spctl --assess --type execute --verbose=4 "${mounted_app}"'
        launch = 'APP_PATH="${mounted_app}" \\\n  bash "${SCRIPT_DIR}/smoke-launch-app.sh"'

        self.assertIn(codesign, mounted_section)
        self.assertIn(gatekeeper, mounted_section)
        self.assertIn(launch, mounted_section)
        self.assertLess(mounted_section.index(codesign), mounted_section.index(gatekeeper))
        self.assertLess(mounted_section.index(gatekeeper), mounted_section.index(launch))

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

    def test_launch_smoke_bounds_platform_failure_diagnostics(self) -> None:
        shell_text = SMOKE_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("report_launch_diagnostics", shell_text)
        self.assertIn("grep -Ei", shell_text)
        self.assertIn("sandbox|deny|container|termination|killed|crash|codesign|signature|launch", shell_text)
        self.assertIn("tail -n 40", shell_text)
        self.assertIn("grep -Eio", shell_text)
        self.assertIn("head -n 40", shell_text)
        self.assertNotIn("sed -n '1,200p'", shell_text)

    def test_ci_persists_bounded_launch_diagnostics_as_failure_artifact(self) -> None:
        workflow_text = CI_WORKFLOW.read_text(encoding="utf-8")
        shell_text = SMOKE_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("LAUNCH_DIAGNOSTICS_PATH", shell_text)
        self.assertIn("LAUNCH_DIAGNOSTICS_PATH: build/sandbox-launch-diagnostics.txt", workflow_text)
        self.assertIn("id: launch-smoke", workflow_text)
        self.assertIn(
            "if: failure() && steps.launch-smoke.outcome == 'failure'",
            workflow_text,
        )
        self.assertIn(
            "uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1",
            workflow_text,
        )
        self.assertIn("name: sandbox-launch-diagnostics-${{ github.run_id }}-${{ github.run_attempt }}", workflow_text)
        self.assertIn("path: build/sandbox-launch-diagnostics.txt", workflow_text)
        self.assertIn("if-no-files-found: error", workflow_text)
        self.assertIn("retention-days: 1", workflow_text)

    def test_unsigned_release_bundle_explicitly_disables_system_notifications(self) -> None:
        text = BUILD_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("<key>SchneeRunnerSystemNotificationsEnabled</key>", text)
        self.assertIn("<false/>", text)


if __name__ == "__main__":
    unittest.main()
