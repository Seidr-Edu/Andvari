# Adapter Contract

Each adapter must expose the same shell function contract so `andvari-run.sh`
can keep one orchestration flow across providers.

## Required functions

For an adapter id `<name>`:

- `<name>_check_prereqs`
- `<name>_run_initial_reconstruction`
- `<name>_run_fix_iteration`
- `<name>_run_gate_declaration`
- `<name>_run_implementation_iteration`

`scripts/adapters/adapter.sh` must:

- source the adapter implementation file.
- include `<name>` in `adapter_list`.
- route all `adapter_run_*` and `adapter_check_prereqs` dispatcher functions.

## Behavior expectations

- `*_check_prereqs` must fail fast with actionable stderr messages when the
  adapter cannot run non-interactively.
- `*_run_*` functions must:
  - write adapter events to the provided events log.
  - append tool stderr to the provided stderr log.
  - write a concise final assistant/tool message to `output_last_message`.
  - return non-zero on adapter execution failure.

## Prompt compatibility

- Adapters should keep phase prompts and acceptance semantics aligned with the
  existing `codex` adapter unless provider limits require minimal adjustments.
- Scope constraints and AGENTS policy precedence must be preserved in prompts.
- Shared prompt templates live in `scripts/adapters/prompts.sh` and should be
  reused across adapters to avoid drift.
