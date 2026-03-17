# AGENTS.md — Diagram-to-Java Reconstruction (Fixed Strategy)

## Mission
Reconstruct a complete, working Java repository from the provided PlantUML diagram (`.puml`).

## Hard requirements
- Language: **Java**
- Build system: choose exactly one (**Gradle** or **Maven**)
- Use `../input/diagram.puml` as the source of truth for behavior and structure
- No placeholder stubs
- Provide meaningful tests
- Provide runnable demo (`main` and executable `run_demo.sh`)
- Provide comprehensive usage documentation (`docs/USAGE.md`) covering how to build artifacts for deployment, integrate the project, and use it in production scenarios

## Required artifacts
- `README.md`
- `docs/ASSUMPTIONS.md`
- `docs/ARCHITECTURE.md`
- `docs/USAGE.md`
- `run_demo.sh`

## Working rules
- Treat `docs/CODE_QUALITY_RULES.md` and `completion/context/sonar_rules.lock.json` as non-functional code-quality constraints only.
- Read `docs/CODE_QUALITY_RULES.md` before implementation; consult the JSON only when exact rule metadata or parameter values are needed.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- Operate only inside this run repository.
- Resolve ambiguity with reasonable assumptions and record them in `docs/ASSUMPTIONS.md`.
- Keep implementation deterministic where practical.

## Stop condition
Do not consider the task complete until `./gate_recon.sh` passes.
If it fails, fix and rerun until green.
