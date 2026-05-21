# Agent notes (ticketing)

Dense pointers only; narrative lives in `README.md`, module map in `modules/README.md`.

## Commands

- **Deploy (scripted host):** `./deploy.sh` (optional `--boot` if switch is inhibited)
- **Deploy + bump inputs:** `./update-and-deploy.sh`
- **Eval/build system locally:** `nixos-rebuild build --flake '.#pretix-server-01'`
- **Secrets:** `nix-shell -p sops --run "sops secrets/secrets.yaml"`

## Structure

```
flake.nix              # nixosConfigurations + auto-exported nixosModules
configuration.nix      # host: enable services, backup jobs, shared deploy user
environments/          # per-app Docker image pins (imported by flake.nix)
modules/<name>/        # NixOS service modules (see modules/README.md)
secrets/               # sops-encrypted secrets (secrets/secrets.yaml)
docs/BACKUP.md         # human ops: restic restore flow
.vibe/docs/            # cross-module architecture (agent concepts)
```

## Invariants

- Festival services use option namespace `zugvoegel.services.<name>` (see `modules/*/default.nix`).
- New module: add `modules/<name>/default.nix` — picked up automatically by `flake.nix` (`readDir ./modules`).
- Secrets: edit encrypted `secrets/secrets.yaml` with sops only; runtime via sops-nix (`/run/secrets/…`).
- CI deploy (Pretix, Schwarmplaner, 99trees): unprivileged `deploy` user — not root SSH keys.
- App image pins in `environments/*.nix`; host/module changes via `./deploy.sh`, container bumps via CI.

## Docs

- `modules/README.md` — module index; per-module READMEs under `modules/<name>/`
- `.vibe/docs/` — architecture, requirements, design, dependency graph, deploy-flow
- `docs/BACKUP.md` — restic layout, secrets keys, restore flow (human ops)
- `docs/deploy-overview.md` / `docs/runbook.md` — deploy SSOT and operator checklist (human ops)
