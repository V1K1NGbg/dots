{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "vimix-monocraft-cursors";
  version = "0.1";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons/Vimix-Monocraft"
    cp -R ${../config/cursor-theme/Vimix-Monocraft}/. \
      "$out/share/icons/Vimix-Monocraft/"
    runHook postInstall
  '';

  meta = {
    description = "Precompiled Vimix cursor theme in the Monocraft palette";
    homepage = "https://github.com/ATM-Jahid/accurse";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = pkgs.lib.platforms.linux;
  };
}
