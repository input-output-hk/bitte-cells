{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages library nixosProfiles;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in {
  node-network-testnet-sync = writeShellApplication {
    name = "cardano-node-network-testnet-sync-check";
    env = {
      inherit
        (library.evalNodeConfig "testnet" nixosProfiles.node)
        socketPath
        ;
      envFlag = library.envFlag "testnet";
    };
    text = fileContents ./node-network-sync-check.sh;
    runtimeInputs = [packages.cli nixpkgs.jq nixpkgs.coreutils];
  };
  node-network-sre-sync = writeShellApplication {
    name = "cardano-node-network-sre-sync-check";
    env = {
      inherit
        (library.evalNodeConfig "sre" nixosProfiles.node)
        socketPath
        ;
      envFlag = library.envFlag "sre";
    };
    text = fileContents ./node-network-sync-check.sh;
    runtimeInputs = [packages.cli nixpkgs.jq nixpkgs.coreutils];
  };
  node-network-mainnet-sync = writeShellApplication {
    name = "cardano-node-network-mainnet-sync-check";
    env = {
      inherit
        (library.evalNodeConfig "mainnet" nixosProfiles.node)
        socketPath
        ;
      envFlag = library.envFlag "mainnet";
    };
    text = fileContents ./node-network-sync-check.sh;
    runtimeInputs = [packages.cli nixpkgs.jq nixpkgs.coreutils];
  };
  db-sync-network-testnet-sync = writeShellApplication {
    name = "cardano-db-sync-network-testnet-sync-check";
    env = {
      inherit
        (library.evalNodeConfig "testnet" nixosProfiles.node)
        socketPath
        ;
      envFlag = library.envFlag "testnet";
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
  db-sync-network-mainnet-sync = writeShellApplication {
    name = "cardano-db-sync-network-mainnet-sync-check";
    env = {
      inherit
        (library.evalNodeConfig "mainnet" nixosProfiles.node)
        socketPath
        ;
      envFlag = library.envFlag "mainnet";
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
