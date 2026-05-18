# Agent Context Files: AGENTS.md / CLAUDE.md / .cursor/rules

These files are **loaded on every AI agent interaction**. Every token counts.
Write for density, not completeness. If it can be inferred from code, omit it.

---

## File hierarchy and tool support

| File | Tools that read it | Scope |
|---|---|---|
| `AGENTS.md` | Claude Code, Cursor, Copilot, Windsurf, OpenAI Codex, Aider, Gemini CLI | Universal — use this as primary |
| `CLAUDE.md` | Claude Code only | Claude-specific overrides |
| `.cursor/rules/*.mdc` | Cursor only | Can be glob-scoped per directory |
| `.github/copilot-instructions.md` | GitHub Copilot | Copilot-specific |

**Strategy:** Put shared content in `AGENTS.md`. Put tool-specific config in
native files. Use symlinks where duplication is unavoidable.

---

## AGENTS.md: required sections (ticketing / NixOS flake)

### Section 1: Commands

```markdown
## Commands

- **Deploy (scripted host):** `./deploy.sh`
- **Eval/build system locally:** `nixos-rebuild build --flake '.#pretix-server-01'`
- **Secrets:** `nix-shell -p sops --run "sops secrets/secrets.yaml"`
```

Rules: exact commands only; no guessed scripts.

### Section 2: Project structure (codemap)

```markdown
## Structure

flake.nix              # nixosConfigurations + auto-exported nixosModules
configuration.nix      # host: enable services, hosts, ports, backup jobs
modules/<name>/        # NixOS service modules (see modules/README.md)
secrets/               # sops-encrypted secrets
docs/BACKUP.md         # human ops: restic restore flow
.vibe/docs/            # architecture.md, requirements.md, design.md (agent concepts)
```

### Section 3: Invariants

- `zugvoegel.services.<name>` option namespace
- New module: `modules/<name>/default.nix` auto-picked up by flake
- Secrets via sops only; CI deploy via unprivileged `deploy` user

### Section 4: Doc index

Point to `modules/README.md`, `.vibe/docs/`, `docs/BACKUP.md` — not legacy `ARCHITECTURE.md`.

---

## CLAUDE.md

Short pointer block to `AGENTS.md`, `modules/README.md`, `.vibe/docs/`.

---

## .cursor/rules

- `core.mdc` — git/security invariants (always apply)
- `main.mdc` — doc index pointers
- `nix.mdc` — glob-scoped Nix module conventions
