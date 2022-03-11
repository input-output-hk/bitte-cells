{
  inputs,
  cell,
}: let
  # Render start commands form NixOS service definitions
  inherit (inputs) nixpkgs;
  inherit
    (nixpkgs.extend inputs.cardano-iohk-nix.overlays.cardano-lib)
    cardanoLib
    ;
in {
  wallet-init-healthcheck-flake-url = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#${nixpkgs.system}.cardano.health.wallet-init-sync";

  lib = cardanoLib;
  localSharePrefix = "~/.local/share/bitte-cells";
  snapShots = {
    dbSync = {
      snapShotUrl = {
        # https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/index.html#12/
        "testnet" = "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3336499-x86_64.tgz";
        # https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#12/
        "mainnet" = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-6878999-x86_64.tgz";
      };
      snapShotSha = {
        "testnet" = "4c0bf34537ff4c703ba41e7613291dea240623d81ac9f55973042a2e2f7dc95c";
        "mainnet" = "f022340ce3e7fd0ac9492d00e9e996dd6158c68b72fc4af67f266ca0e79d2e55";
      };
    };
  };
  stateDirs = {
    dbSync = "/persist-db-sync";
    wallet = "/persist-wallet";
    node = "/var/lib/cardano-node";
  };
}
