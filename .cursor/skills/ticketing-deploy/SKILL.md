---
name: ticketing-deploy
description: >
  Runs the ticketing repo NixOS host workflows via `./deploy.sh` and
  `./update-and-deploy.sh` (flake `pretix-server-01`, remote `nixos-rebuild switch`).
  Use when the user asks to deploy, push config to the server, run update-and-deploy,
  or refresh flake inputs before a deploy.
disable-model-invocation: true
---

# Ticketing — deploy & update-and-deploy

## When to use

- User explicitly wants **production deploy** or **flake update + deploy**.
- Do **not** run these scripts on vague “maybe deploy” — confirm intent if unclear.

## Preconditions

- Either **repository root** when calling `./deploy.sh` / `./update-and-deploy.sh`, **or** any cwd when using the **wrapper scripts** below (they resolve the repo root).
- **Network** and SSH access as assumed by the scripts (host/user are **pinned inside** `deploy.sh` / `update-and-deploy.sh`).
- Local **Nix** with `nix-shell` / `nixos-rebuild` available as used by the scripts.

## `./deploy.sh` (repo root)

- Runs **`nixos-rebuild switch`** for flake **`.#pretix-server-01`** against the **remote build+target** hosts defined in the script.
- Does **not** run `nix flake update` — deploys whatever **`flake.lock`** already pins.

```bash
./deploy.sh
```

**From any cwd** (delegates to the same root scripts):

```bash
bash .cursor/skills/ticketing-deploy/scripts/deploy.sh
```

## `./update-and-deploy.sh` (repo root)

- Runs **`nix flake update`**, then optional **SSH cleanup** for stuck `nixos-rebuild-switch-to-configuration` units on the remote host, then the **same** `nixos-rebuild switch` path as `deploy.sh`.

```bash
./update-and-deploy.sh
```

**From any cwd:**

```bash
bash .cursor/skills/ticketing-deploy/scripts/update-and-deploy.sh
```

## Choose one

| Goal | Script |
|------|--------|
| Ship **current lockfile** only | `./deploy.sh` |
| **Bump flake inputs** then ship | `./update-and-deploy.sh` |

## Local check (no remote switch)

Eval/build configuration only:

```bash
nixos-rebuild build --flake '.#pretix-server-01'
```

Short command list: `AGENTS.md`. Module map: `modules/README.md`. Cross-module context: `.vibe/docs/`.
