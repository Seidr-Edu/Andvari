# Andvari

Andvari runs a diagram-to-Java reconstruction pipeline.

Input: a PlantUML file (`.puml`)  
Output: an isolated generated Java repo + gate/test results

## What this repo contains

- `AGENTS.md`: reconstruction constraints and quality rules.
- `gate_recon.sh`: quality/build gate run inside a generated repo.
- `.github/workflows/reconstruct.yml`: GitHub Actions workflow (`workflow_dispatch`).
- `scripts/mock_reconstruct.sh`: mock generator that creates a minimal valid Java repo.
- `examples/diagram.puml`: default diagram input for manual runs.

## Isolation model

Each run uses a dedicated workspace:

`runs/<run_id>/input`  
`runs/<run_id>/new_repo`  
`runs/<run_id>/logs`  
`runs/<run_id>/outputs`

The workflow copies the requested diagram to `runs/<run_id>/input/diagram.puml`, generates the repo only in `runs/<run_id>/new_repo`, then runs `gate_recon.sh` from inside that repo.

## GitHub Actions usage

Run the workflow from the Actions UI:

- Workflow: `Reconstruct Java Repo`
- Trigger: `workflow_dispatch`
- Inputs:
1. `run_id` (optional, auto-generated if empty)
2. `diagram_path` (default: `examples/diagram.puml`)

Artifacts are uploaded as `reconstructed-<run_id>` and include the full `runs/<run_id>/` directory.

## Local smoke run

Prerequisites:

- Java 25 available on `PATH`
- Maven (`mvn`)
- Bash
- `rg` (ripgrep) for gate checks

Example:

```bash
RUN_ID="local-smoke"
RUN_DIR="runs/${RUN_ID}"

mkdir -p "${RUN_DIR}/input" "${RUN_DIR}/new_repo" "${RUN_DIR}/logs" "${RUN_DIR}/outputs"
cp examples/diagram.puml "${RUN_DIR}/input/diagram.puml"

./scripts/mock_reconstruct.sh \
  "${RUN_DIR}/input/diagram.puml" \
  "${RUN_DIR}/new_repo"

cp gate_recon.sh "${RUN_DIR}/new_repo/gate_recon.sh"
chmod +x "${RUN_DIR}/new_repo/gate_recon.sh"

(cd "${RUN_DIR}/new_repo" && ./gate_recon.sh)
```

## Notes

- The mock generator currently emits a Maven-based Java project with JUnit 5 tests.
- The gate enforces required docs and no-stub markers (`TODO-STUB:`) before running tests.
