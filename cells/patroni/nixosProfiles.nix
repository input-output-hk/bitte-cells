{ ... }:
{
  routing =
    { pkiFiles
    , ...
    }:
    {
      services.traefik.dynamicConfigOptions = {
        http = {
          serversTransports = {
            # patroni-rest-api is just a constant identifier that is defined here
            patroni-rest-api.certificates = {
              certFile = pkiFiles.certFile;
              keyFile = pkiFiles.keyFile;
              rootCAs = pkiFiles.caCertFile;
            };
          };
        };
      };
    };
}
