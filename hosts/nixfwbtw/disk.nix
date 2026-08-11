{ lib, ... }:
{
  # The installer overrides this placeholder with `--disk main DEVICE`.
  # Filesystems are addressed by GPT partition label afterwards, so normal
  # rebuilds never depend on a volatile /dev/nvme* name.
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-id/REPLACE-WITH-INSTALLER-ARGUMENT";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "1G";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/nixfwbtw-luks.key";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };

  # No on-disk swap partition is needed for suspend. Compressed RAM swap keeps
  # the destructive layout independent of the laptop's eventual RAM size.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };
}
