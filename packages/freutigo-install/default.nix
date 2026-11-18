# The guided installer. nixos-install / nixos-generate-config / nixos-enter
# are taken from the running NixOS system's PATH (they must match the
# installer image), so they are deliberately not listed here.
{
  writeShellApplication,
  freutigo-detect-gpu,
  coreutils,
  curl,
  dosfstools,
  e2fsprogs,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  kbd,
  parted,
  systemd,
  util-linux,
}:
writeShellApplication {
  name = "freutigo-install";
  runtimeInputs = [
    freutigo-detect-gpu
    coreutils
    curl
    dosfstools
    e2fsprogs
    findutils
    gawk
    git
    gnugrep
    gnused
    kbd
    parted
    systemd
    util-linux
  ];
  bashOptions = [ ];
  # Fail the build on real problems; style notes are reviewed in CI lint.
  extraShellCheckFlags = [ "--severity=warning" ];
  text = builtins.readFile ../../scripts/freutigo-install.sh;
  meta.description = "Freutigo Aero OS guided installer";
}
