# Stronk 1 — Dell Chromebook 11 3180 (KEFKA) hardware profile
# CPU: Intel Celeron N3060 (Braswell), 4GB RAM
# WiFi: Intel 7265, Audio: Realtek ALC5650, WP: screw
{ config, pkgs, lib, ... }:

{
  # Kernel modules for Braswell SoC
  boot.initrd.availableKernelModules = [
    "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci"
    "i915"      # Intel HD Graphics 400
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

  # Hardware-specific firmware — Intel only (WiFi 7265 + i915 GPU)
  # Full linux-firmware (~500MB) replaced with targeted Intel files (~50MB)
  hardware.enableRedistributableFirmware = false;
  hardware.firmware = let
    stronk-firmware = pkgs.runCommand "stronk-firmware" { } ''
      mkdir -p $out/lib/firmware/i915
      cp ${pkgs.linux-firmware}/lib/firmware/iwlwifi-7265* $out/lib/firmware/
      cp ${pkgs.linux-firmware}/lib/firmware/i915/* $out/lib/firmware/i915/
    '';
  in [
    stronk-firmware
    pkgs.sof-firmware   # SOF topology for Braswell audio
  ];

  # Intel GPU
  hardware.graphics.enable = true;

  # Display — 11.6" 1366x768 TN, ~135 PPI
  # No scaling needed (1x). Font size adjustments via COSMIC settings.

  # Headphone jack detection via acpid
  services.acpid.enable = true;

  # Power management (TLP conflicts with power-profiles-daemon from COSMIC)
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
    };
  };
}
