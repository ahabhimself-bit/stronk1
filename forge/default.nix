{ lib
, rustPlatform
, pkg-config
, libxkbcommon
, wayland
, vulkan-loader
, libinput
, mesa
, fontconfig
, freetype
, expat
, udev
}:

rustPlatform.buildRustPackage {
  pname = "the-forge";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "accesskit-0.22.0" = lib.fakeHash;
      "atomicwrites-0.4.2" = lib.fakeHash;
      "clipboard_macos-0.1.0" = lib.fakeHash;
      "cosmic-config-1.0.0" = lib.fakeHash;
      "cosmic-freedesktop-icons-0.4.0" = lib.fakeHash;
      "cosmic-settings-daemon-0.1.0" = lib.fakeHash;
      "cosmic-text-0.18.2" = lib.fakeHash;
      "cryoglyph-0.1.0" = lib.fakeHash;
      "dpi-0.1.2" = lib.fakeHash;
      "smithay-clipboard-0.8.0" = lib.fakeHash;
      "softbuffer-0.4.1" = lib.fakeHash;
    };
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
    wayland
    vulkan-loader
    libinput
    mesa
    fontconfig
    freetype
    expat
    udev
  ];

  postInstall = ''
    install -Dm644 com.stronk.forge.desktop $out/share/applications/com.stronk.forge.desktop
  '';

  meta = with lib; {
    description = "The Forge — Stronk 1 app store";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "the-forge";
  };
}
