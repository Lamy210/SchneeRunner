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

report_launch_diagnostics() {
  echo "--- Recent SchneeRunner macOS diagnostics ---" >&2
  /usr/bin/log show \
    --style compact \
    --last 2m \
    --info \
    --debug \
    --predicate 'process == "SchneeRunner" OR eventMessage CONTAINS[c] "SchneeRunner"' \
    2>/dev/null |
    tail -n 120 >&2 ||
    true

  local reports_dir="${HOME}/Library/Logs/DiagnosticReports"
  [[ -d "${reports_dir}" ]] || return 0

  local latest_report
  latest_report="$({
    find "${reports_dir}" -type f -mmin -5 -iname '*SchneeRunner*' -exec stat -f '%m %N' {} \; 2>/dev/null |
      sort -rn |
      head -n 1 |
      cut -d' ' -f2-
  } || true)"

  if [[ -n "${latest_report}" && -f "${latest_report}" ]]; then
    echo "--- ${latest_report} ---" >&2
    sed -n '1,200p' "${latest_report}" >&2 || true
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set +e
xcrun swift "${SCRIPT_DIR}/smoke-launch-app.swift" "${APP_PATH}" "${SMOKE_SECONDS}"
smoke_status=$?
set -e

if ((smoke_status != 0)); then
  report_launch_diagnostics
fi

exit "${smoke_status}"
