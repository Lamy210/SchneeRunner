#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
if [[ "${ACTION}" != "preflight" && "${ACTION}" != "publish" ]]; then
  echo "Usage: publish-bootstrap-release.sh <preflight|publish>" >&2
  exit 2
fi

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${EXPECTED_REPOSITORY_ID:?EXPECTED_REPOSITORY_ID is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${RELEASE_VERSION:?RELEASE_VERSION is required}"
: "${DMG_NAME:?DMG_NAME is required}"

EXPECTED_REPOSITORY="Lamy210/SchneeRunner"
EXPECTED_TAG="v0.1.0"
EXPECTED_VERSION="0.1.0"
EXPECTED_DMG="SchneeRunner-0.1.0.dmg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${GITHUB_REPOSITORY}" != "${EXPECTED_REPOSITORY}" ]]; then
  echo "Bootstrap release is restricted to ${EXPECTED_REPOSITORY}." >&2
  exit 1
fi
if [[ "${RELEASE_TAG}" != "${EXPECTED_TAG}" || "${RELEASE_VERSION}" != "${EXPECTED_VERSION}" || "${DMG_NAME}" != "${EXPECTED_DMG}" ]]; then
  echo "Bootstrap release identity must be exactly ${EXPECTED_TAG} / ${EXPECTED_DMG}." >&2
  exit 1
fi
if [[ ! "${EXPECTED_REPOSITORY_ID}" =~ ^[0-9]+$ ]] || ((10#${EXPECTED_REPOSITORY_ID} <= 0)); then
  echo "EXPECTED_REPOSITORY_ID must be a positive integer." >&2
  exit 1
fi
if [[ ! "${SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "SOURCE_SHA must be 40 lowercase hexadecimal characters." >&2
  exit 1
fi

command -v gh >/dev/null 2>&1 || {
  echo "gh is required for bootstrap release publication." >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required for bootstrap release publication." >&2
  exit 1
}

repository_identity() {
  local response
  response="$(gh api "repos/${GITHUB_REPOSITORY}")"
  python3 - "${GITHUB_REPOSITORY}" "${EXPECTED_REPOSITORY_ID}" "${response}" <<'PY'
import json
import re
import sys

expected_name, expected_id_text, payload = sys.argv[1:]
expected_id = int(expected_id_text)
document = json.loads(payload)
if not isinstance(document, dict):
    raise SystemExit("repository response must be an object")
repository_id = document.get("id")
full_name = document.get("full_name")
if type(repository_id) is not int or repository_id != expected_id:
    raise SystemExit(f"repository id mismatch: expected {expected_id}, got {repository_id!r}")
if not isinstance(full_name, str) or re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", full_name) is None:
    raise SystemExit("repository full_name is invalid")
if full_name.casefold() != expected_name.casefold():
    raise SystemExit(f"repository name mismatch: expected {expected_name}, got {full_name}")
PY
}

resolve_tag_sha() {
  local response
  response="$(gh api "repos/${GITHUB_REPOSITORY}/git/matching-refs/tags/${RELEASE_TAG}")"
  python3 - "${RELEASE_TAG}" "${response}" <<'PY'
import json
import re
import sys

tag, payload = sys.argv[1:]
document = json.loads(payload)
if not isinstance(document, list):
    raise SystemExit("matching tag response must be an array")
expected_ref = f"refs/tags/{tag}"
matches = [item for item in document if isinstance(item, dict) and item.get("ref") == expected_ref]
if not matches:
    print("")
    raise SystemExit(0)
if len(matches) != 1:
    raise SystemExit("release tag response is ambiguous")
obj = matches[0].get("object")
if not isinstance(obj, dict) or obj.get("type") != "commit":
    raise SystemExit("bootstrap tag must be a lightweight commit tag")
sha = obj.get("sha")
if not isinstance(sha, str) or re.fullmatch(r"[0-9a-f]{40}", sha) is None:
    raise SystemExit("release tag SHA is invalid")
print(sha)
PY
}

release_exists() {
  local tags
  tags="$(gh api --paginate "repos/${GITHUB_REPOSITORY}/releases?per_page=100" --jq '.[].tag_name')"
  grep -Fxq -- "${RELEASE_TAG}" <<<"${tags}"
}

validate_release_metadata() {
  local root="$1"
  local metadata_path="${root}/release.json"
  gh release view "${RELEASE_TAG}" \
    --repo "${GITHUB_REPOSITORY}" \
    --json assets,isDraft,isPrerelease,tagName >"${metadata_path}"
  python3 "${SCRIPT_DIR}/verify-release-state.py" \
    --metadata "${metadata_path}" \
    --tag "${RELEASE_TAG}" \
    --asset "${DMG_NAME}" \
    --asset "${DMG_NAME}.sha256" \
    --asset release-provenance.json
}

verify_remote_release() {
  local expected_source_sha="$1"
  local local_root="${2:-}"
  local temp_root
  temp_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/bootstrap-release-verify.XXXXXX")"

  validate_release_metadata "${temp_root}"
  local asset
  for asset in "${DMG_NAME}" "${DMG_NAME}.sha256" release-provenance.json; do
    gh release download "${RELEASE_TAG}" \
      --repo "${GITHUB_REPOSITORY}" \
      --pattern "${asset}" \
      --dir "${temp_root}"
    if [[ ! -f "${temp_root}/${asset}" || -L "${temp_root}/${asset}" ]]; then
      echo "Downloaded bootstrap release asset is missing or unsafe: ${asset}" >&2
      rm -rf "${temp_root}"
      return 1
    fi
  done

  python3 "${SCRIPT_DIR}/verify-bootstrap-release-provenance.py" \
    --metadata "${temp_root}/release-provenance.json" \
    --repository "${GITHUB_REPOSITORY}" \
    --source-sha "${expected_source_sha}" \
    --tag "${RELEASE_TAG}" \
    --version "${RELEASE_VERSION}" \
    --dmg-path "${temp_root}/${DMG_NAME}"

  local checksum_digest
  checksum_digest="$(python3 "${SCRIPT_DIR}/release_checksum.py" "${temp_root}/${DMG_NAME}.sha256" "${DMG_NAME}")"
  local dmg_digest
  dmg_digest="$(shasum -a 256 "${temp_root}/${DMG_NAME}" | awk '{print $1}')"
  if [[ "${checksum_digest}" != "${dmg_digest}" ]]; then
    echo "Published bootstrap checksum does not match DMG." >&2
    rm -rf "${temp_root}"
    return 1
  fi

  if [[ -n "${local_root}" ]]; then
    for asset in "${DMG_NAME}" "${DMG_NAME}.sha256" release-provenance.json; do
      if [[ ! -f "${local_root}/${asset}" || -L "${local_root}/${asset}" ]]; then
        echo "Local bootstrap asset is missing or unsafe: ${asset}" >&2
        rm -rf "${temp_root}"
        return 1
      fi
      local local_digest remote_digest
      local_digest="$(shasum -a 256 "${local_root}/${asset}" | awk '{print $1}')"
      remote_digest="$(shasum -a 256 "${temp_root}/${asset}" | awk '{print $1}')"
      if [[ "${local_digest}" != "${remote_digest}" ]]; then
        echo "Remote bootstrap asset differs from the local immutable payload: ${asset}" >&2
        rm -rf "${temp_root}"
        return 1
      fi
    done
  fi

  rm -rf "${temp_root}"
}

write_release_required() {
  local value="$1"
  if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "GITHUB_OUTPUT is required during bootstrap preflight." >&2
    return 1
  fi
  printf 'release_required=%s\n' "${value}" >>"${GITHUB_OUTPUT}"
}

repository_identity
initial_tag_sha="$(resolve_tag_sha)"
initial_release_exists=false
if release_exists; then
  initial_release_exists=true
fi

if [[ "${ACTION}" == "preflight" ]]; then
  if [[ -z "${initial_tag_sha}" && "${initial_release_exists}" == false ]]; then
    write_release_required true
    exit 0
  fi
  if [[ -z "${initial_tag_sha}" || "${initial_release_exists}" != true ]]; then
    echo "Bootstrap release is in a partial remote state; refusing to overwrite it." >&2
    exit 1
  fi
  verify_remote_release "${initial_tag_sha}"
  final_tag_sha="$(resolve_tag_sha)"
  if [[ "${final_tag_sha}" != "${initial_tag_sha}" ]]; then
    echo "Bootstrap release tag changed during preflight verification." >&2
    exit 1
  fi
  repository_identity
  write_release_required false
  exit 0
fi

: "${DMG_PATH:?DMG_PATH is required for publish}"
: "${RELEASE_PROVENANCE_PATH:?RELEASE_PROVENANCE_PATH is required for publish}"
local_root="$(cd "$(dirname "${DMG_PATH}")" && pwd)"
if [[ "$(basename "${DMG_PATH}")" != "${DMG_NAME}" || "${RELEASE_PROVENANCE_PATH}" != "${local_root}/release-provenance.json" ]]; then
  echo "Bootstrap publish paths do not match the canonical asset layout." >&2
  exit 1
fi
if [[ -n "${initial_tag_sha}" || "${initial_release_exists}" == true ]]; then
  echo "Bootstrap publish requires both tag and release to be absent at publication start." >&2
  exit 1
fi

python3 "${SCRIPT_DIR}/verify-bootstrap-release-provenance.py" \
  --metadata "${RELEASE_PROVENANCE_PATH}" \
  --repository "${GITHUB_REPOSITORY}" \
  --source-sha "${SOURCE_SHA}" \
  --tag "${RELEASE_TAG}" \
  --version "${RELEASE_VERSION}" \
  --dmg-path "${DMG_PATH}"

checksum_digest="$(python3 "${SCRIPT_DIR}/release_checksum.py" "${DMG_PATH}.sha256" "${DMG_NAME}")"
dmg_digest="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
if [[ "${checksum_digest}" != "${dmg_digest}" ]]; then
  echo "Local bootstrap checksum does not match DMG." >&2
  exit 1
fi

if ! gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" \
  -f "ref=refs/tags/${RELEASE_TAG}" \
  -f "sha=${SOURCE_SHA}" >/dev/null; then
  raced_tag_sha="$(resolve_tag_sha)"
  if [[ "${raced_tag_sha}" != "${SOURCE_SHA}" ]]; then
    echo "Failed to create immutable bootstrap tag at the expected source SHA." >&2
    exit 1
  fi
fi

created_tag_sha="$(resolve_tag_sha)"
if [[ "${created_tag_sha}" != "${SOURCE_SHA}" ]]; then
  echo "Bootstrap tag does not resolve to the release source SHA." >&2
  exit 1
fi

assets=("${DMG_PATH}" "${DMG_PATH}.sha256" "${RELEASE_PROVENANCE_PATH}")
if ! gh release create "${RELEASE_TAG}" \
  "${assets[@]}" \
  --repo "${GITHUB_REPOSITORY}" \
  --verify-tag \
  --generate-notes \
  --title "${RELEASE_TAG}"; then
  if ! release_exists; then
    echo "GitHub Release creation failed and no concurrent release exists." >&2
    exit 1
  fi
fi

verify_remote_release "${SOURCE_SHA}" "${local_root}"
final_tag_sha="$(resolve_tag_sha)"
if [[ "${final_tag_sha}" != "${SOURCE_SHA}" ]]; then
  echo "Bootstrap tag changed during release publication." >&2
  exit 1
fi
repository_identity
printf 'Bootstrap GitHub Release %s is published and verified.\n' "${RELEASE_TAG}"
