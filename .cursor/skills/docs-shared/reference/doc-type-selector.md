# Doc type selector

Pick the smallest doc that keeps future changes fast and safe.

Used by **docs-init**, **docs-sync**, **docs-commit**, **docs-defrag** — see [`../README.md`](../README.md).

## Decision logic

- Repository-wide commands, structure, invariants → `AGENTS.md` (and `.cursor/rules/*.mdc` if needed).
- Boundaries, flows, cross-cutting architecture → `.vibe/docs/architecture.md` (or run **docs-concepts**).
- “Where to change X” for a module → that module’s `modules/**/README.md` (regen via **docs-update** if large drift).
- Durable architectural decision → ADR under `docs/adr/`.
- Restic restore / backup ops → `docs/BACKUP.md` (human ops, not agent codemap).

## Anti-patterns

- Do not recreate `ARCHITECTURE.md`, `docs/ARCHITECTURE.md`, or `docs/AGENTS_*.md`.
- Do not duplicate architecture in `AGENTS.md` and `.vibe/docs/`.
- Do not use **create-rule** to paste full codemaps into `.mdc` files.
