# QEMU/KVM guest profile. Used for development testing only — a VM result is
# never evidence of real-GPU compatibility (section XIII, F3).
{ config, lib, ... }:
lib.mkIf (config.freutigo.hardware.gpuProfile == "virtual-machine") {
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
}
