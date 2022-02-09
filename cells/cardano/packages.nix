{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  cardno-node-legacy =
    inputs.cardano-node.legacyPackages.${system.host.system};
  cardno-node = inputs.cardano-node.packages.${system.host.system};
  cardno-wallet = inputs.cardano-wallet.packages.${system.host.system};
  cardno-db-sync = inputs.cardano-db-sync.packages.${system.host.system};
in
{
  # TODO: materialize here to fend againts IFD-hell!!!
  node = cardno-node.cardno-node;
  submit-api = cardno-node.cardno-submit-api;
  cardano-cli = cardno-node.cardano-cli;
  bech32 = cardno-node-legacy.bech32;
  wallet = cardno-wallet.cardno-wallet;
  address = cardno-wallet.cardno-address;
  db-sync = cardno-db-sync.cardno-db-sync;
}
