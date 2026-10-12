#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: audit-live-repository-settings.sh owner/repo

Read repository merge settings and validate them against the Solo governance contract.
This command is read-only.
EOF
}

repository="${1:-${GITHUB_REPOSITORY:-}}"
if [[ ! "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  usage
  exit 2
fi
if (($# > 1)); then
  usage
  exit 2
fi

command -v gh >/dev/null 2>&1 || {
  echo "gh is required." >&2
  exit 2
}
command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required." >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/repository-settings-audit.XXXXXX")"
cleanup() {
  rm -rf "${work_root}"
}
trap cleanup EXIT

repository_json="${work_root}/repository.json"
gh api \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "repos/${repository}" >"${repository_json}"

python3 "${repo_root}/scripts/ci/audit_repository_settings.py" "${repository_json}" "${repository}"
