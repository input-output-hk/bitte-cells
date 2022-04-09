{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) entrypoints healthChecks;
  n2c = inputs.n2c.packages.nix2container;
in {
  rabbit = n2c.buildImage {
    name = "docker.infra.aws.iohkdev.io/rabbit";
    tag = inputs.self.rev;
    maxLayers = 25;
    contents = [nixpkgs.bashInteractive];
    config.Cmd = [
      "${entrypoints.rabbit}/bin/rabbit-entrypoint"
    ];
  };
}
