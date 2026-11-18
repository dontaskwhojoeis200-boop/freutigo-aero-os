# F1 minimal system: core OS with networking, audio infrastructure, user
# account and graphics stack, but no desktop. Fast to build and boot; the
# smallest configuration that must always work.
#   scripts/test-vm.sh --minimal     (login: freutigo / freutigo)
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../common/placeholder-hardware.nix
  ];

  networking.hostName = "freutigo-minimal";
  freutigo.hardware.gpuProfile = "virtual-machine";
  freutigo.desktop.enable = false;
  freutigo.boot.mode = "none";
  freutigo.user.initialPassword = "freutigo";

  virtualisation.vmVariant.virtualisation = {
    memorySize = 2048;
    cores = 2;
    graphics = false; # serial console in the terminal
  };
}
