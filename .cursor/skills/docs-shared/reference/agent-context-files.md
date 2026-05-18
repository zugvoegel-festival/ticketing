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

## AGENTS.md: required sections

### Section 1: Commands (highest priority — AI needs these immediately)

```markdown
## Commands

**Build:** `npm run build`
**Test:** `npm test` or `pytest tests/`
**Lint:** `npm run lint` / `ruff check .`
**Type check:** `npx tsc --noEmit`
**Dev server:** `npm run dev` (port 3000)
**Single test:** `pytest tests/path/test_file.py::test_name -v`
```

Rules:
- Exact commands only — no "run the build script"
- Include the port for dev servers
- Include how to run a single test (agents need this constantly)
- Include any required env vars: `cp .env.example .env` if needed

---

### Section 2: Project structure (codemap)

```markdown
## Structure

src/
  api/        # HTTP handlers — thin layer, no business logic
  services/   # Business logic — core domain (no framework deps)
  models/     # Data models and DB schema
  utils/      # Stateless helpers (no side effects)
tests/        # Mirrors src/ structure
docs/         # ADRs in docs/adr/; product SCOPE (human)
.vibe/docs/   # architecture.md, requirements.md, design.md (agent concepts)
web/README.md # module index → per-folder READMEs
```

Rules:
- Max 10–12 lines
- Purpose comment per directory (not just the name)
- Call out non-obvious naming or structure

---

### Section 3: Conventions

```markdown
## Conventions

- **Naming:** camelCase functions, PascalCase classes, SCREAMING_SNAKE constants
- **Errors:** Always throw typed errors (`class NotFoundError extends AppError`)
- **Async:** Always async/await, never .then() chains
- **Tests:** One test file per source file, same name + `.test.ts`
- **Imports:** Absolute paths via `@app/` alias — no relative `../../` imports
- **Types:** No `any`. Use `unknown` + type guards instead.
```

Rules:
- State the convention AND the anti-pattern to avoid
- Bold the category label for scanability
- Include the "why" only if non-obvious

---

### Section 4: Architectural invariants

```markdown
## Invariants

- `services/` NEVER imports from `api/` — dependency flows inward only
- All DB access goes through `models/` — no raw SQL in services
- `utils/` has zero side effects — pure functions only
- Auth validation happens at API layer — services receive authenticated context
```

Rules:
- State as positive facts ("X never depends on Y")
- These are the things AI agents most commonly violate
- Include direction of dependency for layered architectures

---

### Section 5: Gotchas (optional but high-value)

```markdown
## Gotchas

- Tests reset the DB with `beforeEach(resetDb)` — don't assume state between tests
- `config.ts` lazy-loads env vars — access it only inside functions, not at module level
```

Rules:
- Include only things that have actually caused mistakes
- Max 5–8 items

