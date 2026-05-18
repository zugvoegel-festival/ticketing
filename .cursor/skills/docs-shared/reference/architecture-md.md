# .vibe/docs/architecture.md

Cross-module architecture doc (arc42-lite). **Not** a root-level `ARCHITECTURE.md` file.

## Required themes (max ~40 lines total)

1. **Introduction and goals** — what the system does (2–3 sentences).
2. **Context and scope** — in/out of scope, external interfaces.
3. **Building block view** — layers table or short list (`web/app`, `web/server`, `web/shared`).
4. **Runtime view** — key flows (play loop, auth); optional sequence bullets.
5. **Crosscutting** — sessions, config, migrations, scoring single source.
6. **Architectural decisions** — dependency direction, server owns game truth.

## Guidelines

- Dense bullets; no fenced source code.
- API route trees belong in `web/server/api/**/README.md`, not here.
- Mermaid only if it clarifies boundaries (keep small).
- `dependency-graph.md` holds module → module edges.

## Related

- Module detail: `web/README.md` → per-folder READMEs.
- Product spec (human, German): `docs/SCOPE.md` — do not duplicate.
