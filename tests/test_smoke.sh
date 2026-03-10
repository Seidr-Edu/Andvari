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

  ROOT_DIR="$TOOL_ROOT"
  DIAGRAM_PATH="${TOOL_ROOT}/examples/diagram.puml"
  RUN_ID="smoke-run"
  ADAPTER="codex"
  AGENTS_TEMPLATE_PATH="${TOOL_ROOT}/AGENTS.model.md"
  export ANDVARI_RUNS_DIR="${tmp}/runs"

  adapter_check_prereqs "$ADAPTER"
  andvari_init_workspace
  andvari_init_artifact_paths

  at_assert_dir_exists "$RUN_DIR" "run directory should be created"
  at_assert_file_exists "${INPUT_DIR}/diagram.puml" "diagram should be copied into input directory"
  at_assert_file_exists "${NEW_REPO_DIR}/AGENTS.md" "selected AGENTS template should be copied into new repo"
  at_assert_file_exists "${NEW_REPO_DIR}/gate_hard.sh" "hard gate script should be copied into new repo"
  at_assert_file_exists "${NEW_REPO_DIR}/scripts/verify_outcome_coverage.sh" "verification script should be copied into new repo"
  at_assert_file_exists "${EVENTS_LOG}" "events log should be initialized"
}

at_run_case "help_uses_runner_usage" case_help_uses_runner_usage
at_run_case "workspace_init_copies_required_artifacts" case_workspace_init_copies_required_artifacts
at_finish_suite
