{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
  n2c = inputs.n2c.packages.nix2container;
in {
  default = n2c.buildImage {
    name = "registry.ci.iog.io/vector";
    maxLayers = 15;
    contents = [nixpkgs.bashInteractive nixpkgs.cacert];
    config.Entrypoint = ["${packages.default}/bin/vector"];
  };
}
