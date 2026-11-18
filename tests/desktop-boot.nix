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
      # The test harness provides its own display; drop the GL display flags
      # used for interactive runs.
      virtualisation.qemu.options = lib.mkForce [ ];
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
        machine.wait_until_succeeds("pgrep -u freutigo -x kwin_wayland", timeout=60)
        machine.wait_until_succeeds("pgrep -u freutigo -x pipewire", timeout=60)

    with subtest("Idle memory snapshot (VM, informational only)"):
        print(machine.succeed("free -m"))
  '';
}
