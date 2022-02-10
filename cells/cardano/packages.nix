{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  cardano-node-project = (inputs.cardano-node.legacyPackages.${system.host.system}.extend (prev: final: {
    # FIXME: hack to use the materialized version of haskellBuildUtils from cardano-wallet.
    haskellBuildUtils = inputs.cardano-wallet.legacyPackages.${system.host.system}.pkgs.iohk-nix-utils;
  })).cardanoNodeProject.appendModule {
    # TODO: upstream materialization:
    materialized = ./materialized/cardano-node;
  };
  cardano-wallet = inputs.cardano-wallet.packages.${system.host.system};
  cardano-db-sync = inputs.cardano-db-sync.packages.${system.host.system};
in
{
  node = cardano-node-project.hsPkgs.cardano-node.components.exes.cardano-node // {
    # TODO: script to update materialization:
    # $ nix build .\#cardano-node.passthru.generateMaterialized
    # $ ./result cells/cardano/materialized
    passthru = { inherit (cardano-node-project.plan-nix.passthru) generateMaterialized; };
  };
  submit-api = cardano-node-project.hsPkgs.cardano-submit-api.components.exes.cardano-submit-api;
  cli = cardano-node-project.hsPkgs.cardano-cli.components.exes.cardano-cli;
  bech32 = cardano-node-project.hsPkgs.bech32.components.exes.bech32;
  wallet = cardano-wallet.cardano-wallet;
  address = cardano-wallet.cardano-address;
  db-sync = cardano-db-sync.cardano-db-sync;
}
