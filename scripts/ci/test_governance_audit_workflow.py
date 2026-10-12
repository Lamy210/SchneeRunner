from __future__ import annotations

from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github/workflows/governance-audit.yml"


class GovernanceAuditWorkflowContractTests(unittest.TestCase):
    def workflow_text(self) -> str:
        return WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_exists_and_is_manual_only(self) -> None:
        text = self.workflow_text()
        self.assertIn("workflow_dispatch:", text)
        self.assertNotIn("pull_request:", text)
        self.assertNotIn("\n  push:", text)
        self.assertNotIn("schedule:", text)

    def test_workflow_is_read_only(self) -> None:
        text = self.workflow_text()
        self.assertIn("permissions:\n  contents: read", text)
        self.assertNotIn("contents: write", text)
        self.assertNotIn("actions: write", text)
        self.assertNotIn("pull-requests: write", text)
        self.assertNotIn("administration: write", text)
        self.assertNotIn("continue-on-error", text)

    def test_workflow_runs_all_four_doctors_for_current_repository(self) -> None:
        text = self.workflow_text()
        for command in (
            "bash scripts/ci/audit-live-main-ruleset.sh",
            "bash scripts/ci/audit-live-main-rules.sh",
            "bash scripts/ci/audit-live-release-tag-ruleset.sh",
            "bash scripts/ci/audit-live-repository-settings.sh",
        ):
            with self.subTest(command=command):
                self.assertIn(command, text)
        self.assertGreaterEqual(text.count("${{ github.repository }}"), 4)
        self.assertIn("GH_TOKEN: ${{ github.token }}", text)

    def test_each_doctor_runs_even_after_an_earlier_failure(self) -> None:
        text = self.workflow_text()
        names = (
            "Audit live Solo default-branch Ruleset",
            "Audit effective default-branch rules",
            "Audit live immutable release-tag Ruleset",
            "Audit live repository merge settings",
        )
        for name in names:
            with self.subTest(name=name):
                self.assertIn(
                    f"- name: {name}\n        if: ${{{{ always() }}}}",
                    text,
                )

    def test_checkout_does_not_persist_credentials(self) -> None:
        text = self.workflow_text()
        self.assertIn("persist-credentials: false", text)


if __name__ == "__main__":
    unittest.main()
