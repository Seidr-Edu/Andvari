#!/usr/bin/env bash
# andvari-service.sh — Container service entrypoint for Andvari DO mode.
#
# Loads a YAML manifest from /run/config/manifest.yaml (or ANDVARI_MANIFEST),
# bootstraps the Codex provider runtime, invokes andvari-run.sh unchanged,
# promotes its outputs to canonical service paths, and always emits a
# machine-readable /run/outputs/run_report.json.
#
# Local / manual use:  andvari-run.sh (unchanged)
# Container DO mode:   andvari-service.sh (this file)
#
# Exit codes:
#   0 — run_report.json was emitted (even if generation failed a gate)
#   1 — service startup failure that prevented emitting any report

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Source shared utilities (no runner lib internals) ─────────────────────────
ADAPTER_LIB="${ROOT_DIR}/scripts/adapters/adapter.sh"
if [[ ! -f "$ADAPTER_LIB" ]]; then
  echo "error: Missing adapter library: $ADAPTER_LIB" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ADAPTER_LIB"
source "${ROOT_DIR}/scripts/lib/runner_common.sh"

# ── Path overrides for testability ───────────────────────────────────────────
# In DO containers these are always /run and /input/model (the actual mounts).
# Tests set ANDVARI_SERVICE_RUN_DIR and ANDVARI_SERVICE_INPUT_DIR to temp dirs.
SVC_RUN_DIR="${ANDVARI_SERVICE_RUN_DIR:-/run}"
SVC_INPUT_DIR="${ANDVARI_SERVICE_INPUT_DIR:-/input/model}"
SVC_PROVIDER_BIN="${ANDVARI_SERVICE_PROVIDER_BIN:-/opt/provider/bin}"
SVC_PROVIDER_SEED="${ANDVARI_SERVICE_PROVIDER_SEED:-/opt/provider-seed/codex-home}"

# ── Service globals (set by resolve_config; referenced by helper functions) ───
SVC_RUN_ID=""
SVC_ADAPTER=""
SVC_GATING_MODE="model"
SVC_MAX_ITER="8"
SVC_MAX_GATE_REVISIONS="3"
SVC_MODEL_GATE_TIMEOUT_SEC="120"
SVC_DIAGRAM_RELPATH="diagram.puml"
STARTED_AT=""
RUNNER_INVOKED="false"
RUNNER_EXIT_CODE="1"

# ── Usage ─────────────────────────────────────────────────────────────────────
_svc_usage() {
  cat <<'USAGE'
Usage (service / container mode):
  ./andvari-service.sh [--help]

This script is the container entrypoint for Andvari DO service mode.
It does not accept positional run arguments; all configuration is supplied
via a YAML manifest and optional environment variable overrides.

Manifest (default path): /run/config/manifest.yaml
Override with:           ANDVARI_MANIFEST=/path/to/manifest.yaml

Manifest schema (version 1):
  version                    Required. Must be 1.
  run_id                     Optional. Auto-generated (UTC compact ISO-8601) if absent.
  adapter                    Required. Supported in service mode: codex.
  gating_mode                Optional. model (default) or fixed.
  max_iter                   Optional. Non-negative integer. Default: 8.
  max_gate_revisions         Optional. Non-negative integer. Default: 3.
  model_gate_timeout_sec     Optional. Non-negative integer. Default: 120.
  diagram_relpath            Optional. Path relative to /input/model. Default: diagram.puml.

Environment variable overrides (take precedence over manifest fields):
  ANDVARI_MANIFEST              Manifest file path.
  ANDVARI_ADAPTER               Adapter backend.
  ANDVARI_GATING_MODE           Gating strategy (model or fixed).
  ANDVARI_MAX_ITER              Max repair iterations.
  ANDVARI_MAX_GATE_REVISIONS    Max gate revisions (model mode only).
  ANDVARI_MODEL_GATE_TIMEOUT_SEC  Seconds for gate replay timeout.
  ANDVARI_DIAGRAM               diagram_relpath override.

Runtime mounts (container):
  /input/model                          read-only   staged diagram input
  /run/config                           read-only   manifest and service config
  /run                                  read-write  all service outputs
  /opt/provider/bin                     read-only   authenticated provider CLI
  /opt/provider-seed/codex-home         read-only   provider auth seed (copied to writable /run/provider-state)

Canonical outputs (orchestrator consumes):
  /run/outputs/run_report.json          machine-readable service report
  /run/outputs/summary.md               human-readable summary
  /run/artifacts/generated-repo/        reconstructed repository
  /run/artifacts/andvari/logs/          runner logs
  /run/artifacts/andvari/report/        runner-internal report artifacts

Exit codes:
  0  run_report.json was emitted (covers gate failures, unsupported adapter, missing diagram)
  1  service startup failure that prevented writing any report

For local / manual use without Docker, run andvari-run.sh directly.
USAGE
}

# ── Failure report writer ─────────────────────────────────────────────────────
# Writes a structured error report to ${SVC_RUN_DIR}/outputs/run_report.json
# and a summary.md. Called for all pre-runner failures.
# The caller is responsible for the final exit code.
andvari_service_apply_failure() {
  local reason="${1:-unknown}"
  local detail="${2:-}"
  local now; now="$(andvari_timestamp_utc)"
  local start="${STARTED_AT:-$now}"

  # Best-effort: ensure output dir exists (may fail if /run is not writable)
  mkdir -p "${SVC_RUN_DIR}/outputs" 2>/dev/null || true

  SVC_FAILURE_REASON="$reason" \
  SVC_FAILURE_DETAIL="$detail" \
  SVC_FAILURE_STARTED_AT="$start" \
  SVC_FAILURE_FINISHED_AT="$now" \
  SVC_FAILURE_RUN_ID="${SVC_RUN_ID:-}" \
  SVC_FAILURE_ADAPTER="${SVC_ADAPTER:-}" \
  SVC_FAILURE_GATING_MODE="${SVC_GATING_MODE:-}" \
  SVC_FAILURE_RUNNER_INVOKED="${RUNNER_INVOKED:-false}" \
  SVC_FAILURE_REPORT_PATH="${SVC_RUN_DIR}/outputs/run_report.json" \
  python3 -c "
import json, os

def env(k, default=None):
    v = os.environ.get(k, '')
    return v if v else default

report = {
    'service_schema_version': 'andvari_service_report.v1',
    'run_id':        env('SVC_FAILURE_RUN_ID'),
    'status':        'error',
    'failure_scope': 'service',
    'reason':        env('SVC_FAILURE_REASON', 'unknown'),
    'status_detail': env('SVC_FAILURE_DETAIL', ''),
    'runner_invoked': env('SVC_FAILURE_RUNNER_INVOKED', 'false') == 'true',
    'adapter':       env('SVC_FAILURE_ADAPTER'),
    'gating_mode':   env('SVC_FAILURE_GATING_MODE'),
    'exit_code':     1,
    'started_at':    env('SVC_FAILURE_STARTED_AT'),
    'finished_at':   env('SVC_FAILURE_FINISHED_AT'),
    'inputs':  {'diagram_path': None},
    'artifacts': {
        'generated_repo': None,
        'logs_dir':        None,
        'report_dir':      None,
    },
}
out_path = os.environ['SVC_FAILURE_REPORT_PATH']
with open(out_path, 'w') as f:
    json.dump(report, f, indent=2)
    f.write('\n')
"

  # summary.md (best-effort; ignore errors)
  {
    cat <<MD
# Andvari Service Run Report

| Field | Value |
|-------|-------|
| run_id | ${SVC_RUN_ID:-(unset)} |
| status | error |
| reason | $reason |
| detail | $detail |
| adapter | ${SVC_ADAPTER:-(unset)} |
| gating_mode | ${SVC_GATING_MODE:-(unset)} |
| runner_invoked | ${RUNNER_INVOKED:-false} |
| started_at | $start |
| finished_at | $now |
MD
  } > "${SVC_RUN_DIR}/outputs/summary.md" 2>/dev/null || true
}

# ── Manifest loading ──────────────────────────────────────────────────────────
# Parses and validates the YAML manifest at $1.
# The schema is intentionally flat, so this parser only accepts a top-level
# mapping of scalar values and rejects nested collections or block scalars.
# On success, prints a JSON object to stdout and exits 0.
# On failure, writes a one-line reason to stderr and exits with a specific code:
#   5  file missing or unreadable
#   2  unknown top-level key(s)
#   3  unsupported version
#   4  invalid content (bad YAML, missing required field, bad type)
andvari_service_load_manifest() {
  local manifest_path="$1"

  ANDVARI_SVC_MANIFEST_PATH="$manifest_path" python3 -c "
import json, os, re, sys

mpath = os.environ['ANDVARI_SVC_MANIFEST_PATH']

try:
    with open(mpath, 'r', encoding='utf-8') as f:
        raw_lines = f.read().splitlines()
except FileNotFoundError:
    sys.stderr.write('missing-manifest: ' + mpath + '\n')
    sys.exit(5)
except Exception as e:
    sys.stderr.write('invalid-manifest: ' + str(e) + '\n')
    sys.exit(4)

line_re = re.compile(r'^\s*([A-Za-z0-9_]+)\s*:\s*(.*?)\s*$')

def parse_scalar(raw_value, lineno):
    value = raw_value.strip()
    if not value:
        return None

    if value.startswith(('{', '[', '|', '>')) or value == '-':
        sys.stderr.write(
            'invalid-manifest: unsupported YAML value syntax on line ' + str(lineno) + '\n'
        )
        sys.exit(4)

    if value[0] == '\"':
        m = re.match(r'^\"((?:[^\"\\\\]|\\\\.)*)\"(?:\s+#.*)?$', value)
        if not m:
            sys.stderr.write('invalid-manifest: malformed double-quoted string on line ' + str(lineno) + '\n')
            sys.exit(4)
        return bytes(m.group(1), 'utf-8').decode('unicode_escape')

    if value[0] == \"'\":
        m = re.match(r\"^'((?:[^']|'')*)'(?:\\s+#.*)?$\", value)
        if not m:
            sys.stderr.write('invalid-manifest: malformed single-quoted string on line ' + str(lineno) + '\n')
            sys.exit(4)
        return m.group(1).replace(\"''\", \"'\")

    value = re.split(r'\s+#', value, maxsplit=1)[0].rstrip()
    if value.startswith(('{', '[', '|', '>', '- ')):
        sys.stderr.write(
            'invalid-manifest: unsupported YAML value syntax on line ' + str(lineno) + '\n'
        )
        sys.exit(4)

    if value in ('null', 'Null', 'NULL', '~'):
        return None

    if re.fullmatch(r'-?\d+', value):
        return int(value)

    return value

data = {}
for lineno, raw_line in enumerate(raw_lines, start=1):
    stripped = raw_line.strip()
    if not stripped or stripped.startswith('#'):
        continue

    match = line_re.match(raw_line)
    if not match:
        sys.stderr.write('invalid-manifest: unsupported YAML syntax on line ' + str(lineno) + '\n')
        sys.exit(4)

    key, raw_value = match.groups()
    if key in data:
        sys.stderr.write('invalid-manifest: duplicate key ' + key + '\n')
        sys.exit(4)

    data[key] = parse_scalar(raw_value, lineno)

allowed_keys = {
    'version', 'run_id', 'adapter', 'gating_mode',
    'max_iter', 'max_gate_revisions', 'model_gate_timeout_sec', 'diagram_relpath',
}
unknown = set(data.keys()) - allowed_keys
if unknown:
    sys.stderr.write('unknown-manifest-key: ' + ', '.join(sorted(unknown)) + '\n')
    sys.exit(2)

version = data.get('version')
if str(version) != '1':
    sys.stderr.write('unsupported-manifest-version: got ' + repr(version) + '\n')
    sys.exit(3)

adapter = str(data.get('adapter', '')).strip()
if not adapter:
    sys.stderr.write('invalid-manifest: adapter field is required and must be non-empty\n')
    sys.exit(4)

gating_mode = data.get('gating_mode')
if gating_mode is not None and gating_mode not in ('model', 'fixed'):
    sys.stderr.write('invalid-manifest: gating_mode must be one of: model, fixed\n')
    sys.exit(4)

for field in ('max_iter', 'max_gate_revisions', 'model_gate_timeout_sec'):
    val = data.get(field)
    if val is not None:
        if not isinstance(val, int) or val < 0:
            sys.stderr.write('invalid-manifest: ' + field + ' must be a non-negative integer\n')
            sys.exit(4)

# Normalise all values to strings for shell consumption
out = {k: str(v) for k, v in data.items() if v is not None}
print(json.dumps(out))
"
}

# ── Relative-path normaliser ──────────────────────────────────────────────────
# Prints the validated path and returns 0, or returns 1 on any rejection.
andvari_service_normalize_rel_path() {
  local relpath="$1"
  [[ "$relpath" != /* ]]    || return 1   # reject absolute
  [[ "$relpath" != *..* ]]  || return 1   # reject .. traversal
  [[ "$relpath" != *:* ]]   || return 1   # reject colons
  [[ -n "$relpath" ]]        || return 1   # reject empty
  printf '%s' "$relpath"
}

# ── Config resolver ───────────────────────────────────────────────────────────
# Merges manifest JSON (stdin positional $1) with env overrides into SVC_* globals.
andvari_service_resolve_config() {
  local manifest_json="$1"

  # Extract manifest fields into local vars (empty string if absent)
  local m_run_id m_adapter m_gating_mode m_max_iter m_max_gate_revisions \
        m_model_gate_timeout_sec m_diagram_relpath

  m_run_id="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('run_id',''))")"
  m_adapter="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('adapter',''))")"
  m_gating_mode="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('gating_mode',''))")"
  m_max_iter="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('max_iter',''))")"
  m_max_gate_revisions="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('max_gate_revisions',''))")"
  m_model_gate_timeout_sec="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('model_gate_timeout_sec',''))")"
  m_diagram_relpath="$(printf '%s' "$manifest_json" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('diagram_relpath',''))")"

  # Apply: env var > manifest field > built-in default
  SVC_ADAPTER="${ANDVARI_ADAPTER:-${m_adapter:-}}"
  SVC_GATING_MODE="${ANDVARI_GATING_MODE:-${m_gating_mode:-model}}"
  SVC_MAX_ITER="${ANDVARI_MAX_ITER:-${m_max_iter:-8}}"
  SVC_MAX_GATE_REVISIONS="${ANDVARI_MAX_GATE_REVISIONS:-${m_max_gate_revisions:-3}}"
  SVC_MODEL_GATE_TIMEOUT_SEC="${ANDVARI_MODEL_GATE_TIMEOUT_SEC:-${m_model_gate_timeout_sec:-120}}"
  SVC_DIAGRAM_RELPATH="${ANDVARI_DIAGRAM:-${m_diagram_relpath:-diagram.puml}}"

  # run_id: manifest field or auto-generate (same format as runner_cli.sh line 66)
  if [[ -n "$m_run_id" ]]; then
    SVC_RUN_ID="$m_run_id"
  else
    SVC_RUN_ID="$(date -u +"%Y%m%dT%H%M%SZ")"
  fi
}

# ── Resolved config validation ────────────────────────────────────────────────
andvari_service_validate_resolved_config() {
  case "$SVC_GATING_MODE" in
    model|fixed)
      ;;
    *)
      andvari_service_apply_failure "invalid-gating-mode" \
        "gating_mode '${SVC_GATING_MODE}' must be one of: model, fixed"
      return 1
      ;;
  esac

  if [[ ! "$SVC_MAX_ITER" =~ ^[0-9]+$ ]]; then
    andvari_service_apply_failure "invalid-max-iter" \
      "max_iter '${SVC_MAX_ITER}' must be a non-negative integer"
    return 1
  fi

  if [[ ! "$SVC_MAX_GATE_REVISIONS" =~ ^[0-9]+$ ]]; then
    andvari_service_apply_failure "invalid-max-gate-revisions" \
      "max_gate_revisions '${SVC_MAX_GATE_REVISIONS}' must be a non-negative integer"
    return 1
  fi

  if [[ ! "$SVC_MODEL_GATE_TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
    andvari_service_apply_failure "invalid-model-gate-timeout-sec" \
      "model_gate_timeout_sec '${SVC_MODEL_GATE_TIMEOUT_SEC}' must be a non-negative integer"
    return 1
  fi
}

# ── Output directory bootstrap ────────────────────────────────────────────────
andvari_service_prepare_output_dir() {
  if [[ ! -w "${SVC_RUN_DIR}" ]]; then
    echo "error: ${SVC_RUN_DIR} is not writable; cannot emit service report" >&2
    return 1
  fi

  if ! mkdir -p "${SVC_RUN_DIR}/outputs"; then
    echo "error: failed to create ${SVC_RUN_DIR}/outputs" >&2
    return 1
  fi

  if [[ ! -d "${SVC_RUN_DIR}/outputs" || ! -w "${SVC_RUN_DIR}/outputs" ]]; then
    echo "error: ${SVC_RUN_DIR}/outputs is not writable; cannot emit service report" >&2
    return 1
  fi
}

# ── Runtime directory setup ───────────────────────────────────────────────────
andvari_service_prepare_runtime_dirs() {
  mkdir -p \
    "${SVC_RUN_DIR}/runner-internal" \
    "${SVC_RUN_DIR}/provider-state" \
    "${SVC_RUN_DIR}/artifacts/generated-repo" \
    "${SVC_RUN_DIR}/artifacts/andvari/logs" \
    "${SVC_RUN_DIR}/artifacts/andvari/report"
}

# ── Provider bootstrap ────────────────────────────────────────────────────────
# Copies the read-only provider auth seed into a writable runtime dir and
# prepends the provider CLI directory to PATH.
andvari_service_bootstrap_provider() {
  local adapter="$1"

  if [[ "$adapter" == "codex" ]]; then
    local runtime_dir="${SVC_RUN_DIR}/provider-state/codex-home"
    mkdir -p "${runtime_dir}/sessions"

    if [[ -d "$SVC_PROVIDER_SEED" ]]; then
      cp -R "${SVC_PROVIDER_SEED}/." "${runtime_dir}/"
    fi

    export CODEX_HOME="$runtime_dir"
    export PATH="${SVC_PROVIDER_BIN}:${PATH}"
  fi
}

# ── Artifact promotion ────────────────────────────────────────────────────────
# Copies runner-internal outputs into canonical service paths.
# Uses /. pattern to copy directory contents, not the directory itself.
andvari_service_promote_artifacts() {
  local runner_root="${SVC_RUN_DIR}/runner-internal/${SVC_RUN_ID}"

  if [[ -d "${runner_root}/new_repo" ]]; then
    cp -a "${runner_root}/new_repo/." \
         "${SVC_RUN_DIR}/artifacts/generated-repo/" 2>/dev/null || true
  fi
  if [[ -d "${runner_root}/logs" ]]; then
    cp -a "${runner_root}/logs/." \
         "${SVC_RUN_DIR}/artifacts/andvari/logs/" 2>/dev/null || true
  fi
  if [[ -d "${runner_root}/outputs" ]]; then
    cp -a "${runner_root}/outputs/." \
         "${SVC_RUN_DIR}/artifacts/andvari/report/" 2>/dev/null || true
  fi
}

# ── Final service report writer ───────────────────────────────────────────────
# Reads the runner's internal run_report.json (if it exists), merges it with
# service metadata, and writes the canonical service report.
andvari_service_write_reports_or_fail() {
  local finished_at; finished_at="$(andvari_timestamp_utc)"
  local runner_json="${SVC_RUN_DIR}/runner-internal/${SVC_RUN_ID}/outputs/run_report.json"
  local diagram_path="${SVC_INPUT_DIR}/${SVC_DIAGRAM_RELPATH}"
  local out_dir="${SVC_RUN_DIR}/outputs"

  SVC_WR_FINISHED_AT="$finished_at" \
  SVC_WR_STARTED_AT="${STARTED_AT:-$finished_at}" \
  SVC_WR_RUN_ID="$SVC_RUN_ID" \
  SVC_WR_ADAPTER="$SVC_ADAPTER" \
  SVC_WR_GATING_MODE="$SVC_GATING_MODE" \
  SVC_WR_RUNNER_EXIT_CODE="${RUNNER_EXIT_CODE:-1}" \
  SVC_WR_RUNNER_INVOKED="$RUNNER_INVOKED" \
  SVC_WR_RUNNER_JSON="$runner_json" \
  SVC_WR_DIAGRAM_PATH="$diagram_path" \
  SVC_WR_REPORT_PATH="${out_dir}/run_report.json" \
  SVC_WR_GENERATED_REPO="${SVC_RUN_DIR}/artifacts/generated-repo" \
  SVC_WR_LOGS_DIR="${SVC_RUN_DIR}/artifacts/andvari/logs" \
  SVC_WR_REPORT_DIR="${SVC_RUN_DIR}/artifacts/andvari/report" \
  python3 -c "
import json, os

def env(k, default=None):
    v = os.environ.get(k, '')
    return v if v else default

runner_json_path = os.environ['SVC_WR_RUNNER_JSON']
runner_exit_code = int(os.environ.get('SVC_WR_RUNNER_EXIT_CODE', '1'))
runner_invoked   = os.environ.get('SVC_WR_RUNNER_INVOKED', 'false') == 'true'

runner_data = {}
if os.path.isfile(runner_json_path):
    try:
        with open(runner_json_path) as f:
            runner_data = json.load(f)
    except Exception:
        pass

# Determine status
if runner_data.get('status'):
    status = runner_data['status']
else:
    status = 'passed' if runner_exit_code == 0 else 'failed'

# Determine failure_scope
if runner_exit_code != 0 and runner_data:
    failure_scope = 'gate'
elif runner_exit_code != 0:
    failure_scope = 'runner'
else:
    failure_scope = None

report = {
    **runner_data,
    'service_schema_version': 'andvari_service_report.v1',
    'run_id':        runner_data.get('run_id') or env('SVC_WR_RUN_ID'),
    'status':        status,
    'failure_scope': failure_scope,
    'reason':        runner_data.get('reason'),
    'status_detail': runner_data.get('status_detail'),
    'runner_invoked': runner_invoked,
    'adapter':       runner_data.get('adapter') or env('SVC_WR_ADAPTER'),
    'gating_mode':   runner_data.get('gating_mode') or env('SVC_WR_GATING_MODE'),
    'exit_code':     runner_data.get('exit_code', runner_exit_code),
    'started_at':    runner_data.get('started_at') or env('SVC_WR_STARTED_AT'),
    'finished_at':   env('SVC_WR_FINISHED_AT'),
    'inputs':  {'diagram_path': env('SVC_WR_DIAGRAM_PATH')},
    'artifacts': {
        'generated_repo': env('SVC_WR_GENERATED_REPO'),
        'logs_dir':        env('SVC_WR_LOGS_DIR'),
        'report_dir':      env('SVC_WR_REPORT_DIR'),
    },
}

out_path = os.environ['SVC_WR_REPORT_PATH']
with open(out_path, 'w') as f:
    json.dump(report, f, indent=2)
    f.write('\n')
"

  # Read back a couple of display fields for summary.md
  local status_val failure_scope_val
  status_val="$(python3 -c \
    "import json; d=json.load(open('${out_dir}/run_report.json')); print(d.get('status','unknown'))" \
    2>/dev/null || echo "unknown")"
  failure_scope_val="$(python3 -c \
    "import json; d=json.load(open('${out_dir}/run_report.json')); print(d.get('failure_scope') or '')" \
    2>/dev/null || echo "")"

  cat > "${out_dir}/summary.md" <<MD
# Andvari Service Run Report

| Field | Value |
|-------|-------|
| run_id | ${SVC_RUN_ID} |
| status | ${status_val} |
| failure_scope | ${failure_scope_val:-(none)} |
| adapter | ${SVC_ADAPTER} |
| gating_mode | ${SVC_GATING_MODE} |
| runner_invoked | ${RUNNER_INVOKED} |
| exit_code | ${RUNNER_EXIT_CODE:-1} |
| started_at | ${STARTED_AT} |
| finished_at | ${finished_at} |
| diagram | ${SVC_INPUT_DIR}/${SVC_DIAGRAM_RELPATH} |
| generated_repo | ${SVC_RUN_DIR}/artifacts/generated-repo |
| logs | ${SVC_RUN_DIR}/artifacts/andvari/logs |
| report | ${SVC_RUN_DIR}/artifacts/andvari/report |
MD
}

andvari_service_cleanup_runner_internal() {
  local runner_root="${SVC_RUN_DIR}/runner-internal/${SVC_RUN_ID}"
  [[ -e "$runner_root" ]] || return 0
  rm -rf "$runner_root"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  # Handle --help; reject any other positional argument
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        _svc_usage
        exit 0
        ;;
      *)
        echo "error: andvari-service.sh does not accept positional arguments." >&2
        echo "       All configuration must come from the YAML manifest or environment variables." >&2
        echo "       Run with --help for usage details." >&2
        exit 1
        ;;
    esac
  done

  local manifest_path="${ANDVARI_MANIFEST:-${SVC_RUN_DIR}/config/manifest.yaml}"

  # ── Ensure /run/outputs is writable before we do anything else ───────────
  if ! andvari_service_prepare_output_dir; then
    # /run itself is not writable — we cannot emit any report
    exit 1
  fi

  # ── Load and validate manifest ────────────────────────────────────────────
  local manifest_json
  local manifest_exit=0
  manifest_json="$(andvari_service_load_manifest "$manifest_path")" || manifest_exit=$?

  if [[ $manifest_exit -ne 0 ]]; then
    case $manifest_exit in
      5) andvari_service_apply_failure "missing-manifest" \
           "Manifest not found or unreadable: ${manifest_path}" ;;
      2) andvari_service_apply_failure "unknown-manifest-key" \
           "Manifest contains unrecognised top-level keys" ;;
      3) andvari_service_apply_failure "unsupported-manifest-version" \
           "Manifest version must be 1" ;;
      *) andvari_service_apply_failure "invalid-manifest" \
           "Manifest is not valid YAML or contains invalid field values" ;;
    esac
    exit 0
  fi

  # ── Resolve config: env overrides > manifest fields > built-in defaults ──
  andvari_service_resolve_config "$manifest_json"

  if ! andvari_service_validate_resolved_config; then
    exit 0
  fi

  # ── Validate adapter (phase 1: codex only) ────────────────────────────────
  if [[ "$SVC_ADAPTER" != "codex" ]]; then
    andvari_service_apply_failure "unsupported-adapter" \
      "Service mode only supports adapter: codex. Got: ${SVC_ADAPTER:-<empty>}"
    exit 0
  fi

  # ── Validate run_id ───────────────────────────────────────────────────────
  if ! andvari_validate_run_id "$SVC_RUN_ID"; then
    andvari_service_apply_failure "invalid-run-id" \
      "run_id '${SVC_RUN_ID}' contains invalid characters (allowed: letters, digits, ., _, -)"
    exit 0
  fi

  # ── Validate diagram relpath ──────────────────────────────────────────────
  if ! andvari_service_normalize_rel_path "$SVC_DIAGRAM_RELPATH" >/dev/null; then
    andvari_service_apply_failure "invalid-diagram-relpath" \
      "diagram_relpath '${SVC_DIAGRAM_RELPATH}' must be a safe relative path (no leading /, no .., no :)"
    exit 0
  fi

  # ── Validate diagram file exists under /input/model ──────────────────────
  local diagram_full_path="${SVC_INPUT_DIR}/${SVC_DIAGRAM_RELPATH}"
  if [[ ! -f "$diagram_full_path" ]]; then
    andvari_service_apply_failure "missing-diagram" \
      "Diagram not found at: ${diagram_full_path}"
    exit 0
  fi

  # ── Create runtime directories ────────────────────────────────────────────
  andvari_service_prepare_runtime_dirs

  # ── Bootstrap provider into writable runtime dir ─────────────────────────
  andvari_service_bootstrap_provider "$SVC_ADAPTER"

  local prereq_exit=0
  adapter_check_prereqs "$SVC_ADAPTER" || prereq_exit=$?
  if [[ $prereq_exit -ne 0 ]]; then
    andvari_service_apply_failure "provider-bootstrap-failed" \
      "Adapter prerequisite check failed for: ${SVC_ADAPTER}"
    exit 0
  fi

  # ── Invoke the existing runner unchanged ─────────────────────────────────
  STARTED_AT="$(andvari_timestamp_utc)"
  RUNNER_INVOKED="true"

  echo "[andvari-service] run_id:      ${SVC_RUN_ID}"
  echo "[andvari-service] adapter:     ${SVC_ADAPTER}"
  echo "[andvari-service] gating_mode: ${SVC_GATING_MODE}"
  echo "[andvari-service] max_iter:    ${SVC_MAX_ITER}"
  echo "[andvari-service] diagram:     ${diagram_full_path}"

  set +e
  ANDVARI_RUNS_DIR="${SVC_RUN_DIR}/runner-internal" \
    bash "${ROOT_DIR}/andvari-run.sh" \
      --diagram                  "$diagram_full_path" \
      --run-id                   "$SVC_RUN_ID" \
      --adapter                  "$SVC_ADAPTER" \
      --gating-mode              "$SVC_GATING_MODE" \
      --max-iter                 "$SVC_MAX_ITER" \
      --max-gate-revisions       "$SVC_MAX_GATE_REVISIONS" \
      --model-gate-timeout-sec   "$SVC_MODEL_GATE_TIMEOUT_SEC"
  RUNNER_EXIT_CODE=$?
  set -e

  echo "[andvari-service] runner exited: ${RUNNER_EXIT_CODE}"

  # ── Promote artifacts into canonical service layout ───────────────────────
  andvari_service_promote_artifacts

  # ── Write final service report ────────────────────────────────────────────
  local report_exit=0
  andvari_service_write_reports_or_fail || report_exit=$?
  if [[ $report_exit -ne 0 ]]; then
    andvari_service_apply_failure "report-write-failed" \
      "Failed to write canonical service report"
    exit 1
  fi

  if ! andvari_service_cleanup_runner_internal; then
    echo "[andvari-service] warning: failed to clean runner-internal/${SVC_RUN_ID}" >&2
  fi

  echo "[andvari-service] report: ${SVC_RUN_DIR}/outputs/run_report.json"
  exit 0
}

main "$@"
