# Stronk 1 — HP Chromebook 11 G6 EE (SNAPPY) hardware profile
# CPU: Intel Celeron N3350 (Apollo Lake), 4GB RAM
# WiFi: Intel 7265, Audio: SOF (Sound Open Firmware), WP: battery disconnect
{ config, pkgs, lib, ... }:

{
  # Apollo Lake SoC
  boot.initrd.availableKernelModules = [
    "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci"
    "i915"      # Intel HD Graphics 500
  ];

  boot.kernelModules = [
    "kvm-intel"
    "iwlwifi"                # Intel 7265 WiFi
    "btusb"                  # Bluetooth
    "elan_i2c"               # Elan I2C touchpad (ELAN0000)
    "i2c_designware_platform" # I2C bus for Apollo Lake SoC
    # Audio: AVS driver for Apollo Lake + DA7219/MAX98357A
    # AVS (dsp_driver=4) supports headphones; SOF only gives speakers.
    # NOTE: AVS can be unstable on some Apollo Lake boards — test audio on first boot.
    "snd_sof" "snd_sof_pci_intel_apl"
  ];

  # Audio: use AVS driver for Apollo Lake (headphone support)
  # SOF (dsp_driver=3) only gives speakers, no headphone jack.
  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=4
  '';

  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware   # SOF topology files for Apollo Lake
  ];

  hardware.graphics.enable = true;

  # Display — 11.6" 1366x768 TN, ~135 PPI
  # No scaling needed (1x).

  # Power management
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
    };
  };
}
