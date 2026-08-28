{
  bootDevice,
  lib,
  luksDevice,
}:

let
  subvolumes = {
    "/" = "@";
    "/home" = "@home";
    "/nix" = "@nix";
    "/var/log" = "@log";
  };
in
{
  boot.initrd.luks.devices.cryptroot = {
    device = luksDevice;
    allowDiscards = false;
  };

  fileSystems =
    lib.mapAttrs (_: subvolume: {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
      options = [
        "subvol=${subvolume}"
        "compress=zstd"
        "noatime"
      ];
    }) subvolumes
    // {
      "/boot" = {
        device = bootDevice;
        fsType = "vfat";
        options = [
          "fmask=0022"
          "dmask=0022"
        ];
      };
    };
}
