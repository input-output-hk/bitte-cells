{
  inputs,
  cell,
}: let
  # Render start commands form NixOS service definitions
  inherit (inputs) nixpkgs data-merge;
  inherit
    (nixpkgs.extend inputs.cardano-iohk-nix.overlays.cardano-lib)
    cardanoLib
    ;
in
  with data-merge; {
    lib = merge cardanoLib {
      defaultLogConfig.setupScribes = update [0] [{scFormat = "ScJson";}];
      defaultExplorerLogConfig.setupScribes = update [0] [{scFormat = "ScJson";}];
      # environments.sre.nodeConfig.defaultBackends = ["bla"];
      environments =
        builtins.mapAttrs
        (_: _: {
          nodeConfig.setupScribes = update [0] [{scFormat = "ScJson";}];
        })
        cardanoLib.environments;
    };
    localSharePrefix = "~/.local/share/bitte-cells";
    snapShots = {
      dbSync = {
        snapShotUrl = {
          # https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/index.html#12/
          "testnet" = "https://updates-cardano-testnet.s3.amazonaws.com/cardano-db-sync/12/db-sync-snapshot-schema-12-block-3374999-x86_64.tgz";
          # https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#12/
          "mainnet" = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-6965999-x86_64.tgz";
        };
        snapShotSha = {
          "testnet" = "dd3f0fbbe205aa5e9d768de673dcdfd4f01bfedb6d8e10dc8ecc691055739846";
          "mainnet" = "3096a45f27791e661823bb521b25ada30c57df84e835fbbae729ed25f7eec63e";
        };
      };
    };
    stateDirs = {
      dbSync = "/persist-db-sync";
      wallet = "/persist-wallet";
      node = "/var/lib/cardano-node";
    };
  }
