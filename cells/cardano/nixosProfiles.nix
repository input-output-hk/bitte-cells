{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
  packages = inputs.self.packages.${system.host.system};
  constants = inputs.self.constants.${system.build.system};
in
rec {
  # Configuration Profiles for Entrypoint Startcmd rendering
  run-node-testnet =
    { envName
    , config
    , ...
    }:
    {
      imports = [ node ];
      services.cardano-node =
        let
          stateDir = "${constants.cardano-localSharePrefix.__data}/run-cardano-node-testnet";
        in
          {
            stateDir = stateDir;
            runtimeDir = "/run/cardano-node";
            databasePath = "${stateDir}/db-${envName}";
            socketPath = "/tmp/node.socket";
          };
    };
  node =
    { envConfig
    , envName
    , ...
    }:
    {
      services.cardano-node =
        let
          stateDir = constants.cardano-stateDirs.__data.node;
        in
          {
            # find options definitons in `cardano-node/nix/nixos/cardano-node-service.nix`
            package = packages.cardano-node;
            kesKey = null;
            vrfKey = null;
            operationalCertificate = null;
            hostAddr = "0.0.0.0";
            ipv6HostAddr = null;
            stateDir = nixpkgs.lib.mkDefault stateDir;
            runtimeDir = nixpkgs.lib.mkDefault "/run/cardano-node";
            databasePath = nixpkgs.lib.mkDefault "${stateDir}/db-${envName}";
            socketPath = nixpkgs.lib.mkDefault "/alloc/tmp/node.socket";
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
  client = namespace: { bittelib
  , ...
  }:
  {
    imports = [
      (
        # requires glusterfs be configured on the cluster
        bittelib.mkNomadHostVolumesConfig [ "${namespace}-db-sync" "${namespace}-wallet" ] (n: "/mnt/gv0/nomad/${n}")
      )
    ];
    # for scheduling constraints
    services.nomad.client.meta.cardano = "yeah";
  };
}
