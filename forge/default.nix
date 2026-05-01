{ lib
, rustPlatform
, pkg-config
, libxkbcommon
, wayland
, copyDesktopItems
, makeDesktopItem
}:

rustPlatform.buildRustPackage {
  pname = "the-forge";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  buildInputs = [
    libxkbcommon
    wayland
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
