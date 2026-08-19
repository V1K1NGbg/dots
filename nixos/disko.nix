{
  disko.devices.disk.system = {
    # The Framework Laptop 16 has one internal NVMe drive at this path. The
    # destructive installer refuses to proceed if its argument differs.
    device = "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
            extraArgs = [
              "-n"
              "NIXBOOT"
            ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/dots-luks-password";
            extraFormatArgs = [ "--type=luks2" ];
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              extraArgs = [
                "-L"
                "nixos"
              ];
            };
          };
        };
      };
    };
  };
}
