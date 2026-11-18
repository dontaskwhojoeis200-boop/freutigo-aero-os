# NVIDIA Kepler open-source profile (GeForce GTX 660, GK106).
# Kernel: nouveau. OpenGL: Mesa nouveau (nvc0). Vulkan: Mesa NVK.
#
# Known limitations (must be validated on real hardware, see docs/HARDWARE.md):
#  - nouveau starts Kepler GPUs at boot clocks; without reclocking, 3D
#    performance is far below the proprietary driver. Reclocking is an F3
#    investigation item and is deliberately NOT configured here.
#  - NVK support for pre-Turing GPUs is newer and less mature than for
#    Turing+; available Vulkan extensions must be checked with vulkaninfo.
{ config, lib, ... }:
lib.mkIf (config.freutigo.hardware.gpuProfile == "nvidia-kepler-oss") {
  # Load nouveau early for a native-resolution console and to make sure the
  # open driver, not a leftover proprietary module, owns the GPU.
  boot.initrd.kernelModules = [ "nouveau" ];
  services.xserver.videoDrivers = [ "modesetting" ];

  assertions = [
    {
      assertion = !(builtins.elem "nvidia" config.services.xserver.videoDrivers);
      message = "nvidia-kepler-oss profile must not be combined with the proprietary NVIDIA driver.";
    }
  ];
}
