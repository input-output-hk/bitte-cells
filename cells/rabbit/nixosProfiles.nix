{ inputs
, system
}:
{
  routing =
    { ... }:
    {
      services.traefik.staticConfigOptions = { entryPoints = { amqps.address = ":5671"; }; };
    };
}
