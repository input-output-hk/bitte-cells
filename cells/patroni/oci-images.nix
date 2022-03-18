{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) entrypoints;
  n2c = inputs.n2c.packages.nix2container;
in {
  patroni = n2c.buildImage {
    name = "docker.infra.aws.iohkdev.io/patroni";
    tag = inputs.self.rev;
    maxLayers = 15;
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.patroni-entrypoint}/bin/patroni-entrypoint"
    ];
  };
  patroni-backup-sidecar = n2c.buildImage {
    name = "docker.infra.aws.iohkdev.io/patroni-backup-sidecar";
    tag = inputs.self.rev;
    maxLayers = 15;
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.backup-sidecar-entrypoint}/bin/patroni-backup-sidecar-entrypoint"
    ];
  };
}
