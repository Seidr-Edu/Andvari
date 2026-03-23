# AGENTS.md — Diagram-to-Java Reconstruction (Behavioral Fidelity Strategy)

## Mission
Reconstruct a complete, working Java repository from `../input/diagram.puml`.

Your real goal is to recreate the original repository's externally observable functionality as closely as possible. Do not produce a merely plausible, simplified, or demo-only implementation. This repository will later be evaluated with adapted tests derived from the original repository, and you will not see those tests.

## Primary success criteria
- Behavioral fidelity to the original repository
- Repository, package, and type structure aligned with the diagram
- Compliance with the supplied code-quality rules without sacrificing behavior
- Buildable, testable, maintainable Java code with no placeholder production logic

## Non-negotiable outcomes
- Language: **Java**
- Build system: choose exactly one (**Gradle** or **Maven**)
- Follow conventional Java repository layout with packages aligned to diagram namespaces
- Tests: meaningful unit tests for core logic, plus integration tests when real boundaries exist
- Buildable: project compiles and tests pass
- Usable: runnable demo entrypoint (`main`) and executable `run_demo.sh`
- Usage documentation: comprehensive guide in `docs/USAGE.md` covering how to build artifacts for deployment, integrate the project, and use it in production scenarios
- No placeholder stubs (`TODO-STUB`, `return null`, `UnsupportedOperationException`, `NotImplementedError` in production logic)

## Source of truth and scope
- Treat `../input/diagram.puml` as the primary structural and behavioral evidence about the original repository, but not as an infallible specification.
- The diagram may contain omissions, inconsistencies, or occasional incorrect details.
- Follow the diagram by default.
- Deviate from a diagram detail only when there is strong evidence it is flawed, such as an internal contradiction, an impossible or incoherent literal implementation, or a small local mistake whose correction yields a much more coherent overall design and observable behavior.
- When you deviate from a diagram detail, make the smallest local correction necessary, preserve the surrounding design, and document the rationale in `docs/ASSUMPTIONS.md`.
- Do not ignore diagram details based on vague intuition, generic preferences, or unsupported guesses.
- Treat `docs/CODE_QUALITY_RULES.md` and `completion/context/sonar_rules.lock.json` as non-functional code-quality constraints only.
- Read `docs/CODE_QUALITY_RULES.md` before implementation; consult the JSON only when exact rule metadata or parameter values are needed.
- If a Sonar quality rule appears to conflict with behavior implied by the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- Operate only inside this run repository.
- If the diagram is underspecified, choose the interpretation most likely to preserve original observable behavior and common Java/library/framework conventions, then document the choice in `docs/ASSUMPTIONS.md`.

## Behavioral fidelity guidance
- Preserve package names, public API shape, nested types, responsibilities, and relationships implied by the diagram.
- Preserve likely externally visible contracts such as defaults, null and empty behavior, exception behavior, state transitions, lifecycle ordering, protocol and serialization behavior, configuration semantics, and boundary conditions.
- Prefer conventional library and framework behavior over toy simplifications when ambiguity remains.
- Do not collapse behavior-rich subsystems into thin demo-only implementations.
- If a diagram detail appears flawed, prefer a minimal coherence-restoring correction over a broad redesign.
- If you simplify internals, keep the public behavior compatible and document the limitation in `docs/ASSUMPTIONS.md`.
- Do not add production shims whose main purpose is to satisfy local gates while hiding missing behavior.

## Required repo artifacts
- `README.md` (build/test/run instructions)
- `docs/ASSUMPTIONS.md`
- `docs/ARCHITECTURE.md`
- `docs/USAGE.md`
- `run_demo.sh` (executable)

## Adaptive self-gating protocol
### 1) Declare outcomes first
Create:
- `completion/outcomes.initial.json`
- `completion/gates.v1.json`
- `completion/run_all_gates.sh` (executable)

Required shape:
- `outcomes.initial.json`: array of `{id, description, priority, diagram_rationale}` where `priority` is `core` or `non-core`
- `gates.v1.json`: array of `{id, description, command, outcome_ids}` with non-empty `outcome_ids`
- Every outcome id must be covered by at least one gate
- Outcomes and gates should be designed to catch the kinds of behavioral mismatches hidden original-repository tests are likely to expose, not just compile and smoke success

### 2) Implement and iterate
- Implement the project from the diagram and the declared outcomes.
- You may evolve verification strategy with newer `gates.vN.json` versions.
- Do not mutate `completion/outcomes.initial.json` after declaration.
- Keep all initial outcomes covered in the latest gate version.
- When a gate reveals a mismatch, prefer fixing the implementation over weakening the gate unless the gate is genuinely wrong.

### 3) Produce proof
`completion/run_all_gates.sh` must execute the latest gate set and write:
- `completion/proof/results.vN.json` with `{gate_id, status, exit_code, log_path}`
- `completion/proof/logs/<gate-id>.log`

## Stop condition
Do not stop until both pass:
- `./gate_hard.sh`
- `./scripts/verify_outcome_coverage.sh`
