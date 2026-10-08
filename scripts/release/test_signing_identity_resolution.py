from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
RESOLVER = REPO_ROOT / "scripts/release/resolve-signing-identity.py"


class SigningIdentityResolutionTests(unittest.TestCase):
    def run_resolver(self, text: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(RESOLVER)],
            input=text,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_returns_single_developer_id_application_identity(self) -> None:
        result = self.run_resolver(
            '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Developer ID Application: Example Developer (ABCDE12345)"\n'
            '     1 valid identities found\n'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "Developer ID Application: Example Developer (ABCDE12345)",
        )

    def test_ignores_non_developer_id_application_identities(self) -> None:
        result = self.run_resolver(
            '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Apple Development: Example Developer (ABCDE12345)"\n'
            '  2) 89ABCDEF0123456789ABCDEF0123456789ABCDEF "Developer ID Application: Example Developer (ABCDE12345)"\n'
            '     2 valid identities found\n'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout.strip(),
            "Developer ID Application: Example Developer (ABCDE12345)",
        )

    def test_rejects_missing_developer_id_application_identity(self) -> None:
        result = self.run_resolver(
            '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Apple Development: Example Developer (ABCDE12345)"\n'
            '     1 valid identities found\n'
        )
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_ambiguous_developer_id_application_identities(self) -> None:
        result = self.run_resolver(
            '  1) 0123456789ABCDEF0123456789ABCDEF01234567 "Developer ID Application: One (ABCDE12345)"\n'
            '  2) 89ABCDEF0123456789ABCDEF0123456789ABCDEF "Developer ID Application: Two (FGHIJ67890)"\n'
            '     2 valid identities found\n'
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
