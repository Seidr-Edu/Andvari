#!/usr/bin/env bash
# runner_workspace.sh - Workspace and artifact path initialization
# Creates run directories, copies required files, and initializes artifact/log paths

# shellcheck disable=SC2034 # Initializes workspace path globals consumed by other sourced modules.

andvari_init_workspace() {
  RUNS_DIR="${ANDVARI_RUNS_DIR:-${ROOT_DIR}/runs}"
  RUN_DIR="${RUNS_DIR}/${RUN_ID}"
  INPUT_DIR="${RUN_DIR}/input"
  NEW_REPO_DIR="${RUN_DIR}/new_repo"
  LOGS_DIR="${RUN_DIR}/logs"
  OUTPUTS_DIR="${RUN_DIR}/outputs"

  if [[ -e "$RUN_DIR" ]]; then
    andvari_fail "Run directory already exists: $RUN_DIR. Use a different --run-id."
  fi

  andvari_require_file "${ROOT_DIR}/AGENTS.md"
  andvari_require_file "${ROOT_DIR}/AGENTS.model.md"
  andvari_require_file "${ROOT_DIR}/AGENTS.fixed.md"
  andvari_require_file "${ROOT_DIR}/gate_recon.sh"
  andvari_require_file "${ROOT_DIR}/gate_hard.sh"
  andvari_require_file "${ROOT_DIR}/scripts/verify_outcome_coverage.sh"
  andvari_resolve_quality_rules_bundle
  adapter_check_prereqs "$ADAPTER"

  mkdir -p \
    "$INPUT_DIR" \
    "$NEW_REPO_DIR" \
    "$LOGS_DIR" \
    "$OUTPUTS_DIR" \
    "${NEW_REPO_DIR}/completion/context" \
    "${NEW_REPO_DIR}/docs" \
    "${NEW_REPO_DIR}/scripts"
  cp "$DIAGRAM_PATH" "${INPUT_DIR}/diagram.puml"
  cp "$AGENTS_TEMPLATE_PATH" "${NEW_REPO_DIR}/AGENTS.md"
  cp "${ROOT_DIR}/gate_recon.sh" "${NEW_REPO_DIR}/gate_recon.sh"
  cp "${ROOT_DIR}/gate_hard.sh" "${NEW_REPO_DIR}/gate_hard.sh"
  cp "${ROOT_DIR}/scripts/verify_outcome_coverage.sh" "${NEW_REPO_DIR}/scripts/verify_outcome_coverage.sh"
  cp "${QUALITY_RULES_SUMMARY_PATH}" "${NEW_REPO_DIR}/docs/CODE_QUALITY_RULES.md"
  cp "${QUALITY_RULES_LOCK_PATH}" "${NEW_REPO_DIR}/completion/context/sonar_rules.lock.json"
  cp "${QUALITY_RULES_MANIFEST_PATH}" "${NEW_REPO_DIR}/completion/context/sonar_rules_manifest.json"
  chmod +x "${NEW_REPO_DIR}/gate_recon.sh" "${NEW_REPO_DIR}/gate_hard.sh" "${NEW_REPO_DIR}/scripts/verify_outcome_coverage.sh"
}

andvari_init_artifact_paths() {
  EVENTS_LOG="${LOGS_DIR}/adapter_events.jsonl"
  ADAPTER_STDERR_LOG="${LOGS_DIR}/adapter_stderr.log"
  GATE_LOG="${LOGS_DIR}/gate.log"
  LAST_FIXED_GATE_OUTPUT="${LOGS_DIR}/gate_fixed_last.log"
  LAST_HARD_GATE_OUTPUT="${LOGS_DIR}/gate_hard_last.log"
  LAST_MODEL_VERIFY_OUTPUT="${LOGS_DIR}/gate_model_verify_last.log"
  GATE_SUMMARY_FILE="${LOGS_DIR}/gate_summary.txt"
  RUN_REPORT="${OUTPUTS_DIR}/run_report.md"
  RUN_REPORT_JSON="${OUTPUTS_DIR}/run_report.json"

  touch "$EVENTS_LOG" "$ADAPTER_STDERR_LOG" "$GATE_LOG"
}

andvari_resolve_quality_rules_bundle() {
  local quality_rules_root="${ROOT_DIR}/resources/quality-rules"
  [[ -d "$quality_rules_root" ]] || andvari_fail "Missing quality rules root: ${quality_rules_root}"

  local bundle_override="${ANDVARI_QUALITY_RULES_BUNDLE:-}"
  local bundle_dir=""
  if [[ -n "$bundle_override" ]]; then
    [[ "$bundle_override" != */* && "$bundle_override" != *..* && "$bundle_override" != *:* ]] \
      || andvari_fail "ANDVARI_QUALITY_RULES_BUNDLE must be a bundle directory name under ${quality_rules_root}"
    bundle_dir="${quality_rules_root}/${bundle_override}"
    [[ -d "$bundle_dir" ]] || andvari_fail "Requested quality rules bundle not found: ${bundle_dir}"
  else
    local -a bundle_dirs=()
    local candidate
    while IFS= read -r candidate; do
      bundle_dirs+=("$candidate")
    done < <(LC_ALL=C find "$quality_rules_root" -mindepth 1 -maxdepth 1 -type d | sort)

    case "${#bundle_dirs[@]}" in
      0)
        andvari_fail "No quality rules bundles found under ${quality_rules_root}"
        ;;
      1)
        bundle_dir="${bundle_dirs[0]}"
        ;;
      *)
        local -a bundle_names=()
        for candidate in "${bundle_dirs[@]}"; do
          bundle_names+=("${candidate##*/}")
        done
        andvari_fail \
          "Multiple quality rules bundles found under ${quality_rules_root}: ${bundle_names[*]}. Set ANDVARI_QUALITY_RULES_BUNDLE to one of those directory names."
        ;;
    esac
  fi

  [[ -n "$bundle_dir" ]] || andvari_fail "No quality rules bundles found under ${quality_rules_root}"

  QUALITY_RULES_BUNDLE_DIR="$bundle_dir"
  QUALITY_RULES_MANIFEST_PATH="${QUALITY_RULES_BUNDLE_DIR}/manifest.json"
  QUALITY_RULES_LOCK_PATH="${QUALITY_RULES_BUNDLE_DIR}/model/rules.lock.json"
  QUALITY_RULES_SUMMARY_PATH="${QUALITY_RULES_BUNDLE_DIR}/model/rules.summary.md"

  andvari_require_file "$QUALITY_RULES_MANIFEST_PATH"
  andvari_require_file "$QUALITY_RULES_LOCK_PATH"
  andvari_require_file "$QUALITY_RULES_SUMMARY_PATH"
}
