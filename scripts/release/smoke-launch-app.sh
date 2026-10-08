#!/usr/bin/env bash
set -euo pipefail

: "${APP_PATH:?APP_PATH is required}"

SMOKE_SECONDS="${SMOKE_SECONDS:-2}"
case "${SMOKE_SECONDS}" in
  '' | *[!0-9]*)
    echo "SMOKE_SECONDS must be a positive integer." >&2
    exit 1
    ;;
esac
if ((SMOKE_SECONDS < 1 || SMOKE_SECONDS > 10)); then
  echo "SMOKE_SECONDS must be between 1 and 10 seconds." >&2
  exit 1
fi

if [[ ! -d "${APP_PATH}" || -L "${APP_PATH}" ]]; then
  echo "Application bundle is missing or invalid: ${APP_PATH}" >&2
  exit 1
fi

APP_PATH="$(cd "$(dirname "${APP_PATH}")" && pwd -P)/$(basename "${APP_PATH}")"
plist="${APP_PATH}/Contents/Info.plist"
if [[ ! -f "${plist}" || -L "${plist}" ]]; then
  echo "Application Info.plist is missing or invalid: ${plist}" >&2
  exit 1
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${plist}")"
executable_path="${APP_PATH}/Contents/MacOS/${executable_name}"
if [[ ! -f "${executable_path}" || -L "${executable_path}" || ! -x "${executable_path}" ]]; then
  echo "Application executable is missing or invalid: ${executable_path}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
xcrun swift "${SCRIPT_DIR}/smoke-launch-app.swift" "${APP_PATH}" "${SMOKE_SECONDS}"
