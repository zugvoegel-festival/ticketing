#!/usr/bin/env bash
# update-and-deploy.sh
# Updates flake inputs and deploys the new version to the server

set -euo pipefail

# Update flake inputs
echo "Updating flake inputs..."
nix flake update

echo "Deploying new version to server..."

# Clean up any stuck systemd transient service units on the remote server
echo "Cleaning up any stuck systemd units..."
ssh root@185.232.69.172 "systemctl reset-failed nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; systemctl stop nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; systemctl daemon-reload" || true

echo "Entering nix-shell for nixos-rebuild..."
nix-shell -p nixos-rebuild --run "nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@185.232.69.172 --build-host root@185.232.69.172  --option eval-cache false"

echo "Deployment complete."
