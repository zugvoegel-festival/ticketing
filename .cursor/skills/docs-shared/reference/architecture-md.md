# .vibe/docs/architecture.md

Cross-module architecture doc (arc42-lite). **Not** `ARCHITECTURE.md` or `docs/ARCHITECTURE.md`.

## Required themes (max ~40 lines total)

1. **Introduction and goals** — NixOS flake purpose, host name, service namespace.
2. **Context and scope** — in/out of scope (app images vs this repo), external deps (S3, ACME, CI).
3. **Building block view** — table of `modules/*` roles + host/flake/secrets layers.
4. **Runtime view** — Internet → nginx → Docker services; backup and monitoring paths.
5. **Crosscutting** — sops, deploy user, backup URL pattern, security headers.
6. **Architectural decisions** — flake module discovery, doc layer split.

## Guidelines

- Dense bullets; no fenced source code.
- Per-module options belong in `modules/<name>/README.md`, not here.
- Mermaid only if it clarifies boundaries (keep small).
- `dependency-graph.md` holds module → module edges; `deploy-flow.md` for multi-module deploy paths.

## Related

- Module detail: `modules/README.md` → per-module READMEs.
- Human backup ops: `docs/BACKUP.md` — do not duplicate.
