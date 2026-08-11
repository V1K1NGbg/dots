{ lib, stdenvNoCC, src }:
stdenvNoCC.mkDerivation {
  pname = "monocraft-nerd-font";
  version = "4.0-0d88c49";
  inherit src;

  dontBuild = true;
  unpackPhase = "true";
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/fonts/truetype"
    install -m 0444 "$src" "$out/share/fonts/truetype/Monocraft-nerd-fonts-patched.ttc"
    runHook postInstall
  '';

  meta = {
    description = "Monocraft programming font, including the Nerd Font build";
    homepage = "https://github.com/IdreesInc/Monocraft";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
