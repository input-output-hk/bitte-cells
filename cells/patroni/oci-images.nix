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
  patroni = buildDebugImage entrypoints.patroni {
    name = "registry.ci.iog.io/patroni";
    maxLayers = 15;
    layers = [
      (n2c.buildLayer {deps = entrypoints.patroni.runtimeInputs;})
    ];
    contents = with nixpkgs; [bashInteractive cacert];
    config.Entrypoint = ["${entrypoints.patroni}/bin/entrypoint"];
  };
  patroni-backup-sidecar = buildDebugImage entrypoints.patroni-backup-sidecar {
    name = "registry.ci.iog.io/patroni-backup-sidecar";
    maxLayers = 15;
    layers = [
      (n2c.buildLayer {deps = entrypoints.patroni-backup-sidecar.runtimeInputs;})
    ];
    contents = with nixpkgs; [bashInteractive cacert];
    config.Entrypoint = [
      "${entrypoints.patroni-backup-sidecar}/bin/entrypoint"
    ];
  };
}
