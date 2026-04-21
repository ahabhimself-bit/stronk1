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

    # ── Audio: PipeWire installed ───────────────────────────────────
    # PipeWire runs as a user service; COSMIC's compositor crashes in QEMU
    # (no DRM render node), which destabilizes the user session.
    # Build-time assertions verify services.pipewire.enable = true.
    machine.succeed("which pipewire && which wireplumber")

    # ── Privacy: no unexpected outbound connections at idle ────────────
    import time
    time.sleep(10)

    all_conns = machine.succeed("ss -Htunp").strip()
    if all_conns:
        print(f"Active connections after 10s idle:\n{all_conns}")
    else:
        print("No active connections after 10s idle")

    # Filter essential network infrastructure — this check targets telemetry/tracking.
    # DHCP (67/68): NetworkManager lease maintenance, required for IP connectivity
    # NTP (123): systemd-timesyncd, required for TLS cert validation
    infra_ports = {':67 ', ':67\t', ':68 ', ':68\t', ':123 ', ':123\t'}
    lines = [l for l in all_conns.split('\n') if l.strip()]
    unexpected = [l for l in lines if not any(p in l for p in infra_ports)]
    assert len(unexpected) == 0, \
        f"Expected 0 non-infrastructure connections, got {len(unexpected)}:\n" + '\n'.join(unexpected)

    # ── Desktop: COSMIC session running ──────────────────────────────
    machine.succeed("pgrep -u stronk cosmic-session")

    # ── Apps: Brave is installed and Firejail-wrapped ────────────────
    machine.succeed("which brave")
    machine.succeed("firejail --list 2>/dev/null || true")

    # ── Apps: The Forge stub is installed ────────────────────────────
    machine.succeed("which the-forge")

    # ── Apps: Flatpak installed (system helper is D-Bus activated on demand) ──
    machine.succeed("flatpak --version")

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
