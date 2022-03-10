{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages constants;
in rec {
  # Configuration Profiles for Entrypoint Startcmd rendering
  run-dgraph-testnet = {
    envName,
    config,
    ...
  }: {
    imports = [dgraph];
    services.dgraph = let
      stateDir = "${constants.localSharePrefix}/run-dgraph-testnet";
    in {
      stateDir = stateDir;
      runtimeDir = "/run/dgraph";
    };
  };
  dgraph = {
    envConfig,
    envName,
    ...
  }: {
    services.dgraph = let
      stateDir = constants.stateDirs.dgraph;
    in {
      # find options definitons in `cardano-node/nix/nixos/cardano-node-service.nix`
      package = packages.dgraph;
      operationalCertificate = null;
      hostAddr = "0.0.0.0";
      ipv6HostAddr = null;
      stateDir = nixpkgs.lib.mkDefault stateDir;
      runtimeDir = nixpkgs.lib.mkDefault "/run/dgraph";
      port = 9999;
    };
  };
  client = namespace: {bittelib, ...}: {
    imports = [
    ];
    # for scheduling constraints
    services.nomad.client.meta.dgraph = "yeah";
  };
}
