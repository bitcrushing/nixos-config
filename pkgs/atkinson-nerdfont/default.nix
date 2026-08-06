{
  lib,
  stdenvNoCC,
  nerd-font-patcher,
  atkinson-hyperlegible-mono,
}:

stdenvNoCC.mkDerivation {
  pname = "atkinson-hyperlegible-mono-nerdfont";
  version = "2.001";

  src = atkinson-hyperlegible-mono;

  nativeBuildInputs = [ nerd-font-patcher ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    # Mono font (terminal): force monospace, add all icons.
    # Skip variable fonts ([wght]) — fontforge crashes on them.
    for font in ${atkinson-hyperlegible-mono}/share/fonts/truetype/*.ttf; do
      case "$font" in
        *"[wght]"*) continue ;;
      esac
      nerd-font-patcher --complete --mono --outputdir . "$font"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype
    mv ./*.ttf $out/share/fonts/truetype/

    runHook postInstall
  '';

  meta = {
    description = "Atkinson Hyperlegible Mono patched with Nerd Font icons";
    license = lib.licenses.ofl;
  };
}
