{
  description = "Bitte Cells development shell";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.devshell.url = "github:numtide/devshell?ref=refs/pull/169/head";
  inputs.treefmt.url = "github:numtide/treefmt";
  inputs.alejandra.url = "github:kamadorueda/alejandra";
  inputs.alejandra.inputs.treefmt.url = "github:divnix/blank";
  inputs.std.url = "github:divnix/std";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs =
    inputs:
    inputs.flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (
      system:
      let
        stdProfiles = inputs.std.devshellProfiles.${system};
        devshell = inputs.devshell.legacyPackages.${system};
        nixpkgs = inputs.nixpkgs.legacyPackages.${system};
        alejandra = inputs.alejandra.defaultPackage.${system};
        treefmt = inputs.treefmt.defaultPackage.${system};
      in
        {
          devShells.__default = devshell.mkShell {
            name = "Bitte Cells";
            imports = [ stdProfiles.std ];
            commands = [{
              package = treefmt;
            }];
            packages = [
              alejandra
              nixpkgs.shfmt
              nixpkgs.nodePackages.prettier
              nixpkgs.nodePackages.prettier-plugin-toml
            ];
          };
        }
    );
}

