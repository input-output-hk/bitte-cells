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
in
{
  node-network-testnet-sync = writeShellApplication {
    name = "cardano-node-network-testnet-sync-check";
    env = {
      inherit
        (library.cardano-evalNodeConfig "testnet" nixosProfiles.cardano-node)
        socketPath
        ;
      envFlag = library.cardano-envFlag "testnet";
    };
    text = (fileContents ./node-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.jq ];
  };
  node-network-mainnet-sync = writeShellApplication {
    name = "cardano-node-network-mainnet-sync-check";
    env = {
      inherit
        (library.cardano-evalNodeConfig "mainnet" nixosProfiles.cardano-node)
        socketPath
        ;
      envFlag = library.cardano-envFlag "mainnet";
    };
    text = (fileContents ./node-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.jq ];
  };
  db-sync-network-testnet-sync = writeShellApplication {
    name = "cardano-db-sync-network-testnet-sync-check";
    env = {
      inherit
        (library.cardano-evalNodeConfig "testnet" nixosProfiles.cardano-node)
        socketPath
        ;
      envFlag = library.cardano-envFlag "testnet";
    };
    text = (fileContents ./db-sync-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.curl nixpkgs.jq nixpkgs.gnugrep ];
  };
  db-sync-network-mainnet-sync = writeShellApplication {
    name = "cardano-db-sync-network-mainnet-sync-check";
    env = {
      inherit
        (library.cardano-evalNodeConfig "mainnet" nixosProfiles.cardano-node)
        socketPath
        ;
      envFlag = library.cardano-envFlag "mainnet";
    };
    text = (fileContents ./db-sync-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.curl nixpkgs.jq nixpkgs.gnugrep ];
  };
  wallet-network-sync = writeShellApplication {
    name = "cardano-wallet-network-sync-check";
    text = (fileContents ./wallet-network-sync-check.sh);
    runtimeInputs = [ nixpkgs.curl nixpkgs.jq ];
  };
  wallet-id-sync = writeShellApplication {
    name = "cardano-wallet-id-sync-check";
    text = (fileContents ./wallet-id-sync-check.sh);
    runtimeInputs = [ nixpkgs.curl nixpkgs.jq ];
  };
}
