{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
in {
  default = _: {
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
        package = packages.bech32;
        category = "cardano";
      }
      {
        package = packages.wallet;
        category = "cardano";
      }
      {
        package = packages.address;
        category = "cardano";
      }
      {
        package = packages.cli;
        name = "cardano-cli";
        category = "cardano";
      }
    ];
  };
}
