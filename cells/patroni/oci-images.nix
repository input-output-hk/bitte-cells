{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) entrypoints;
in {
  patroni = nixpkgs.dockerTools.buildLayeredImage {
    name = "docker.infra.aws.iohkdev.io/patroni";
    tag = inputs.self.rev;
    maxLayers = 15;
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.patroni-entrypoint}/bin/patroni-entrypoint"
    ];
  };
  patroni-backup-sidecar = nixpkgs.dockerTools.buildLayeredImage {
    name = "docker.infra.aws.iohkdev.io/patroni-backup-sidecar";
    tag = inputs.self.rev;
    maxLayers = 15;
    contents = [nixpkgs.bashInteractive];
    config.Entrypoint = [
      "${entrypoints.backup-sidecar-entrypoint}/bin/patroni-backup-sidecar-entrypoint"
    ];
  };
}
