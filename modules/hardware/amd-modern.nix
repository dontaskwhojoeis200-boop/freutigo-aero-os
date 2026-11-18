# AMD GCN 3+ / RDNA profile. amdgpu binds these GPUs automatically.
{ config, lib, ... }:
lib.mkIf (config.freutigo.hardware.gpuProfile == "amd-modern") {
  hardware.amdgpu.initrd.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
}
