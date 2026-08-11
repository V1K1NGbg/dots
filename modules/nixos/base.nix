{ config, pkgs, ... }:
{
  networking = {
    hostName = "nixfwbtw";
    networkmanager = {
      enable = true;
      dns = "none";
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };

  environment.etc."NetworkManager/conf.d/90-nixfwbtw-dns.conf".text = ''
    [global-dns-domain-*]
    servers=1.1.1.1,1.0.0.1
  '';

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  users = {
    mutableUsers = true;
    users.victor = {
      isNormalUser = true;
      description = "Victor";
      shell = pkgs.bashInteractive;
      extraGroups = [ "wheel" "networkmanager" "docker" ];
    };
  };

  services.getty.autologinUser = "victor";
  services.logind.settings.Login.HandlePowerKey = "ignore";
  services.power-profiles-daemon.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  services.fprintd.enable = true;
  security.pam.services = {
    sudo.fprintAuth = true;
    hyprlock = { };
  };

  security.sudo.wheelNeedsPassword = true;
  programs.dconf.enable = true;
  programs.nm-applet.enable = true;

  documentation.man.enable = true;
  system.stateVersion = "26.05";

  assertions = [
    {
      assertion = config.users.mutableUsers;
      message = "Victor's password must remain mutable and must not be committed as a hash.";
    }
    {
      assertion = builtins.elem "docker" config.users.users.victor.extraGroups;
      message = "The migration explicitly preserves Victor's privileged Docker group access.";
    }
  ];
}
