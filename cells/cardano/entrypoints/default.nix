{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.build.system};
  library = inputs.self.library.${system.build.system};
  writeShellApplication = library._writers-writeShellApplication;
  fileContents = nixpkgs.lib.strings.fileContents;
  inherit
    (nixpkgs.extend inputs.cardano-iohk-nix.overlays.cardano-lib)
    cardanoLib
    ;
in
(
  let
    entrypoints = envName: let
      inherit (library.cardano-evalNodeConfig envName) socketPath;
      envFlag = library.cardano-envFlag envName;
      nodeStateDir = (library.cardano-evalNodeConfig envName).stateDir;
      dbSyncStateDir = "/var/lib/cardano-db-sync";
      walletStateDir = "/var/lib/cardano-wallet";
      walletEnvFlag =
        if envName == "testnet"
        then
          "--testnet ${
            library.cardano-lib.testnet.networkConfig.ByronGenesisFile
          }"
        else if envName == "mainnet"
        then "--mainnet"
        else abort "unreachable";
    in
      {
        "node-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-node-${envName}-entrypoint";
          text =
            (fileContents ./node-entrypoint.sh)
            + "\n"
            + (library.cardano-evalNodeConfig envName).script;
          env = {
            stateDir = nodeStateDir;
            inherit envName;
          };
          runtimeInputs = [
            packages.cardano-node
            packages.cardano-cli
            # TODO: take from somewhere else than aws, e.g. an iohk hydra published path or similar
            nixpkgs.awscli2
          ];
        };
        "submit-api-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-submit-api-${envName}-entrypoint";
          env = {
            inherit socketPath envFlag;
            configFile = builtins.toFile "submit-api-config.json" (builtins.toJSON cardanoLib.defaultExplorerLogConfig);
          };
          text = (fileContents ./submit-api-entrypoint.sh);
          runtimeInputs = [ packages.cardano-submit-api packages.cardano-cli ];
        };
        "db-sync-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-db-sync-${envName}-entrypoint";
          env = {
            schemaDir = inputs.cardano-db-sync + "/schema";
            stateDir = dbSyncStateDir;
            configFile = builtins.toFile "db-sync-config.json" (
              builtins.toJSON (
                cardanoLib.environments.${envName}.explorerConfig
                // cardanoLib.defaultExplorerLogConfig
              )
            );
          };
          text = (fileContents ./db-sync-entrypoint.sh);
          runtimeInputs = [ packages.cardano-db-sync packages.cardano-cli ];
        };
        "wallet-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-wallet-${envName}-entrypoint";
          env = {
            inherit socketPath envFlag;
            stateDir = walletStateDir;
          };
          text = (fileContents ./wallet-entrypoint.sh);
          runtimeInputs = [ packages.cardano-wallet packages.cardano-cli ];
        };
      };
  in
    (entrypoints "testnet")
    // (entrypoints "mainnet")
    // {
      wallet-init-entrypoint = writeShellApplication {
        name = "cardano-wallet-init-entrypoint";
        text = (fileContents ./wallet-init-entrypoint.sh);
        runtimeInputs = [ nixpkgs.gnused nixpkgs.curl ];
      };
      socat-publisher-entrypoint = writeShellApplication {
        name = "cardano-socat-publisher-entrypoint";
        env = {
          inherit (library.cardano-evalNodeConfig "dummy") socketPath;
          port = 3000;
        };
        text = (fileContents ./socat-publisher-entrypoint.sh);
        runtimeInputs = [ nixpkgs.socat ];
      };
      socat-subscriber-entrypoint = writeShellApplication {
        name = "cardano-socat-subscriber-entrypoint";
        env = {
          inherit (library.cardano-evalNodeConfig "dummy") socketPath;
          port = 3000;
        };
        text = (fileContents ./socat-subscriber-entrypoint.sh);
        runtimeInputs = [ nixpkgs.socat ];
      };
    }
)
