#!/usr/bin/env bash
set -euo pipefail

: "${APP_PATH:?APP_PATH is required}"

readonly RESOURCE_ROOT="${APP_PATH}/Contents/Resources"
readonly RESOURCE_BUNDLE_NAME="SchneeRunner_SchneeRunnerApp.bundle"
readonly RESOURCE_BUNDLE="${RESOURCE_ROOT}/${RESOURCE_BUNDLE_NAME}"
readonly BUILT_IN_CHARACTER="${RESOURCE_BUNDLE}/BuiltInCharacters/YukihanaLamy"

if [[ ! -d "${RESOURCE_ROOT}" || -L "${RESOURCE_ROOT}" ]]; then
  echo "Application resource directory is missing or invalid: ${RESOURCE_ROOT}" >&2
  exit 1
fi

if [[ ! -d "${RESOURCE_BUNDLE}" || -L "${RESOURCE_BUNDLE}" ]]; then
  echo "SwiftPM resource bundle is missing or invalid: ${RESOURCE_BUNDLE}" >&2
  exit 1
fi

bundle_count="$(find "${RESOURCE_ROOT}" -mindepth 1 -maxdepth 1 -type d -name "${RESOURCE_BUNDLE_NAME}" -print | wc -l | tr -d ' ')"
if [[ "${bundle_count}" != "1" ]]; then
  echo "Expected exactly one SwiftPM app resource bundle, found ${bundle_count}." >&2
  exit 1
fi

if [[ ! -d "${BUILT_IN_CHARACTER}" || -L "${BUILT_IN_CHARACTER}" ]]; then
  echo "Bundled character resource directory is missing or invalid: ${BUILT_IN_CHARACTER}" >&2
  exit 1
fi

for frame in 1 2 3 4; do
  frame_path="${BUILT_IN_CHARACTER}/walk_${frame}.png"
  if [[ ! -f "${frame_path}" || -L "${frame_path}" || ! -s "${frame_path}" ]]; then
    echo "Bundled character frame is missing or invalid: ${frame_path}" >&2
    exit 1
  fi

done

for locale in en ja; do
  locale_dir="${RESOURCE_BUNDLE}/${locale}.lproj"
  strings_file="${locale_dir}/Localizable.strings"
  if [[ ! -d "${locale_dir}" || -L "${locale_dir}" ]]; then
    echo "Localization directory is missing or invalid: ${locale_dir}" >&2
    exit 1
  fi
  if [[ ! -f "${strings_file}" || -L "${strings_file}" || ! -s "${strings_file}" ]]; then
    echo "Localization strings file is missing or invalid: ${strings_file}" >&2
    exit 1
  fi
done

if [[ -x /usr/bin/sips ]]; then
  for frame in 1 2 3 4; do
    /usr/bin/sips \
      -g pixelWidth \
      -g pixelHeight \
      "${BUILT_IN_CHARACTER}/walk_${frame}.png" >/dev/null
  done
fi

if [[ -x /usr/bin/plutil ]]; then
  for locale in en ja; do
    /usr/bin/plutil -lint \
      "${RESOURCE_BUNDLE}/${locale}.lproj/Localizable.strings" >/dev/null
  done
fi
