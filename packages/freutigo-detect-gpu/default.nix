{
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  util-linux,
}:
writeShellApplication {
  name = "freutigo-detect-gpu";
  runtimeInputs = [
    coreutils
    gawk
    gnugrep
    gnused
    util-linux # dmesg
  ];
  bashOptions = [ ];
  # Fail the build on real problems; style notes are reviewed in CI lint.
  extraShellCheckFlags = [ "--severity=warning" ];
  text = builtins.readFile ../../scripts/detect-gpu-profile.sh;
  meta.description = "Suggest a Freutigo Aero OS GPU profile for the running hardware";
}
