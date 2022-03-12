{
  inputs,
  cell,
}: {
  routing = {...}: {
    services.traefik.staticConfigOptions = {entryPoints = {amqps.address = ":5671";};};
  };
  client = {
    # for scheduling constraints
    services.nomad.client.meta.rabbit = "yeah";
  };
}
