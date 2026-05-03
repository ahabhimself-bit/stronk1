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
      "accesskit-0.22.0" = "sha256-pP9CyiV1zIONQ7vbl5MkMtilemSPrHaZ0c/SyR+lb0k=";
      "atomicwrites-0.4.2" = "sha256-QZSuGPrJXh+svMeFWqAXoqZQxLq/WfIiamqvjJNVhxA=";
      "clipboard_macos-0.1.0" = "sha256-WO3JFbE+6ESRAfkxrnEFeZyGuhUHLOKOVHcGQyHwoK0=";
      "cosmic-config-1.0.0" = "sha256-dp6IPF6MBPkR0Ig9GjuklKe/UoSaZKi7G8AKyxcLtFk=";
      "cosmic-freedesktop-icons-0.4.0" = "sha256-n+6nDpRdLeWYVFrtDqFYI83K7s96UEE6bqCF+UYyv7I=";
      "cosmic-settings-daemon-0.1.0" = "sha256-YRCNF2NQia6a9QlUIoEw0v2bMiZq94eViLsx+8NoghI=";
      "cosmic-text-0.18.2" = "sha256-PUmICUP9yh5Cpy6AlvjMrosrNo9Jg/OZfyAjOiou6YA=";
      "cryoglyph-0.1.0" = "sha256-sSfgXlWgrM4wdczdquqzc/uuUmHL/GuK+Xvn0XNO+UQ=";
      "dpi-0.1.2" = "sha256-pvGeHgfGetFutV2Pr39Jse+REFOmCkI1djzHqMQcWmE=";
      "smithay-clipboard-0.8.0" = "sha256-GojAFRbhJcP0Rpr+v9WOivgW9x38PZdeBWTbMhkDB3A=";
      "softbuffer-0.4.1" = "sha256-9Ret/nfieBFl4yJ9TddyWsSuS7sI4QAza/TZrxYMb+I=";
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
