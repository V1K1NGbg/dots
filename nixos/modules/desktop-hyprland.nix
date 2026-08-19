{
  lib,
  pkgs,
  ...
}:

{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.hyprland.version "0.55.0";
      message = "The checked-in Lua configuration requires Hyprland 0.55 or newer.";
    }
  ];

  services.getty.autologinUser = "victor";

  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    withUWSM = true;
    # Discord, Spotify, pCloud, GLava and some utilities still need this.
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland.default = [
      "hyprland"
      "gtk"
    ];
  };

  security.pam.services.hyprlock.fprintAuth = true;

  environment.systemPackages = with pkgs; [
    grim
    hypridle
    hyprlock
    hyprpolkitagent
    hyprsunset
    mako
    qt6.qtwayland
    satty
    slurp
    swaybg
    waybar
    wev
    wl-clipboard
    wlrctl
  ];
}
