{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  cardano-node-nixosModules = inputs.cardano-node.nixosModules;
  constants = inputs.self.constants.${system.build.system};
in
rec {
  walletEnvFlag = envName: if envName == "testnet"
  then
    "--testnet ${
      constants
      .cardano-lib
      .__data
      .environments
      .testnet
      .networkConfig
      .ByronGenesisFile
    }"
  else if envName == "mainnet"
  then "--mainnet"
  else abort "unreachable";
  envFlag = envName: if envName == "testnet"
  then "--testnet-magic 1097911063"
  else if "mainnet"
  then "--mainnet"
  else abort "unreachable";
  evalNodeConfig = envName: profile: let
    envConfig = constants.cardano-lib.__data.environments.${envName};
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
          profile
        ];
      }
    )
    .config
    .services
    .cardano-node;
}
