{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dots.desktop.hyprland;
  sessionRoot = "${config.services.displayManager.sessionData.desktops}/share";
in
{
  options.dots.desktop.hyprland.enable = lib.mkEnableOption ''
    the experimental Hyprland session alongside the stable Awesome/X11 session
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionAtLeast pkgs.hyprland.version "0.55.0";
        message = "The checked-in Lua configuration requires Hyprland 0.55 or newer.";
      }
    ];

    # The normal `dots` profile keeps tty1 autologin + startx. Only the opt-in
    # Hyprland variant replaces that with a chooser containing both sessions.
    services.getty.autologinUser = lib.mkForce null;
    services.xserver.displayManager.startx.enable = lib.mkForce false;
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
          "--xsessions"
          "${sessionRoot}/xsessions"
        ];
        user = "greeter";
      };
    };

    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      withUWSM = true;
      # This is intentional. Discord, Spotify, pCloud, GLava and several
      # utility windows still need X11 compatibility during the trial.
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
  };
}
