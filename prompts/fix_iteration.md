Gate failed. Fix the repository and get gate_recon.sh to pass.

Source diagram:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Actions:
1. Read `docs/CODE_QUALITY_RULES.md`.
2. Read the gate failure summary below.
3. Apply fixes in this repository.
4. Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
5. Run ./gate_recon.sh.
6. If gate still fails, continue fixing and rerunning until it passes.
7. Return concise summary of root cause and fixes.

Constraints:
- Treat the diagram as the behavioral source of truth and the Sonar files as non-functional quality constraints only.
- If a Sonar quality rule appears to conflict with the diagram, preserve the diagram's behavior and satisfy the quality rule through naming, structure, safety, and maintainability choices.

Gate failure summary (last ~200 lines):
