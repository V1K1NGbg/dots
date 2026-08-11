{ pkgs, inputs }:
let
  monocraft = pkgs.callPackage ./monocraft.nix {
    src = inputs.monocraft-src;
  };
  plymouthTheme = pkgs.callPackage ./plymouth-theme.nix {
    src = inputs.plymouth-themes-src;
  };
  rofiUnwrappedWaylandOnly = pkgs.rofi-unwrapped.override {
    waylandSupport = true;
    x11Support = false;
  };
  rofiCalcWaylandOnly = pkgs.rofi-calc.override {
    rofi-unwrapped = rofiUnwrappedWaylandOnly;
  };
  rofiWaylandOnly = pkgs.rofi.override {
    rofi-unwrapped = rofiUnwrappedWaylandOnly;
    plugins = [ rofiCalcWaylandOnly ];
  };
  scripts = import ./scripts.nix {
    inherit pkgs;
    rofiPackage = rofiWaylandOnly;
    repoRoot = ../.;
  };
in
{
  monocraft-nerd-font = monocraft;
  hexagon-hud-plymouth = plymouthTheme;
  rofi-wayland-only = rofiWaylandOnly;
}
// scripts
