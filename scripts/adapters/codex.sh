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

append_adapter_runtime_event() {
  local events_log="$1"
  local event="$2"
  local run_time
  run_time="$(timestamp_utc_adapter)"

  printf '{"type":"andvari.adapter","adapter":"codex","phase":"provider-runtime","iteration":"-","event":"%s","time":"%s"}\n' \
    "$event" "$run_time" >> "$events_log"
}

# _codex_prompts_dir - returns the absolute path to the prompts directory.
_codex_prompts_dir() {
  echo "${ROOT_DIR}/prompts"
}

# _codex_render_template TEMPLATE_NAME [VAR=VALUE ...]
# Reads the named template from the prompts directory and substitutes
# any VAR=VALUE pairs supplied as extra arguments.
# Prints the rendered content to stdout; returns 1 if the file is missing.
_codex_render_template() {
  local template_name="$1"
  shift
  local prompts_dir
  prompts_dir="$(_codex_prompts_dir)"
  local template_path="${prompts_dir}/${template_name}"

  [[ -f "$template_path" ]] || {
    echo "Prompt template not found: ${template_path}" >&2
    return 1
  }

  local content
  # Preserve trailing newlines from the template. Command substitution would
  # strip them and can accidentally join the next appended section onto the
  # final template line.
  IFS= read -r -d '' content < "$template_path" || true

  # Callers only pass pre-validated integer values; substitution is safe.
  local pair key val
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    content="${content//\$\{${key}\}/${val}}"
  done

  # Use printf '%s' so output matches the template's existing newline layout.
  printf '%s' "$content"
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

  local prompts_dir
  prompts_dir="$(_codex_prompts_dir)"
  local required_templates=(
    "initial_reconstruction.md"
    "fix_iteration.md"
    "gate_declaration.md"
    "implementation_iteration.md"
    "test_port_initial.md"
    "test_port_iteration.md"
  )
  local tpl
  for tpl in "${required_templates[@]}"; do
    [[ -f "${prompts_dir}/${tpl}" ]] || {
      echo "Required prompt template not found: ${prompts_dir}/${tpl}" >&2
      return 1
    }
  done
}

_codex_completion_grace_sec() {
  local raw="${ANDVARI_TEST_CODEX_COMPLETION_GRACE_SEC:-30}"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '%s' "$raw"
  else
    printf '30'
  fi
}

_codex_process_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

_codex_signal_process_group() {
  local signal="$1"
  local pid="$2"

  kill -s "$signal" -- "-${pid}" 2>/dev/null || kill -s "$signal" "$pid" 2>/dev/null || true
}

_codex_exec_in_process_group() {
  if command -v setsid >/dev/null 2>&1; then
    exec setsid "$@"
  fi

  exec python3 -c '
import os, sys
argv = sys.argv[1:]
os.setsid()
os.execvp(argv[0], argv)
' "$@"
}

_codex_flush_file_delta() {
  local source_path="$1"
  local target_path="$2"
  local previous_size="${3:-0}"
  local current_size="0"

  if [[ -f "$source_path" ]]; then
    current_size="$(wc -c < "$source_path" | tr -d '[:space:]')"
  fi

  if (( current_size > previous_size )); then
    dd if="$source_path" bs=1 skip="$previous_size" count="$((current_size - previous_size))" status=none \
      >> "$target_path" 2>/dev/null || true
  fi

  printf '%s' "$current_size"
}

_codex_terminal_marker_seen() {
  local source_path="$1"
  [[ -f "$source_path" ]] || return 1
  grep -E -q 'task_complete|turn\.completed' "$source_path"
}

run_codex_prompt() {
  local new_repo_dir="$1"
  local input_diagram_path="$2"
  local prompt_file="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"
  shift 6
  local -a extra_args=("$@")

  local input_dir
  input_dir="$(cd "$(dirname "$input_diagram_path")" && pwd)"
  local grace_sec
  grace_sec="$(_codex_completion_grace_sec)"

  local stdout_spool stderr_spool
  stdout_spool="$(mktemp)"
  stderr_spool="$(mktemp)"

  local stdout_size="0"
  local stderr_size="0"
  local completion_seen="false"
  local completion_seen_at="0"
  local recovered_hang="false"
  local status="0"

  rm -f "$output_last_message"

  set +e
  (
    cd "$new_repo_dir"
    # Service containers are already isolated by Docker. Bypass Codex's inner
    # sandbox so it can operate on bind-mounted workspaces reliably, including
    # Docker Desktop's fakeowner mounts on macOS.
    local -a cmd=(
      codex exec
      --skip-git-repo-check
      --dangerously-bypass-approvals-and-sandbox
      --cd "$new_repo_dir"
      --add-dir "$input_dir"
    )
    if [[ ${#extra_args[@]} -gt 0 ]]; then
      cmd+=("${extra_args[@]}")
    fi
    cmd+=(
      --json
      --output-last-message "$output_last_message"
      -
    )
    _codex_exec_in_process_group "${cmd[@]}" < "$prompt_file"
  ) > "$stdout_spool" 2> "$stderr_spool" &
  local cmd_pid=$!

  while _codex_process_alive "$cmd_pid"; do
    stdout_size="$(_codex_flush_file_delta "$stdout_spool" "$events_log" "$stdout_size")"
    stderr_size="$(_codex_flush_file_delta "$stderr_spool" "$stderr_log" "$stderr_size")"

    if [[ "$completion_seen" != "true" ]] && _codex_terminal_marker_seen "$stdout_spool"; then
      completion_seen="true"
    fi

    if [[ "$completion_seen" == "true" && -e "$output_last_message" && "$completion_seen_at" == "0" ]]; then
      completion_seen_at="$(date +%s)"
    fi

    if [[ "$completion_seen_at" != "0" ]]; then
      local now
      now="$(date +%s)"
      if (( now - completion_seen_at >= grace_sec )); then
        append_adapter_runtime_event "$events_log" "post-completion-hang-recovered"
        _codex_signal_process_group TERM "$cmd_pid"
        sleep 2
        if _codex_process_alive "$cmd_pid"; then
          _codex_signal_process_group KILL "$cmd_pid"
        fi
        recovered_hang="true"
        break
      fi
    fi

    sleep 1
  done

  wait "$cmd_pid" 2>/dev/null
  status=$?
  set -e

  stdout_size="$(_codex_flush_file_delta "$stdout_spool" "$events_log" "$stdout_size")"
  stderr_size="$(_codex_flush_file_delta "$stderr_spool" "$stderr_log" "$stderr_size")"

  rm -f "$stdout_spool" "$stderr_spool"

  if [[ "$recovered_hang" == "true" ]]; then
    return 0
  fi

  return "$status"
}

codex_run_test_port_initial() {
  local working_repo_dir="$1"
  local input_diagram_path="$2"
  local original_repo_path="$3"
  local events_log="$4"
  local stderr_log="$5"
  local output_last_message="$6"

  local prompt_file
  prompt_file="$(mktemp)"
  _codex_render_template "test_port_initial.md" > "$prompt_file"

  append_adapter_event "$events_log" "test-port-initial" "0"
  local status
  set +e
  run_codex_prompt \
    "$working_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message" \
    --add-dir "$original_repo_path"
  status=$?
  set -e
  rm -f "$prompt_file"
  return "$status"
}

codex_run_test_port_iteration() {
  local working_repo_dir="$1"
  local input_diagram_path="$2"
  local original_repo_path="$3"
  local failure_summary_file="$4"
  local events_log="$5"
  local stderr_log="$6"
  local output_last_message="$7"
  local iteration="$8"

  local prompt_file
  prompt_file="$(mktemp)"
  _codex_render_template "test_port_iteration.md" \
    "FAILURE_SUMMARY=$(cat "$failure_summary_file" 2>/dev/null || true)" \
    > "$prompt_file"

  append_adapter_event "$events_log" "test-port-iter" "$iteration"
  local status
  set +e
  run_codex_prompt \
    "$working_repo_dir" \
    "$input_diagram_path" \
    "$prompt_file" \
    "$events_log" \
    "$stderr_log" \
    "$output_last_message" \
    --add-dir "$original_repo_path"
  status=$?
  set -e
  rm -f "$prompt_file"
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

  _codex_render_template "initial_reconstruction.md" > "$prompt_file"

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

  {
    _codex_render_template "fix_iteration.md"
    echo "----- BEGIN GATE SUMMARY -----"
    cat "$gate_summary_file"
    echo "----- END GATE SUMMARY -----"
  } > "$prompt_file"

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

  local max_gate_version=$((max_gate_revisions + 1))
  local prompt_file
  prompt_file="$(mktemp)"

  _codex_render_template "gate_declaration.md" \
    "MAX_GATE_VERSION=${max_gate_version}" \
    > "$prompt_file"

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

  local max_gate_version=$((max_gate_revisions + 1))
  local prompt_file
  prompt_file="$(mktemp)"

  {
    _codex_render_template "implementation_iteration.md" \
      "MAX_GATE_VERSION=${max_gate_version}" \
      "MAX_GATE_REVISIONS=${max_gate_revisions}" \
      "MODEL_GATE_TIMEOUT_SEC=${model_gate_timeout_sec}"
    echo "----- BEGIN GATE SUMMARY -----"
    cat "$gate_summary_file"
    echo "----- END GATE SUMMARY -----"
  } > "$prompt_file"

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
