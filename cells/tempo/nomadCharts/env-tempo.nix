{
  tempoConfigFile,
}:

{
  env = {
    PATH = "/bin";

    # Log level defaults to "info" if empty.
    # Overridable with valid values of:
    # "debug" "info" "warn" "error"
    LOG_LEVEL = "info";

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
