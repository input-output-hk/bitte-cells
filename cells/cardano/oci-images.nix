{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) entrypoints;
  n2c = inputs.n2c.packages.nix2container;
in (
  let
    containers = envName: {
      "node-${envName}" = n2c.buildImage {
        name = "docker.infra.aws.iohkdev.io/cardano-node-${envName}";
        tag = inputs.self.rev;
        maxLayers = 15;
        config.Cmd = [
          "${entrypoints."node-${envName}-entrypoint"}/bin/cardano-node-${envName}-entrypoint"
        ];
      };
      "submit-api-${envName}" = n2c.buildImage {
        name = "docker.infra.aws.iohkdev.io/cardano-submit-api-${envName}";
        tag = inputs.self.rev;
        maxLayers = 15;
        config.Cmd = [
          "${entrypoints."submit-api-${envName}-entrypoint"}/bin/cardano-submit-api-${envName}-entrypoint"
        ];
      };
      "db-sync-${envName}" = n2c.buildImage {
        name = "docker.infra.aws.iohkdev.io/cardano-db-sync-${envName}";
        tag = inputs.self.rev;
        maxLayers = 15;
        config.Cmd = [
          "${entrypoints."db-sync-${envName}-entrypoint"}/bin/cardano-db-sync-${envName}-entrypoint"
        ];
      };
      "wallet-${envName}" = n2c.buildImage {
        name = "docker.infra.aws.iohkdev.io/cardano-wallet-${envName}";
        tag = inputs.self.rev;
        maxLayers = 15;
        config.Cmd = [
          "${entrypoints."wallet-${envName}-entrypoint"}/bin/cardano-wallet-${envName}-entrypoint"
        ];
      };
    };
  in
    (containers "testnet")
    // {
      wallet-init = n2c.buildImage {
        name = "docker.infra.aws.iohkdev.io/cardano-wallet-init";
        tag = inputs.self.rev;
        maxLayers = 15;
        config.Cmd = [
          "${entrypoints.wallet-init-entrypoint}/bin/cardano-wallet-init-entrypoint"
        ];
      };
    }
)
