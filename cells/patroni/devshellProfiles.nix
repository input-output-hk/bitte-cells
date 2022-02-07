{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.host.system};
in
{
  "" =
    { pkgs
    , ...
    }:
    {
      commands = [
        {
          package = nixpkgs.postgresql;
          name = "psql";
          category = "patroni";
        }
        {
          package = packages.patroni;
          name = "patronictl";
          category = "patroni";
        }
      ];
    };
}
