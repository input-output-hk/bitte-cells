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
  client = namespace: {...}: {
    services.nomad.client = {
      host_volume = [
        {
          "${namespace}-database" = {
            path = "/var/lib/nomad-volumes/${namespace}-database";
            read_only = false;
          };
        }
      ];
    };
  };
}
