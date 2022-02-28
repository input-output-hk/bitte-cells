{ inputs
, cell
}:
let
  inherit (inputs) nixpkgs;
  inherit (inputs.cells._writer.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in
{
  entrypoint = writeShellApplication {
    name = "rabbit-entrypoint";
    text = (fileContents ./entrypoint.sh);
    runtimeInputs = [ nixpkgs.rabbitmq-server ];
  };
}
