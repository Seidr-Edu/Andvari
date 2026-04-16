#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/testlib.sh"
# shellcheck source=/dev/null
source "${TOOL_ROOT}/scripts/adapters/adapter.sh"

setup_fake_claude() {
  local root="$1"
  local fake_bin="${root}/bin"
  mkdir -p "$fake_bin"

  cat > "${fake_bin}/claude" <<'CLAUDE'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-claude 1.0\n'
  exit 0
fi

if [[ "${1:-}" == "--dangerously-skip-permissions" && "${2:-}" == "--print" ]]; then
  cat >/dev/null
  case "${ANDVARI_TEST_CLAUDE_MODE:-success}" in
    success)
      printf 'fake claude response\n'
      exit 0
      ;;
    complete-then-hang)
      printf 'fake claude response\n'
      while true; do
        sleep 60
      done
      ;;
    hang-before-output)
      while true; do
        sleep 60
      done
      ;;
    *)
      exit 2
      ;;
  esac
fi

printf 'unexpected fake claude invocation\n' >&2
exit 1
CLAUDE

  chmod +x "${fake_bin}/claude"
  export PATH="${fake_bin}:$PATH"
}

case_claude_adapter_happy_path_writes_output_last_message() {
  local tmp
  tmp="$(at_mktemp_dir)"
  setup_fake_claude "$tmp"

  ROOT_DIR="$TOOL_ROOT"

  local repo_dir="${tmp}/repo"
  local events_log="${tmp}/adapter_events.jsonl"
  local stderr_log="${tmp}/adapter_stderr.log"
  local output_last_message="${tmp}/last_message.txt"
  mkdir -p "$repo_dir"

  adapter_check_prereqs "claude"

  local status=0
  set +e
  adapter_run_initial_reconstruction \
    "claude" \
    "$repo_dir" \
    "${TOOL_ROOT}/examples/diagram.puml" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  at_assert_eq 0 "$status" "claude adapter happy path should succeed"
  at_assert_file_exists "$output_last_message" "claude adapter should materialize output_last_message"

  local output_text events_text
  output_text="$(cat "$output_last_message")"
  at_assert_contains "$output_text" "fake claude response" "claude output should be copied into output_last_message"

  events_text="$(cat "$events_log")"
  if [[ "$events_text" == *"post-completion-hang-recovered"* ]]; then
    echo "ASSERT failed: happy-path claude run must not log hang recovery" >&2
    return 1
  fi
}

case_claude_adapter_complete_then_hang_recovers() {
  local tmp
  tmp="$(at_mktemp_dir)"
  setup_fake_claude "$tmp"

  # shellcheck disable=SC2034
  ROOT_DIR="$TOOL_ROOT"

  local repo_dir="${tmp}/repo"
  local events_log="${tmp}/adapter_events.jsonl"
  local stderr_log="${tmp}/adapter_stderr.log"
  local output_last_message="${tmp}/last_message.txt"
  mkdir -p "$repo_dir"

  adapter_check_prereqs "claude"

  local status=0
  set +e
  ANDVARI_TEST_CLAUDE_MODE="complete-then-hang" \
  ANDVARI_TEST_CLAUDE_COMPLETION_GRACE_SEC="1" \
    adapter_run_initial_reconstruction \
      "claude" \
      "$repo_dir" \
      "${TOOL_ROOT}/examples/diagram.puml" \
      "$events_log" \
      "$stderr_log" \
      "$output_last_message"
  status=$?
  set -e

  at_assert_eq 0 "$status" "claude adapter should recover a post-completion hang"
  at_assert_file_exists "$output_last_message" "recovered claude run should still write output_last_message"

  local output_text events_text
  output_text="$(cat "$output_last_message")"
  at_assert_contains "$output_text" "fake claude response" "recovered claude output should be preserved"

  events_text="$(cat "$events_log")"
  at_assert_contains "$events_text" "post-completion-hang-recovered" \
    "claude adapter should log its hang recovery event"
}

echo "=== test_adapters.sh ==="

at_run_case "claude_adapter_happy_path_writes_output_last_message" \
  case_claude_adapter_happy_path_writes_output_last_message
at_run_case "claude_adapter_complete_then_hang_recovers" \
  case_claude_adapter_complete_then_hang_recovers

at_finish_suite
