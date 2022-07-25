{
  inputs,
  cell,
}: let
  inherit (inputs.std) std;
  inherit (inputs) nixpkgs;
in {
  default = std.lib.mkShell {
    name = "Bitte Cells";
    imports = [
      std.devshellProfiles.default
    ];
    packages = with nixpkgs; [
      treefmt
      alejandra
      nodePackages.prettier
      nodePackages.prettier-plugin-toml
      shfmt
      editorconfig-checker
    ];
    devshell.startup.nodejs-setuphook = nixpkgs.lib.stringsWithDeps.noDepEntry ''
      export NODE_PATH=${nixpkgs.nodePackages.prettier-plugin-toml}/lib/node_modules:$NODE_PATH
    '';
  };
}
