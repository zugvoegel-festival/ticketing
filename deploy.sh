#!/usr/bin/env bash
# deploy.sh
# Deploys the pinned flake to the server without updating inputs.

set -euo pipefail

ACTION="switch"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --boot)
      ACTION="boot"
      shift
      ;;
    --switch)
      ACTION="switch"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./deploy.sh [--switch|--boot]

Options:
  --switch   Deploy and activate immediately (default).
  --boot     Build/set next boot generation; activate on reboot.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help to see available options." >&2
      exit 1
      ;;
  esac
done

echo "Deploying pinned flake to pretix-server-01..."
echo "Running nixos-rebuild ($ACTION) via remote build host..."
# Pinned nixos-rebuild from flake (apps.<host-system>.nixos-rebuild).
# --fast: skip re-exec as x86_64-linux nixos-rebuild (cannot run on darwin).
nix run .#nixos-rebuild -- \
  "${ACTION}" \
  --fast \
  --flake '.#pretix-server-01' \
  --target-host root@185.232.69.172 \
  --build-host root@185.232.69.172 \
  --option eval-cache false

echo "Deployment complete."
