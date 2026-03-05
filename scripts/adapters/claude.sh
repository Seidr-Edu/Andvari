#!/usr/bin/env bash
set -euo pipefail

timestamp_utc_adapter_claude() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_claude_adapter_event() {
  local events_log="$1"
  local phase="$2"
  local iteration="$3"
  local run_time
  run_time="$(timestamp_utc_adapter_claude)"

  printf '{"type":"andvari.adapter","adapter":"claude","phase":"%s","iteration":"%s","time":"%s"}\n' \
    "$phase" "$iteration" "$run_time" >> "$events_log"
}

claude_check_prereqs() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "claude CLI not found. Install Claude Code and ensure 'claude' is on PATH." >&2
    return 1
  fi

  if ! claude --version >/dev/null 2>&1; then
    cat >&2 <<'PREREQ_EOF'
claude CLI is installed but failed a basic health check.
Run:
  claude --version
Then verify the CLI is authenticated/configured for non-interactive use.
PREREQ_EOF
    return 1
  fi
}

run_claude_prompt() {
  local new_repo_dir="$1"
  local prompt_file="$2"
  local events_log="$3"
  local stderr_log="$4"
  local output_last_message="$5"

  local response_file
  response_file="$(mktemp)"

  set +e
  (
    cd "$new_repo_dir"
    claude --print < "$prompt_file"
  ) > "$response_file" 2>> "$stderr_log"
  local status=$?
  set -e

  cat "$response_file" >> "$events_log"
  cp "$response_file" "$output_last_message"
  rm -f "$response_file"

  return "$status"
}

claude_run_initial_reconstruction() {
  local new_repo_dir="$1"
  local _input_diagram_path="$2"
  local events_log="$3"
  local stderr_log="$4"
  local output_last_message="$5"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_initial_reconstruction "$prompt_file"

  append_claude_adapter_event "$events_log" "initial" "0"
  local status
  set +e
  run_claude_prompt \
    "$new_repo_dir" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

claude_run_fix_iteration() {
  local new_repo_dir="$1"
  local _input_diagram_path="$2"
  local gate_summary_file="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"
  local iteration="$7"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_fix_iteration "$prompt_file" "$gate_summary_file"

  append_claude_adapter_event "$events_log" "repair-fixed" "$iteration"
  local status
  set +e
  run_claude_prompt \
    "$new_repo_dir" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

claude_run_gate_declaration() {
  local new_repo_dir="$1"
  local _input_diagram_path="$2"
  local events_log="$3"
  local stderr_log="$4"
  local output_last_message="$5"
  local max_gate_revisions="$6"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_gate_declaration "$prompt_file" "$max_gate_revisions"

  append_claude_adapter_event "$events_log" "declare" "0"
  local status
  set +e
  run_claude_prompt \
    "$new_repo_dir" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

claude_run_implementation_iteration() {
  local new_repo_dir="$1"
  local _input_diagram_path="$2"
  local gate_summary_file="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"
  local iteration="$7"
  local max_gate_revisions="$8"
  local model_gate_timeout_sec="$9"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_implementation_iteration \
    "$prompt_file" \
    "$gate_summary_file" \
    "$max_gate_revisions" \
    "$model_gate_timeout_sec"

  append_claude_adapter_event "$events_log" "implement" "$iteration"
  local status
  set +e
  run_claude_prompt \
    "$new_repo_dir" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}
