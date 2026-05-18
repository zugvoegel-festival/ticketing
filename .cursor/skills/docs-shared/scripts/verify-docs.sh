#!/usr/bin/env bash
# Hybrid layout: AGENTS.md + modules/README.md + .vibe/docs. Fails if legacy agent md exists.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ERRORS=0
WARNINGS=0

check_file() {
  local rel="$1"
  local limit="${2:-0}"
  local path="$ROOT/$rel"
  if [ -f "$path" ]; then
    if [ "$limit" -gt 0 ]; then
      local lines
      lines=$(wc -l < "$path" | tr -d ' ')
      if [ "$lines" -le "$limit" ]; then
        echo "OK $rel (${lines} lines)"
      else
        echo "WARN $rel (${lines} lines, recommended max ${limit})"
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      echo "OK $rel"
    fi
  else
    echo "MISSING $rel"
    ERRORS=1
  fi
}

check_forbidden() {
  local rel="$1"
  if [ -f "$ROOT/$rel" ]; then
    echo "FORBIDDEN (present): $rel"
    ERRORS=1
  else
    echo "OK absent: $rel"
  fi
}

echo "Checking hybrid documentation layout..."
echo ""

echo "=== Layer 0/1: Always-loaded ==="
check_file "AGENTS.md" 200
check_file "CLAUDE.md"

echo ""
echo "=== Layer 2: Module index + concepts ==="
check_file "modules/README.md"
check_file ".vibe/docs/architecture.md" 40
check_file ".vibe/docs/requirements.md" 40
check_file ".vibe/docs/design.md" 40

echo ""
echo "=== Forbidden legacy agent files ==="
check_forbidden "ARCHITECTURE.md"
check_forbidden "docs/ARCHITECTURE.md"
check_forbidden "docs/AGENTS_ARCHITECTURE.md"
check_forbidden "docs/AGENTS_APP.md"
check_forbidden "docs/AGENTS_SERVER.md"

echo ""
echo "=== Obsolete skill paths ==="
if [ -d "$ROOT/.cursor/skills/global-docs-init" ]; then
  echo "FORBIDDEN (present): .cursor/skills/global-docs-init/"
  ERRORS=1
else
  echo "OK absent: .cursor/skills/global-docs-init/"
fi

echo ""
echo "=== MDC rules ==="
check_file ".cursor/rules/core.mdc"
check_file ".cursor/rules/main.mdc"
check_file ".cursor/rules/nix.mdc"

echo ""
if [ "$ERRORS" -eq 0 ]; then
  if [ "$WARNINGS" -gt 0 ]; then
    echo "PASS with $WARNINGS line-limit warning(s)"
  else
    echo "PASS: all required context docs present"
  fi
  exit 0
else
  echo "FAIL: documentation layout check failed"
  exit 1
fi
