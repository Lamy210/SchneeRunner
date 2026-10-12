from __future__ import annotations

import json
from pathlib import Path
import sys


EXPECTED_SETTINGS: dict[str, bool] = {
    "allow_squash_merge": True,
    "allow_merge_commit": False,
    "allow_rebase_merge": False,
    "delete_branch_on_merge": True,
}


def validate_repository_settings(
    document: object,
    *,
    expected_repository: str,
) -> list[str]:
    if not isinstance(document, dict):
        return ["repository settings audit failed: repository JSON must be a JSON object"]

    errors: list[str] = []
    actual_repository = document.get("full_name")
    if actual_repository != expected_repository:
        errors.append(
            "repository settings audit failed: expected repository "
            f"{expected_repository}, got {actual_repository}"
        )

    for field, expected in EXPECTED_SETTINGS.items():
        if field not in document:
            errors.append(
                f"repository settings audit failed: missing boolean field '{field}'"
            )
            continue

        actual = document[field]
        if type(actual) is not bool:
            errors.append(
                f"repository settings audit failed: field '{field}' must be a JSON boolean"
            )
            continue

        if actual is not expected:
            errors.append(
                f"repository settings drift: {field} expected {str(expected).lower()}, "
                f"got {str(actual).lower()}"
            )

    return errors


def _load_json(path: str) -> object:
    if path == "-":
        try:
            return json.load(sys.stdin)
        except json.JSONDecodeError as error:
            raise SystemExit(
                "invalid JSON from stdin: "
                f"{error.msg} at line {error.lineno} column {error.colno}"
            ) from error

    try:
        with Path(path).open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except OSError as error:
        raise SystemExit(f"failed to read {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"{path}: invalid JSON: {error.msg} at line {error.lineno} column {error.colno}"
        ) from error


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 2:
        print(
            "Usage: audit_repository_settings.py <repository-json|-> owner/repo",
            file=sys.stderr,
        )
        return 2

    path, repository = args
    if (
        "/" not in repository
        or repository.startswith("/")
        or repository.endswith("/")
        or repository.count("/") != 1
    ):
        print("repository must be in owner/repo form", file=sys.stderr)
        return 2

    document = _load_json(path)
    errors = validate_repository_settings(document, expected_repository=repository)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1

    print(f"Repository merge settings for {repository} matches the Solo governance contract.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
