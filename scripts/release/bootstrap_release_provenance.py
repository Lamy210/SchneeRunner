from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
SUPPORTED_RELEASES = {
    ("v0.1.0", "0.1.0", "SchneeRunner-0.1.0.dmg"): "bootstrap-v0.1.0",
    ("v0.1.1", "0.1.1", "SchneeRunner-0.1.1.dmg"): "bootstrap-v0.1.1-signed",
}
EXPECTED_KEYS = frozenset(
    {
        "schemaVersion",
        "releaseMode",
        "repository",
        "sourceSHA",
        "tag",
        "version",
        "workflowRunId",
        "workflowRunAttempt",
        "dmgName",
        "dmgSHA256",
    }
)
_REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
_DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _validate_repository(repository: Any) -> str:
    _require(isinstance(repository, str), "repository must be a string")
    _require(_REPOSITORY_RE.fullmatch(repository) is not None, "repository must be owner/repo")
    owner, name = repository.split("/", 1)
    _require(owner not in {".", ".."} and name not in {".", ".."}, "repository is invalid")
    return repository


def _validate_source_sha(source_sha: Any) -> str:
    _require(isinstance(source_sha, str), "source SHA must be a string")
    _require(_SHA_RE.fullmatch(source_sha) is not None, "source SHA must be 40 lowercase hex characters")
    return source_sha


def _validate_positive_int(value: Any, name: str) -> int:
    _require(type(value) is int and value > 0, f"{name} must be a positive integer")
    return value


def _release_mode(tag: str, version: str, dmg_name: str) -> str:
    identity = (tag, version, dmg_name)
    _require(identity in SUPPORTED_RELEASES, "unsupported bootstrap release identity")
    return SUPPORTED_RELEASES[identity]


def validate_dmg_path(dmg_path: Path, expected_name: str) -> Path:
    _require(dmg_path.name == expected_name, f"DMG must be named {expected_name}")
    _require(not dmg_path.is_symlink(), "DMG must not be a symlink")
    _require(dmg_path.is_file(), "DMG must be a regular file")
    return dmg_path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def build_bootstrap_provenance(
    *,
    repository: str,
    source_sha: str,
    tag: str,
    version: str,
    workflow_run_id: int,
    workflow_run_attempt: int,
    dmg_path: Path,
) -> dict[str, object]:
    repository = _validate_repository(repository)
    source_sha = _validate_source_sha(source_sha)
    release_mode = _release_mode(tag, version, dmg_path.name)
    workflow_run_id = _validate_positive_int(workflow_run_id, "workflow run ID")
    workflow_run_attempt = _validate_positive_int(workflow_run_attempt, "workflow run attempt")
    dmg_path = validate_dmg_path(dmg_path, dmg_path.name)

    return {
        "schemaVersion": SCHEMA_VERSION,
        "releaseMode": release_mode,
        "repository": repository,
        "sourceSHA": source_sha,
        "tag": tag,
        "version": version,
        "workflowRunId": workflow_run_id,
        "workflowRunAttempt": workflow_run_attempt,
        "dmgName": dmg_path.name,
        "dmgSHA256": sha256_file(dmg_path),
    }


def validate_bootstrap_provenance(
    document: Any,
    *,
    expected_repository: str,
    expected_source_sha: str,
    expected_tag: str,
    expected_version: str,
    dmg_path: Path,
) -> None:
    _validate_repository(expected_repository)
    _validate_source_sha(expected_source_sha)
    release_mode = _release_mode(expected_tag, expected_version, dmg_path.name)
    dmg_path = validate_dmg_path(dmg_path, dmg_path.name)

    _require(isinstance(document, dict), "bootstrap provenance must be an object")
    _require(set(document) == EXPECTED_KEYS, "bootstrap provenance schema keys do not match")
    _require(type(document["schemaVersion"]) is int and document["schemaVersion"] == SCHEMA_VERSION, "invalid schema version")
    _require(document["releaseMode"] == release_mode, "invalid release mode")
    _validate_repository(document["repository"])
    _validate_source_sha(document["sourceSHA"])
    _require(document["tag"] == expected_tag, "invalid tag")
    _require(document["version"] == expected_version, "invalid version")
    _validate_positive_int(document["workflowRunId"], "workflow run ID")
    _validate_positive_int(document["workflowRunAttempt"], "workflow run attempt")
    _require(document["dmgName"] == dmg_path.name, "invalid DMG name")
    _require(isinstance(document["dmgSHA256"], str) and _DIGEST_RE.fullmatch(document["dmgSHA256"]) is not None, "invalid DMG digest")

    _require(document["repository"] == expected_repository, "repository does not match expected identity")
    _require(document["sourceSHA"] == expected_source_sha, "source SHA does not match expected identity")
    _require(document["tag"] == expected_tag, "tag does not match expected identity")
    _require(document["version"] == expected_version, "version does not match expected identity")
    _require(document["dmgSHA256"] == sha256_file(dmg_path), "DMG digest does not match provenance")
