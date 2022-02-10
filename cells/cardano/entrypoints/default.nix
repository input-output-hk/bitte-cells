{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.build.system};
  library = inputs.self.library.${system.build.system};
  writeShellApplication = library._writers-writeShellApplication;
  fileContents = nixpkgs.lib.strings.fileContents;
  # Render start commands form NixOS service definitions
  inherit
    (nixpkgs.extend inputs.cardano-iohk-nix.overlays.cardano-lib)
    cardanoLib
    ;
  cardano-node-nixosModules = inputs.cardano-node.nixosModules;
  nixosProfiles = inputs.self.nixosProfiles.${system.host.system};
  nodeCmd = envName: let
    envConfig = cardanoLib.environments.${envName};
  in
    (
      nixpkgs.lib.evalModules {
        specialArgs = { inherit envConfig envName; };
        modules = [
          cardano-node-nixosModules.cardano-node
          nixosProfiles.cardano-node
        ];
      }
    )
    .services
    .cardano-node
    .script;
in
(
  let
    entrypoints = envName: {
      "node-${envName}-entrypoint" = writeShellApplication {
        name = "cardano-node-${envName}-entrypoint";
        text = (fileContents ./node-entrypoint.sh) + "\n" + (nodeCmd envName);
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
          configFile = builtins.toFile "submit-api-config.json" (builtins.toJSON cardanoLib.defaultExplorerLogConfig);
        };
        text = (fileContents ./submit-api-entrypoint.sh);
        runtimeInputs = [ packages.cardano-submit-api packages.cardano-cli ];
      };
      "db-sync-${envName}-entrypoint" = writeShellApplication {
        name = "cardano-db-sync-${envName}-entrypoint";
        env = {
          schemaDir = inputs.cardano-db-sync + "/schema";
          stateDir = "/var/lib/cexplorer";
          configFile = builtins.toFile "db-sync-config.json" (
            builtins.toJSON (
              cardanoLib.${envName}.explorerConfig
              // cardanoLib.defaultExplorerLogConfig
            )
          );
        };
        text = (fileContents ./db-sync-entrypoint.sh);
        runtimeInputs = [ packages.cardano-db-sync packages.cardano-cli ];
      };
      "wallet-${envName}-entrypoint" = writeShellApplication {
        name = "cardano-wallet-${envName}-entrypoint";
        text = (fileContents ./wallet-entrypoint.sh);
        runtimeInputs = [ packages.cardano-wallet packages.cardano-cli ];
      };
    };
  in
    (entrypoints "testnet") // (entrypoints "mainnet")
)
