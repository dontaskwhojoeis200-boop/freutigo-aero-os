# Vulkan / OpenGL diagnostics available on every graphical system
# (sections 5.5, 9.3). The Vulkan loader itself comes from hardware.graphics.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
lib.mkIf (config.freutigo.hardware.gpuProfile != "none") {
  environment.systemPackages = [
    pkgs.vulkan-tools # vulkaninfo, vkcube
    pkgs.mesa-demos # glxinfo, eglinfo
    self.packages.${pkgs.stdenv.hostPlatform.system}.freutigo-gpu-diagnostics
  ];
}
