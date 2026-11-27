#!/usr/bin/env bash
set -euo pipefail

suite=${1-all}
if [[ $# -gt 1 || ( "$suite" != all && "$suite" != account && "$suite" != download ) ]]; then
  echo "Usage: bash script/test/mobile_regressions.sh [all|account|download]" >&2
  exit 2
fi

CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

core_tests=(
  test/service/app_update_reminder_test.dart
  test/page/api_local_video_facets_test.dart
  test/page/api_video_history_facets_test.dart
  test/page/api_video_missing_covers_test.dart
  test/plugin/cloud_catalog_fallback_test.dart
  test/comic_read/reader_system_status_bar_test.dart
  test/comic_read/reader_system_ui_handoff_test.dart
)

account_tests=(
  test/service/plugin_account_authentication_test.dart
  test/service/plugin_account_profiles_test.dart
  test/service/plugin_account_web_switch_test.dart
  test/service/omofun_account_lifecycle_test.dart
  test/page/plugin_settings_web_account_host_test.dart
)

download_tests=(
  test/comic_info/chapter_batch_download_host_test.dart
  test/page/video_download_panel_test.dart
  test/page/video_playback_download_adapter_test.dart
  test/page/video_episode_download_queue_test.dart
  test/page/video_api_download_retry_identity_test.dart
  test/page/video_download_lifecycle_host_test.dart
  test/download_retry_test.dart
  test/service/comic_download_chapter_integrity_test.dart
  test/service/download_startup_resume_test.dart
  test/service/download_cancellation_recovery_test.dart
)

run_suite() {
  local name=$1
  shift
  local test_file
  for test_file in "$@"; do
    if [[ ! -f "$test_file" ]]; then
      echo "Missing $name regression test: $test_file" >&2
      return 1
    fi
  done

  printf '\nRunning %s mobile regressions (%s test files)\n' "$name" "$#"
  flutter test --no-pub --reporter expanded "$@"
}

objectbox_dir=$(bash script/test/prepare_objectbox.sh)
if [[ -n "$objectbox_dir" ]]; then
  export LD_LIBRARY_PATH="$objectbox_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

case "$suite" in
  all)
    run_suite core "${core_tests[@]}"
    run_suite account "${account_tests[@]}"
    run_suite download "${download_tests[@]}"
    ;;
  account)
    run_suite account "${account_tests[@]}"
    ;;
  download)
    run_suite download "${download_tests[@]}"
    ;;
esac
