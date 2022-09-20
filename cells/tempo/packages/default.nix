{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  otel-cli = nixpkgs.callPackage ./otel.nix {};
  tempo = nixpkgs.callPackage ./tempo.nix {buildGoModule = nixpkgs.buildGo118Module;};
}
