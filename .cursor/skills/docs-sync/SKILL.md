---
name: docs-sync
description: >
  Surgical factual patches to AGENTS.md, modules/**/README.md, and .vibe/docs/ after code changes.
  Use docs-init when context is missing. Formerly docs-bootstrap.
---

# Docs sync

**Role:** Keep agent context **factually aligned** with code (not full regen).

Shared: [`../docs-shared/README.md`](../docs-shared/README.md)  
Selector: [`../docs-shared/reference/doc-type-selector.md`](../docs-shared/reference/doc-type-selector.md)

| Related | When |
|---------|------|
| **docs-update** | Many module READMEs stale — regen traces |
| **docs-concepts** | Cross-module vibe docs stale |
| **docs-defrag** | Principles / layout audit |
| **docs-init** | Missing hybrid layout |

---

## Scope

| Layer | Files |
|-------|--------|
| Always-loaded | `AGENTS.md`, `CLAUDE.md` (pointers only) |
| Module | `modules/**/README.md`, `modules/README.md` |
| Concepts | `.vibe/docs/*.md` |
| Rules | `.cursor/rules/*.mdc` if conventions changed |

Human-only (unless user asks): `docs/BACKUP.md`, `README.md`, `secrets/README.md`.

---

## Workflow

1. Read changed code areas (targeted, not whole tree).
2. Diff against docs; patch **only stale sections** per doc-type-selector.
3. Remove dead paths (deleted modules, services, URLs).
4. Run verify:

```bash
bash .cursor/skills/docs-shared/scripts/verify-docs.sh
```

---

## Quality checklist

- [ ] No legacy `ARCHITECTURE.md` / `docs/ARCHITECTURE.md` / `docs/AGENTS_*` references reintroduced
- [ ] Module option facts live in `modules/**/README.md`, not `AGENTS.md`
- [ ] `AGENTS.md` ≤200 lines
- [ ] Invariants still true

Suggested commit: `docs: sync agent context for <topic>`
