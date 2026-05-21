#!/usr/bin/env bash
# update-and-deploy.sh
# Updates flake inputs and delegates deployment to deploy.sh

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: ./update-and-deploy.sh [--switch|--boot]

Options:
  --switch   Update inputs, then deploy with switch (default).
  --boot     Update inputs, then deploy with boot.
EOF
  exit 0
fi

echo "Updating flake inputs..."
nix flake update

echo "Cleaning up any stuck systemd units on pretix-server-01..."
ssh root@185.232.69.172 \
  "systemctl reset-failed nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; \
   systemctl stop nixos-rebuild-switch-to-configuration.service 2>/dev/null || true; \
   systemctl daemon-reload" || true

./deploy.sh "$@"

echo "Update and deployment complete."
