Adaptive self-gating implementation phase.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Mode details:
- completion/outcomes.initial.json is immutable after declaration.
- You may evolve verification strategy by adding/replacing completion/gates.vN.json.
- Allowed gate versions are v1 through v${MAX_GATE_VERSION}.
- The latest gate version must still map every initial outcome id to at least one gate.
- The repository will later be evaluated using adapted tests derived from the original repository, and you will not see those tests.
- Optimize for recreating original observable behavior, not merely making the current local gates go green.
- Treat the diagram as the primary behavioral evidence, but not as an infallible specification.

Execution loop (continue until green):
1. Read `docs/CODE_QUALITY_RULES.md`.
2. Read the failure summary below.
3. Implement or fix the repository from the diagram and declared outcomes, using the strongest coherent interpretation when a diagram detail appears flawed.
4. Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
5. Update completion/run_all_gates.sh and completion/proof/results.vN.json behavior as needed.
6. Run ./gate_hard.sh.
7. Run ./scripts/verify_outcome_coverage.sh --max-gate-revisions ${MAX_GATE_REVISIONS} --model-gate-timeout-sec ${MODEL_GATE_TIMEOUT_SEC}
8. If either command fails, continue fixing and rerunning until both pass.

Scope constraints:
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Treat the diagram as the primary behavioral evidence and the Sonar files as non-functional quality constraints only.
- Follow the diagram by default.
- Deviate from a diagram detail only when there is strong evidence it is flawed, such as an internal contradiction, an impossible or incoherent literal implementation, or a small local mistake whose correction produces a more coherent overall design and observable behavior.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- When a failure appears, prefer fixing the implementation over relaxing or replacing a gate.
- Revise gates only when a gate is genuinely a poor or incomplete expression of the intended behavior, and keep the latest gate set at least as behaviorally strong as the previous version.
- Re-check likely hidden-test mismatch areas during repairs: defaults and configuration semantics, exception behavior, null and empty handling, state transitions, lifecycle ordering, protocol or framework contracts, and boundary or temporal semantics.
- Keep any diagram correction minimal and local, preserve the surrounding design, and document the rationale in `docs/ASSUMPTIONS.md`.
- Do not use possible diagram flaws as a license for broad redesigns or unsupported guesswork.
- Preserve diagram-implied package topology and subsystem boundaries instead of collapsing behavior-rich areas into demo-oriented simplifications.
- Do not inspect or modify any other run directories.

Failure summary:
