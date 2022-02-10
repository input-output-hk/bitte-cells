{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  library = inputs.self.library.${system.build.system};
  writeShellApplication = library._writers-writeShellApplication;
  fileContents = nixpkgs.lib.strings.fileContents;
in
{
  db-sync-network-sync = writeShellApplication {
    name = "cardano-db-sync-network-sync-check";
    text = (fileContents ./db-sync-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.curl nixpkgs.jq nixpkgs.grep ];
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
  node-network-sync = writeShellApplication {
    name = "cardano-node-network-sync-check";
    text = (fileContents ./node-network-sync-check.sh);
    runtimeInputs = [ packages.cardano-cli nixpkgs.jq ];
  };
}
