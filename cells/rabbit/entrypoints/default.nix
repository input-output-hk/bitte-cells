{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
  inherit (inputs.cells._writers.library) writeShellApplication;
in {
  entrypoint = writeShellApplication {
    name = "rabbit-entrypoint";
    text = fileContents ./entrypoint.sh;
    runtimeInputs = [nixpkgs.rabbitmq-server];
  };
}
