# QEMU test of the graphical desktop (virtual-machine host): SDDM greeter
# starts, the user can log in, and a Plasma Wayland session comes up.
# This proves the desktop *software* works in a VM; it is not evidence of
# real-GPU compatibility (section XIII, F3).
{
  pkgs,
  self,
  freutigoLib,
}:
pkgs.testers.runNixOSTest {
  name = "freutigo-desktop-boot";

  node.specialArgs = { inherit self freutigoLib; };
  node.pkgsReadOnly = false;

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        self.nixosModules.default
        ../hosts/virtual-machine
      ];
      nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
      users.users.root.hashedPassword = lib.mkForce null;
      virtualisation.memorySize = 3072;
      virtualisation.cores = 2;
      # Note: the host's interactive display flags live in
      # virtualisation.vmVariant and do not apply inside tests. Never force
      # virtualisation.qemu.options here: the qemu-vm module uses it for the
      # direct kernel boot (-kernel/-initrd/-append).
    };

  enableOCR = false;

  testScript = ''
    machine.wait_for_unit("display-manager.service")

    with subtest("SDDM greeter is running"):
        machine.wait_until_succeeds("pgrep -f sddm-greeter", timeout=180)
        machine.sleep(15)  # let the greeter render and focus the password field
        machine.screenshot("01-sddm-greeter")

    with subtest("Freutigo desktop defaults installed"):
        machine.succeed("grep -qx aero /etc/freutigo/desktop-mode")
        machine.succeed("grep -q 'blurEnabled=true' /etc/xdg/kwinrc")
        machine.succeed("grep -q 'Indexing-Enabled=false' /etc/xdg/baloofilerc")

    with subtest("Log in through SDDM"):
        machine.send_chars("freutigo\n")
        machine.wait_until_succeeds("pgrep -u freutigo -f plasmashell", timeout=300)
        machine.sleep(20)
        machine.screenshot("02-plasma-session")

    with subtest("Session is Wayland with PipeWire running"):
        # NixOS wraps KWin, so match the command line, not the process name.
        machine.wait_until_succeeds("pgrep -u freutigo -f kwin_wayland", timeout=60)
        machine.succeed(
            "tr '\\0' '\\n' < /proc/$(pgrep -u freutigo -f plasmashell | head -1)/environ"
            " | grep -qx XDG_SESSION_TYPE=wayland"
        )
        machine.wait_until_succeeds("pgrep -u freutigo -f 'bin/pipewire( |$)'", timeout=60)

    with subtest("Idle memory snapshot (VM, informational only)"):
        print(machine.succeed("free -m"))
  '';
}
