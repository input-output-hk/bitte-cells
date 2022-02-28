{
  description = "Bitte Cells development shell";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.alejandra.url = "github:kamadorueda/alejandra";
  inputs.alejandra.inputs.treefmt.url = "github:divnix/blank";
  inputs.main.url = "path:../.";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = inputs: inputs.flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (
    system: let
      inherit
        (inputs.main.inputs.std.deSystemize system inputs)
        main
        devshell
        nixpkgs
        alejandra
        treefmt
        ;
      inherit (main.inputs.std.deSystemize system main.inputs) std;
    in
      {
        devShells.__default = devshell.legacyPackages.mkShell {
          name = "Bitte Cells";
          imports = [ std.std.devshellProfiles.default ];
          commands = [ { package = nixpkgs.legacyPackages.treefmt; } ];
          packages = [
            alejandra.defaultPackage
            nixpkgs.legacyPackages.shfmt
            nixpkgs.legacyPackages.nodePackages.prettier
            nixpkgs.legacyPackages.nodePackages.prettier-plugin-toml
            nixpkgs.legacyPackages.python3Packages.black
          ];
          devshell.startup.nodejs-setuphook = nixpkgs.lib.stringsWithDeps.noDepEntry ''
            export NODE_PATH=${
            nixpkgs.legacyPackages.nodePackages.prettier-plugin-toml
          }/lib/node_modules:$NODE_PATH
          '';
        };
      }
  );
}
