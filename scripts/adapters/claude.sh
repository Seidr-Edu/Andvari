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

  cat > "$prompt_file" <<'PROMPT_EOF'
Reconstruct this Java repository from the source-of-truth diagram at:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Execution:
1. Read ../input/diagram.puml.
2. Reconstruct the repo accordingly.
3. Run ./gate_recon.sh.
4. If gate fails, fix and rerun until it passes.

Scope constraints:
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Do not inspect or modify any other run directories.

Return a concise summary including final gate result.
PROMPT_EOF

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

  {
    cat <<'PROMPT_EOF'
Gate failed. Fix the repository and get gate_recon.sh to pass.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Actions:
1. Read the gate failure summary below.
2. Apply fixes in this repository.
3. Run ./gate_recon.sh.
4. If gate still fails, continue fixing and rerunning until it passes.
5. Return concise summary of root cause and fixes.

Gate failure summary (last ~200 lines):
PROMPT_EOF
    echo "----- BEGIN GATE SUMMARY -----"
    cat "$gate_summary_file"
    echo "----- END GATE SUMMARY -----"
  } > "$prompt_file"

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

  local max_gate_version=$((max_gate_revisions + 1))
  local prompt_file
  prompt_file="$(mktemp)"

  cat > "$prompt_file" <<PROMPT_EOF
You are in phase 1 (gate declaration only) for adaptive self-gating.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Goal for this phase:
- Define diagram-derived completion outcomes and initial verification gates before implementation.
- Do not implement production/test source code in this phase.

Create these files:
1) completion/outcomes.initial.json
   - JSON array only.
   - Each item: {"id","description","priority","diagram_rationale"}
   - priority must be exactly "core" or "non-core".
2) completion/gates.v1.json
   - JSON array only.
   - Each item: {"id","description","command","outcome_ids"}
   - outcome_ids must be a non-empty JSON array of outcome ids.
3) completion/run_all_gates.sh
   - Executable script.
   - It must locate the latest completion/gates.vN.json.
   - It must execute every gate command from that latest version.
   - It must write completion/proof/results.vN.json with per-gate records:
     {"gate_id","status","exit_code","log_path"}
   - It must write per-gate logs under completion/proof/logs/.
   - Exit non-zero if any gate fails.

Rules:
- Allowed gate versions are v1 through v${max_gate_version}.
- Every outcome id in outcomes.initial.json must appear in at least one gate outcome_ids entry in gates.v1.json.
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Do not inspect or modify any other run directories.

Return a concise summary of the declared outcomes and gates.
PROMPT_EOF

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

  local max_gate_version=$((max_gate_revisions + 1))
  local prompt_file
  prompt_file="$(mktemp)"

  {
    cat <<PROMPT_EOF
Adaptive self-gating implementation phase.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Mode details:
- completion/outcomes.initial.json is immutable after declaration.
- You may evolve verification strategy by adding/replacing completion/gates.vN.json.
- Allowed gate versions are v1 through v${max_gate_version}.
- The latest gate version must still map every initial outcome id to at least one gate.

Execution loop (continue until green):
1. Read the failure summary below.
2. Implement/fix the repository from the diagram.
3. Update completion/run_all_gates.sh and completion/proof/results.vN.json behavior as needed.
4. Run ./gate_hard.sh.
5. Run ./scripts/verify_outcome_coverage.sh --max-gate-revisions ${max_gate_revisions} --model-gate-timeout-sec ${model_gate_timeout_sec}
6. If either command fails, continue fixing and rerunning until both pass.

Scope constraints:
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Do not inspect or modify any other run directories.

Failure summary:
PROMPT_EOF
    echo "----- BEGIN GATE SUMMARY -----"
    cat "$gate_summary_file"
    echo "----- END GATE SUMMARY -----"
  } > "$prompt_file"

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
