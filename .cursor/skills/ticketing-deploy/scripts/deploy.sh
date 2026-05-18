#!/usr/bin/env bash
# Wrapper: run repo-root deploy.sh from any cwd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec "$ROOT/deploy.sh"
