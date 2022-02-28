{ inputs
, cell
}:
{
  routing =
    { ... }:
    {
      services.traefik.staticConfigOptions = { entryPoints = { amqps.address = ":5671"; }; };
    };
}
