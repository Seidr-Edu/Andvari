Reconstruct this Java repository from the source-of-truth diagram at:
../input/diagram.puml

Policy:
- Follow AGENTS.md in this repository as the authoritative requirements document.
- If any instruction in this prompt appears to conflict with AGENTS.md, AGENTS.md wins.

Execution:
1. Read `docs/CODE_QUALITY_RULES.md`.
2. Read `../input/diagram.puml`.
3. Reconstruct the repo accordingly.
4. Consult `completion/context/sonar_rules.lock.json` only when you need exact rule metadata or parameter values.
5. Run ./gate_recon.sh.
6. If gate fails, fix and rerun until it passes.

Scope constraints:
- Operate only inside this run repository.
- Use ../input/diagram.puml as read-only input.
- Treat the diagram as the behavioral source of truth and the Sonar files as non-functional quality constraints only.
- Do not inspect or modify any other run directories.

Return a concise summary including final gate result.
