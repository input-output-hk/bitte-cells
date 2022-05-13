{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) entrypoints;
  n2c = inputs.n2c.packages.nix2container;
in {
  patroni = nixpkgs.dockerTools.buildLayeredImage {
    name = "docker.infra.aws.iohkdev.io/patroni";
    maxLayers = 15;
    layers = [
      (n2c.buildLayer {deps = entrypoints.patroni-entrypoint.runtimeInputs;})
    ];
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.patroni-entrypoint}/bin/patroni-entrypoint"
    ];
  };
  patroni-backup-sidecar = nixpkgs.dockerTools.buildLayeredImage {
    name = "docker.infra.aws.iohkdev.io/patroni-backup-sidecar";
    maxLayers = 15;
    layers = [
      (n2c.buildLayer {deps = entrypoints.backup-sidecar-entrypoint.runtimeInputs;})
    ];
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.backup-sidecar-entrypoint}/bin/patroni-backup-sidecar-entrypoint"
    ];
  };
}
