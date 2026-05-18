# Project skills

Scripts live at `.cursor/skills/{skill-name}/scripts/`. Run from repo root.

## Doc skills (hybrid agent context)

| Skill | Role |
|-------|------|
| **docs-init** | Global `~/.cursor/skills/docs-init` — one-time bootstrap |
| **docs-shared** | Reference only (principles, verify script) |
| **docs-sync** | Surgical factual patches after code changes |
| **docs-update** | Regen `modules/**/README.md` from `.nix` sources |
| **docs-concepts** | Regen `.vibe/docs/` from module READMEs |
| **docs-defrag** | Principles audit + verify gate |
| **docs-commit** | Commits, changelog, doc gate |

Verify layout:

```bash
bash .cursor/skills/docs-shared/scripts/verify-docs.sh
```

## Project-specific

| Skill | Script | Command |
|-------|--------|---------|
| **ticketing-deploy** | deploy.sh | `bash .cursor/skills/ticketing-deploy/scripts/deploy.sh` |
| **ticketing-deploy** | update-and-deploy.sh | `bash .cursor/skills/ticketing-deploy/scripts/update-and-deploy.sh` |

Changelog draft: `change_notes.md` in project root.
