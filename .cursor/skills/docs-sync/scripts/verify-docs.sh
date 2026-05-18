#!/usr/bin/env bash
# Delegates to shared verify script (hybrid layout).
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../docs-shared/scripts/verify-docs.sh" "$@"
