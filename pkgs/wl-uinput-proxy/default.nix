{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "wl-uinput-proxy";
  version = "0.0.4";

  src = fetchFromGitHub {
    owner = "pgaskin";
    repo = "wl-uinput-proxy";
    rev = "v${version}";
    hash = "sha256-coJrAYecrRE25Ao+/NFTwuE6yRLlYCbloJ5WJJq/GJk=";
  };

  cargoHash = "sha256-Gtxz99gotvz9LI0mt3L7VUF4W/l6LPs6bvtta4Fs8CY=";

  meta = {
    description = "Wayland proxy implementing virtual keyboard/pointer via uinput";
    homepage = "https://github.com/pgaskin/wl-uinput-proxy";
    license = lib.licenses.mit;
    mainProgram = "wl-uinput-proxy";
    platforms = lib.platforms.linux;
  };
}
