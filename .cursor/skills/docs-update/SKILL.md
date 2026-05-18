---
name: docs-update
description: >
  Regenerate module READMEs and .docs-trace.json under modules/ (incremental or --full).
  Updates modules/README.md module index. Concept docs are docs-concepts.
---

# Docs update

**Role:** Regenerate **module READMEs** from source. Does not edit `AGENTS.md` or `.vibe/docs/`.

**Boundary:** Module READMEs + traces only. Cross-module concepts → **docs-concepts**.

---

## Target

Argument: `$ARGUMENTS` (strip `--full` if present). Default root: **`modules/`**.

- **Incremental:** Only dirs whose `.nix` files changed since trace commit, or dirs without a trace.
- **`--full`:** All module dirs under target + always refresh `modules/README.md` index.

NixOS note: each `modules/<name>/` dir is one module; read `default.nix` and sibling `.nix` files.

---

## Step 1 — Identify directories

1. List dirs containing `.nix` under target (exclude `dashboards/` subdirs unless they are the only content).
2. For each dir with `.docs-trace.json`, compare `git diff trace.commit..HEAD` for `*.nix` in that dir.
3. Collect: **needs update**, **no trace**, or all dirs if `--full`.
4. If none need update (not full), report and stop.

---

## Step 2 — Per directory

1. `ls` dir; read each `.nix` file.
2. **Tier:** Tier 2 if module defines complex submodules, multiple instances, or deploy/sudo wiring; else Tier 1.
3. Tier 2: note **Used by** references from `configuration.nix` and sibling modules.
4. Write `<dir>/README.md` and `<dir>/.docs-trace.json`.

**Tier 1** (~12 lines max): `# Display Name`, Purpose, one-clause bullets per file/subdir. No tables, no fenced code blocks.

**Tier 2** (~22 lines max): Purpose, optional State, option/service bullets, **Used by**, **Depends on**.

**Trace JSON:**

```json
{
  "commit": "<git rev-parse HEAD>",
  "createdAt": "<preserve or now ISO>",
  "updatedAt": "<now ISO>",
  "files": ["<relative paths read>"]
}
```

Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` for timestamps.

---

## Step 3 — Module index

When processing multiple dirs or `--full`, write **`modules/README.md`**:

```markdown
# Module Index

**Purpose:** One-line map of documented NixOS modules. Load full READMEs only for modules relevant to the current task.

- **path**: one-line from that README Purpose
```

List every documented dir under `modules/` that has a `README.md`.

---

## Step 4 — Summarize

Report: skipped (up to date), updated, newly documented, index written.

Do not ask for confirmation.
