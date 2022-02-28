{ inputs
, cell
}:
let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
in
{
  default = _: {
    commands = [
      {
        package = nixpkgs.postgresql;
        name = "psql";
        category = "patroni";
      }
      {
        package = packages.default;
        name = "patronictl";
        category = "patroni";
      }
    ];
  };
}
