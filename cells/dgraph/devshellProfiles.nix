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
        package = nixpkgs.dgraph;
        category = "dgraph";
      }
    ];
  };
}
