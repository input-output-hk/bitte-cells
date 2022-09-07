{
  inputs,
  namespace,
  packages,
  extraTempo ? {},
}:

let
  inherit (evaluated.config.services.tempo) computedTempoConfig computedFirewallConfig;

  # nixpkgs master 2022-09-08 for nixosSystem convenience function
  pkgsSystem = builtins.getFlake "github:NixOS/nixpkgs?rev=a013583ca0713ed50be62ca6cb3906c6f03021e7";

  evaluated = pkgsSystem.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ../modules/tempo.nix
      extraTempo
    ];
  };

  tempoConfigFile = (inputs.nixpkgs.formats.yaml {}).generate "config.yaml" computedTempoConfig;

in {
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
