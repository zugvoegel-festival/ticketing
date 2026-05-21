# HANDOVER — Zugvögel Nix-Host (`zugvoegel-festival/ticketing`)

## 1. Kontext

- **Rolle:** NixOS-Flake und Betriebs-SSOT für **pretix-server-01** (`185.232.69.172`).
- **Gehostete Apps:** Pretix, Schwarmplaner (nur prod), 99trees (nur prod), Bank-Automation, Backup, Monitoring.
- **App-Repos** (Docker-CI, eigene GitHub-Secrets): `zugvoegel-festival/pretix`, `schwarmplaner`, `99trees`.

## 2. Was wurde geändert (Rollout-Stand, lokal uncommitted)

`git status` (Stand Erstellung dieses Dokuments):

**Geändert (tracked):**

| Datei | Inhalt |
|-------|--------|
| `flake.nix` | nixpkgs `nixos-25.05`, `environments/*.nix` als Module |
| `configuration.nix` | Vereinheitlichter `deploy`-User, `deployAuthorizedKeys` pro Service |
| `deploy.sh` | `--switch` / `--boot`, Ziel `pretix-server-01` @ `185.232.69.172` |
| `modules/pretix/default.nix` | `pretix-deploy-backup`, sudo-Regeln für CI-Deploy |
| `modules/schwarmplaner/default.nix` | Deploy-Backup-Integration bereinigt |
| `modules/99trees/default.nix` | Analog |

**Neu (untracked):**

| Pfad | Inhalt |
|------|--------|
| `environments/` | Image-Pins: `pretix.nix`, `schwarmplaner-prod.nix`, `99trees-prod.nix` |
| `.github/workflows/flake-update.yml` | Wöchentlicher nixpkgs Lock-PR |
| `docs/deploy-overview.md` | Deploy-SSOT |
| `docs/runbook.md` | Operator-Checkliste |

**Kritischer Stand in `configuration.nix`:**

- `zugvoegel.services.pretix.deployAuthorizedKeys = [ ];` — **leer**, Pretix-CI kann noch nicht deployen.
- Schwarmplaner + 99trees: Deploy-Keys bereits eingetragen.

## 3. Architektur / Deploy-Modell

Zwei Schichten:

| Schicht | Verantwortung | Deploy |
|---------|---------------|--------|
| **Host / Module** | nginx, Docker-Units, Secrets, Monitoring, Pins in Nix | `./deploy.sh` oder `./update-and-deploy.sh` |
| **App-Container** | Immutable Docker-Tags | CI → SSH `deploy` → Backup → `<app>-restart-container <env> <tag>` (Runtime-Pin unter `/var/lib/<app>/deploy/`) |

**Dokumentation:**

- [`docs/deploy-overview.md`](docs/deploy-overview.md) — Architektur, CI-Tabelle, Secrets
- [`docs/runbook.md`](docs/runbook.md) — Operator-Schritte
- [`modules/README.md`](modules/README.md) — Modul-Karte

**Image-Pins (`environments/`):**

| Datei | Service | Beispiel-Pin |
|-------|---------|--------------|
| `pretix.nix` | Pretix | `manulinger/zv-ticketing:pretix-latest` |
| `schwarmplaner-prod.nix` | Schwarmplaner prod | `manulinger/schwarmplaner:0.1.5` |
| `99trees-prod.nix` | 99trees | `manulinger/99trees:1.0.2` |

App-Release-Skripte in pretix/schwarmplaner/99trees committen Pin-Updates hier (`TICKETING_REPO`, default `../ticketing`).

## 4. Offene manuelle Schritte

1. **Alle Rollout-Änderungen reviewen und committen** (inkl. `environments/`, Workflows, Docs).
2. **Pretix Deploy-Key generieren** und Public Key in `configuration.nix` → `zugvoegel.services.pretix.deployAuthorizedKeys` eintragen.
3. **GitHub Secrets (pretix-Repo)** setzen — siehe `pretix/DEPLOYMENT.md`:
   - `SSH_KNOWN_HOSTS` = `ssh-keyscan -H 185.232.69.172` (**Pflicht**)
   - `SSH_PRIVATE_KEY` (Pretix deploy key)
   - `DOCKER_USERNAME` / `DOCKER_PASSWORD`
4. **Erstes Host-Deploy nach Merge:**
   ```bash
   ./deploy.sh
   ```
5. **Bei nixpkgs-Migration:** `./update-and-deploy.sh` (ggf. `--boot` bei switch-Inhibitor).
6. **Pretix-Release testen:** `bash pretix/.cursor/skills/release/scripts/release-prod.sh` oder Tag `vX.Y.Z` in pretix → `docker-build.yml` → `deploy.yml`.
7. **Schwarmplaner/99trees:** App-Repos committen + pushen, dann Prod-Release aus App-Repo (CI: `*-restart-container`, siehe deren HANDOVER).

## 5. Secrets & GitHub

**Repo:** `zugvoegel-festival/ticketing` — nur Host-Infra (`flake-update.yml`). Keine App-Deploy-Secrets.

**Repo:** `zugvoegel-festival/pretix` — Pretix CI-Secrets (`DOCKER_*`, `SSH_*`); Workflows `docker-build.yml`, `deploy.yml`, `rollback.yml`.

**Workflows (ticketing):**

| Workflow | Trigger |
|----------|---------|
| `flake-update.yml` | Wöchentlich — PR only |

App-Repos (pretix, schwarmplaner, 99trees) haben **eigene** `SSH_*` / `DOCKER_*` Secrets.

## 6. Nächste sinnvolle Agent-Aufgaben

1. *„Review alle uncommitted Änderungen in ticketing, gruppiere in logische Commits und aktualisiere `change_notes` falls vorhanden."*
2. *„Generiere Anleitung für Pretix `deployAuthorizedKeys`: Key-Paar erstellen, Nix eintragen, Secret-Namen dokumentieren — ohne Private Keys ins Repo."*
3. *„Prüfe `modules/pretix/default.nix` sudo-Regeln und vergleiche mit dem Vocura-Muster in vocura-org/vocura."*
4. *„Führe lokal `nix flake check` aus und behebe Eval-Fehler in `environments/*.nix`."*
5. *„Nach `./deploy.sh`: Verifiziere `pretix-container`, `schwarmplaner-prod-container`, `99trees-prod-container` und Runtime-Dateien unter `/var/lib/*/deploy/`."*
6. *„App-Repos (schwarmplaner/99trees): CI-Workflows committen/pushen (`schwarmplaner-restart-container prod` / `99trees-restart-container prod`)."*

## 7. Abhängigkeiten zu anderen Repos

| Repo | Beziehung |
|------|-----------|
| **schwarmplaner** | Release-Skripte pushen Pins nach `environments/schwarmplaner-prod.nix`; `deploy.yml` checkt `zugvoegel-festival/ticketing` aus |
| **99trees** | Analog → `environments/99trees-prod.nix` |
| **zugvoegel-festival/pretix** | `docker-build.yml` / `deploy.yml` / `rollback.yml`; Release-Skript pinnt `environments/pretix.nix` |
| **vocura** | Separater Host (soundwave) — **keine** Abhängigkeit zu diesem Repo |

**Checkout-Token:** App-Deploy-Workflows nutzen `actions/checkout` auf public Repo `zugvoegel-festival/ticketing` (kein extra PAT nötig, solange public).

## 8. Wichtige Befehle

```bash
# Pinned deploy (ohne flake update)
./deploy.sh
./deploy.sh --boot    # bei switch-Inhibitor

# nixpkgs update + deploy
./update-and-deploy.sh

# Secrets bearbeiten
nix-shell -p sops --run "sops secrets/secrets.yaml"

# Flake lokal prüfen
nix flake check

# Remote rebuild (manuell, falls deploy.sh nicht reicht)
nixos-rebuild switch --flake '.#pretix-server-01' \
  --target-host root@185.232.69.172 --build-host root@185.232.69.172
```

## 9. Nicht anfassen / Invarianten

- **Kein Auto-Commit.**
- **Kein Force-Push** auf `main`/`master`.
- **SOPS:** `secrets/secrets.yaml` verschlüsselt — Keys nie im Klartext committen.
- **Merge von flake-update PR deployt nicht automatisch** — `./update-and-deploy.sh` auf dem Host ausführen.
- **CI deployt keine NixOS-Module** — nur Container restart; Host-Änderungen immer `./deploy.sh`.
- Pretix-Deploy **blockiert**, solange `deployAuthorizedKeys` leer ist.
