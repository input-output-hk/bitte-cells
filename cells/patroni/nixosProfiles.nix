{
  inputs,
  cell,
}: {
  client = namespace: {bittelib, ...}: {
    imports = [
      (
        bittelib.mkNomadHostVolumesConfig ["${namespace}-database"] (n: "/var/lib/nomad-volumes/${n}")
      )
    ];
    # for scheduling constraints
    services.nomad.client.meta.patroni = "yeah";
  };
}
