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

TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
log_path="$(mktemp "${TEMP_ROOT%/}/schneerunner-launch-smoke.XXXXXX.log")"
crash_marker="$(mktemp "${TEMP_ROOT%/}/schneerunner-launch-smoke.XXXXXX.marker")"
smoke_token="schneerunner-launch-smoke-$(/usr/bin/uuidgen)"
launcher_pid=''
app_pid=''

cleanup() {
  if [[ -n "${app_pid}" ]] && kill -0 "${app_pid}" 2>/dev/null; then
    kill -TERM "${app_pid}" 2>/dev/null || true
    sleep 0.2
    if kill -0 "${app_pid}" 2>/dev/null; then
      kill -KILL "${app_pid}" 2>/dev/null || true
    fi
  fi

  if [[ -n "${launcher_pid}" ]] && kill -0 "${launcher_pid}" 2>/dev/null; then
    kill -TERM "${launcher_pid}" 2>/dev/null || true
  fi
  if [[ -n "${launcher_pid}" ]]; then
    wait "${launcher_pid}" 2>/dev/null || true
  fi

  rm -f "${log_path}" "${crash_marker}"
}
trap cleanup EXIT

/usr/bin/open -n -W "${APP_PATH}" --args "${smoke_token}" >"${log_path}" 2>&1 &
launcher_pid="$!"

for _ in {1..20}; do
  while IFS= read -r candidate_pid; do
    if [[ -n "${candidate_pid}" && "${candidate_pid}" != "${launcher_pid}" ]]; then
      app_pid="${candidate_pid}"
      break 2
    fi
  done < <(/usr/bin/pgrep -f "${smoke_token}" 2>/dev/null || true)

  if ! kill -0 "${launcher_pid}" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

sleep "${SMOKE_SECONDS}"

if [[ -n "${app_pid}" ]] && kill -0 "${app_pid}" 2>/dev/null; then
  echo "Packaged application survived ${SMOKE_SECONDS}s launch smoke: ${APP_PATH}"
  exit 0
fi

if ! kill -0 "${launcher_pid}" 2>/dev/null; then
  set +e
  wait "${launcher_pid}"
  status="$?"
  set -e
  echo "SchneeRunner exited during launch smoke with status ${status}." >&2
  cat "${log_path}" >&2

  # CrashReporter can flush the .ips/.crash file just after the process exits.
  sleep 1
  diagnostic_dir="${HOME}/Library/Logs/DiagnosticReports"
  if [[ -d "${diagnostic_dir}" ]]; then
    echo "Recent SchneeRunner diagnostic reports:" >&2
    while IFS= read -r report; do
      echo "===== ${report} =====" >&2
      cat "${report}" >&2 || true
    done < <(
      find "${diagnostic_dir}" -type f \
        \( -name 'SchneeRunner*.ips' -o -name 'SchneeRunner*.crash' \) \
        -newer "${crash_marker}" -print 2>/dev/null
    )
  fi

  exit 1
fi

echo "SchneeRunner launch smoke could not confirm the launched application process." >&2
cat "${log_path}" >&2
exit 1
