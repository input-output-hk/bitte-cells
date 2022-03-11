{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in {
  dgraph-zero-entrypoint = writeShellApplication {
    name = "dgraph-zero-entrypoint";
    text = fileContents ./zero-entrypoint.sh;
    runtimeInputs = [
      nixpkgs.dgraph
    ];
  };
  dgraph-alpha-entrypoint = writeShellApplication {
    name = "dgraph-alpha-entrypoint";
    text = fileContents ./alpha-entrypoint.sh;
    runtimeInputs = [
      nixpkgs.dgraph
    ];
  };
}
