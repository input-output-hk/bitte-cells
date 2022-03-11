{
  namespace,
  healthChecks,
}: {
  address_mode = "auto";
  check = [
    {
      address_mode = "host";
      args = [];
      command = "${
        builtins.unsafeDiscardStringContext (toString healthChecks.wallet-network-sync)
      }/bin/cardano-wallet-network-sync-check";
      interval = "30s";
      # on_update = "ignore_warnings";
      # check_restart.ignore_warnings = true;
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
            {config = [{envoy_prometheus_bind_addr = "0.0.0.0:9091";}];}
          ];
        }
      ];
    }
  ];
  name = "${namespace}-wallet";
  port = "8090";
}
