{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.cardano-node) nixosModules;
  inherit (cell) constants;
in rec {
  walletEnvFlag = envName:
    if envName == "testnet"
    then "--testnet ${
      constants.lib.environments.testnet.networkConfig.ByronGenesisFile
    }"
    else if envName == "sre"
    then "--testnet ${
      constants.lib.environments.sre.networkConfig.ByronGenesisFile
    }"
    else if envName == "mainnet"
    then "--mainnet"
    else abort "unreachable";
  envFlag = envName:
    if envName == "testnet"
    then "--testnet-magic 1097911063"
    else if "sre"
    then "--testnet-magic 3"
    else if "mainnet"
    then "--mainnet"
    else abort "unreachable";
  evalNodeConfig = envName: profile: let
    envConfig = constants.lib.environments.${envName};
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
            {lib, ...}: {
              options.systemd = lib.mkOption {type = lib.types.any;};
              options.users = lib.mkOption {type = lib.types.any;};
            }
          )
          nixosModules.cardano-node
          profile
        ];
      }
    )
    .config
    .services
    .cardano-node;
}
