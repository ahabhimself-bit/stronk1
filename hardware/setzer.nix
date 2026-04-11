# Stronk 1 — HP Chromebook 11 G5 EE (SETZER) hardware profile
# CPU: Intel Celeron N3060 (Braswell), 2GB RAM (minimum tier)
# WiFi: Intel 7265, Audio: Realtek ALC5650, WP: screw
{ config, pkgs, lib, ... }:

{
  # Same Braswell SoC as KEFKA
  boot.initrd.availableKernelModules = [
    "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci"
    "i915"
  ];

  boot.kernelModules = [
    "kvm-intel"
    "iwlwifi"                # Intel 7265 WiFi
    "btusb"                  # Bluetooth
    "elan_i2c"               # Elan I2C touchpad (ELAN0000)
    "i2c_designware_platform" # I2C bus for Braswell SoC
    "pinctrl_cherryview"     # CherryView GPIO/IRQ for touchpad
    # Audio: SOF driver for Braswell + RT5650
    "snd_sof" "snd_sof_acpi"
  ];

  # Audio: force SOF driver for Braswell DSP
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=3
    options snd-sof sof_debug=1
  '';

  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware   # SOF topology for Braswell audio
  ];

  hardware.graphics.enable = true;

  # Display — 11.6" 1366x768 TN, ~135 PPI
  # No scaling needed (1x).

  # Headphone jack detection via acpid
  services.acpid.enable = true;

  # Aggressive power savings for 2GB tier (TLP conflicts with power-profiles-daemon from COSMIC)
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave"; # Even on AC, conserve on 2GB
    };
  };

  # 2GB-specific: tighter memory management
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 150;
  };
}
