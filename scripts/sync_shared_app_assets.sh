#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_SUPPORT_DIR="${ROOT_DIR}/Pinball App 2/Pinball App 2/SharedAppSupport"
APP_INTRO_DIR="${SHARED_SUPPORT_DIR}/app-intro"

IOS_APP_ROOT="${ROOT_DIR}/Pinball App 2/Pinball App 2"
IOS_ASSETCATALOG_DIR="${IOS_APP_ROOT}/Assets.xcassets"

ANDROID_MAIN_DIR="${ROOT_DIR}/Pinball App Android/app/src/main"
ANDROID_DRAWABLE_NODPI_DIR="${ANDROID_MAIN_DIR}/res/drawable-nodpi"

require_file() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo "Missing shared app asset: ${file_path}" >&2
    exit 1
  fi
}

resolve_shared_asset() {
  local base_name="$1"
  local png_path="${APP_INTRO_DIR}/${base_name}.png"
  local webp_path="${APP_INTRO_DIR}/${base_name}.webp"
  if [[ -f "${webp_path}" ]]; then
    printf '%s\n' "${webp_path}"
    return 0
  fi
  if [[ -f "${png_path}" ]]; then
    printf '%s\n' "${png_path}"
    return 0
  fi
  echo "Missing shared app asset: ${png_path} or ${webp_path}" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

copy_file() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  rsync -a "${source_path}" "${target_path}"
}

remove_if_exists() {
  local file_path="$1"
  if [[ -e "${file_path}" ]]; then
    rm -f "${file_path}"
  fi
}

convert_android_webp() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  if [[ "${source_path##*.}" == "webp" ]]; then
    rsync -a "${source_path}" "${target_path}"
  else
    cwebp -quiet -q 82 "${source_path}" -o "${target_path}"
  fi
}

render_ios_png() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  sips -s format png "${source_path}" --out "${target_path}" >/dev/null
}

render_ios_scaled_png() {
  local source_path="$1"
  local width="$2"
  local height="$3"
  local target_path="$4"
  mkdir -p "$(dirname "${target_path}")"
  sips -z "${height}" "${width}" -s format png "${source_path}" --out "${target_path}" >/dev/null
}

require_command cwebp

LAUNCH_LOGO_SOURCE="$(resolve_shared_asset "launch-logo")"
LEAGUE_SCREENSHOT_SOURCE="$(resolve_shared_asset "league-screenshot")"
LIBRARY_SCREENSHOT_SOURCE="$(resolve_shared_asset "library-screenshot")"
PRACTICE_SCREENSHOT_SOURCE="$(resolve_shared_asset "practice-screenshot")"
GAMEROOM_SCREENSHOT_SOURCE="$(resolve_shared_asset "gameroom-screenshot")"
SETTINGS_SCREENSHOT_SOURCE="$(resolve_shared_asset "settings-screenshot")"
PROFESSOR_HEADSHOT_SOURCE="$(resolve_shared_asset "professor-headshot")"

mkdir -p "${ANDROID_DRAWABLE_NODPI_DIR}"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_launch_logo.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_league_screenshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_library_screenshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_practice_screenshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_gameroom_screenshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_settings_screenshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_professor_headshot.png"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_launch_logo.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_league_screenshot.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_library_screenshot.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_practice_screenshot.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_gameroom_screenshot.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_settings_screenshot.webp"
remove_if_exists "${ANDROID_DRAWABLE_NODPI_DIR}/intro_professor_headshot.webp"
convert_android_webp "${LAUNCH_LOGO_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_launch_logo.webp"
convert_android_webp "${LEAGUE_SCREENSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_league_screenshot.webp"
convert_android_webp "${LIBRARY_SCREENSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_library_screenshot.webp"
convert_android_webp "${PRACTICE_SCREENSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_practice_screenshot.webp"
convert_android_webp "${GAMEROOM_SCREENSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_gameroom_screenshot.webp"
convert_android_webp "${SETTINGS_SCREENSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_settings_screenshot.webp"
convert_android_webp "${PROFESSOR_HEADSHOT_SOURCE}" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_professor_headshot.webp"

if [[ ! -d "${IOS_ASSETCATALOG_DIR}" ]]; then
  echo "Missing iOS asset catalog directory: ${IOS_ASSETCATALOG_DIR}" >&2
  exit 1
fi

render_ios_scaled_png "${LAUNCH_LOGO_SOURCE}" 682 682 "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo.png"
render_ios_scaled_png "${LAUNCH_LOGO_SOURCE}" 1364 1364 "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo@2x.png"
render_ios_png "${LAUNCH_LOGO_SOURCE}" "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo@3x.png"
echo "Shared app intro assets synced into Android resources and the iOS native launch logo asset."
