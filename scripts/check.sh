#!/usr/bin/env bash
# Automated checks for Freutigo Aero OS.
#
#   scripts/check.sh            evaluation checks only: every host, every GPU
#                               profile and the ISO are fully evaluated
#                               (all module assertions run). No building, no
#                               binary cache needed. ~1–3 min.
#   scripts/check.sh --full     `nix flake check`: additionally builds lint
#                               checks (shellcheck, nixfmt) and runs the
#                               QEMU boot test (needs KVM + binary cache).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [[ "${1:-}" == "--full" ]]; then
  exec nix flake check -L
fi

# Untracked files are invisible to flakes; catch that early.
if git rev-parse --git-dir >/dev/null 2>&1; then
  untracked=$(git ls-files --others --exclude-standard -- '*.nix' '*.sh')
  if [[ -n "$untracked" ]]; then
    echo "error: untracked files are ignored by Nix flakes; git add them:" >&2
    echo "$untracked" >&2
    exit 1
  fi
fi

echo "nixpkgs: $(nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked | "\(.ref) @ \(.rev)"')"

names=$(nix eval --json .#checks.x86_64-linux --apply builtins.attrNames | jq -r '.[]' | grep '^eval-')
fail=0
for n in $names; do
  printf '  %-40s ' "$n"
  if log=$(nix eval --raw ".#checks.x86_64-linux.$n.text" 2>&1 >/dev/null); then
    echo "OK"
    grep -E '^(evaluation )?warning:' <<<"$log" | sed 's/^/      /' || true
  else
    echo "FAIL"
    grep -v "^ *$" <<<"$log" | tail -8 | sed 's/^/      /'
    fail=1
  fi
done

for s in scripts/*.sh; do
  bash -n "$s" || { echo "syntax error: $s" >&2; fail=1; }
done
if command -v shellcheck >/dev/null; then
  shellcheck --severity=warning scripts/*.sh || fail=1
else
  echo "  (shellcheck not installed; skipped — run inside 'nix develop')"
fi

exit $fail
