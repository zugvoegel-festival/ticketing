# Runtime container restart scripts

Installed on the host via NixOS modules (`lib/runtime-container.nix`). Logic is generated at eval time; there are no separate `.sh` sources in this directory.

## Commands (on pretix-server-01)

| Command | Usage |
|---------|--------|
| `pretix-restart-container` | `pretix-restart-container prod [tag]` |
| `schwarmplaner-restart-container` | `schwarmplaner-restart-container prod [tag]` |
| `99trees-restart-container` | `99trees-restart-container prod [tag]` |

Without `[tag]`, the tag is read from `/var/lib/<app>/deploy/<env>-image`.

CI and rollback workflows call these with an explicit tag. `./deploy.sh` reconciles the runtime files from `environments/*.nix` via activation scripts.
