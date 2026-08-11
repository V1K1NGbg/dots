{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    user = "ollama";
    group = "ollama";
    home = "/var/lib/ollama";
    modelsDir = "/var/lib/ollama/models";
    host = "127.0.0.1";
    port = 11434;
    openFirewall = false;
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "0";
      OLLAMA_MAX_QUEUE = "2";
      OLLAMA_VULKAN = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      GPU_DEVICE_ORDINAL = "0";
      GGML_VK_VISIBLE_DEVICES = "0";
      HIP_VISIBLE_DEVICES = "0";
      ROC_ENABLE_PRE_VEGA = "1";
      OMP_NUM_THREADS = "12";
      GOMP_CPU_AFFINITY = "0-11";
      GGML_USE_MLOCK = "0";
    };
  };

  systemd.services.ollama.serviceConfig = {
    CPUQuota = "2400%";
    MemoryMax = "48G";
    LimitMEMLOCK = "infinity";
    LimitSTACK = 67108864;
  };
}
