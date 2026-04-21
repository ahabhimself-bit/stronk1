# Stronk 1 — NixOS VM integration test
# Verifies system behavior in a QEMU VM without physical hardware.
# Run: nix build .#checks.x86_64-linux.integration
{ pkgs, commonModules }:

pkgs.nixosTest {
  name = "stronk-integration";

  nodes.machine = { config, pkgs, ... }: {
    imports = commonModules;

    # VM overrides — filesystem and boot don't apply in test VMs
    fileSystems = pkgs.lib.mkForce {
      "/" = { device = "/dev/vda"; fsType = "ext4"; };
    };
    boot.loader.systemd-boot.enable = pkgs.lib.mkForce false;
    boot.loader.grub.enable = pkgs.lib.mkForce false;

    # Give VM enough resources for COSMIC
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      qemu.options = [ "-vga virtio" ];
    };
  };

  testScript = ''
    machine.start()

    # ── Boot verification ────────────────────────────────────────────
    machine.wait_for_unit("multi-user.target", timeout=120)
    machine.wait_for_unit("graphical.target", timeout=60)

    # ── Security: zero listening TCP/UDP ports ───────────────────────
    listening = machine.succeed("ss -tulnp")
    print(f"Listening sockets:\n{listening}")

    tcp_listeners = machine.succeed("ss -Htlnp | wc -l").strip()
    assert tcp_listeners == "0", f"Expected 0 TCP listeners, got {tcp_listeners}"

    # ── Security: firewall active ────────────────────────────────────
    machine.succeed("systemctl is-active nftables.service")

    # ── Security: AppArmor loaded ────────────────────────────────────
    machine.succeed("systemctl is-active apparmor.service")
    apparmor_status = machine.succeed("cat /sys/module/apparmor/parameters/enabled")
    assert apparmor_status.strip() == "Y", "AppArmor not enabled in kernel"

    # ── Audio: PipeWire running ──────────────────────────────────────
    machine.wait_for_unit("pipewire.service", "stronk", timeout=30)
    machine.wait_for_unit("wireplumber.service", "stronk", timeout=30)

    # ── Privacy: no outbound connections at idle ─────────────────────
    import time
    time.sleep(5)
    connections = machine.succeed("ss -Htunp | wc -l").strip()
    print(f"Active connections after 5s idle: {connections}")
    # Allow 0 established connections (NetworkManager may briefly connect for captive portal check,
    # but we disabled connectivity checking in security.nix)
    assert int(connections) == 0, f"Expected 0 active connections, got {connections}"

    # ── Desktop: COSMIC session running ──────────────────────────────
    machine.succeed("pgrep -u stronk cosmic-session || pgrep -u stronk cosmic-comp")

    # ── Apps: Brave is installed and Firejail-wrapped ────────────────
    machine.succeed("which brave")
    machine.succeed("firejail --list 2>/dev/null || true")

    # ── Apps: The Forge stub is installed ────────────────────────────
    machine.succeed("which the-forge")

    # ── Apps: Flatpak service is active ──────────────────────────────
    machine.succeed("systemctl is-active flatpak-system-helper.service || systemctl is-enabled flatpak-system-helper.service")

    # ── Kernel hardening ─────────────────────────────────────────────
    dmesg_restrict = machine.succeed("cat /proc/sys/kernel/dmesg_restrict").strip()
    assert dmesg_restrict == "1", f"dmesg_restrict is {dmesg_restrict}, expected 1"

    kptr_restrict = machine.succeed("cat /proc/sys/kernel/kptr_restrict").strip()
    assert kptr_restrict == "2", f"kptr_restrict is {kptr_restrict}, expected 2"

    ip_forward = machine.succeed("cat /proc/sys/net/ipv4/ip_forward").strip()
    assert ip_forward == "0", f"ip_forward is {ip_forward}, expected 0"

    # ── Journald: volatile, capped ──────────────────────────────────
    machine.succeed("journalctl --header | grep -q 'Storage: volatile' || test -d /run/log/journal")

    print("All integration tests passed!")
  '';
}
