#!/usr/bin/env bash
# Wrapper: run repo-root update-and-deploy.sh from any cwd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec "$ROOT/update-and-deploy.sh"
