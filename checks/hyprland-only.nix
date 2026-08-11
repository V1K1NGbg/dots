{ lib, runCommand, systemConfig }:
let
  names = map lib.getName systemConfig.environment.systemPackages;
  absent = forbidden: lib.all (name: !(builtins.elem name names)) forbidden;
  homeFiles = systemConfig.home-manager.users.victor.xdg.configFile;
in
assert systemConfig.programs.hyprland.enable;
assert !systemConfig.programs.hyprland.xwayland.enable;
assert !systemConfig.services.xserver.enable;
assert absent [ "awesome" "picom-pijulius" "xwayland" ];
assert builtins.hasAttr "hypr/hyprland.lua" homeFiles;
assert !(builtins.hasAttr "hypr/hyprland.conf" homeFiles);
assert !(builtins.hasAttr "awesome" homeFiles);
runCommand "nixfwbtw-hyprland-only" { } ''
  touch "$out"
''
