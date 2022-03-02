{
  inputs,
  cell,
}: {
  routing = {pkiFiles, ...}: {
    services.traefik.staticConfigOptions = {entryPoints = {psql.address = ":5432";};};
    services.traefik.dynamicConfigOptions = {
      http = {
        serversTransports = {
          # patroni-rest-api is just a constant identifier that is defined here
          # grep for `patroni-rest-api@file` for usage
          patroni-rest-api.certificates = {
            certFile = pkiFiles.certFile;
            keyFile = pkiFiles.keyFile;
            rootCAs = pkiFiles.caCertFile;
          };
        };
      };
    };
  };
  client = namespace: { bittelib
  , ...
  }:
  {
    imports = [
      (
        bittelib.mkNomadHostVolumesConfig [ "${namespace}-database" ] (n: "/var/lib/nomad-volumes/${n}")
      )
    ];
    # for scheduling constraints
    services.nomad.client.meta.patroni = "yeah";
  };
}
