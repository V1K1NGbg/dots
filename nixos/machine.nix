{
  # These are deliberate, easy-to-find machine policy choices. Hardware
  # filesystems and storage drivers still live in hardware-configuration.nix.
  dots = {
    hardware.amdgpuDisplayFix = true;

    llamaCpp = {
      enable = true;
    };
  };
}
