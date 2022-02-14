{ namespace
, healthChecks
}:
{
  address_mode = "auto";
  check = [
    {
      address_mode = "host";
      args = [ ];
      command = "${healthChecks.cardano-db-sync-network-testnet-sync}/bin/cardano-db-sync-network-testnet-sync-check";
      interval = "30s";
      on_update = "ignore_warnings";
      task = "db-sync";
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
                  destination_name = "${namespace}-node-synced";
                  local_bind_port = 3002;
                }
              ];
            }
          ];
        }
      ];
    }
  ];
  name = "${namespace}-dbsync";
  port = "5432";
}
