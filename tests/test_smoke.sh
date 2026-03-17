#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/testlib.sh"
# shellcheck source=/dev/null
source "${TOOL_ROOT}/scripts/adapters/adapter.sh"
# shellcheck source=/dev/null
source "${TOOL_ROOT}/scripts/lib/runner_common.sh"
# shellcheck source=/dev/null
source "${TOOL_ROOT}/scripts/lib/runner_workspace.sh"

setup_fake_codex() {
  local root="$1"
  local fake_bin="${root}/bin"
  mkdir -p "$fake_bin"

  cat > "${fake_bin}/codex" <<'CODEX'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then
  exit 0
fi

printf 'unexpected fake codex invocation\n' >&2
exit 1
CODEX

  chmod +x "${fake_bin}/codex"
  export PATH="${fake_bin}:$PATH"
  export CODEX_HOME="${root}/codex-home"
  mkdir -p "${CODEX_HOME}/sessions"
}

case_help_uses_runner_usage() {
  local output
  output="$("${TOOL_ROOT}/andvari-run.sh" --help)"
  at_assert_contains "$output" "--diagram" "help output should mention required arguments"
  at_assert_contains "$output" "--adapter" "help output should mention adapter selection"
}

case_workspace_init_copies_required_artifacts() {
  local tmp
  tmp="$(at_mktemp_dir)"
  setup_fake_codex "$tmp"

  # shellcheck disable=SC2034
  ROOT_DIR="$TOOL_ROOT"
  # shellcheck disable=SC2034
  DIAGRAM_PATH="${TOOL_ROOT}/examples/diagram.puml"
  # shellcheck disable=SC2034
  RUN_ID="smoke-run"
  ADAPTER="codex"
  # shellcheck disable=SC2034
  AGENTS_TEMPLATE_PATH="${TOOL_ROOT}/AGENTS.model.md"
  export ANDVARI_RUNS_DIR="${tmp}/runs"

  adapter_check_prereqs "$ADAPTER"
  andvari_init_workspace
  andvari_init_artifact_paths

  at_assert_dir_exists "$RUN_DIR" "run directory should be created"
  at_assert_file_exists "${INPUT_DIR}/diagram.puml" "diagram should be copied into input directory"
  at_assert_file_exists "${NEW_REPO_DIR}/AGENTS.md" "selected AGENTS template should be copied into new repo"
  at_assert_file_exists "${NEW_REPO_DIR}/docs/CODE_QUALITY_RULES.md" "quality rules summary should be staged into the run repo"
  at_assert_file_exists "${NEW_REPO_DIR}/completion/context/sonar_rules.lock.json" "quality rules lock file should be staged into the run repo"
  at_assert_file_exists "${NEW_REPO_DIR}/completion/context/sonar_rules_manifest.json" "quality rules manifest should be staged into the run repo"
  at_assert_file_exists "${NEW_REPO_DIR}/gate_hard.sh" "hard gate script should be copied into new repo"
  at_assert_file_exists "${NEW_REPO_DIR}/scripts/verify_outcome_coverage.sh" "verification script should be copied into new repo"
  at_assert_file_not_exists "${NEW_REPO_DIR}/profile-backup.xml" "archival profile backup must not be staged into the run repo"
  at_assert_file_not_exists "${NEW_REPO_DIR}/rules.raw.json" "archival raw rules export must not be staged into the run repo"
  at_assert_file_exists "${EVENTS_LOG}" "events log should be initialized"
}

case_prompts_reference_staged_quality_rules() {
  local model_agents
  model_agents="$(cat "${TOOL_ROOT}/AGENTS.model.md")"
  at_assert_contains "$model_agents" "docs/CODE_QUALITY_RULES.md" "model AGENTS should mention the staged quality rules summary"
  at_assert_contains "$model_agents" "diagram's behavior" "model AGENTS should preserve diagram precedence"

  local fixed_agents
  fixed_agents="$(cat "${TOOL_ROOT}/AGENTS.fixed.md")"
  at_assert_contains "$fixed_agents" "completion/context/sonar_rules.lock.json" "fixed AGENTS should mention the staged quality rules lock file"
  at_assert_contains "$fixed_agents" "diagram's behavior" "fixed AGENTS should preserve diagram precedence"

  local gate_prompt
  gate_prompt="$(cat "${TOOL_ROOT}/prompts/gate_declaration.md")"
  at_assert_contains "$gate_prompt" 'Read `docs/CODE_QUALITY_RULES.md`' "gate declaration prompt should read the quality rules summary first"
  at_assert_contains "$gate_prompt" "non-functional quality constraints only" "gate declaration prompt should distinguish behavioral and quality sources"
}

at_run_case "help_uses_runner_usage" case_help_uses_runner_usage
at_run_case "workspace_init_copies_required_artifacts" case_workspace_init_copies_required_artifacts
at_run_case "prompts_reference_staged_quality_rules" case_prompts_reference_staged_quality_rules
at_finish_suite
