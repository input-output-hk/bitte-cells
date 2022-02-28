{ inputs
, cell
}:
let
  inherit (inputs) nixpkgs;
in
{
  default = _: {
    commands = [
      {
        package = nixpkgs.rabbitmq-server;
        name = "rabbitmqctl";
        category = "rabbit";
      }
    ];
  };
}
