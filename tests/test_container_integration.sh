#!/usr/bin/env bash
# test_container_integration.sh — End-to-end container service tests.
#
# Builds andvari:local, runs it with the DO mount contract, and asserts that
# canonical outputs are emitted.
#
# Skip conditions:
#   ANDVARI_SKIP_CONTAINER_TESTS=1   explicit skip (e.g., CI without Docker)
#   docker not on PATH               silently skip with a warning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tests/lib/testlib.sh
source "${SCRIPT_DIR}/lib/testlib.sh"

# ── Skip guard ────────────────────────────────────────────────────────────────
if [[ "${ANDVARI_SKIP_CONTAINER_TESTS:-0}" == "1" ]]; then
  echo "=== test_container_integration.sh: SKIPPED (ANDVARI_SKIP_CONTAINER_TESTS=1) ==="
  exit 0
fi

if ! command -v docker &>/dev/null; then
  echo "=== test_container_integration.sh: SKIPPED (docker not on PATH) ==="
  exit 0
fi

echo "=== test_container_integration.sh ==="

# ── Build image ───────────────────────────────────────────────────────────────
echo "[integration] Building andvari:local …"
docker build -t andvari:local "$ROOT_DIR" >/dev/null

# ── Helpers ───────────────────────────────────────────────────────────────────

# Create a minimal fake codex binary that satisfies codex_check_prereqs and
# supports explicit hang modes for wrapper recovery tests.
_write_fake_codex_bin() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "${bin_dir}/codex" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  login)
    # codex login status -> 0
    exit 0
    ;;
  exec)
    shift
    output_last_message=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output-last-message" && $# -gt 1 ]]; then
        output_last_message="$2"
        shift 2
      else
        shift
      fi
    done
    case "${ANDVARI_TEST_CODEX_MODE:-success}" in
      success)
        if [[ -n "$output_last_message" ]]; then
          touch "$output_last_message" 2>/dev/null || true
        fi
        exit 0
        ;;
      complete-then-hang)
        if [[ -n "$output_last_message" ]]; then
          touch "$output_last_message" 2>/dev/null || true
        fi
        printf '{"type":"task_complete"}\n'
        while true; do
          sleep 60
        done
        ;;
      *)
        exit 2
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
SH
  chmod +x "${bin_dir}/codex"
}

case_image_default_user_is_non_root() {
  local uid
  uid="$(docker run --rm --entrypoint id andvari:local -u)"

  if [[ "$uid" == "0" ]]; then
    echo "ASSERT failed: container default user must not be root" >&2
    return 1
  fi
}

# ── Case: basic container run emits canonical outputs ────────────────────────
case_container_run_emits_outputs() {
  local tmp; tmp="$(at_mktemp_dir)"

  local input_model_dir="${tmp}/input_model"
  local config_dir="${tmp}/config"
  local run_dir="${tmp}/run"
  local provider_bin_dir="${tmp}/provider_bin"
  local provider_seed_dir="${tmp}/provider_seed"

  mkdir -p "$input_model_dir" "$config_dir" "$run_dir" \
           "${provider_seed_dir}/sessions"
  chmod 0777 "$run_dir"
  _write_fake_codex_bin "$provider_bin_dir"

  # Stage diagram
  cp "${ROOT_DIR}/examples/diagram.puml" "${input_model_dir}/diagram.puml"

  # Write manifest
  cat > "${config_dir}/manifest.yaml" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 1
diagram_relpath: diagram.puml
YAML

  chmod -R a+rX "$input_model_dir" "$config_dir" "$provider_bin_dir" "$provider_seed_dir"

  # Run container with the DO mount contract
  local container_exit=0
  docker run --rm \
    -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
    -e CODEX_HOME=/run/provider-state/codex-home \
    -e PATH="/opt/provider/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    -v "${input_model_dir}:/input/model:ro" \
    -v "${config_dir}:/run/config:ro" \
    -v "${run_dir}:/run" \
    -v "${provider_bin_dir}:/opt/provider/bin:ro" \
    -v "${provider_seed_dir}:/opt/provider-seed/codex-home:ro" \
    andvari:local \
    || container_exit=$?

  # Service exits 0 when run_report.json is emitted (even if runner gate failed)
  at_assert_eq 0 "$container_exit" \
    "container should exit 0 (run_report.json emitted)"

  at_assert_file_exists "${run_dir}/outputs/run_report.json" \
    "/run/outputs/run_report.json must be written"
  at_assert_file_exists "${run_dir}/outputs/summary.md" \
    "/run/outputs/summary.md must be written"
  at_assert_dir_exists "${run_dir}/artifacts/generated-repo" \
    "/run/artifacts/generated-repo must exist"
  at_assert_dir_exists "${run_dir}/artifacts/andvari/logs" \
    "/run/artifacts/andvari/logs must exist"
  at_assert_dir_exists "${run_dir}/artifacts/andvari/report" \
    "/run/artifacts/andvari/report must exist"

  # Report must carry canonical service fields
  local schema_ver runner_invoked
  schema_ver="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('service_schema_version',''))")"
  runner_invoked="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(str(d.get('runner_invoked',False)).lower())")"

  at_assert_eq "andvari_service_report.v1" "$schema_ver" \
    "service_schema_version must be andvari_service_report.v1"
  at_assert_eq "true" "$runner_invoked" \
    "runner_invoked must be true in the report"
}

case_container_recovers_complete_then_hang() {
  local tmp; tmp="$(at_mktemp_dir)"

  local input_model_dir="${tmp}/input_model"
  local config_dir="${tmp}/config"
  local run_dir="${tmp}/run"
  local provider_bin_dir="${tmp}/provider_bin"
  local provider_seed_dir="${tmp}/provider_seed"

  mkdir -p "$input_model_dir" "$config_dir" "$run_dir" \
           "${provider_seed_dir}/sessions"
  chmod 0777 "$run_dir"
  _write_fake_codex_bin "$provider_bin_dir"

  cp "${ROOT_DIR}/examples/diagram.puml" "${input_model_dir}/diagram.puml"

  cat > "${config_dir}/manifest.yaml" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 0
diagram_relpath: diagram.puml
YAML

  chmod -R a+rX "$input_model_dir" "$config_dir" "$provider_bin_dir" "$provider_seed_dir"

  local container_exit=0
  docker run --rm \
    -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
    -e CODEX_HOME=/run/provider-state/codex-home \
    -e PATH="/opt/provider/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    -e ANDVARI_TEST_CODEX_MODE=complete-then-hang \
    -e ANDVARI_TEST_CODEX_COMPLETION_GRACE_SEC=1 \
    -v "${input_model_dir}:/input/model:ro" \
    -v "${config_dir}:/run/config:ro" \
    -v "${run_dir}:/run" \
    -v "${provider_bin_dir}:/opt/provider/bin:ro" \
    -v "${provider_seed_dir}:/opt/provider-seed/codex-home:ro" \
    andvari:local \
    || container_exit=$?

  at_assert_eq 0 "$container_exit" \
    "container should exit 0 after recovering a post-completion provider hang"
  at_assert_file_exists "${run_dir}/outputs/run_report.json" \
    "recovered hang must still write /run/outputs/run_report.json"
  at_assert_file_exists "${run_dir}/outputs/summary.md" \
    "recovered hang must still write /run/outputs/summary.md"

  local runner_invoked events_log events_contents
  runner_invoked="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(str(d.get('runner_invoked',False)).lower())")"
  at_assert_eq "true" "$runner_invoked" \
    "runner_invoked must stay true after hang recovery"

  events_log="${run_dir}/artifacts/andvari/logs/adapter_events.jsonl"
  at_assert_file_exists "$events_log" \
    "recovered hang must promote adapter events to the canonical logs directory"
  events_contents="$(cat "$events_log")"
  at_assert_contains "$events_contents" "post-completion-hang-recovered" \
    "adapter events must record the container recovery path"
}

# ── Case: --help exits 0 ──────────────────────────────────────────────────────
case_help_flag_exits_0() {
  local help_exit=0
  docker run --rm andvari:local --help || help_exit=$?
  at_assert_eq 0 "$help_exit" "andvari-service.sh --help should exit 0"
}

# ── Case: missing manifest exits 0 and emits error report ────────────────────
case_missing_manifest_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local run_dir="${tmp}/run"
  mkdir -p "$run_dir"
  chmod 0777 "$run_dir"

  local container_exit=0
  docker run --rm \
    -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
    -v "${run_dir}:/run" \
    andvari:local \
    || container_exit=$?

  at_assert_eq 0 "$container_exit" \
    "container should exit 0 (error report emitted) for missing manifest"
  at_assert_file_exists "${run_dir}/outputs/run_report.json" \
    "error report must be written even when manifest is missing"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "missing-manifest" "$reason" \
    "report reason must be missing-manifest"
}

# ── Case: unsupported adapter exits 0 and emits error report ─────────────────
case_unsupported_adapter_container() {
  local tmp; tmp="$(at_mktemp_dir)"
  local config_dir="${tmp}/config"
  local run_dir="${tmp}/run"
  mkdir -p "$config_dir" "$run_dir"
  chmod 0777 "$run_dir"

  cat > "${config_dir}/manifest.yaml" <<'YAML'
version: 1
adapter: openai
YAML

  chmod -R a+rX "$config_dir"

  local container_exit=0
  docker run --rm \
    -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
    -v "${config_dir}:/run/config:ro" \
    -v "${run_dir}:/run" \
    andvari:local \
    || container_exit=$?

  at_assert_eq 0 "$container_exit" \
    "container should exit 0 (error report emitted) for unsupported adapter"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "unsupported-adapter" "$reason" "report reason must be unsupported-adapter"
}

# ─────────────────────────────────────────────────────────────────────────────
# Run all cases
# ─────────────────────────────────────────────────────────────────────────────
at_run_case "image_default_user_is_non_root"    case_image_default_user_is_non_root
at_run_case "help_flag_exits_0"                 case_help_flag_exits_0
at_run_case "missing_manifest_emits_report"     case_missing_manifest_emits_report
at_run_case "unsupported_adapter_container"     case_unsupported_adapter_container
at_run_case "container_run_emits_outputs"       case_container_run_emits_outputs
at_run_case "container_recovers_complete_then_hang" case_container_recovers_complete_then_hang

at_finish_suite
