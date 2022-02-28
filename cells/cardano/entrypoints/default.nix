{ inputs
, cell
}:
let
  inherit (inputs) nixpkgs;
  inherit (cell) packages constants library nixosProfiles;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in
(
  let
    entrypoints = envName: let
      cfg = library.evalNodeConfig envName nixosProfiles.node;
      envFlag = library.envFlag envName;
      walletEnvFlag = library.walletEnvFlag envName;
      inherit (cfg) socketPath;
      nodeStateDir = (cfg).stateDir;
      dbSyncStateDir = constants.stateDirs.dbSync;
      walletStateDir = constants.stateDirs.wallet;
      inherit (constants.snapShots.dbSync) snapShotUrl snapShotSha;
    in
      {
        "node-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-node-${envName}-entrypoint";
          text = (fileContents ./node-entrypoint.sh) + "\n" + cfg.script;
          env = {
            stateDir = nodeStateDir;
            inherit envName socketPath;
          };
          runtimeInputs = [
            packages.node
            packages.cli
            # TODO: take from somewhere else than aws, e.g. an iohk hydra published path or similar
            nixpkgs.awscli2
            nixpkgs.coreutils
            nixpkgs.gnutar
            nixpkgs.gzip
          ];
        };
        "submit-api-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-submit-api-${envName}-entrypoint";
          env = {
            inherit socketPath envFlag;
            configFile = builtins.toFile "submit-api-config.json" (builtins.toJSON constants.lib.defaultExplorerLogConfig);
          };
          text = (fileContents ./submit-api-entrypoint.sh);
          runtimeInputs = [ packages.submit-api packages.cli ];
        };
        "db-sync-${envName}-entrypoint" = nixpkgs.symlinkJoin {
          name = "cardano-db-sync-${envName}-symlinks";
          paths = [
            (
              writeShellApplication {
                name = "cardano-db-sync-${envName}-entrypoint";
                env = {
                  inherit socketPath envFlag;
                  schemaDir = inputs.cardano-db-sync + "/schema";
                  stateDir = dbSyncStateDir;
                  snapShotUrl = snapShotUrl.${envName};
                  snapShotSha = snapShotSha.${envName};
                  configFile = builtins.toFile "db-sync-config.json" (
                    builtins.toJSON (
                      constants.lib.environments.${envName}.explorerConfig
                      // constants.lib.defaultExplorerLogConfig
                    )
                  );
                };
                text = (fileContents ./db-sync-entrypoint.sh);
                runtimeInputs = [
                  packages.db-sync
                  packages.cli
                  nixpkgs.coreutils
                  nixpkgs.curl
                  nixpkgs.dig
                  nixpkgs.findutils
                  nixpkgs.gnutar
                  nixpkgs.gzip
                  nixpkgs.jq
                  nixpkgs.postgresql_12
                ];
              }
            )
            # fix for popen failure: Cannot allocate memory
            # through `nix profile install`, this provides /bin/sh which is a hard-coded dependency of some postgres commands
            nixpkgs.bashInteractive
          ];
        };
        "wallet-${envName}-entrypoint" = writeShellApplication {
          name = "cardano-wallet-${envName}-entrypoint";
          env = {
            inherit socketPath envFlag walletEnvFlag;
            stateDir = walletStateDir;
          };
          text = (fileContents ./wallet-entrypoint.sh);
          runtimeInputs = [
            packages.wallet
            packages.cli
            nixpkgs.coreutils
            nixpkgs.dig
            nixpkgs.jq
          ];
        };
      };
  in
    (entrypoints "testnet")
    // (entrypoints "mainnet")
    // {
      wallet-init-entrypoint = writeShellApplication {
        name = "cardano-wallet-init-entrypoint";
        text = (fileContents ./wallet-init-entrypoint.sh);
        runtimeInputs = [ nixpkgs.gnused nixpkgs.curl nixpkgs.coreutils ];
      };
    }
)
