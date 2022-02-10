{ inputs
, system
}:
let
  packages = inputs.self.packages.${system.host.system};
in
{
  routing =
    { pkiFiles
    , ...
    }:
    {
      services.traefik.staticConfigOptions = { entryPoints = { psql.address = ":5432"; }; };
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
  client = namespace: { ... }:
  {
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
  # Configuration Profiles for Entrypoint Startcmd rendering
  node =
    { envConfig
    , envName
    }:
    {
      services.cardano-node = {
        # find options definitons in `cardano-node/nix/nixos/cardano-node-service.nix`
        package = packages.node;
        kesKey = null;
        vrfKey = null;
        operationalCertificate = null;
        hostAddr = "0.0.0.0";
        ipv6HostAddr = null;
        stateDir = "/var/lib/cardano-node";
        runtimeDir = "/run/cardano-node";
        databasePath = "/var/lib/cardano-node/db-${envName}";
        socketPath = "/run/cardano-node/node.socket";
        port = "3001";
        nodeId = 0;
        publicProducers = [
          {
            addrs = [
              {
                addr = envConfig.relaysNew;
                port = envConfig.edgePort;
              }
            ];
            advertise = false;
          }
        ];
        instancePublicProudcers = _: [ ];
        producers = [ ];
        instanceProducers = _: [ ];
        useNowTopology = envConfig.EnableP2P or false;
        targetNumberOfRootPeers = envConfig.TargetNumberOfRootPeers or 60;
        targetNumberOfKnownPeers =
          envConfig.TargetNumberOfKnownPeers or envConfig.TargetNumberOfRootPeers or 60;
        targetNumberOfEstablishedPeers =
          envConfig.TargetNumberOfEstablishedPeers or (
              2
              * (
                envConfig.TargetNumberOfKnownPeers or envConfig.TargetNumberOfRootPeers or 60
              )
              / 3
            );
      };
    };
}
