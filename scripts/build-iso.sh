#!/usr/bin/env bash
# Build the Freutigo Aero OS installation ISO and record checksums + build info.
#
# Usage: scripts/build-iso.sh [--offline-host HOST]
#   --offline-host HOST  embed HOST's full system closure for offline install
#                        (HOST must not enable Steam).
#
# Requires: Linux x86_64 with Nix (flakes enabled) and access to
# cache.nixos.org (or a lot of time to build from source).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OFFLINE_HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline-host) OFFLINE_HOST="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

attr=".#nixosConfigurations.installation-iso.config.system.build.isoImage"
if [[ -n "$OFFLINE_HOST" ]]; then
  # Override via --impure expression so the committed config stays default.
  echo "Building offline ISO embedding host '$OFFLINE_HOST'..." >&2
  out=$(nix build --no-link --print-out-paths --impure --expr "
    let f = builtins.getFlake (toString $ROOT);
    in (f.nixosConfigurations.installation-iso.extendModules {
         modules = [ { freutigo.iso.includeTargetClosure = \"$OFFLINE_HOST\"; } ];
       }).config.system.build.isoImage")
else
  out=$(nix build --no-link --print-out-paths "$attr")
fi

mkdir -p dist
iso=$(find "$out/iso" -name '*.iso' | head -1)
[[ -n "$iso" ]] || { echo "error: no ISO produced in $out" >&2; exit 1; }
name=$(basename "$iso")
[[ -n "$OFFLINE_HOST" ]] && name="${name%.iso}-offline-${OFFLINE_HOST}.iso"
cp --no-preserve=mode "$iso" "dist/$name"
(cd dist && sha256sum "$name" > "$name.sha256")

rev=$(nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev')
cat > "dist/${name%.iso}.buildinfo" <<EOF
artifact: $name
built: $(date -u +%Y-%m-%dT%H:%M:%SZ)
freutigo-git-rev: $(git rev-parse HEAD 2>/dev/null || echo unknown)$(git diff --quiet 2>/dev/null || echo "-dirty")
nixpkgs-rev: $rev
nix-version: $(nix --version)
build-host: $(uname -srm)
store-path: $out
offline-host: ${OFFLINE_HOST:-none}
EOF

echo "ISO:       dist/$name"
echo "SHA-256:   $(cut -d' ' -f1 "dist/$name.sha256")"
echo "Buildinfo: dist/${name%.iso}.buildinfo"
