{ inputs
, system
}:
let
  packages = inputs.self.packages.${system.host.system};
in
{
  # Configuration Profiles for Entrypoint Startcmd rendering
  node =
    { envConfig
    , envName
    , ...
    }:
    {
      services.cardano-node = {
        # find options definitons in `cardano-node/nix/nixos/cardano-node-service.nix`
        package = packages.cardano-node;
        kesKey = null;
        vrfKey = null;
        operationalCertificate = null;
        hostAddr = "0.0.0.0";
        ipv6HostAddr = null;
        stateDir = "/var/lib/cardano-node";
        runtimeDir = "/run/cardano-node";
        databasePath = "/var/lib/cardano-node/db-${envName}";
        socketPath = "/run/cardano-node/node.socket";
        port = 3001;
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
        instancePublicProducers = _: [ ];
        producers = [ ];
        instanceProducers = _: [ ];
        useNewTopology = envConfig.EnableP2P or false;
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
