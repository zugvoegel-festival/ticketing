---
name: docs-commit
description: >
  Logical commits, change_notes.md, and doc gate when staged code makes agent docs wrong.
  Use docs-sync for bulk refactors. Formerly docs-commit-check.
---

# Docs commit

**Role:** Commit-time hygiene — not full doc rewrite.

Shared: [`../docs-shared/README.md`](../docs-shared/README.md)  
Selector: [`../docs-shared/reference/doc-type-selector.md`](../docs-shared/reference/doc-type-selector.md)

---

## Rules

- Commit **only on explicit user request**. Never auto-commit.
- One logical unit per commit; one changelog bullet each.

---

## Doc gate (same commit if factually wrong)

| If commit changes… | Update |
|--------------------|--------|
| Commands, structure, invariants, gotchas | `AGENTS.md` |
| Module options, services, deploy wiring | relevant `modules/**/README.md` |
| Boundaries, flows, cross-cutting architecture | `.vibe/docs/architecture.md` (or `docs-concepts`) |
| Doc index pointers | `AGENTS.md` Doc index section |

If only incomplete (not wrong), follow-up **docs-sync** / **docs-update** is OK.

---

## Changelog

`change_notes.md` sections: What's New, Bug Fixes, Improvements, Documentation, Breaking Changes.

```bash
bash .cursor/skills/docs-commit/scripts/change-notes-template.sh
```

---

## Verify (optional after batch)

```bash
bash .cursor/skills/docs-shared/scripts/verify-docs.sh
```
