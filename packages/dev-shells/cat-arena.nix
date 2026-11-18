# Reproducible development shell for a native Linux port of
# Cat Arena: Feral Claw (C++20, Vulkan 1.1 baseline, SDL3) — section 9.4, Path B.
#
# Usage:  nix develop /path/to/freutigo-aero-os#cat-arena
#
# This shell does not contain or modify the game; it only provides tools.
{ pkgs }:
pkgs.mkShell {
  name = "cat-arena-dev";

  packages = with pkgs; [
    # Build system
    cmake
    ninja
    pkg-config
    gnumake

    # Compilers (GCC is the stdenv default; clang tools for clangd/format/tidy)
    clang-tools
    gdb
    lldb
    valgrind

    # Windowing / input / audio
    sdl3

    # Vulkan
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
    vulkan-tools-lunarg # vkconfig
    spirv-tools
    spirv-headers

    # Shader compilers
    shaderc # glslc
    glslang

    # Graphics debugging
    renderdoc
  ];

  # Validation layers discoverable by the loader inside the shell.
  VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

  # Let CMake's find_package(Vulkan)/find_package(SDL3) and the runtime find
  # the loader without system-wide installation.
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.vulkan-loader
    pkgs.sdl3
  ];

  shellHook = ''
    echo "Cat Arena dev shell: $(cmake --version | head -1), $(c++ --version | head -1)"
    echo "Vulkan validation layers: $VK_LAYER_PATH"
  '';
}
