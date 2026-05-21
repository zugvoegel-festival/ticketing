# HANDOVER — Zugvögel Nix-Host (`zugvoegel-festival/ticketing`)

## 1. Kontext

- **Rolle:** NixOS-Flake und Betriebs-SSOT für **pretix-server-01** (`185.232.69.172`).
- **Gehostete Apps:** Pretix, Schwarmplaner (prod + test), 99trees (nur prod), Bank-Automation, Backup, Monitoring.
- **App-Repos** (Docker-CI, eigene GitHub-Secrets): `schwarmplaner`, `99trees`, extern `zugvoegel-festival/pretix` (Dockerfile-Quelle).

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
| `environments/` | Image-Pins: `pretix.nix`, `schwarmplaner-{prod,test}.nix`, `99trees-prod.nix` |
| `.github/workflows/flake-update.yml` | Wöchentlicher nixpkgs Lock-PR |
| `.github/workflows/pretix-build.yml` | Pretix-Image bauen bei `pretix-v*.*.*` |
| `.github/workflows/pretix-deploy.yml` | SSH Deploy Pretix (kein nixos-rebuild) |
| `.github/workflows/pretix-rollback.yml` | Manueller Pretix-Rollback |
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
| `schwarmplaner-test.nix` | Schwarmplaner test | `manulinger/schwarmplaner:test-latest` |
| `99trees-prod.nix` | 99trees | `manulinger/99trees:1.0.2` |

App-Release-Skripte in schwarmplaner/99trees committen Pin-Updates hier (`TICKETING_REPO`, default `../ticketing`).

## 4. Offene manuelle Schritte

1. **Alle Rollout-Änderungen reviewen und committen** (inkl. `environments/`, Workflows, Docs).
2. **Pretix Deploy-Key generieren** und Public Key in `configuration.nix` → `zugvoegel.services.pretix.deployAuthorizedKeys` eintragen.
3. **GitHub Secrets (ticketing-Repo)** setzen:
   - `SSH_KNOWN_HOSTS` = `ssh-keyscan -H 185.232.69.172` (**Pflicht**)
   - `SSH_PRIVATE_KEY` (Pretix deploy key)
   - `DOCKER_USERNAME` / `DOCKER_PASSWORD`
4. **Erstes Host-Deploy nach Merge:**
   ```bash
   ./deploy.sh
   ```
5. **Bei nixpkgs-Migration:** `./update-and-deploy.sh` (ggf. `--boot` bei switch-Inhibitor).
6. **Pretix-Release testen:** Tag `pretix-vX.Y.Z` pushen → `pretix-build.yml` → `pretix-deploy.yml`.
7. **Schwarmplaner/99trees:** App-Repos committen + pushen, dann Test/Prod-Release aus App-Repo (siehe deren HANDOVER).

## 5. Secrets & GitHub

**Repo:** `zugvoegel-festival/ticketing`

| Secret | Zweck |
|--------|--------|
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | Pretix-Image Push |
| `SSH_PRIVATE_KEY` | Pretix CI → `deploy@pretix-server-01` |
| `SSH_HOST` | Optional, Default `185.232.69.172` |
| `SSH_KNOWN_HOSTS` | **Pflicht** für pretix-deploy/rollback |

**Workflows (dieses Repo):**

| Workflow | Trigger |
|----------|---------|
| `flake-update.yml` | Wöchentlich — PR only |
| `pretix-build.yml` | Tag `pretix-v*.*.*` |
| `pretix-deploy.yml` | Nach Build oder manuell |
| `pretix-rollback.yml` | Manuell |

App-Repos haben **eigene** `SSH_*` Secrets für Schwarmplaner/99trees.

## 6. Nächste sinnvolle Agent-Aufgaben

1. *„Review alle uncommitted Änderungen in ticketing, gruppiere in logische Commits und aktualisiere `change_notes` falls vorhanden."*
2. *„Generiere Anleitung für Pretix `deployAuthorizedKeys`: Key-Paar erstellen, Nix eintragen, Secret-Namen dokumentieren — ohne Private Keys ins Repo."*
3. *„Prüfe `modules/pretix/default.nix` sudo-Regeln und vergleiche mit dem Vocura-Muster in vocura-org/vocura."*
4. *„Führe lokal `nix flake check` aus und behebe Eval-Fehler in `environments/*.nix`."*
5. *„Nach `./deploy.sh`: Verifiziere `pretix-container`, `schwarmplaner-{test,prod}-container`, `99trees-prod-container` und Runtime-Dateien unter `/var/lib/*/deploy/`."*
6. *„App-Repos (schwarmplaner/99trees): CI auf `schwarmplaner-restart-container` / `99trees-restart-container` umstellen (statt `systemctl restart docker-*`)."*

## 7. Abhängigkeiten zu anderen Repos

| Repo | Beziehung |
|------|-----------|
| **schwarmplaner** | Release-Skripte pushen Pins nach `environments/schwarmplaner-*.nix`; `deploy.yml` checkt `zugvoegel-festival/ticketing` aus |
| **99trees** | Analog → `environments/99trees-prod.nix` |
| **zugvoegel-festival/pretix** | Dockerfile-Quelle für `pretix-build.yml` |
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
