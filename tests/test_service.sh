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
# Handles `codex login status` and `codex exec` (writes --output-last-message
# file if supplied, then exits 0).
_write_fake_codex() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "${bin_dir}/codex" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  login)
    exit 0
    ;;
  exec)
    shift
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output-last-message" && $# -gt 1 ]]; then
        touch "$2" 2>/dev/null || true
        shift 2
      else
        shift
      fi
    done
    exit 0
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

# ── 10. artifact promotion writes canonical output dirs ──────────────────────
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

# ─────────────────────────────────────────────────────────────────────────────
# Run all cases
# ─────────────────────────────────────────────────────────────────────────────
echo "=== test_service.sh ==="

at_run_case "valid_manifest_startup"            case_valid_manifest_startup
at_run_case "malformed_yaml_emits_report"       case_malformed_yaml_emits_report
at_run_case "unknown_key_rejected"              case_unknown_key_rejected
at_run_case "invalid_gating_mode_emits_report"  case_invalid_gating_mode_emits_report
at_run_case "missing_diagram_emits_report"      case_missing_diagram_emits_report
at_run_case "unsupported_adapter_emits_report"  case_unsupported_adapter_emits_report
at_run_case "env_overrides_manifest_adapter"    case_env_overrides_manifest_adapter
at_run_case "invalid_run_id_emits_report"       case_invalid_run_id_emits_report
at_run_case "non_writable_run_dir_exits_1"      case_non_writable_run_dir_exits_1
at_run_case "artifact_promotion_layout"         case_artifact_promotion_layout

at_finish_suite
