{
  # These are deliberate, easy-to-find machine policy choices. Hardware
  # filesystems and storage drivers still live in hardware-configuration.nix.
  dots = {
    hardware.amdgpuDisplayFix = true;

    ollama = {
      enable = true;
      # "docker" preserves the working setup and its named volume. After model
      # migration, "native" uses the fully pinned NixOS Ollama service.
      backend = "docker";
      # Keep the API off the LAN unless remote access is intentional.
      listenAddress = "127.0.0.1";
    };
  };
}
