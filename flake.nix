{
  description = "Bitte Cells";
  inputs.std.url = "github:divnix/std";
  # Cardano Stack Inputs
  inputs = {
    cardano-iohk-nix.url = "github:input-output-hk/iohk-nix";
    cardano-node.url = "github:input-output-hk/cardano-node/flake-improvements";
    cardano-db-sync.url = "github:input-output-hk/cardano-db-sync/12.0.1-flake-improvements";
    cardano-wallet.url = "github:input-output-hk/cardano-wallet";
  };
  outputs = inputs: inputs.std.grow {
    inherit inputs;
    as-nix-cli-epiphyte = false;
    systems = [
      {
        build = "x86_64-unknown-linux-gnu";
        # GNU/Linux 64 bits
        host = "x86_64-unknown-linux-gnu";
        # GNU/Linux 64 bits
      }
    ];
    cellsFrom = ./cells;
    organelles = [
      (inputs.std.runnables "healthChecks")
      (inputs.std.runnables "entrypoints")
      # just repo automation; std - just integration pending
      (inputs.std.runnables "justTasks")
      (inputs.std.installables "packages")
      (inputs.std.functions "library")
      (inputs.std.functions "nomadJob")
      (inputs.std.functions "devshellProfiles")
      (inputs.std.functions "nixosProfiles")
      (inputs.std.functions "hydrationProfiles")
    ];
  };
}
