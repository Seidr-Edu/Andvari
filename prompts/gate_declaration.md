You are in phase 1 (gate declaration only) for adaptive self-gating.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Goal for this phase:
- Define diagram-derived completion outcomes and initial verification gates before implementation.
- Maximize confidence that the reconstructed repository will match the unseen original repository's observable behavior, not merely compile and pass shallow local checks.
- Do not implement production/test source code in this phase.

Before you start:
- Read `docs/CODE_QUALITY_RULES.md`.
- Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
- Treat the diagram as the primary behavioral evidence and the Sonar files as non-functional quality constraints only.
- Assume most diagram details are useful, but some may be omitted, inconsistent, or incorrect.
- Follow the diagram by default.
- Remember that this repository will later be evaluated using adapted tests derived from the original repository, and you will not see those tests.

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
- outcomes.initial.json must cover, at minimum:
  - diagram-aligned repository, package, and type structure
  - public API and observable behavior implied by the diagram
  - defaults, null and empty behavior, error behavior, and boundary conditions
  - runtime or integration surfaces implied by the diagram
  - build, test, demo, and documentation viability
- gates.v1.json must include, at minimum:
  - one structure or layout gate
  - one behavioral contract gate
  - one edge-case or error-semantics gate
- If you suspect a diagram flaw, include at least one outcome and one gate that validate the chosen resolution.
- Plan to deviate from a diagram detail only when there is strong evidence it is flawed, and keep any such deviation minimal and local.
- Prefer gates that execute meaningful behavior.
- Do not rely only on file existence, compilation, or smoke checks unless those checks are part of a stronger behavior-oriented gate set.
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.
- Do not inspect or modify any other run directories.

Return a concise summary of the declared outcomes and gates.
