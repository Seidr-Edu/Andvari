#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  cat >&2 <<'EOF'
shellcheck is required to run the local CI wrapper.
Install it first, then rerun this script.
EOF
  exit 1
fi

echo "== local ci: shellcheck =="
(cd "$ROOT_DIR" && git ls-files -z '*.sh' | xargs -0 --no-run-if-empty shellcheck -x)

echo "== local ci: tests =="
bash "${ROOT_DIR}/tests/run.sh"
