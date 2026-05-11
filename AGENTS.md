# Agent notes (ticketing)

Dense pointers only; narrative lives in `README.md`, codemap in `docs/ARCHITECTURE.md`.

## Commands

- **Deploy (scripted host):** `./deploy.sh`
- **Deploy + bump inputs:** `./update-and-deploy.sh`
- **Eval/build system locally:** `nixos-rebuild build --flake '.#pretix-server-01'`
- **Secrets:** `nix-shell -p sops --run "sops secrets/secrets.yaml"`

## Docs

- `docs/ARCHITECTURE.md` — modules, flake, invariants, where to edit
- `docs/BACKUP.md` — restic layout, secrets keys, restore flow

## Conventions

- Service options: `zugvoegel.services.<module>` in `modules/*/default.nix`
- New module: `modules/foo/default.nix` is picked up automatically by `flake.nix`
