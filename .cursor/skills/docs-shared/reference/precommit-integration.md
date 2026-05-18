# Pre-commit integration (optional)

This repo uses “docs as infrastructure”. When staging changes, do a quick check:

1. Do staged changes make `AGENTS.md`, `modules/**/README.md`, or `.vibe/docs/` incorrect?
2. If yes, update the relevant doc(s) **in the same commit**.

If you want a hook-driven workflow later, integrate **docs-commit** (doc gate + changelog) and run `bash .cursor/skills/docs-shared/scripts/verify-docs.sh` before allowing commits.
