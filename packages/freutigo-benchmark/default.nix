{
  writeShellApplication,
  gawk,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "freutigo-benchmark";
  runtimeInputs = [
    gawk
    coreutils
    gnugrep
  ];
  bashOptions = [ ];
  # Fail the build on real problems; style notes are reviewed in CI lint.
  extraShellCheckFlags = [ "--severity=warning" ];
  text = builtins.readFile ../../scripts/benchmark.sh;
  meta.description = "Freutigo Aero OS idle memory/CPU/disk measurement (section 6.1 method)";
}
