# QEMU boot test of the Freutigo core system (no desktop).
# Verifies the F1 acceptance basics: boots, essential services up, branding,
# security invariants. Run: nix build .#checks.x86_64-linux.vmtest-core -L
{
  pkgs,
  self,
  freutigoLib,
}:
pkgs.testers.runNixOSTest {
  name = "freutigo-core-boot";

  node.specialArgs = { inherit self freutigoLib; };
  # Our modules set nixpkgs.config (unfree allowlist).
  node.pkgsReadOnly = false;

  nodes.machine =
    { lib, ... }:
    {
      imports = [ self.nixosModules.default ];
      nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
      freutigo.boot.mode = "none";
      freutigo.hardware.gpuProfile = "virtual-machine";
      freutigo.user.initialPassword = "test";
      virtualisation.memorySize = 2048;
      # The test harness gives root an empty password for interactive
      # debugging; let it win inside the test VM only. The locked root of
      # installed systems is checked at evaluation level (docs/BUILD.md).
      users.users.root.hashedPassword = lib.mkForce null;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("branding"):
        machine.succeed("grep -q 'NAME=\"Freutigo Aero OS\"' /etc/os-release")
        machine.succeed("test -s /etc/freutigo/version")
        machine.succeed("grep -qx virtual-machine /etc/freutigo/gpu-profile")

    with subtest("essential services"):
        machine.wait_for_unit("NetworkManager.service")
        machine.wait_for_unit("systemd-resolved.service")
        # timesyncd: NixOS' qemu-vm module disables it inside test VMs (the
        # guest gets time from KVM). It is checked on a real install by
        # scripts/e2e-install-test.sh and at evaluation level for all hosts.
        machine.succeed("systemctl is-enabled bluetooth.service")

    with subtest("audio stack installed for user sessions"):
        machine.succeed("test -e /run/current-system/sw/share/pipewire")
        machine.succeed("systemctl --global is-enabled pipewire.socket")

    with subtest("security invariants"):
        machine.succeed("iptables -S nixos-fw >/dev/null 2>&1 || nft list ruleset | grep -q nixos-fw")
        machine.fail("su freutigo -c 'sudo -n true'")

    with subtest("filesystem support"):
        machine.succeed("command -v mkfs.exfat mkfs.ntfs mkfs.vfat")

    with subtest("diagnostics tool runs"):
        # exit 0/1/2 are all valid outcomes in a headless VM; 127 is not.
        machine.succeed("freutigo-gpu-diagnostics || test $? -le 2")
  '';
}
