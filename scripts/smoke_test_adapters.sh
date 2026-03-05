#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[smoke] checking adapter contract conformance..."
"${ROOT_DIR}/scripts/adapters/check_adapter_conformance.sh"

echo "[smoke] checking --adapter flag wiring..."
help_output="$("${ROOT_DIR}/andvari-run.sh" --help)"
if [[ "$help_output" != *"--adapter"* ]]; then
  echo "[FAIL] --adapter flag not present in help output" >&2
  exit 1
fi

echo "[smoke] checking adapter list in README..."
readme_text="$(<"${ROOT_DIR}/README.md")"
if [[ "$readme_text" != *"ANDVARI_ADAPTER"* ]]; then
  echo "[FAIL] README is missing adapter configuration docs" >&2
  exit 1
fi

echo "Adapter smoke checks passed."
