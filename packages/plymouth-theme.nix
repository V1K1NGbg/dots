{ lib, stdenvNoCC, src }:
stdenvNoCC.mkDerivation {
  pname = "hexagon-hud-plymouth";
  version = "5d881745";
  inherit src;

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    theme="$src/pack_2/hexagon_hud"
    test -f "$theme/hexagon_hud.plymouth"
    mkdir -p "$out/share/plymouth/themes/hexagon_hud"
    cp -R "$theme/." "$out/share/plymouth/themes/hexagon_hud/"
    substituteInPlace "$out/share/plymouth/themes/hexagon_hud/hexagon_hud.plymouth" \
      --replace-fail "/usr/share/plymouth/themes/hexagon_hud" "$out/share/plymouth/themes/hexagon_hud"
    runHook postInstall
  '';

  meta = {
    description = "Hexagon HUD Plymouth boot theme";
    homepage = "https://github.com/adi1090x/plymouth-themes";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
