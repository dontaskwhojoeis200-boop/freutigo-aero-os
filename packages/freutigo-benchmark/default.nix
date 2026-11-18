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
  text = builtins.readFile ../../scripts/benchmark.sh;
  meta.description = "Freutigo Aero OS idle memory/CPU/disk measurement (section 6.1 method)";
}
