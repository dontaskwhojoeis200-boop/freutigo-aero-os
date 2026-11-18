{
  writeShellApplication,
  pciutils,
  mesa-demos,
  vulkan-tools,
  gawk,
  gnused,
  gnugrep,
  coreutils,
}:
writeShellApplication {
  name = "freutigo-gpu-diagnostics";
  runtimeInputs = [
    pciutils
    mesa-demos
    vulkan-tools
    gawk
    gnused
    gnugrep
    coreutils
  ];
  # The script sets its own strict mode.
  bashOptions = [ ];
  # Fail the build on real problems; style notes are reviewed in CI lint.
  extraShellCheckFlags = [ "--severity=warning" ];
  text = builtins.readFile ../../scripts/diagnostics.sh;
  meta.description = "Freutigo Aero OS graphics stack diagnostic report";
}
