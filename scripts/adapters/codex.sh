#!/usr/bin/env bash
set -euo pipefail

timestamp_utc_adapter() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_adapter_event() {
  local events_log="$1"
  local phase="$2"
  local iteration="$3"
  local run_time
  run_time="$(timestamp_utc_adapter)"

  printf '{"type":"andvari.adapter","adapter":"codex","phase":"%s","iteration":"%s","time":"%s"}\n' \
    "$phase" "$iteration" "$run_time" >> "$events_log"
}

codex_check_prereqs() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "codex CLI not found. Install Codex CLI and ensure 'codex' is on PATH." >&2
    return 1
  fi

  local codex_home="${CODEX_HOME:-${HOME}/.codex}"
  local session_dir="${codex_home}/sessions"
  if [[ -e "$codex_home" && ! -w "$codex_home" ]]; then
    cat >&2 <<PREREQ_EOF
codex CLI home is not writable: ${codex_home}
Fix ownership/permissions, for example:
  sudo chown -R \$(whoami) "${codex_home}"
PREREQ_EOF
    return 1
  fi
  if [[ -e "$session_dir" && ! -w "$session_dir" ]]; then
    cat >&2 <<PREREQ_EOF
codex CLI session directory is not writable: ${session_dir}
Fix ownership/permissions, for example:
  sudo chown -R \$(whoami) "${codex_home}"
PREREQ_EOF
    return 1
  fi

  if ! codex login status >/dev/null 2>&1; then
    cat >&2 <<'PREREQ_EOF'
codex CLI is not authenticated.
Run one of:
  codex login
  printenv OPENAI_API_KEY | codex login --with-api-key
PREREQ_EOF
    return 1
  fi
}

run_codex_prompt() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
  local prompt_file="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"

  local input_dir
  input_dir="$(cd "$(dirname "$input_diagram_path")" && pwd)"

  set +e
  (
    cd "$new_repo_dir"
    codex exec \
      --skip-git-repo-check \
      --full-auto \
      --add-dir "$input_dir" \
      --json \
      --output-last-message "$output_last_message" \
      - < "$prompt_file"
  ) >> "$events_log" 2>> "$stderr_log"
  local status=$?
  set -e

  return "$status"
}

codex_run_initial_reconstruction() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
  local events_log="$3"
  local stderr_log="$4"
  local output_last_message="$5"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_initial_reconstruction "$prompt_file"

  append_adapter_event "$events_log" "initial" "0"
  local status
  set +e
  run_codex_prompt \
    "$new_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

codex_run_fix_iteration() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
  local gate_summary_file="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"
  local iteration="$7"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_fix_iteration "$prompt_file" "$gate_summary_file"

  append_adapter_event "$events_log" "repair-fixed" "$iteration"
  local status
  set +e
  run_codex_prompt \
    "$new_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

codex_run_gate_declaration() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
  local events_log="$3"
  local stderr_log="$4"
  local output_last_message="$5"
  local max_gate_revisions="$6"

  local prompt_file
  prompt_file="$(mktemp)"

  write_prompt_gate_declaration "$prompt_file" "$max_gate_revisions"

  append_adapter_event "$events_log" "declare" "0"
  local status
  set +e
  run_codex_prompt \
    "$new_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}

codex_run_implementation_iteration() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
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

  append_adapter_event "$events_log" "implement" "$iteration"
  local status
  set +e
  run_codex_prompt \
    "$new_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message"
  status=$?
  set -e

  rm -f "$prompt_file"
  return "$status"
}
