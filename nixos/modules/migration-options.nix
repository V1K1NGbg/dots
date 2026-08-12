{ lib, ... }:

{
  options.dots = {
    hardware.amdgpuDisplayFix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the amdgpu DC workaround carried over from the working Arch system.";
    };

    ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the local Ollama service.";
      };
      backend = lib.mkOption {
        type = lib.types.enum [
          "docker"
          "native"
        ];
        default = "docker";
        description = "Keep the compatible Docker setup or opt into the pinned native NixOS service.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address on which Ollama listens. Use 0.0.0.0 only when LAN access is intentional.";
      };
    };
  };
}
