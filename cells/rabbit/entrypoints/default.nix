{ inputs
, system
}:
let
  packages = inputs.self.packages.${system.build.system};
  library = inputs.self.library.${system.build.system};
  nixpkgs = inputs.nixpkgs;
  writeShellApplication = library._writers-writeShellApplication;
  fileContents = nixpkgs.lib.strings.fileContents;
in
{
  entrypoint = writeShellApplication {
    name = "rabbit-entrypoint";
    text = (fileContents ./entrypoint.sh);
    runtimeInputs = [ nixpkgs.rabbitmq-server ];
  };
}
