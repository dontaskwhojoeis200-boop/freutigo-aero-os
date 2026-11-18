# Installer

F0/F1: the ISO (`hosts/installation-iso`) uses the proven NixOS minimal
installer with Freutigo branding and the documented flake workflow in
docs/INSTALL.md.

F6: branded guided installer (language/keyboard, user creation, networking,
explicit-confirmation partitioning, dual-boot-safe mode, automatic GPU profile
detection from PCI IDs with manual override). Calamares with Freutigo
branding is the first candidate; it must install from this flake, not a
generic NixOS configuration.
