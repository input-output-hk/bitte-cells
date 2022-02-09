{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.host.system};
in
{
  "" = _: {
    commands = [
      {
        package = nixpkgs.b2sum;
        category = "cardano";
      }
      {
        package = nixpkgs.xxd;
        category = "cardano";
      }
      {
        package = nixpkgs.haskellPackages.cbor-tool;
        category = "cardano";
      }
      {
        package = packages.cardano-bech32;
        category = "cardano";
      }
      {
        package = packages.cardano-wallet;
        category = "cardano";
      }
      {
        package = packages.cardano-address;
        category = "cardano";
      }
      {
        package = packages.cardano-cli;
        name = "cardano-cli";
        category = "cardano";
      }
    ];
  };
}
