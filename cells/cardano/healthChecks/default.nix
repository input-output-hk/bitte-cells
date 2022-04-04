{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages library nixosProfiles;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;

  syncs = env: {
    "node-network-${env}-sync" = writeShellApplication {
      name = "cardano-node-network-${env}-sync-check";
      env = {
        inherit
          (library.evalNodeConfig env nixosProfiles.node)
          socketPath
          ;
        envFlag = library.envFlag env;
      };
      text = fileContents ./node-network-sync-check.sh;
      runtimeInputs = [packages.cli nixpkgs.jq nixpkgs.coreutils];
    };

    "db-sync-network-${env}-sync" = writeShellApplication {
      name = "cardano-db-sync-network-${env}-sync-check";
      env = {
        inherit
          (library.evalNodeConfig env nixosProfiles.node)
          socketPath
          ;
        envFlag = library.envFlag env;
      };
      text = fileContents ./db-sync-network-sync-check.sh;
      runtimeInputs = [
        packages.cli
        nixpkgs.curl
        nixpkgs.jq
        nixpkgs.gnugrep
        nixpkgs.coreutils
      ];
    };
  };
in
  (syncs "testnet")
  // (syncs "sre")
  // (syncs "mainnet")
  // (syncs "marlowe-pioneers")
  // {
  wallet-network-sync = writeShellApplication {
    name = "cardano-wallet-network-sync-check";
    text = fileContents ./wallet-network-sync-check.sh;
    runtimeInputs = [nixpkgs.curl nixpkgs.jq];
  };
  wallet-id-sync = writeShellApplication {
    name = "cardano-wallet-id-sync-check";
    text = fileContents ./wallet-id-sync-check.sh;
    runtimeInputs = [nixpkgs.curl nixpkgs.jq];
  };
}
