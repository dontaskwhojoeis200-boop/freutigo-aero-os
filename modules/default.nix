# Freutigo Aero OS module set. Every host imports this; behaviour is selected
# through the `freutigo.*` options declared by the individual modules.
{
  imports = [
    ./core/base.nix
    ./core/boot.nix
    ./core/kernel.nix
    ./core/services.nix
    ./core/networking.nix
    ./core/audio.nix
    ./core/security.nix
    ./core/storage.nix
    ./core/users.nix
    ./core/testing.nix

    ./hardware
    ./desktop
    ./gaming

    ./optimization/services.nix
    ./optimization/memory.nix
    ./optimization/storage.nix
  ];
}
