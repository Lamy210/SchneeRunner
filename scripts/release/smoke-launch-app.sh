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

TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
log_path="$(mktemp "${TEMP_ROOT%/}/schneerunner-launch-smoke.XXXXXX.log")"
pid=''

cleanup() {
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    kill -TERM "${pid}" 2>/dev/null || true
    sleep 0.2
    if kill -0 "${pid}" 2>/dev/null; then
      kill -KILL "${pid}" 2>/dev/null || true
    fi
  fi
  if [[ -n "${pid}" ]]; then
    wait "${pid}" 2>/dev/null || true
  fi
  rm -f "${log_path}"
}
trap cleanup EXIT

"${executable_path}" >"${log_path}" 2>&1 &
pid="$!"

sleep "${SMOKE_SECONDS}"

if ! kill -0 "${pid}" 2>/dev/null; then
  set +e
  wait "${pid}"
  status="$?"
  set -e
  echo "SchneeRunner exited during launch smoke with status ${status}." >&2
  cat "${log_path}" >&2
  exit 1
fi

echo "Packaged application survived ${SMOKE_SECONDS}s launch smoke: ${APP_PATH}"
