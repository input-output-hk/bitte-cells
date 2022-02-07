{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
in
{
  "" = _: {
    commands = [
      {
        package = nixpkgs.rabbitmq-server;
        name = "rabbitmqctl";
        category = "rabbit";
      }
    ];
  };
}
