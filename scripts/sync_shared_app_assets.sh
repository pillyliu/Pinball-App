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

copy_file() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  rsync -a "${source_path}" "${target_path}"
}

require_file "${APP_INTRO_DIR}/launch-logo.png"
require_file "${APP_INTRO_DIR}/league-screenshot.png"
require_file "${APP_INTRO_DIR}/library-screenshot.png"
require_file "${APP_INTRO_DIR}/practice-screenshot.png"
require_file "${APP_INTRO_DIR}/gameroom-screenshot.png"
require_file "${APP_INTRO_DIR}/settings-screenshot.png"
require_file "${APP_INTRO_DIR}/professor-headshot.png"

mkdir -p "${ANDROID_DRAWABLE_NODPI_DIR}"
copy_file "${APP_INTRO_DIR}/launch-logo.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_launch_logo.png"
copy_file "${APP_INTRO_DIR}/league-screenshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_league_screenshot.png"
copy_file "${APP_INTRO_DIR}/library-screenshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_library_screenshot.png"
copy_file "${APP_INTRO_DIR}/practice-screenshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_practice_screenshot.png"
copy_file "${APP_INTRO_DIR}/gameroom-screenshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_gameroom_screenshot.png"
copy_file "${APP_INTRO_DIR}/settings-screenshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_settings_screenshot.png"
copy_file "${APP_INTRO_DIR}/professor-headshot.png" "${ANDROID_DRAWABLE_NODPI_DIR}/intro_professor_headshot.png"

if [[ ! -d "${IOS_ASSETCATALOG_DIR}" ]]; then
  echo "Missing iOS asset catalog directory: ${IOS_ASSETCATALOG_DIR}" >&2
  exit 1
fi

sips -z 682 682 "${APP_INTRO_DIR}/launch-logo.png" \
  --out "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo.png" >/dev/null
sips -z 1364 1364 "${APP_INTRO_DIR}/launch-logo.png" \
  --out "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo@2x.png" >/dev/null
copy_file "${APP_INTRO_DIR}/launch-logo.png" \
  "${IOS_ASSETCATALOG_DIR}/LaunchLogo.imageset/LaunchLogo@3x.png"
copy_file "${APP_INTRO_DIR}/league-screenshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroLeagueScreenshot.imageset/IntroLeagueScreenshot.png"
copy_file "${APP_INTRO_DIR}/library-screenshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroStudyScreenshot.imageset/IntroStudyScreenshot.png"
copy_file "${APP_INTRO_DIR}/practice-screenshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroAssessmentScreenshot.imageset/IntroAssessmentScreenshot.png"
copy_file "${APP_INTRO_DIR}/gameroom-screenshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroCollectionScreenshot.imageset/IntroCollectionScreenshot.png"
copy_file "${APP_INTRO_DIR}/settings-screenshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroCurationScreenshot.imageset/IntroCurationScreenshot.png"
copy_file "${APP_INTRO_DIR}/professor-headshot.png" \
  "${IOS_ASSETCATALOG_DIR}/IntroProfessorHeadshot.imageset/IntroProfessorHeadshot.png"

echo "Shared app intro assets synced into iOS and Android resources."
