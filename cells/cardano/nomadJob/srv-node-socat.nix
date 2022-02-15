{ namespace
, healthChecks
, socatPort
}:
{
  address_mode = "auto";
  check = [
    {
      address_mode = "host";
      args = [ ];
      command = "${
        builtins.unsafeDiscardStringContext (toString healthChecks.cardano-node-network-testnet-sync)
      }/bin/cardano-node-network-testnet-sync-check";
      interval = "30s";
      # on_update = "ignore_warnings";
      # check_restart.ignore_warnings = true;
      task = "node";
      timeout = "10s";
      type = "script";
    }
  ];
  connect = [
    {
      sidecar_service = [
        {
          proxy = [
            {
              config = [ { envoy_prometheus_bind_addr = "0.0.0.0:9091"; } ];
              local_service_address = "127.0.0.1";
              upstreams = [
                {
                  destination_name = "${namespace}-wallet-synced";
                  local_bind_port = 8090;
                }
                {
                  destination_name = "${namespace}-wallet";
                  local_bind_port = 8091;
                }
              ];
            }
          ];
        }
      ];
    }
  ];
  name = "${namespace}-node-socat";
  port = "${toString socatPort}";
}
