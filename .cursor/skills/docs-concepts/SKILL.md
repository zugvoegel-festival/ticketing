---
name: docs-concepts
description: >
  Generate or update .vibe/docs/ concept docs from modules/**/README.md only (no .nix reads).
  architecture.md, requirements.md, design.md, optional flow docs.
---

# Docs concepts

**Role:** Cross-module **concept docs** in `.vibe/docs/`. Never read `.nix` source — use module READMEs only.

**Boundary:** `.vibe/docs/` only. Module READMEs → **docs-update** first if missing.

---

## Step 1 — Incremental skip

If `.vibe/docs/.docs-trace.json` has `commit` and no `modules/**/README.md` changed since that commit → report up to date and stop.

---

## Step 2 — Understand system

From `modules/README.md` + all `modules/**/README.md` (and optional file tree listing only):

- Major components, data/control flow, patterns, extension points.

---

## Step 3 — Canonical docs (max ~40 lines each, dense, no source code fences)

| File | Content |
|------|---------|
| `architecture.md` | Goals, scope, building blocks, runtime view, crosscutting, key decisions |
| `requirements.md` | REQ-* EARS-style functional requirements |
| `design.md` | Naming, errors, patterns, boundaries, quality attributes |
| `dependency-graph.md` | Compact module → module graph (optional if not stale) |
| `*-flow.md` | Flows crossing 3+ modules (e.g. `deploy-flow.md`) |

`mkdir -p .vibe/docs` if needed.

---

## Step 4 — Trace

Write `.vibe/docs/.docs-trace.json`:

```json
{
  "commit": "<HEAD>",
  "createdAt": "<preserve or now>",
  "updatedAt": "<now>",
  "files": ["<md files written>"],
  "dependsOn": ["<modules/**/README.md paths read>"]
}
```

---

## Step 5 — Summarize

New vs updated files; whether skip applied. No confirmation prompt.
