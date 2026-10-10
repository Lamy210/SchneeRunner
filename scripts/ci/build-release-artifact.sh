#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="SchneeRunner"
readonly PRODUCT_NAME="SchneeRunner"
readonly BUNDLE_IDENTIFIER="io.github.Lamy210.SchneeRunner"
readonly MINIMUM_MACOS_VERSION="14.0"
readonly OUTPUT_APP="build/${APP_NAME}.app"
readonly SWIFTPM_RESOURCE_BUNDLE_NAME="SchneeRunner_SchneeRunnerApp.bundle"
readonly APP_RESOURCE_BUNDLE="${OUTPUT_APP}/Contents/Resources/${SWIFTPM_RESOURCE_BUNDLE_NAME}"
readonly BUILT_IN_CHARACTER_DESTINATION="${APP_RESOURCE_BUNDLE}/BuiltInCharacters/YukihanaLamy"

release_version="${RELEASE_VERSION:-}"
if [[ -z "${release_version}" ]]; then
  echo "RELEASE_VERSION is required." >&2
  exit 1
fi

if [[ "${release_version}" == *$'\n'* || "${release_version}" == *$'\r'* ]]; then
  echo "RELEASE_VERSION must not contain line breaks." >&2
  exit 1
fi

if [[ ! "${release_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  echo "RELEASE_VERSION must be a SemVer-like value without a leading v." >&2
  exit 1
fi

swift test
swift build -c release

bin_dir="$(swift build -c release --show-bin-path)"
executable="${bin_dir}/${PRODUCT_NAME}"
resource_bundle="${bin_dir}/${SWIFTPM_RESOURCE_BUNDLE_NAME}"

if [[ ! -f "${executable}" || -L "${executable}" || ! -x "${executable}" ]]; then
  echo "Release executable is missing, linked, or not executable: ${executable}" >&2
  exit 1
fi

if [[ ! -d "${resource_bundle}" || -L "${resource_bundle}" ]]; then
  echo "SwiftPM resource bundle is missing or invalid: ${resource_bundle}" >&2
  exit 1
fi

rm -rf "${OUTPUT_APP}"
mkdir -p \
  "${OUTPUT_APP}/Contents/MacOS" \
  "${OUTPUT_APP}/Contents/Resources"

cp "${executable}" "${OUTPUT_APP}/Contents/MacOS/${PRODUCT_NAME}"
chmod 0755 "${OUTPUT_APP}/Contents/MacOS/${PRODUCT_NAME}"
cp -R "${resource_bundle}" "${OUTPUT_APP}/Contents/Resources/"

if [[ ! -d "${BUILT_IN_CHARACTER_DESTINATION}" || -L "${BUILT_IN_CHARACTER_DESTINATION}" ]]; then
  echo "Bundled character resource directory is missing after packaging: ${BUILT_IN_CHARACTER_DESTINATION}" >&2
  exit 1
fi

for frame in 1 2 3 4; do
  destination="${BUILT_IN_CHARACTER_DESTINATION}/walk_${frame}.png"
  if [[ ! -f "${destination}" || -L "${destination}" || ! -s "${destination}" ]]; then
    echo "Bundled character frame is missing or invalid: ${destination}" >&2
    exit 1
  fi
  /usr/bin/sips -g pixelWidth -g pixelHeight "${destination}" >/dev/null
done

cat >"${OUTPUT_APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
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
  <key>SchneeRunnerSystemNotificationsEnabled</key>
  <false/>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "${OUTPUT_APP}/Contents/Info.plist"

if [[ ! -x "${OUTPUT_APP}/Contents/MacOS/${PRODUCT_NAME}" ]]; then
  echo "Packaged executable is not executable." >&2
  exit 1
fi

echo "Built unsigned release application at ${OUTPUT_APP}"
