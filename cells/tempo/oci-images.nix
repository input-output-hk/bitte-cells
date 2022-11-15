{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.cells) _utils;
  inherit (cell) entrypoints;
  n2c = inputs.n2c.packages.nix2container;

  buildDebugImage = ep: o: n2c.buildImage (_utils.library.mkDebugOCI ep o);
in {
  tempo = buildDebugImage entrypoints.tempo {
    name = "registry.ci.iog.io/tempo";
    maxLayers = 15;
    layers = [
      (n2c.buildLayer {deps = entrypoints.tempo.runtimeInputs;})
    ];
    copyToRoot = with nixpkgs; [bashInteractive cacert];
    config.Entrypoint = ["${entrypoints.tempo}/bin/entrypoint"];
  };
}
