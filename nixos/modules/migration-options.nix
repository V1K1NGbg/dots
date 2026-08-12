{ lib, ... }:

{
  options.dots = {
    hardware.amdgpuDisplayFix = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the amdgpu DC workaround carried over from the working Arch system.";
    };

    llamaCpp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install llama.cpp with Vulkan acceleration.";
      };
    };
  };
}
