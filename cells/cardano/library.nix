{ inputs
, system
}:
let
  # Render start commands form NixOS service definitions
  nixpkgs = inputs.nixpkgs;
  inherit
    (nixpkgs.extend inputs.cardano-iohk-nix.overlays.cardano-lib)
    cardanoLib
    ;
  cardano-node-nixosModules = inputs.cardano-node.nixosModules;
  nixosProfiles = inputs.self.nixosProfiles.${system.host.system};
in
{
  lib = cardanoLib;
  envFlag = envName: if envName == "testnet"
  then "--testnet-magic 1097911063"
  else if "mainnet"
  then "--mainnet"
  else abort "unreachable";
  evalNodeConfig = envName: let
    envConfig = cardanoLib.environments.${envName};
  in
    (
      nixpkgs.lib.evalModules {
        specialArgs = {
          inherit envConfig envName;
          pkgs = nixpkgs;
        };
        modules = [
          (nixpkgs.path + "/nixos/modules/misc/assertions.nix")
          # FIXME: remove dependency on the systemd module from the script renderer
          (
            { lib
            , ...
            }:
            {
              options.systemd = lib.mkOption { type = lib.types.any; };
              options.users = lib.mkOption { type = lib.types.any; };
            }
          )
          cardano-node-nixosModules.cardano-node
          nixosProfiles.cardano-node
        ];
      }
    )
    .config
    .services
    .cardano-node;
}
