{
  config,
  lib,
  pkgs,
  ...
}:

let
  sessionRoot = "${config.services.displayManager.sessionData.desktops}/share";
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.hyprland.version "0.55.0";
      message = "The checked-in Lua configuration requires Hyprland 0.55 or newer.";
    }
  ];

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--asterisks"
        "--remember"
        "--remember-session"
        "--sessions"
        "${sessionRoot}/wayland-sessions"
      ];
      user = "greeter";
    };
  };

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
    tuigreet
    waybar
    wev
    wl-clipboard
    wlrctl
  ];
}
