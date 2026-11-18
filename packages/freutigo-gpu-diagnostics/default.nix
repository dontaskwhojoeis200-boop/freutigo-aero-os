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
  text = builtins.readFile ../../scripts/diagnostics.sh;
  meta.description = "Freutigo Aero OS graphics stack diagnostic report";
}
