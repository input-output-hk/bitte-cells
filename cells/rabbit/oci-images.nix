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
    maxLayers = 25;
    layers = [
      (n2c.buildLayer {deps = entrypoints.rabbit.runtimeInputs;})
    ];
    contents = [nixpkgs.bashInteractive];
    config.Cmd = [
      "${entrypoints.rabbit}/bin/rabbit-entrypoint"
    ];
  };
}
