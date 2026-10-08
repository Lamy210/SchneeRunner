#!/usr/bin/env bash
set -euo pipefail

: "${APP_PATH:?APP_PATH is required}"
: "${DMG_PATH:?DMG_PATH is required}"

RELEASE_SIGNED="${RELEASE_SIGNED:-true}"
case "${RELEASE_SIGNED}" in
  true | false) ;;
  *)
    echo "RELEASE_SIGNED must be true or false." >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_RELATIVE_DIR="Contents/Resources/BuiltInCharacters/YukihanaLamy"

verify_bundled_character() {
  local app_path="$1"
  local resource_dir="${app_path}/${RESOURCE_RELATIVE_DIR}"
  if [[ ! -d "${resource_dir}" || -L "${resource_dir}" ]]; then
    echo "Bundled character resource directory is missing or invalid: ${resource_dir}" >&2
    exit 1
  fi

  local frame
  for frame in 1 2 3 4; do
    local frame_path="${resource_dir}/walk_${frame}.png"
    if [[ ! -f "${frame_path}" || -L "${frame_path}" || ! -s "${frame_path}" ]]; then
      echo "Bundled character frame is missing or invalid: ${frame_path}" >&2
      exit 1
    fi
  done
}

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Application bundle not found: ${APP_PATH}" >&2
  exit 1
fi

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "DMG not found: ${DMG_PATH}" >&2
  exit 1
fi

plist="${APP_PATH}/Contents/Info.plist"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${plist}")"
APP_PATH="${APP_PATH}" \
  EXECUTABLE_NAME="${executable_name}" \
  bash "${SCRIPT_DIR}/verify-app-executable.sh"
verify_bundled_character "${APP_PATH}"

TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
MOUNT_POINT="$(mktemp -d "${TEMP_ROOT%/}/release-mount.XXXXXX")"
APP_BASENAME="$(basename "${APP_PATH}")"
MOUNTED=false

cleanup() {
  if [[ "${MOUNTED}" == true ]]; then
    hdiutil detach "${MOUNT_POINT}" -quiet || true
  fi
  rm -rf "${MOUNT_POINT}"
}
trap cleanup EXIT

if [[ "${RELEASE_SIGNED}" == "true" ]]; then
  codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
  spctl --assess --type execute --verbose=4 "${APP_PATH}"
  codesign --verify --verbose=2 "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
  spctl --assess \
    --type open \
    --context context:primary-signature \
    --verbose=4 \
    "${DMG_PATH}"
fi

hdiutil verify "${DMG_PATH}"

hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "${MOUNT_POINT}" \
  "${DMG_PATH}" >/dev/null
MOUNTED=true

mounted_app="${MOUNT_POINT}/${APP_BASENAME}"
if [[ ! -d "${mounted_app}" ]]; then
  echo "Expected application not found in DMG: ${APP_BASENAME}" >&2
  exit 1
fi

APP_PATH="${mounted_app}" \
  EXECUTABLE_NAME="${executable_name}" \
  bash "${SCRIPT_DIR}/verify-app-executable.sh"
verify_bundled_character "${mounted_app}"
for frame in 1 2 3 4; do
  cmp \
    "${APP_PATH}/${RESOURCE_RELATIVE_DIR}/walk_${frame}.png" \
    "${mounted_app}/${RESOURCE_RELATIVE_DIR}/walk_${frame}.png"
done

if [[ "${RELEASE_SIGNED}" == "true" ]]; then
  codesign --verify --deep --strict --verbose=2 "${mounted_app}"
fi

CHECKSUM_PATH="${DMG_PATH}.sha256"
(
  cd "$(dirname "${DMG_PATH}")"
  shasum -a 256 "$(basename "${DMG_PATH}")" >"$(basename "${CHECKSUM_PATH}")"
)

cat "${CHECKSUM_PATH}"
