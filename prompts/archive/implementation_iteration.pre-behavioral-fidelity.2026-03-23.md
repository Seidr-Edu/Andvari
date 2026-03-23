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

Execution loop (continue until green):
1. Read `docs/CODE_QUALITY_RULES.md`.
2. Read the failure summary below.
3. Implement/fix the repository from the diagram.
4. Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
5. Update completion/run_all_gates.sh and completion/proof/results.vN.json behavior as needed.
6. Run ./gate_hard.sh.
7. Run ./scripts/verify_outcome_coverage.sh --max-gate-revisions ${MAX_GATE_REVISIONS} --model-gate-timeout-sec ${MODEL_GATE_TIMEOUT_SEC}
8. If either command fails, continue fixing and rerunning until both pass.

Scope constraints:
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Treat the diagram as the behavioral source of truth and the Sonar files as non-functional quality constraints only.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- Do not inspect or modify any other run directories.

Failure summary:
