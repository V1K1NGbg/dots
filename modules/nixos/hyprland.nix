{ lib, pkgs, ... }:
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.hyprland.version "0.55.0";
      message = "The checked-in Lua configuration requires Hyprland 0.55 or newer.";
    }
  ];

  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    withUWSM = true;
    xwayland.enable = false;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    grim
    hypridle
    hyprlock
    hyprpaper
    hyprpolkitagent
    hyprsunset
    mako
    nixfwbtw-hypr-keybinds
    nixfwbtw-hypr-screenshot
    nixfwbtw-rofi-autocorrect
    nixfwbtw-rofi-bluetooth
    nixfwbtw-rofi-media
    nixfwbtw-rofi-power
    nixfwbtw-rofi-wifi
    qt6.qtwayland
    satty
    slurp
    wev
    wl-clipboard
    wlrctl
  ];
}
