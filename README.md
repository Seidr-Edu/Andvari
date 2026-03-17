# Andvari

Andvari runs a local diagram-to-Java reconstruction pipeline using an adapter-backed CLI (`codex` or `claude`).

This README assumes commands are run from the tool root.
Inside the monorepo that is `tools/andvari/`; in the standalone `Andvari` repo these files live at repo root.
From the monorepo root, use `./andvari-run.sh`.

Input: PlantUML (`.puml`)  
Output: isolated reconstructed repository, gate logs, and run report

## Single command

```bash
./andvari-run.sh --diagram /path/to/diagram.puml --adapter claude --run-id optional-id --max-iter 8
```

If you prefer explicit env-driven output placement:

```bash
ANDVARI_RUNS_DIR=.data/andvari/runs \
./andvari-run.sh --diagram /path/to/diagram.puml --adapter codex
```

## Key options

- `--diagram` (required): path to input diagram.
- `--run-id` (optional): explicit run id (defaults to UTC timestamp).
- `--max-iter` (optional): max repair loops after first implementation attempt.
- `--adapter` (required): adapter backend.
- `--gating-mode model|fixed` (optional):
  - `model` (default): adaptive self-gating with model-defined outcomes/gates.
  - `fixed`: legacy `gate_recon.sh` flow.
- `--max-gate-revisions` (optional, model mode): max revisions after `gates.v1` (default `3`).
- `--model-gate-timeout-sec` (optional, model mode): timeout for replaying `completion/run_all_gates.sh` (default `120`).

## Model mode flow (default)

1. Creates run workspace:
   - `runs/<run_id>/input`
   - `runs/<run_id>/new_repo`
   - `runs/<run_id>/logs`
   - `runs/<run_id>/outputs`
2. Copies diagram to `runs/<run_id>/input/diagram.puml`.
3. Copies runner policy/scripts into `new_repo`:
   - strategy-selected AGENTS template as `new_repo/AGENTS.md`
   - Sonar quality rules summary as `new_repo/docs/CODE_QUALITY_RULES.md`
   - Sonar quality rules lock file as `new_repo/completion/context/sonar_rules.lock.json`
   - Sonar quality rules manifest as `new_repo/completion/context/sonar_rules_manifest.json`
   - `gate_hard.sh`
   - `scripts/verify_outcome_coverage.sh`
   - `gate_recon.sh` (legacy compatibility)
4. Runs declaration phase via selected adapter:
   - model creates `completion/outcomes.initial.json`
   - model creates `completion/gates.v1.json`
   - model creates `completion/run_all_gates.sh`
5. Runner locks hash of `completion/outcomes.initial.json`.
6. Runs implementation phase via selected adapter.
7. Runner evaluates acceptance:
   - `./gate_hard.sh`
   - `./scripts/verify_outcome_coverage.sh --max-gate-revisions <N> --model-gate-timeout-sec <S>`
8. If acceptance fails, runner loops repair iterations up to `--max-iter`.

`verify_outcome_coverage.sh` enforces:
- locked `outcomes.initial.json` was not mutated
- latest `gates.vN.json` does not exceed revision budget
- model gate runner (`completion/run_all_gates.sh`) replays successfully
- `results.vN.json` exists and covers every gate in latest `gates.vN.json`
- every initial outcome is covered by latest gates
- every core outcome has at least one passing gate

## Fixed mode flow (legacy)

`--gating-mode fixed` preserves current behavior:
- initial reconstruction prompt
- run `./gate_recon.sh`
- summarize failures and iterate repairs up to `--max-iter`

## Artifacts

Per run:

- `runs/<run_id>/logs/adapter_events.jsonl`
- `runs/<run_id>/logs/adapter_stderr.log`
- `runs/<run_id>/logs/gate.log`
- `runs/<run_id>/outputs/run_report.md`

## AGENTS templates

- `AGENTS.model.md`: used when `--gating-mode model`
- `AGENTS.fixed.md`: used when `--gating-mode fixed`
- `AGENTS.md`: repository-level index that points to the strategy templates

### Required artifacts in generated repositories

All reconstruction modes require the following artifacts:
- `README.md` (build/test/run instructions)
- `docs/ASSUMPTIONS.md` (documented assumptions and design decisions)
- `docs/ARCHITECTURE.md` (architectural overview)
- `docs/USAGE.md` (comprehensive usage guide including how to build artifacts for deployment, integrate the project, and use it in production scenarios)
- `run_demo.sh` (executable demo script)

Model-mode generated repo artifacts (inside `new_repo`):

- `completion/outcomes.initial.json`
- `completion/gates.vN.json`
- `completion/run_all_gates.sh`
- `completion/proof/results.vN.json`
- `completion/proof/logs/*.log`
- `completion/context/sonar_rules.lock.json`
- `completion/context/sonar_rules_manifest.json`
- `docs/CODE_QUALITY_RULES.md`

## Quality Rules Bundle

Andvari ships a frozen Sonar quality-rules bundle under `resources/quality-rules/`.
At workspace init, the runner copies only the model-facing bundle files into the
generated repo. The archival source files stay inside the tool repository and
are not staged into the run workspace.

## Prerequisites

- `codex` or `claude` CLI installed and on `PATH` (matching selected adapter)
- active auth/configuration for the selected adapter
- Bash
- Java + build tooling required by the generated project
- `rg`
- `perl` (used for JSON proof validation in `verify_outcome_coverage.sh`)

The runner fails fast with actionable errors if the selected adapter cannot run non-interactively.

## Runner modules

- `andvari-run.sh`: thin entrypoint that wires config parsing, workspace init, mode dispatch, and final report/exit.
- `scripts/lib/runner_common.sh`: shared helpers (usage, error handling, timestamping, sha256, validators).
- `scripts/lib/runner_cli.sh`: CLI parsing and configuration validation.
- `scripts/lib/runner_workspace.sh`: run workspace creation and artifact/log path initialization.
- `scripts/lib/runner_gates.sh`: fixed/model gate execution plus gate failure summarization and outcome locking.
- `scripts/lib/runner_flows.sh`: fixed-mode and model-mode orchestration flows with unchanged adapter call order.
- `scripts/lib/runner_report.sh`: run report rendering and final pass/fail exit handling.

## Adapter design

The runner uses an adapter entrypoint:

- `scripts/adapters/adapter.sh`
- `scripts/adapters/codex.sh`
- `scripts/adapters/claude.sh`

Supported adapters are:

- `codex`
- `claude`

```bash
./andvari-run.sh --diagram /path/to/diagram.puml --adapter claude
```

Both adapters support fixed mode (legacy initial/fix prompts), model mode (declaration + implementation prompts), and test-port adaptation prompts.

## Docker

Build the standalone image from the tool root:

```bash
docker build -t andvari:local .
docker run --rm andvari:local --help
```

The image includes the shell and Java/build prerequisites needed by the runner.
Adapter CLIs and authentication still need to be layered in or mounted at runtime.

## Release
This repo includes:

- `.github/workflows/release.yml` for semantic-release
- `.github/workflows/publish-ghcr.yml` for publishing `ghcr.io/<owner>/andvari`
- `.releaserc.json` for semantic-release branch/plugin configuration

## Service Mode

Service mode is the production entrypoint for running Andvari as a containerised
pipeline step on a Digital Ocean VPS (or any Docker host).  
The container entrypoint is `andvari-service.sh`; local/manual use stays on
`andvari-run.sh`.

### Manifest schema

Store the manifest at `/run/config/manifest.yaml` (or override with
`ANDVARI_MANIFEST`).

```yaml
version: 1                        # Required. Must be 1.
run_id: 20260310T120000Z__example  # Optional. Auto-generated if absent.
adapter: codex                     # Required. Service mode: codex only (Phase 1).
gating_mode: model                 # Optional. model (default) or fixed.
max_iter: 8                        # Optional. Non-negative integer. Default: 8.
max_gate_revisions: 3              # Optional. Non-negative integer. Default: 3.
model_gate_timeout_sec: 120        # Optional. Non-negative integer. Default: 120.
diagram_relpath: diagram.puml      # Optional. Relative to /input/model. Default: diagram.puml.
```

Validation rules:
- `version` is required and must be `1`.
- `adapter` is required and non-empty.
- `gating_mode` must be `model` or `fixed` if present.
- Integer fields must be non-negative integers if present.
- `diagram_relpath` must be a safe relative path: no leading `/`, no `..`, no `:`.
- Unknown top-level keys are rejected.

### Environment variables

Environment variables take precedence over manifest fields.

| Variable | Overrides manifest field |
|---|---|
| `ANDVARI_MANIFEST` | Manifest file path (default `/run/config/manifest.yaml`) |
| `ANDVARI_ADAPTER` | `adapter` |
| `ANDVARI_GATING_MODE` | `gating_mode` |
| `ANDVARI_MAX_ITER` | `max_iter` |
| `ANDVARI_MAX_GATE_REVISIONS` | `max_gate_revisions` |
| `ANDVARI_MODEL_GATE_TIMEOUT_SEC` | `model_gate_timeout_sec` |
| `ANDVARI_DIAGRAM` | `diagram_relpath` |

### Runtime mounts

| Host path | Container path | Access | Purpose |
|---|---|---|---|
| `runs/<runId>/services/andvari/input/model` | `/input/model` | read-only | Staged diagram input |
| `runs/<runId>/services/andvari/config` | `/run/config` | read-only | Manifest file |
| `runs/<runId>/services/andvari/run` | `/run` | read-write | All service outputs |
| `provider/codex/bin` | `/opt/provider/bin` | read-only | Authenticated Codex CLI |
| `provider/codex/home` | `/opt/provider-seed/codex-home` | read-only | Codex auth seed (copied into `/run/provider-state/codex-home` at startup) |

The service copies the read-only provider seed home into a writable runtime
directory under `/run/provider-state/codex-home` so the Codex CLI can write
session state without a writable bind-mount over the host auth directory.

Do **not** mount the whole `runs/<runId>` tree into the container.

### Canonical outputs (orchestrator consumes)

| Path | Description |
|---|---|
| `/run/outputs/run_report.json` | Machine-readable service report (`andvari_service_report.v1`) |
| `/run/outputs/summary.md` | Human-readable run summary |
| `/run/artifacts/generated-repo/` | Reconstructed repository |
| `/run/artifacts/andvari/logs/` | Runner adapter and gate logs |
| `/run/artifacts/andvari/report/` | Runner-internal report artifacts |

### Service report schema

The service report at `/run/outputs/run_report.json` includes all
runner-compatible fields plus additive service metadata:

```json
{
  "service_schema_version": "andvari_service_report.v1",
  "run_id": "20260310T120000Z__example",
  "status": "passed | failed | error",
  "failure_scope": "gate | runner | service | null",
  "reason": null,
  "status_detail": null,
  "runner_invoked": true,
  "adapter": "codex",
  "gating_mode": "model",
  "exit_code": 0,
  "started_at": "2026-03-10T12:00:00Z",
  "finished_at": "2026-03-10T12:05:00Z",
  "inputs": { "diagram_path": "/input/model/diagram.puml" },
  "artifacts": {
    "generated_repo": "/run/artifacts/generated-repo",
    "logs_dir":       "/run/artifacts/andvari/logs",
    "report_dir":     "/run/artifacts/andvari/report"
  }
}
```

`failure_scope` values:
- `gate` — runner completed but generation failed acceptance gating.
- `runner` — runner crashed before emitting its own report.
- `service` — service startup failure (manifest, missing diagram, unsupported adapter, etc.).
- `null` — success.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | `run_report.json` was emitted (covers gate failures, unsupported adapter, missing diagram) |
| `1` | Service startup failure that prevented writing any report (e.g., `/run` not writable) |

The orchestrator should branch on `run_report.json`.`status`, not on the shell
exit code.

### Supported adapters (Phase 1)

| Adapter | Service mode |
|---|---|
| `codex` | Supported |
| `claude` | Not supported (emits `unsupported-adapter` report, exits 0) |

`claude` currently uses `--dangerously-skip-permissions`, which does not meet
the least-privilege requirements for DO service mode.

### Example `docker run`

```bash
docker run --rm \
  -e PATH="/opt/provider/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  -e ANDVARI_MANIFEST=/run/config/manifest.yaml \
  -e CODEX_HOME=/run/provider-state/codex-home \
  -v /srv/pipeline/runs/<runId>/services/andvari/input/model:/input/model:ro \
  -v /srv/pipeline/runs/<runId>/services/andvari/config:/run/config:ro \
  -v /srv/pipeline/runs/<runId>/services/andvari/run:/run \
  -v /srv/pipeline/provider/codex/bin:/opt/provider/bin:ro \
  -v /srv/pipeline/provider/codex/home:/opt/provider-seed/codex-home:ro \
  andvari:local
```

### Local dry-run (without writing Docker commands)

```bash
./scripts/run-service-local.sh \
  --diagram /path/to/diagram.puml \
  --adapter codex \
  --gating-mode model \
  --keep-tmp
```

This creates a temp staging directory, writes a manifest, copies the diagram,
and runs `andvari:local` with the full DO mount contract.

### Orchestrator integration

1. Create `runs/<runId>/services/andvari/input/model/diagram.puml` — copy the
   canonical pipeline diagram (do not symlink).
2. Write `runs/<runId>/services/andvari/config/manifest.yaml`.
3. Launch the container with the three principal mounts (`/input/model`,
   `/run/config`, `/run`) plus the two provider mounts.
4. Consume `runs/<runId>/services/andvari/run/outputs/run_report.json`.
5. Collect `runs/<runId>/services/andvari/run/artifacts/generated-repo/`.
