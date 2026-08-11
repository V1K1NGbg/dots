{ pkgs, repoRoot, rofiPackage }:
let
  script = path: builtins.readFile (repoRoot + "/packages/scripts/${path}");
in
{
  nixfwbtw-hypr-keybinds = pkgs.writeShellApplication {
    name = "nixfwbtw-hypr-keybinds";
    runtimeInputs = [ rofiPackage ];
    text = script "hypr/keybinds";
  };

  nixfwbtw-hypr-screenshot = pkgs.writeShellApplication {
    name = "nixfwbtw-hypr-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim satty slurp ];
    text = script "hypr/screenshot";
  };

  nixfwbtw-rofi-autocorrect = pkgs.writeShellApplication {
    name = "nixfwbtw-rofi-autocorrect";
    bashOptions = [ ];
    runtimeInputs = with pkgs; [
      (aspellWithDicts (dictionaries: [ dictionaries.en ]))
      coreutils
      gnugrep
      gnused
      wl-clipboard
    ];
    text = script "rofi/autocorrect";
  };

  nixfwbtw-rofi-bluetooth = pkgs.writeShellApplication {
    name = "nixfwbtw-rofi-bluetooth";
    bashOptions = [ ];
    runtimeInputs = with pkgs; [ bluez coreutils gawk gnugrep gnused ];
    text = script "rofi/bluetooth";
  };

  nixfwbtw-rofi-media = pkgs.writeShellApplication {
    name = "nixfwbtw-rofi-media";
    bashOptions = [ ];
    runtimeInputs = with pkgs; [ coreutils gawk playerctl wireplumber ];
    text = script "rofi/media";
  };

  nixfwbtw-rofi-power = pkgs.writeShellApplication {
    name = "nixfwbtw-rofi-power";
    bashOptions = [ ];
    runtimeInputs = with pkgs; [ coreutils hyprlock procps systemd ];
    text = script "rofi/power";
  };

  nixfwbtw-rofi-wifi = pkgs.writeShellApplication {
    name = "nixfwbtw-rofi-wifi";
    bashOptions = [ ];
    runtimeInputs = with pkgs; [ coreutils gawk gnugrep gnused iputils networkmanager ];
    text = script "rofi/wifi";
  };
}
