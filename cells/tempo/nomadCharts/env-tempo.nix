{
  tempoConfigFile,
}:

{
  env = {
    PATH = "/bin";

    # Specified in flake; defaults to "info"
    # Valid values are strings of:
    # "debug" "info" "warn" "error"
    LOG_LEVEL = "";

    # The Nomad template writes the configuration
    # file to this default path
    CONFIG_FILE = "/local/config.yaml";
  };
  template = [
    {
      change_mode = "restart";

      data = builtins.readFile tempoConfigFile;
      destination = "local/config.yaml";
      env = false;
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
  ];
}
