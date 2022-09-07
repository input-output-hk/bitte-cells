{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  default = nixpkgs.callPackage ./tempo.nix {buildGoModule = nixpkgs.buildGo118Module;};
}
