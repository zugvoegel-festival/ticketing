#!/usr/bin/env bash
# Grep-based principle checks (complement LLM audit in docs-defrag).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ISSUES=0

fail() {
  echo "❌ $1"
  ISSUES=1
}

warn() {
  echo "⚠️  $1"
}

echo "Principles grep checks..."
echo ""

# Stale pointers in always-applied rules
if grep -qE 'ARCHITECTURE\.md|docs/AGENTS_' "$ROOT/.cursor/rules/main.mdc" 2>/dev/null; then
  fail "main.mdc still references ARCHITECTURE.md or docs/AGENTS_*"
else
  echo "✅ main.mdc has no legacy doc pointers"
fi

# CLAUDE.md should not claim trilogy as primary
if grep -qE 'ARCHITECTURE\.md|docs/AGENTS_' "$ROOT/CLAUDE.md" 2>/dev/null; then
  fail "CLAUDE.md still references legacy agent codemaps"
else
  echo "✅ CLAUDE.md has no legacy codemap pointers"
fi

# AGENTS.md doc index
if grep -qE 'ARCHITECTURE\.md|docs/AGENTS_' "$ROOT/AGENTS.md" 2>/dev/null; then
  fail "AGENTS.md still references ARCHITECTURE.md or docs/AGENTS_*"
else
  echo "✅ AGENTS.md has no legacy doc pointers"
fi

# Duplicate skill registration
if [[ -d "$ROOT/.cursor/skills/global-docs-init" ]]; then
  fail "global-docs-init directory still exists"
fi

for dup in docs-sync docs-commit; do
  count=$(find "$ROOT/.cursor/skills" -path "*/bundle/$dup/SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    fail "bundle duplicate skill: $dup"
  fi
done

echo ""
if [[ $ISSUES -eq 0 ]]; then
  echo "✅ Principles grep checks passed"
  exit 0
else
  echo "❌ Principles grep checks failed"
  exit 1
fi
