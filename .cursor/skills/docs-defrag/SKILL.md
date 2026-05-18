---
name: docs-defrag
description: >
  Audit documentation against docs-shared principles and run structural verify-docs.sh.
  Produces docs/defrag-report.md with blocking/warning/suggestion findings. Optional --fix.
---

# Docs defrag

**Role:** “Does our doc set follow the rules?” — not factual code drift (**docs-sync**) or regen (**docs-update**).

---

## Phase 1 — Structural verify (required)

```bash
bash .cursor/skills/docs-shared/scripts/verify-docs.sh
bash .cursor/skills/docs-defrag/scripts/verify-docs-principles.sh
```

Fix **blocking** script failures before finishing (or document as open blockers in report).

---

## Phase 2 — Principles audit (LLM)

Read:

- `.cursor/skills/docs-shared/README.md`
- `.cursor/skills/docs-shared/reference/doc-type-selector.md`
- `.cursor/skills/docs-shared/reference/agent-context-files.md`

Review corpus: `AGENTS.md`, `CLAUDE.md`, `modules/README.md`, `modules/**/README.md`, `.vibe/docs/*.md`, `.cursor/rules/*.mdc`.

Check:

- One source of truth (no duplicate architecture across AGENTS + vibe + READMEs)
- Correct layers (commands in AGENTS only; no module trees in always-loaded files)
- Token density; dead paths (deleted modules, old URLs)
- `AGENTS.md` doc index matches real paths
- Human ops docs (`docs/BACKUP.md`) not copied into agent codemaps
- Module README tier rules (no fenced code blocks, line caps)

---

## Phase 3 — Report

Write **`docs/defrag-report.md`** (gitignored) with sections:

```markdown
# Docs defrag report
Date: ...
Verify scripts: pass | fail

## Blocking
## Warning
## Suggestion
```

Default: **no auto-fix**. With `--fix`: safe mechanical edits only; regen needs → **docs-update** / **docs-concepts** / **docs-sync**.

---

## When to run

| Trigger | |
|---------|---|
| After **docs-init** | Required gate |
| Large refactor | After **docs-sync** |
| Before release | Optional |
