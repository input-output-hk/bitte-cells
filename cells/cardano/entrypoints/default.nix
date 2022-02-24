{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.build.system};
  library = inputs.self.library.${system.build.system};
  nixosProfiles = inputs.self.nixosProfiles.${system.host.system};
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
      cfg = library.cardano-evalNodeConfig envName nixosProfiles.cardano-node;
      inherit (cfg) socketPath;
      envFlag = library.cardano-envFlag envName;
      nodeStateDir = (cfg).stateDir;
      dbSyncStateDir = "/var/lib/cardano-db-sync";
      walletStateDir = "/var/lib/cardano-wallet";
      walletEnvFlag =
        if envName == "testnet"
        then
          "--testnet ${
            library
            .cardano-lib
            .environments
            .testnet
            .networkConfig
            .ByronGenesisFile
          }"
        else if envName == "mainnet"
        then "--mainnet"
        else abort "unreachable";
      snapShotUrl = {
        # https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/index.html#12/
        "testnet" = "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3336499-x86_64.tgz";
        # https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#12/
        "mainnet" = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-6878999-x86_64.tgz";
      };
      snapShotSha = {
        "testnet" = "4c0bf34537ff4c703ba41e7613291dea240623d81ac9f55973042a2e2f7dc95c";
        "mainnet" = "f022340ce3e7fd0ac9492d00e9e996dd6158c68b72fc4af67f266ca0e79d2e55";
      };
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
            packages.cardano-node
            packages.cardano-cli
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
            configFile = builtins.toFile "submit-api-config.json" (builtins.toJSON cardanoLib.defaultExplorerLogConfig);
          };
          text = (fileContents ./submit-api-entrypoint.sh);
          runtimeInputs = [ packages.cardano-submit-api packages.cardano-cli ];
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
                      cardanoLib.environments.${envName}.explorerConfig
                      // cardanoLib.defaultExplorerLogConfig
                    )
                  );
                };
                text = (fileContents ./db-sync-entrypoint.sh);
                runtimeInputs = [
                  packages.cardano-db-sync
                  packages.cardano-cli
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
            packages.cardano-wallet
            packages.cardano-cli
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
