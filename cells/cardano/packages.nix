{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  cardano-node-legacy =
    inputs.cardano-node.legacyPackages.${system.host.system};
  cardano-node = inputs.cardano-node.packages.${system.host.system};
  cardano-wallet = inputs.cardano-wallet.packages.${system.host.system};
  cardano-db-sync = inputs.cardano-db-sync.packages.${system.host.system};
in
{
  # TODO: materialize here to fend againts IFD-hell!!!
  node = cardano-node.cardano-node;
  submit-api = cardano-node.cardano-submit-api;
  cardano-cli = cardano-node.cardano-cli;
  bech32 = cardano-node-legacy.bech32;
  wallet = cardano-wallet.cardano-wallet;
  address = cardano-wallet.cardano-address;
  db-sync = cardano-db-sync.cardano-db-sync;
}
