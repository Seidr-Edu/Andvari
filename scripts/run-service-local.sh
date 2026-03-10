#!/usr/bin/env bash
# run-service-local.sh — Local convenience wrapper for andvari-service.sh.
#
# Creates a temp directory tree that mirrors the DO container mount contract,
# stages the diagram and manifest, then runs the andvari:local Docker image
# with those mounts.
#
# This lets you exercise the full container service path locally without
# writing Docker run commands by hand.
#
# Usage:
#   ./scripts/run-service-local.sh --diagram /path/to/diagram.puml [options]
#
# Options:
#   --diagram PATH              Path to input PlantUML diagram. Required.
#   --adapter NAME              Adapter backend. Default: codex.
#   --gating-mode model|fixed   Gating strategy. Default: model.
#   --max-iter N                Max repair iterations. Default: 8.
#   --run-id ID                 Explicit run id. Auto-generated if omitted.
#   --codex-home PATH           Path to authenticated codex home dir.
#                               Default: $CODEX_HOME or $HOME/.codex.
#   --keep-tmp                  Do not delete the temp staging directory on exit.
#   --image-tag TAG             Docker image tag. Default: andvari:local.
#   -h, --help                  Show this message.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,2\}//'
}

# ── Defaults ──────────────────────────────────────────────────────────────────
DIAGRAM_PATH=""
ADAPTER="codex"
GATING_MODE="model"
MAX_ITER="8"
RUN_ID=""
CODEX_HOME_PATH="${CODEX_HOME:-${HOME}/.codex}"
KEEP_TMP="false"
IMAGE_TAG="andvari:local"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --diagram)
      [[ $# -ge 2 ]] || { echo "error: --diagram requires a value" >&2; exit 1; }
      DIAGRAM_PATH="$2"
      shift 2
      ;;
    --adapter)
      [[ $# -ge 2 ]] || { echo "error: --adapter requires a value" >&2; exit 1; }
      ADAPTER="$2"
      shift 2
      ;;
    --gating-mode)
      [[ $# -ge 2 ]] || { echo "error: --gating-mode requires a value" >&2; exit 1; }
      GATING_MODE="$2"
      shift 2
      ;;
    --max-iter)
      [[ $# -ge 2 ]] || { echo "error: --max-iter requires a value" >&2; exit 1; }
      MAX_ITER="$2"
      shift 2
      ;;
    --run-id)
      [[ $# -ge 2 ]] || { echo "error: --run-id requires a value" >&2; exit 1; }
      RUN_ID="$2"
      shift 2
      ;;
    --codex-home)
      [[ $# -ge 2 ]] || { echo "error: --codex-home requires a value" >&2; exit 1; }
      CODEX_HOME_PATH="$2"
      shift 2
      ;;
    --keep-tmp)           KEEP_TMP="true";       shift ;;
    --image-tag)
      [[ $# -ge 2 ]] || { echo "error: --image-tag requires a value" >&2; exit 1; }
      IMAGE_TAG="$2"
      shift 2
      ;;
    -h|--help)            _usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$DIAGRAM_PATH" ]] || { echo "error: --diagram is required" >&2; exit 1; }
[[ -f "$DIAGRAM_PATH" ]] || { echo "error: diagram not found: $DIAGRAM_PATH" >&2; exit 1; }

if ! command -v docker &>/dev/null; then
  echo "error: docker not found on PATH" >&2
  exit 1
fi

# ── Auto-generate run id if not supplied ──────────────────────────────────────
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(date -u +"%Y%m%dT%H%M%SZ")"
fi

# ── Create staging directory ──────────────────────────────────────────────────
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/andvari-local-svc.XXXXXX")"

if [[ "$KEEP_TMP" != "true" ]]; then
  # shellcheck disable=SC2064
  trap "rm -rf '$STAGING_DIR'" EXIT
fi

INPUT_MODEL_DIR="${STAGING_DIR}/input_model"
CONFIG_DIR="${STAGING_DIR}/config"
RUN_OUTPUT_DIR="${STAGING_DIR}/run"
PROVIDER_SEED_DIR="${STAGING_DIR}/provider_seed"

mkdir -p "$INPUT_MODEL_DIR" "$CONFIG_DIR" "$RUN_OUTPUT_DIR" "$PROVIDER_SEED_DIR"
chmod 0777 "$RUN_OUTPUT_DIR"

# ── Stage diagram ─────────────────────────────────────────────────────────────
cp "$DIAGRAM_PATH" "${INPUT_MODEL_DIR}/diagram.puml"

# ── Copy local codex home into seed dir (service will make its own writable copy) ──
if [[ -d "$CODEX_HOME_PATH" ]]; then
  cp -a "${CODEX_HOME_PATH}/." "${PROVIDER_SEED_DIR}/"
else
  echo "warning: codex home not found at ${CODEX_HOME_PATH}; provider bootstrap may fail" >&2
  mkdir -p "${PROVIDER_SEED_DIR}/sessions"
fi

chmod -R a+rX "$INPUT_MODEL_DIR" "$CONFIG_DIR" "$PROVIDER_SEED_DIR"

# ── Write manifest ────────────────────────────────────────────────────────────
cat > "${CONFIG_DIR}/manifest.yaml" <<YAML
version: 1
run_id: ${RUN_ID}
adapter: ${ADAPTER}
gating_mode: ${GATING_MODE}
max_iter: ${MAX_ITER}
diagram_relpath: diagram.puml
YAML

# ── Resolve provider bin dir ──────────────────────────────────────────────────
# Try to find the codex binary and use its parent directory as the provider bin.
PROVIDER_BIN_DIR=""
if command -v codex &>/dev/null; then
  PROVIDER_BIN_DIR="$(dirname "$(command -v codex)")"
fi

if [[ -z "$PROVIDER_BIN_DIR" ]]; then
  echo "warning: 'codex' not found on PATH; provider bin mount will be empty" >&2
  PROVIDER_BIN_DIR="${STAGING_DIR}/empty_bin"
  mkdir -p "$PROVIDER_BIN_DIR"
fi

chmod -R a+rX "$PROVIDER_BIN_DIR"

# ── Print run plan ────────────────────────────────────────────────────────────
echo "[run-service-local] run_id:      ${RUN_ID}"
echo "[run-service-local] image:       ${IMAGE_TAG}"
echo "[run-service-local] adapter:     ${ADAPTER}"
echo "[run-service-local] gating_mode: ${GATING_MODE}"
echo "[run-service-local] diagram:     ${DIAGRAM_PATH}"
echo "[run-service-local] staging:     ${STAGING_DIR}"
echo ""

# ── Run the container ─────────────────────────────────────────────────────────
CONTAINER_EXIT=0
docker run --rm \
  -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
  -e CODEX_HOME=/run/provider-state/codex-home \
  -e PATH="/opt/provider/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  -v "${INPUT_MODEL_DIR}:/input/model:ro" \
  -v "${CONFIG_DIR}:/run/config:ro" \
  -v "${RUN_OUTPUT_DIR}:/run" \
  -v "${PROVIDER_BIN_DIR}:/opt/provider/bin:ro" \
  -v "${PROVIDER_SEED_DIR}:/opt/provider-seed/codex-home:ro" \
  "${IMAGE_TAG}" \
  || CONTAINER_EXIT=$?

echo ""
echo "[run-service-local] container exited: ${CONTAINER_EXIT}"
echo "[run-service-local] outputs:    ${RUN_OUTPUT_DIR}/outputs/"
echo "[run-service-local] artifacts:  ${RUN_OUTPUT_DIR}/artifacts/"

if [[ -f "${RUN_OUTPUT_DIR}/outputs/run_report.json" ]]; then
  echo ""
  echo "--- run_report.json ---"
  cat "${RUN_OUTPUT_DIR}/outputs/run_report.json"
fi

if [[ "$KEEP_TMP" == "true" ]]; then
  echo ""
  echo "[run-service-local] staging dir preserved at: ${STAGING_DIR}"
fi

exit "$CONTAINER_EXIT"
