#!/usr/bin/env bash
# update-and-deploy.sh
# Updates flake inputs and deploys the new version to the server

set -euo pipefail



echo "Deploying new version to server..."
echo "Entering nix-shell for nixos-rebuild..."
nix-shell -p nixos-rebuild --run "nixos-rebuild switch --flake '.#pretix-server-01' --target-host root@185.232.69.172 --build-host root@185.232.69.172  --option eval-cache false"

echo "Deployment complete."
