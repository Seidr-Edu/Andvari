#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/test_smoke.sh"
bash "${SCRIPT_DIR}/test_service.sh"

# Container integration tests require Docker.
# Skip by setting ANDVARI_SKIP_CONTAINER_TESTS=1 or when docker is not on PATH.
if [[ "${ANDVARI_SKIP_CONTAINER_TESTS:-0}" != "1" ]] && command -v docker &>/dev/null; then
  bash "${SCRIPT_DIR}/test_container_integration.sh"
else
  echo "=== test_container_integration.sh: SKIPPED ==="
fi
