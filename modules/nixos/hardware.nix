{ lib, pkgs, ... }:
{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.kernelModules = [ "amdgpu" ];
    # mkAfter makes the retained installer value win over the hardware module's
    # current dcdebugmask default while keeping its other mitigation flags.
    kernelParams = lib.mkAfter [ "amdgpu.dcdebugmask=0x10" "quiet" "splash" ];
    plymouth = {
      enable = true;
      theme = "hexagon_hud";
      themePackages = [ pkgs.hexagon-hud-plymouth ];
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [ pkgs.linux-firmware ];
    graphics = {
      enable = true;
    };
  };

  services.fwupd.enable = true;
}
