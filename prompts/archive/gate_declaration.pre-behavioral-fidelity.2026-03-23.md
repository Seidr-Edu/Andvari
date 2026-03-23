You are in phase 1 (gate declaration only) for adaptive self-gating.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Goal for this phase:
- Define diagram-derived completion outcomes and initial verification gates before implementation.
- Do not implement production/test source code in this phase.

Before you start:
- Read `docs/CODE_QUALITY_RULES.md`.
- Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
- Treat the diagram as the behavioral source of truth and the Sonar files as non-functional quality constraints only.

Create these files:
1) completion/outcomes.initial.json
   - JSON array only.
   - Each item: {"id","description","priority","diagram_rationale"}
   - priority must be exactly "core" or "non-core".
2) completion/gates.v1.json
   - JSON array only.
   - Each item: {"id","description","command","outcome_ids"}
   - outcome_ids must be a non-empty JSON array of outcome ids.
3) completion/run_all_gates.sh
   - Executable script.
   - It must locate the latest completion/gates.vN.json.
   - It must execute every gate command from that latest version.
   - It must write completion/proof/results.vN.json with per-gate records:
     {"gate_id","status","exit_code","log_path"}
   - It must write per-gate logs under completion/proof/logs/.
   - Exit non-zero if any gate fails.

Rules:
- Allowed gate versions are v1 through v${MAX_GATE_VERSION}.
- Every outcome id in outcomes.initial.json must appear in at least one gate outcome_ids entry in gates.v1.json.
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- Do not inspect or modify any other run directories.

Return a concise summary of the declared outcomes and gates.
