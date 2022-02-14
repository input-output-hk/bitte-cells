{ namespace
, healthChecks
}:
{
  address_mode = "auto";
  check = [
    {
      address_mode = "host";
      args = [ ];
      command = "${healthChecks.cardano-wallet-network-sync}/bin/cardano-wallet-network-sync-check";
      interval = "30s";
      on_update = "ignore_warnings";
      task = "wallet";
      timeout = "10s";
      type = "script";
    }
    {
      address_mode = "host";
      args = [ ];
      command = "${healthChecks.cardano-wallet-id-sync}/bin/cardano-wallet-id-sync-check";
      interval = "30s";
      on_update = "ignore_warnings";
      task = "wallet";
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
  name = "${namespace}-wallet";
  port = "8090";
}
