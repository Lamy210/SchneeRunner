#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="SchneeRunner"
readonly BUNDLE_ID="io.github.Lamy210.SchneeRunner"
readonly MINIMUM_MACOS_VERSION="14.0"
readonly OUTPUT_APP="build/${APP_NAME}.app"
readonly BUILT_IN_CHARACTER_SOURCE="Resources/BuiltInCharacters/YukihanaLamy"
readonly BUILT_IN_CHARACTER_DESTINATION="${OUTPUT_APP}/Contents/Resources/BuiltInCharacters/YukihanaLamy"

release_version="${RELEASE_VERSION:-}"
if [[ -z "${release_version}" ]]; then
  echo "RELEASE_VERSION is required (for example 0.1.0)." >&2
  exit 1
fi
if [[ ! "${release_version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "RELEASE_VERSION must be canonical stable SemVer without a leading v: ${release_version}" >&2
  exit 1
fi

swift test
swift build -c release --product "${APP_NAME}"
bin_dir="$(swift build -c release --show-bin-path)"
binary_path="${bin_dir}/${APP_NAME}"

if [[ ! -f "${binary_path}" || -L "${binary_path}" || ! -x "${binary_path}" ]]; then
  echo "Release executable is missing or invalid: ${binary_path}" >&2
  exit 1
fi

rm -rf "${OUTPUT_APP}"
mkdir -p "${OUTPUT_APP}/Contents/MacOS"
install -m 0755 "${binary_path}" "${OUTPUT_APP}/Contents/MacOS/${APP_NAME}"

mkdir -p "${BUILT_IN_CHARACTER_DESTINATION}"
for frame in 1 2 3 4; do
  source_frame="${BUILT_IN_CHARACTER_SOURCE}/walk_${frame}.png"
  destination_frame="${BUILT_IN_CHARACTER_DESTINATION}/walk_${frame}.png"

  if [[ ! -f "${source_frame}" || -L "${source_frame}" ]]; then
    echo "Bundled character frame must be a regular non-symlink file: ${source_frame}" >&2
    exit 1
  fi

  if ! sips -g pixelWidth -g pixelHeight "${source_frame}" >/dev/null 2>&1; then
    echo "Bundled character frame is not a readable image: ${source_frame}" >&2
    exit 1
  fi

  install -m 0644 "${source_frame}" "${destination_frame}"
done

cat >"${OUTPUT_APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${release_version}</string>
    <key>CFBundleVersion</key>
    <string>${release_version}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MINIMUM_MACOS_VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "${OUTPUT_APP}/Contents/Info.plist" >/dev/null

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${OUTPUT_APP}/Contents/Info.plist")"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${OUTPUT_APP}/Contents/Info.plist")"
actual_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${OUTPUT_APP}/Contents/Info.plist")"

if [[ "${actual_bundle_id}" != "${BUNDLE_ID}" ]]; then
  echo "Bundle identifier mismatch after build: ${actual_bundle_id}" >&2
  exit 1
fi
if [[ "${actual_version}" != "${release_version}" ]]; then
  echo "Bundle version mismatch after build: ${actual_version}" >&2
  exit 1
fi
if [[ "${actual_executable}" != "${APP_NAME}" ]]; then
  echo "Bundle executable mismatch after build: ${actual_executable}" >&2
  exit 1
fi

for frame in 1 2 3 4; do
  bundled_frame="${BUILT_IN_CHARACTER_DESTINATION}/walk_${frame}.png"
  if [[ ! -f "${bundled_frame}" || -L "${bundled_frame}" ]]; then
    echo "Bundled character frame is missing from application bundle: ${bundled_frame}" >&2
    exit 1
  fi
done

APP_PATH="${OUTPUT_APP}" \
  EXECUTABLE_NAME="${APP_NAME}" \
  bash scripts/release/verify-app-executable.sh

echo "Built unsigned release application: ${OUTPUT_APP}"
