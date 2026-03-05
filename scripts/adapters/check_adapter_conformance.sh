#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER_LIB="${ROOT_DIR}/scripts/adapters/adapter.sh"

# shellcheck source=/dev/null
source "$ADAPTER_LIB"

required_suffixes=(
  "check_prereqs"
  "run_initial_reconstruction"
  "run_fix_iteration"
  "run_gate_declaration"
  "run_implementation_iteration"
)

failures=0

for adapter in $(adapter_list); do
  if ! adapter_is_supported "$adapter"; then
    echo "[FAIL] adapter_list includes unsupported adapter '${adapter}'" >&2
    failures=$((failures + 1))
  fi

  for suffix in "${required_suffixes[@]}"; do
    fn="${adapter}_${suffix}"
    if ! declare -F "$fn" >/dev/null 2>&1; then
      echo "[FAIL] missing function: ${fn}" >&2
      failures=$((failures + 1))
    fi
  done
done

if (( failures > 0 )); then
  echo "Adapter conformance failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Adapter conformance passed for: $(adapter_list)"
