#!/usr/bin/env bash
# test_service.sh — Unit tests for andvari-service.sh
#
# Uses ANDVARI_SERVICE_RUN_DIR and ANDVARI_SERVICE_INPUT_DIR overrides so
# all tests run in isolated temp directories without touching /run or /input/model.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tests/lib/testlib.sh
source "${SCRIPT_DIR}/lib/testlib.sh"

# ── Helper: write a minimal valid manifest ────────────────────────────────────
_write_valid_manifest() {
  local path="$1"
  cat > "$path" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 1
diagram_relpath: diagram.puml
YAML
}

# ── Helper: create a minimal fake codex binary ───────────────────────────────
# Handles `codex login status` plus explicit test modes for `codex exec`.
_write_fake_codex() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "${bin_dir}/codex" <<'SH'
#!/usr/bin/env bash
if [[ -n "${ANDVARI_TEST_CODEX_ARGS_LOG:-}" ]]; then
  {
    printf 'argv:'
    printf ' %q' "$@"
    printf '\n'
  } >> "${ANDVARI_TEST_CODEX_ARGS_LOG}"
fi
case "${1:-}" in
  login)
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
    if [[ -n "${ANDVARI_TEST_CODEX_PID_FILE:-}" ]]; then
      printf '%s\n' "$$" > "${ANDVARI_TEST_CODEX_PID_FILE}"
    fi
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
      hang-before-complete)
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

# ── Helper: create provider seed dir (satisfies CODEX_HOME sessions check) ───
_write_provider_seed() {
  local seed_dir="$1"
  mkdir -p "${seed_dir}/sessions"
}

# ── Helper: run the service in full isolation ─────────────────────────────────
# Args: TMPROOT (temp base), manifest_path, diagram_exists (yes|no)
# Returns the service exit code via global _SVC_EXIT.
_run_service_in_tmproot() {
  local tmproot="$1"
  local manifest_path="$2"
  local diagram_exists="${3:-yes}"

  local run_dir="${tmproot}/run"
  local input_dir="${tmproot}/input_model"
  local bin_dir="${tmproot}/provider_bin"
  local seed_dir="${tmproot}/provider_seed"

  mkdir -p "$run_dir" "$input_dir" "$bin_dir" "$seed_dir"
  _write_fake_codex "$bin_dir"
  _write_provider_seed "$seed_dir"

  if [[ "$diagram_exists" == "yes" ]]; then
    cp "${ROOT_DIR}/examples/diagram.puml" "${input_dir}/diagram.puml"
  fi

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest_path" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
  ANDVARI_SERVICE_INPUT_DIR="$input_dir" \
  ANDVARI_SERVICE_PROVIDER_BIN="$bin_dir" \
  ANDVARI_SERVICE_PROVIDER_SEED="$seed_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  _SVC_EXIT=$svc_exit
  _SVC_RUN_DIR="$run_dir"
}

_assert_pid_file_reaped() {
  local pid_file="$1"
  local msg="${2:-expected process to be reaped}"
  local pid=""
  local remaining_checks=5

  at_assert_file_exists "$pid_file" "pid file must exist before checking process cleanup"
  pid="$(tr -d '[:space:]' < "$pid_file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || {
    printf 'ASSERT failed: pid file did not contain a numeric pid\nfile: %s\nvalue: %s\n' "$pid_file" "$pid" >&2
    return 1
  }

  while (( remaining_checks > 0 )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    remaining_checks=$((remaining_checks - 1))
    sleep 1
  done

  printf 'ASSERT failed: %s\npid: %s\n' "$msg" "$pid" >&2
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST CASES
# ─────────────────────────────────────────────────────────────────────────────

# ── 1. valid manifest startup ─────────────────────────────────────────────────
# The service loads a fully valid manifest, bootstraps the provider, invokes
# the runner (which will fail the gate with fake codex output), and still emits
# a machine-readable report + exits 0.
case_valid_manifest_startup() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  _write_valid_manifest "$manifest"

  _run_service_in_tmproot "$tmp" "$manifest" "yes"

  at_assert_eq 0 "$_SVC_EXIT" "service should exit 0 when report is emitted"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/run_report.json" "run_report.json must exist"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/summary.md" "summary.md must exist"
}

# ── 1b. codex exec uses container-safe flags ─────────────────────────────────
case_codex_exec_uses_container_safe_flags() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  local args_log="${tmp}/codex_args.log"

  cat > "$manifest" <<'YAML'
version: 1
run_id: 20260314T080000Z__flags
adapter: codex
gating_mode: fixed
max_iter: 1
diagram_relpath: diagram.puml
YAML

  local run_dir="${tmp}/run"
  local input_dir="${tmp}/input_model"
  local bin_dir="${tmp}/provider_bin"
  local seed_dir="${tmp}/provider_seed"

  mkdir -p "$run_dir" "$input_dir" "$bin_dir" "$seed_dir"
  _write_fake_codex "$bin_dir"
  _write_provider_seed "$seed_dir"
  cp "${ROOT_DIR}/examples/diagram.puml" "${input_dir}/diagram.puml"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
  ANDVARI_SERVICE_INPUT_DIR="$input_dir" \
  ANDVARI_SERVICE_PROVIDER_BIN="$bin_dir" \
  ANDVARI_SERVICE_PROVIDER_SEED="$seed_dir" \
  ANDVARI_TEST_CODEX_ARGS_LOG="$args_log" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service should exit 0 when report is emitted"
  at_assert_file_exists "$args_log" "fake codex must record exec arguments"

  if ! grep -q -- '--dangerously-bypass-approvals-and-sandbox' "$args_log"; then
    echo "ASSERT failed: codex exec must bypass the inner sandbox in service mode" >&2
    return 1
  fi
  if grep -q -- '--full-auto' "$args_log"; then
    echo "ASSERT failed: codex exec must not rely on --full-auto in service mode" >&2
    return 1
  fi
  if ! grep -q -- '--cd' "$args_log"; then
    echo "ASSERT failed: codex exec must set an explicit working root" >&2
    return 1
  fi
  if ! grep -q -- '/run/runner-internal/20260314T080000Z__flags/new_repo' "$args_log"; then
    echo "ASSERT failed: codex exec must target the generated repo workspace" >&2
    return 1
  fi
}

# ── 2. malformed YAML emits report ────────────────────────────────────────────
case_malformed_yaml_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  printf 'version: 1\nadapter: codex\nbad: [unclosed\n' > "$manifest"

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service should exit 0 (report emitted) even on malformed manifest"
  at_assert_file_exists "${run_dir}/outputs/run_report.json" "report must be emitted for malformed manifest"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "invalid-manifest" "$reason" "reason must be invalid-manifest"
}

# ── 3. unknown manifest key is rejected ───────────────────────────────────────
case_unknown_key_rejected() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
unknown_field: oops
YAML

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service should exit 0 (report emitted) for unknown manifest key"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "unknown-manifest-key" "$reason" "reason must be unknown-manifest-key"
}

# ── 4. missing diagram emits report ──────────────────────────────────────────
case_invalid_gating_mode_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
gating_mode: maybe
YAML

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service should exit 0 (report emitted) for invalid gating_mode"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "invalid-manifest" "$reason" "reason must be invalid-manifest"
}

# ── 5. missing diagram emits report ──────────────────────────────────────────
case_missing_diagram_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  _write_valid_manifest "$manifest"

  # Intentionally do NOT create input_model/diagram.puml
  _run_service_in_tmproot "$tmp" "$manifest" "no"

  at_assert_eq 0 "$_SVC_EXIT" "service should exit 0 (report emitted) for missing diagram"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/run_report.json"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "missing-diagram" "$reason" "reason must be missing-diagram"
}

# ── 6. unsupported adapter emits report ──────────────────────────────────────
case_unsupported_adapter_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  cat > "$manifest" <<'YAML'
version: 1
adapter: claude
gating_mode: model
YAML

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service should exit 0 (report emitted) for unsupported adapter"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  local reason status
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  status="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('status',''))")"
  at_assert_eq "unsupported-adapter" "$reason" "reason must be unsupported-adapter"
  at_assert_eq "error" "$status" "status must be error"
}

# ── 7. env override wins over manifest adapter ────────────────────────────────
# Manifest says codex; env forces claude → service should reject as unsupported
# but crucially used the env value, not the manifest value.
case_env_overrides_manifest_adapter() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  _write_valid_manifest "$manifest"  # adapter: codex

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_ADAPTER="claude" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service exits 0 when report is emitted"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  # The report's adapter field must reflect the env override, not the manifest
  local adapter_in_report
  adapter_in_report="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('adapter',''))")"
  at_assert_eq "claude" "$adapter_in_report" "adapter in report must be the env-overridden value"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "unsupported-adapter" "$reason" "should reject claude as unsupported"
}

# ── 8. invalid run_id emits report ────────────────────────────────────────────
case_invalid_run_id_emits_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
run_id: "bad run id!"
YAML

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  at_assert_eq 0 "$svc_exit" "service exits 0 even for invalid run_id (report emitted)"
  at_assert_file_exists "${run_dir}/outputs/run_report.json"

  local reason
  reason="$(python3 -c "import json; d=json.load(open('${run_dir}/outputs/run_report.json')); print(d.get('reason',''))")"
  at_assert_eq "invalid-run-id" "$reason" "reason must be invalid-run-id"
}

# ── 9. non-writable run dir — exits 1, no report ─────────────────────────────
case_non_writable_run_dir_exits_1() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  _write_valid_manifest "$manifest"

  local run_dir="${tmp}/locked_run"
  mkdir -p "$run_dir"
  chmod 555 "$run_dir"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  chmod 755 "$run_dir"  # restore so cleanup can delete it
  at_assert_eq 1 "$svc_exit" "service must exit 1 when run dir is not writable"
}

# ── 10. non-writable outputs dir — exits 1, no report ───────────────────────
case_non_writable_outputs_dir_exits_1() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  _write_valid_manifest "$manifest"

  local run_dir="${tmp}/run"
  mkdir -p "${run_dir}/outputs"
  chmod 755 "$run_dir"
  chmod 555 "${run_dir}/outputs"

  local svc_exit=0
  ANDVARI_MANIFEST="$manifest" \
  ANDVARI_SERVICE_RUN_DIR="$run_dir" \
    bash "${ROOT_DIR}/andvari-service.sh" || svc_exit=$?

  chmod 755 "${run_dir}/outputs"
  at_assert_eq 1 "$svc_exit" "service must exit 1 when outputs dir is not writable"
}

# ── 11. artifact promotion writes canonical output dirs ──────────────────────
# Verifies that after a full service run (runner exits 1 due to gate failure
# with fake codex), all canonical output directories and the report file exist.
case_artifact_promotion_layout() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 1
diagram_relpath: diagram.puml
YAML

  _run_service_in_tmproot "$tmp" "$manifest" "yes"

  # Service exits 0 regardless of gate result because it emitted a report
  at_assert_eq 0 "$_SVC_EXIT" "service should exit 0 after promoting artifacts"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/run_report.json"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/summary.md"
  at_assert_dir_exists  "${_SVC_RUN_DIR}/artifacts/generated-repo"
  at_assert_dir_exists  "${_SVC_RUN_DIR}/artifacts/andvari/logs"
  at_assert_dir_exists  "${_SVC_RUN_DIR}/artifacts/andvari/report"
  if compgen -G "${_SVC_RUN_DIR}/runner-internal/*" >/dev/null; then
    echo "ASSERT failed: runner-internal should be cleaned after report promotion" >&2
    return 1
  fi

  # service_schema_version must be present
  local schema_ver
  schema_ver="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('service_schema_version',''))")"
  at_assert_eq "andvari_service_report.v1" "$schema_ver" "service_schema_version must be set"

  local runner_schema runner_max_iter runner_max_gate_revisions
  runner_schema="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('schema_version',''))")"
  runner_max_iter="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(str(d.get('max_iter','')))")"
  runner_max_gate_revisions="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(str(d.get('max_gate_revisions','')))")"
  at_assert_eq "run_report.v1" "$runner_schema" "runner schema_version must be preserved"
  at_assert_eq "1" "$runner_max_iter" "runner max_iter must be preserved"
  at_assert_eq "3" "$runner_max_gate_revisions" "runner max_gate_revisions must be preserved"

  # runner_invoked must be true
  local runner_invoked
  runner_invoked="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(str(d.get('runner_invoked',False)).lower())")"
  at_assert_eq "true" "$runner_invoked" "runner_invoked must be true in the report"
}

case_complete_then_hang_recovers_and_reports() {
  local baseline_tmp; baseline_tmp="$(at_mktemp_dir)"
  local baseline_manifest="${baseline_tmp}/manifest.yaml"
  cat > "$baseline_manifest" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 0
diagram_relpath: diagram.puml
YAML

  _run_service_in_tmproot "$baseline_tmp" "$baseline_manifest" "yes"

  local baseline_status
  baseline_status="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('status',''))")"

  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  local pid_file="${tmp}/codex.pid"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 0
diagram_relpath: diagram.puml
YAML

  ANDVARI_TEST_CODEX_MODE="complete-then-hang" \
  ANDVARI_TEST_CODEX_COMPLETION_GRACE_SEC="1" \
  ANDVARI_TEST_CODEX_PID_FILE="$pid_file" \
    _run_service_in_tmproot "$tmp" "$manifest" "yes"

  at_assert_eq 0 "$_SVC_EXIT" "service should exit 0 after recovering a post-completion provider hang"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/run_report.json" "run_report.json must exist after recovery"

  local status failure_scope reason events_log events_contents
  status="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('status',''))")"
  failure_scope="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('failure_scope') or '')")"
  reason="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('reason') or '')")"

  at_assert_eq "$baseline_status" "$status" "recovered hang should keep the normal runner-derived status"
  at_assert_eq "gate" "$failure_scope" "recovered hang should still classify using the runner result"
  at_assert_eq "" "$reason" "recovered hang should not be rewritten as a runner timeout"

  events_log="${_SVC_RUN_DIR}/artifacts/andvari/logs/adapter_events.jsonl"
  at_assert_file_exists "$events_log" "adapter events log must be promoted after recovery"
  events_contents="$(cat "$events_log")"
  at_assert_contains "$events_contents" "post-completion-hang-recovered" \
    "adapter events must record the post-completion recovery"
  _assert_pid_file_reaped "$pid_file" "recovered provider process should be reaped"

  if compgen -G "${_SVC_RUN_DIR}/runner-internal/*" >/dev/null; then
    echo "ASSERT failed: runner-internal should be cleaned after recovery" >&2
    return 1
  fi
}

case_hang_before_complete_emits_runner_timeout_report() {
  local tmp; tmp="$(at_mktemp_dir)"
  local manifest="${tmp}/manifest.yaml"
  local pid_file="${tmp}/codex.pid"
  cat > "$manifest" <<'YAML'
version: 1
adapter: codex
gating_mode: fixed
max_iter: 0
diagram_relpath: diagram.puml
YAML

  ANDVARI_TEST_CODEX_MODE="hang-before-complete" \
  ANDVARI_TEST_CODEX_PID_FILE="$pid_file" \
  ANDVARI_TEST_RUNNER_TIMEOUT_SEC="2" \
    _run_service_in_tmproot "$tmp" "$manifest" "yes"

  at_assert_eq 0 "$_SVC_EXIT" "service should exit 0 after emitting a runner timeout report"
  at_assert_file_exists "${_SVC_RUN_DIR}/outputs/run_report.json" "run_report.json must exist after runner timeout"

  local status failure_scope reason status_detail
  status="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('status',''))")"
  failure_scope="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('failure_scope') or '')")"
  reason="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('reason') or '')")"
  status_detail="$(python3 -c "import json; d=json.load(open('${_SVC_RUN_DIR}/outputs/run_report.json')); print(d.get('status_detail') or '')")"

  at_assert_eq "error" "$status" "runner timeout should produce an error report"
  at_assert_eq "runner" "$failure_scope" "runner timeout should be classified to the runner scope"
  at_assert_eq "runner-timeout" "$reason" "runner timeout should set the canonical reason"
  at_assert_contains "$status_detail" "terminal provider marker observed: false" \
    "runner timeout detail should record whether completion markers were seen"
  _assert_pid_file_reaped "$pid_file" "runner timeout cleanup should reap the provider process"

  if compgen -G "${_SVC_RUN_DIR}/runner-internal/*" >/dev/null; then
    echo "ASSERT failed: runner-internal should be cleaned after timeout report promotion" >&2
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Run all cases
# ─────────────────────────────────────────────────────────────────────────────
echo "=== test_service.sh ==="

at_run_case "valid_manifest_startup"            case_valid_manifest_startup
at_run_case "codex_exec_uses_container_safe_flags" case_codex_exec_uses_container_safe_flags
at_run_case "malformed_yaml_emits_report"       case_malformed_yaml_emits_report
at_run_case "unknown_key_rejected"              case_unknown_key_rejected
at_run_case "invalid_gating_mode_emits_report"  case_invalid_gating_mode_emits_report
at_run_case "missing_diagram_emits_report"      case_missing_diagram_emits_report
at_run_case "unsupported_adapter_emits_report"  case_unsupported_adapter_emits_report
at_run_case "env_overrides_manifest_adapter"    case_env_overrides_manifest_adapter
at_run_case "invalid_run_id_emits_report"       case_invalid_run_id_emits_report
at_run_case "non_writable_run_dir_exits_1"      case_non_writable_run_dir_exits_1
at_run_case "non_writable_outputs_dir_exits_1"  case_non_writable_outputs_dir_exits_1
at_run_case "artifact_promotion_layout"         case_artifact_promotion_layout
at_run_case "complete_then_hang_recovers_and_reports" case_complete_then_hang_recovers_and_reports
at_run_case "hang_before_complete_emits_runner_timeout_report" case_hang_before_complete_emits_runner_timeout_report

at_finish_suite
